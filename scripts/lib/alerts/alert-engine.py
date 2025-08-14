#!/usr/bin/env python3
"""
Claude Agent Telemetry - Security Alert Engine
Phase 6.1: Enhanced Security Alerting

Real-time security monitoring system that analyzes telemetry logs from Loki
and generates alerts for security violations and suspicious behavior.

Author: Claude Code Agent Telemetry System
Version: 1.0.0
"""

import json
import re
import time
import sys
import os
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple
import requests
import yaml
import hashlib
from dataclasses import dataclass, asdict
from collections import defaultdict, deque

# Add the project root to Python path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


@dataclass
class Alert:
    """Represents a security alert"""
    alert_id: str
    rule_name: str
    severity: str
    description: str
    category: str
    timestamp: str
    session_id: str
    context: Dict[str, Any]
    raw_log: Dict[str, Any]
    escalation_count: int = 0
    

@dataclass
class AlertRule:
    """Represents a security detection rule"""
    name: str
    enabled: bool
    severity: str
    pattern: Optional[str]
    description: str
    category: str
    response: Dict[str, Any]
    context_fields: List[str]
    compiled_pattern: Optional[re.Pattern] = None
    threshold: Optional[Dict[str, Any]] = None


class LokiClient:
    """Client for interacting with Loki API"""
    
    def __init__(self, base_url: str = "http://localhost:3100"):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.timeout = 10
        
    def query_range(self, query: str, start: datetime, end: datetime, limit: int = 1000) -> List[Dict]:
        """Query Loki for log entries in a time range"""
        url = f"{self.base_url}/loki/api/v1/query_range"
        params = {
            'query': query,
            'start': int(start.timestamp() * 1_000_000_000),  # nanoseconds
            'end': int(end.timestamp() * 1_000_000_000),
            'limit': limit
        }
        
        try:
            response = self.session.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            
            # Extract log entries from Loki response format
            logs = []
            if 'data' in data and 'result' in data['data']:
                for stream in data['data']['result']:
                    for entry in stream.get('values', []):
                        timestamp, log_line = entry
                        try:
                            # Try to parse as JSON
                            log_data = json.loads(log_line)
                            log_data['_timestamp'] = timestamp
                            logs.append(log_data)
                        except json.JSONDecodeError:
                            # If not JSON, create a simple structure
                            logs.append({
                                '_timestamp': timestamp,
                                '_raw': log_line
                            })
            return logs
            
        except requests.RequestException as e:
            logging.error(f"Loki query failed: {e}")
            return []
    
    def health_check(self) -> bool:
        """Check if Loki is healthy"""
        try:
            response = self.session.get(f"{self.base_url}/ready", timeout=5)
            return response.status_code == 200
        except requests.RequestException:
            return False


class AlertDeduplicator:
    """Handles alert deduplication to prevent spam"""
    
    def __init__(self, config: Dict[str, Any]):
        self.enabled = config.get('enabled', True)
        self.window_minutes = config.get('window_minutes', 5)
        self.key_fields = config.get('key_fields', ['rule_name', 'session_id'])
        self.max_occurrences = config.get('max_occurrences', 3)
        self.alert_history = defaultdict(deque)
        
    def should_alert(self, alert: Alert) -> bool:
        """Check if alert should be sent or is a duplicate"""
        if not self.enabled:
            return True
            
        # Generate deduplication key
        key_values = []
        for field in self.key_fields:
            if hasattr(alert, field):
                key_values.append(str(getattr(alert, field)))
            elif field in alert.context:
                key_values.append(str(alert.context[field]))
                
        dedup_key = "|".join(key_values)
        
        # Check recent alerts for this key
        now = datetime.fromisoformat(alert.timestamp)
        cutoff_time = now - timedelta(minutes=self.window_minutes)
        
        # Clean old entries
        history = self.alert_history[dedup_key]
        while history and history[0] < cutoff_time:
            history.popleft()
            
        # Check if we should suppress this alert
        if len(history) >= self.max_occurrences:
            return False
            
        # Add this alert to history
        history.append(now)
        return True


class BehavioralAnalyzer:
    """Analyzes behavioral patterns for anomaly detection"""
    
    def __init__(self):
        self.session_stats = defaultdict(lambda: {
            'operations': [],
            'scope_violations': 0,
            'start_time': None
        })
        
    def analyze_session(self, session_id: str, log_entry: Dict) -> List[Alert]:
        """Analyze session behavior for anomalies"""
        alerts = []
        stats = self.session_stats[session_id]
        
        # Initialize session tracking
        timestamp_str = log_entry.get('timestamp', '')
        if not timestamp_str:
            timestamp = datetime.now()
        else:
            try:
                timestamp = datetime.fromisoformat(timestamp_str)
            except ValueError:
                timestamp = datetime.now()
        if stats['start_time'] is None:
            stats['start_time'] = timestamp
            
        # Track operations
        stats['operations'].append(timestamp)
        
        # Clean old operations (keep last hour)
        cutoff = timestamp - timedelta(hours=1)
        stats['operations'] = [ts for ts in stats['operations'] if ts > cutoff]
        
        # Check for high frequency operations
        recent_ops = [ts for ts in stats['operations'] if ts > timestamp - timedelta(minutes=5)]
        if len(recent_ops) > 20:  # More than 20 operations in 5 minutes
            alert = Alert(
                alert_id=self._generate_alert_id("high_frequency", session_id),
                rule_name="high_frequency_operations",
                severity="MEDIUM",
                description="Unusually high frequency of operations detected",
                category="behavioral_anomaly",
                timestamp=timestamp.isoformat(),
                session_id=session_id,
                context={
                    "operation_count": len(recent_ops),
                    "time_window": "5 minutes",
                    "operations_per_minute": len(recent_ops) / 5
                },
                raw_log=log_entry
            )
            alerts.append(alert)
            
        # Track scope violations
        if log_entry.get('action_details', {}).get('outside_project_scope'):
            stats['scope_violations'] += 1
            
            # Check for repeated scope violations
            if stats['scope_violations'] >= 3:
                alert = Alert(
                    alert_id=self._generate_alert_id("repeated_scope", session_id),
                    rule_name="repeated_scope_violations",
                    severity="HIGH",
                    description="Multiple scope violations in session",
                    category="behavioral_anomaly",
                    timestamp=timestamp.isoformat(),
                    session_id=session_id,
                    context={
                        "violation_count": stats['scope_violations'],
                        "session_duration": str(timestamp - stats['start_time'])
                    },
                    raw_log=log_entry
                )
                alerts.append(alert)
                
        return alerts
    
    def _generate_alert_id(self, rule_type: str, session_id: str) -> str:
        """Generate unique alert ID"""
        content = f"{rule_type}_{session_id}_{int(time.time())}"
        return hashlib.md5(content.encode()).hexdigest()[:12]


class SecurityAlertEngine:
    """Main security alert engine"""
    
    def __init__(self, config_path: str):
        self.config_path = Path(config_path)
        self.config = self._load_config()
        self.loki_client = LokiClient()
        self.rules = self._load_rules()
        self.deduplicator = AlertDeduplicator(self.config.get('deduplication', {}))
        self.behavioral_analyzer = BehavioralAnalyzer()
        self.last_check_time = datetime.now() - timedelta(hours=1)  # Start 1 hour ago
        self.alert_count = 0
        self.error_count = 0
        
        # Setup logging
        self._setup_logging()
        
        # Setup notification systems - import here to avoid circular imports
        scripts_path = str(PROJECT_ROOT / 'scripts')
        if scripts_path not in sys.path:
            sys.path.insert(0, scripts_path)
        try:
            import notification_dispatcher
            self.notifier = notification_dispatcher.NotificationDispatcher(self.config.get('notifications', {}))
        except ImportError as e:
            logging.warning(f"Notification dispatcher not available: {e}")
            self.notifier = None
        
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file"""
        try:
            with open(self.config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            logging.error(f"Failed to load config: {e}")
            return {}
            
    def _load_rules(self) -> List[AlertRule]:
        """Load and compile security rules"""
        rules = []
        rules_config = self.config.get('rules', {})
        
        for rule_name, rule_config in rules_config.items():
            if not rule_config.get('enabled', True):
                continue
                
            rule = AlertRule(
                name=rule_name,
                enabled=rule_config.get('enabled', True),
                severity=rule_config.get('severity', 'MEDIUM'),
                pattern=rule_config.get('pattern'),
                description=rule_config.get('description', ''),
                category=rule_config.get('category', 'general'),
                response=rule_config.get('response', {}),
                context_fields=rule_config.get('context_fields', []),
                threshold=rule_config.get('threshold')
            )
            
            # Compile regex pattern if present
            if rule.pattern:
                try:
                    rule.compiled_pattern = re.compile(rule.pattern, re.IGNORECASE)
                except re.error as e:
                    logging.error(f"Invalid regex pattern in rule {rule_name}: {e}")
                    continue
                    
            rules.append(rule)
            
        logging.info(f"Loaded {len(rules)} alert rules")
        return rules
        
    def _setup_logging(self):
        """Setup logging configuration"""
        log_level = logging.INFO
        log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(log_level)
        console_handler.setFormatter(logging.Formatter(log_format))
        
        # File handler
        log_file = PROJECT_ROOT / 'data' / 'alerts' / 'alert-engine.log'
        log_file.parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(log_level)
        file_handler.setFormatter(logging.Formatter(log_format))
        
        # Configure root logger
        logging.basicConfig(
            level=log_level,
            handlers=[console_handler, file_handler],
            format=log_format
        )
        
    def check_health(self) -> bool:
        """Check system health"""
        if not self.loki_client.health_check():
            logging.error("Loki health check failed")
            return False
            
        # Check error rate
        max_errors = self.config.get('reliability', {}).get('max_consecutive_errors', 5)
        if self.error_count >= max_errors:
            logging.error(f"Too many consecutive errors: {self.error_count}")
            return False
            
        return True
        
    def process_logs(self) -> List[Alert]:
        """Process new logs and generate alerts"""
        alerts = []
        
        # Query for new logs since last check
        end_time = datetime.now()
        query = '{service="claude-telemetry"}'
        
        try:
            logs = self.loki_client.query_range(
                query=query,
                start=self.last_check_time,
                end=end_time,
                limit=1000
            )
            
            logging.debug(f"Processing {len(logs)} log entries")
            
            for log_entry in logs:
                # Apply pattern-based rules
                for rule in self.rules:
                    if rule.compiled_pattern:
                        alert = self._check_pattern_rule(rule, log_entry)
                        if alert:
                            alerts.append(alert)
                            
                # Apply behavioral analysis
                session_id = log_entry.get('session_id', 'unknown')
                behavioral_alerts = self.behavioral_analyzer.analyze_session(session_id, log_entry)
                alerts.extend(behavioral_alerts)
                
            # Update last check time
            self.last_check_time = end_time
            self.error_count = 0  # Reset error count on successful processing
            
        except Exception as e:
            self.error_count += 1
            logging.error(f"Error processing logs: {e}")
            
        return alerts
        
    def _check_pattern_rule(self, rule: AlertRule, log_entry: Dict) -> Optional[Alert]:
        """Check if log entry matches a pattern rule"""
        # Convert log entry to searchable text
        log_text = json.dumps(log_entry, default=str)
        
        if rule.compiled_pattern and rule.compiled_pattern.search(log_text):
            # Extract context fields
            context = {}
            for field in rule.context_fields:
                if '.' in field:
                    # Handle nested fields like "action_details.command"
                    keys = field.split('.')
                    value = log_entry
                    for key in keys:
                        value = value.get(key, '') if isinstance(value, dict) else ''
                        if not value:
                            break
                    context[field] = value
                else:
                    context[field] = log_entry.get(field, '')
                    
            # Handle timestamp
            timestamp_str = log_entry.get('timestamp', '')
            if not timestamp_str:
                timestamp_str = datetime.now().isoformat()
            
            alert = Alert(
                alert_id=self._generate_alert_id(rule.name, log_entry),
                rule_name=rule.name,
                severity=rule.severity,
                description=rule.description,
                category=rule.category,
                timestamp=timestamp_str,
                session_id=log_entry.get('session_id', 'unknown'),
                context=context,
                raw_log=log_entry
            )
            
            return alert
            
        return None
        
    def _generate_alert_id(self, rule_name: str, log_entry: Dict) -> str:
        """Generate unique alert ID"""
        content = f"{rule_name}_{log_entry.get('session_id', '')}_{log_entry.get('timestamp', '')}"
        return hashlib.md5(content.encode()).hexdigest()[:12]
        
    def run_once(self) -> int:
        """Run one cycle of alert processing"""
        if not self.check_health():
            return 1
            
        alerts = self.process_logs()
        
        # Process alerts through deduplication and notification
        sent_alerts = 0
        for alert in alerts:
            if self.deduplicator.should_alert(alert):
                try:
                    if self.notifier:
                        self.notifier.send_alert(alert)
                    else:
                        # Fallback to console output
                        print(f"ALERT [{alert.severity}] {alert.rule_name}: {alert.description}")
                    sent_alerts += 1
                    self.alert_count += 1
                    logging.info(f"Alert sent: {alert.rule_name} - {alert.description}")
                except Exception as e:
                    logging.error(f"Failed to send alert: {e}")
                    
        if alerts:
            logging.info(f"Processed {len(alerts)} alerts, sent {sent_alerts}")
            
        return 0
        
    def run_continuous(self):
        """Run continuous monitoring loop"""
        poll_interval = self.config.get('settings', {}).get('poll_interval', 5)
        
        logging.info("Starting continuous monitoring...")
        
        try:
            while True:
                start_time = time.time()
                
                result = self.run_once()
                if result != 0:
                    logging.warning("Alert processing returned error, continuing...")
                    
                # Sleep for remaining poll interval
                elapsed = time.time() - start_time
                sleep_time = max(0, poll_interval - elapsed)
                time.sleep(sleep_time)
                
        except KeyboardInterrupt:
            logging.info("Received interrupt signal, shutting down...")
        except Exception as e:
            logging.error(f"Fatal error in monitoring loop: {e}")
            raise


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Claude Agent Telemetry Security Alert Engine")
    parser.add_argument('--config', default='config/alerts/security-rules.yaml',
                        help='Path to configuration file')
    parser.add_argument('--once', action='store_true',
                        help='Run once and exit (default: continuous)')
    parser.add_argument('--test', action='store_true',
                        help='Test configuration and exit')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Enable verbose logging')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
        
    # Initialize alert engine
    config_path = PROJECT_ROOT / args.config
    if not config_path.exists():
        print(f"Configuration file not found: {config_path}")
        return 1
        
    try:
        engine = SecurityAlertEngine(config_path)
        
        if args.test:
            print("Configuration loaded successfully")
            print(f"Loaded {len(engine.rules)} rules")
            print("Health check:", "PASS" if engine.check_health() else "FAIL")
            return 0
            
        if args.once:
            return engine.run_once()
        else:
            engine.run_continuous()
            return 0
            
    except Exception as e:
        logging.error(f"Failed to start alert engine: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())