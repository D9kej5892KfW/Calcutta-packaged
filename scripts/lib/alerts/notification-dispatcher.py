#!/usr/bin/env python3
"""
Claude Agent Telemetry - Notification Dispatcher
Phase 6.1: Enhanced Security Alerting

Multi-channel notification system for security alerts with support for
console output, log files, email, webhooks, and Grafana integration.

Author: Claude Code Agent Telemetry System
Version: 1.0.0
"""

import json
import logging
import smtplib
import time
from datetime import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path
from typing import Dict, Any, List, Optional
from dataclasses import asdict
import requests
import os
import sys


class ConsoleNotifier:
    """Console output notification handler"""
    
    def __init__(self, config: Dict[str, Any]):
        self.enabled = config.get('enabled', True)
        self.min_severity = config.get('min_severity', 'MEDIUM')
        self.format = config.get('format', 'text')
        self.colors = config.get('colors', True)
        
        # ANSI color codes
        self.colors_map = {
            'CRITICAL': '\033[91m',  # Red
            'HIGH': '\033[93m',      # Yellow
            'MEDIUM': '\033[94m',    # Blue
            'LOW': '\033[92m',       # Green
            'RESET': '\033[0m'       # Reset
        } if self.colors else {}
        
        # Severity levels for filtering
        self.severity_levels = {'CRITICAL': 4, 'HIGH': 3, 'MEDIUM': 2, 'LOW': 1}
        
    def should_notify(self, severity: str) -> bool:
        """Check if alert meets minimum severity threshold"""
        if not self.enabled:
            return False
        current_level = self.severity_levels.get(severity, 0)
        min_level = self.severity_levels.get(self.min_severity, 2)
        return current_level >= min_level
        
    def send(self, alert) -> bool:
        """Send alert to console"""
        if not self.should_notify(alert.severity):
            return True
            
        try:
            if self.format == 'json':
                alert_data = asdict(alert)
                print(json.dumps(alert_data, indent=2, default=str))
            else:
                # Text format with colors
                color = self.colors_map.get(alert.severity, '')
                reset = self.colors_map.get('RESET', '')
                
                timestamp = datetime.fromisoformat(alert.timestamp).strftime('%Y-%m-%d %H:%M:%S')
                
                print(f"{color}[{alert.severity}] {timestamp}{reset}")
                print(f"Rule: {alert.rule_name}")
                print(f"Description: {alert.description}")
                print(f"Session: {alert.session_id}")
                print(f"Category: {alert.category}")
                
                if alert.context:
                    print("Context:")
                    for key, value in alert.context.items():
                        print(f"  {key}: {value}")
                        
                print("-" * 60)
                
            return True
            
        except Exception as e:
            logging.error(f"Console notification failed: {e}")
            return False


class LogFileNotifier:
    """Log file notification handler with rotation"""
    
    def __init__(self, config: Dict[str, Any]):
        self.enabled = config.get('enabled', True)
        self.log_path = Path(config.get('path', 'data/alerts/security-alerts.log'))
        self.format = config.get('format', 'json')
        self.rotation_config = config.get('rotation', {})
        
        # Create log directory
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
        
    def send(self, alert) -> bool:
        """Write alert to log file"""
        if not self.enabled:
            return True
            
        try:
            # Check if rotation is needed
            self._rotate_if_needed()
            
            # Format alert
            if self.format == 'json':
                alert_data = asdict(alert)
                log_line = json.dumps(alert_data, default=str)
            else:
                log_line = f"{alert.timestamp} [{alert.severity}] {alert.rule_name}: {alert.description}"
                
            # Write to file
            with open(self.log_path, 'a') as f:
                f.write(log_line + '\n')
                f.flush()
                
            return True
            
        except Exception as e:
            logging.error(f"Log file notification failed: {e}")
            return False
            
    def _rotate_if_needed(self):
        """Rotate log file if size limit exceeded"""
        if not self.log_path.exists():
            return
            
        max_size_mb = self.rotation_config.get('max_size_mb', 100)
        keep_files = self.rotation_config.get('keep_files', 5)
        
        # Check file size
        size_mb = self.log_path.stat().st_size / (1024 * 1024)
        if size_mb < max_size_mb:
            return
            
        # Rotate files
        for i in range(keep_files - 1, 0, -1):
            old_file = self.log_path.with_suffix(f'.log.{i}')
            new_file = self.log_path.with_suffix(f'.log.{i + 1}')
            if old_file.exists():
                old_file.rename(new_file)
                
        # Move current log to .1
        self.log_path.rename(self.log_path.with_suffix('.log.1'))


class EmailNotifier:
    """Email notification handler"""
    
    def __init__(self, config: Dict[str, Any]):
        self.enabled = config.get('enabled', False)
        self.smtp_server = config.get('smtp_server', 'localhost')
        self.smtp_port = config.get('smtp_port', 587)
        self.use_tls = config.get('use_tls', True)
        self.username = config.get('username', '')
        self.password = config.get('password', '')
        self.from_address = config.get('from_address', 'claude-alerts@localhost')
        self.recipients = config.get('recipients', {})
        self.subject_template = config.get('subject_template', '[CLAUDE-ALERT-{severity}] {description}')
        
    def send(self, alert) -> bool:
        """Send alert via email"""
        if not self.enabled:
            return True
            
        # Get recipients for this severity level
        recipients = self._get_recipients(alert.severity)
        if not recipients:
            return True
            
        try:
            # Create message
            msg = MIMEMultipart()
            msg['From'] = self.from_address
            msg['To'] = ', '.join(recipients)
            msg['Subject'] = self.subject_template.format(
                severity=alert.severity,
                description=alert.description,
                rule_name=alert.rule_name
            )
            
            # Create email body
            body = self._create_email_body(alert)
            msg.attach(MIMEText(body, 'plain'))
            
            # Send email
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                if self.use_tls:
                    server.starttls()
                if self.username and self.password:
                    server.login(self.username, self.password)
                    
                server.send_message(msg)
                
            logging.info(f"Email sent for alert {alert.alert_id} to {len(recipients)} recipients")
            return True
            
        except Exception as e:
            logging.error(f"Email notification failed: {e}")
            return False
            
    def _get_recipients(self, severity: str) -> List[str]:
        """Get email recipients for given severity"""
        if severity in self.recipients:
            return self.recipients[severity]
        return self.recipients.get('default', [])
        
    def _create_email_body(self, alert) -> str:
        """Create formatted email body"""
        timestamp = datetime.fromisoformat(alert.timestamp).strftime('%Y-%m-%d %H:%M:%S UTC')
        
        body = f"""Claude Agent Telemetry Security Alert

Alert Details:
  ID: {alert.alert_id}
  Severity: {alert.severity}
  Rule: {alert.rule_name}
  Description: {alert.description}
  Category: {alert.category}
  Timestamp: {timestamp}
  Session ID: {alert.session_id}

Context Information:
"""
        
        for key, value in alert.context.items():
            body += f"  {key}: {value}\n"
            
        body += f"""
Raw Log Entry:
{json.dumps(alert.raw_log, indent=2, default=str)}

--
Claude Agent Telemetry System
"""
        
        return body


class WebhookNotifier:
    """Webhook notification handler"""
    
    def __init__(self, config: Dict[str, Any]):
        self.enabled = config.get('enabled', False)
        self.url = config.get('url', '')
        self.method = config.get('method', 'POST')
        self.headers = config.get('headers', {'Content-Type': 'application/json'})
        self.timeout = config.get('timeout_seconds', 10)
        self.retry_attempts = config.get('retry_attempts', 3)
        self.payload_template = config.get('payload_template', '')
        
    def send(self, alert) -> bool:
        """Send alert via webhook"""
        if not self.enabled or not self.url:
            return True
            
        # Create payload
        payload = self._create_payload(alert)
        
        # Send with retries
        for attempt in range(self.retry_attempts):
            try:
                response = requests.request(
                    method=self.method,
                    url=self.url,
                    headers=self.headers,
                    json=payload,
                    timeout=self.timeout
                )
                response.raise_for_status()
                
                logging.info(f"Webhook sent for alert {alert.alert_id}")
                return True
                
            except requests.RequestException as e:
                logging.warning(f"Webhook attempt {attempt + 1} failed: {e}")
                if attempt < self.retry_attempts - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
                    
        logging.error(f"Webhook notification failed after {self.retry_attempts} attempts")
        return False
        
    def _create_payload(self, alert) -> Dict[str, Any]:
        """Create webhook payload"""
        if self.payload_template:
            # Use template
            template_vars = {
                'alert_id': alert.alert_id,
                'severity': alert.severity,
                'description': alert.description,
                'timestamp': alert.timestamp,
                'category': alert.category,
                'session_id': alert.session_id,
                'context': json.dumps(alert.context)
            }
            
            payload_str = self.payload_template.format(**template_vars)
            return json.loads(payload_str)
        else:
            # Default payload
            return asdict(alert)


class GrafanaNotifier:
    """Grafana annotation integration"""
    
    def __init__(self, config: Dict[str, Any]):
        self.enabled = config.get('enabled', True)
        self.url = config.get('url', 'http://localhost:3000')
        self.api_key = config.get('api_key', '')
        self.dashboard_uid = config.get('dashboard_uid', 'claude-performance-fixed')
        self.annotation_tags = config.get('annotation_tags', ['security', 'alert'])
        
    def send(self, alert) -> bool:
        """Create Grafana annotation for alert"""
        if not self.enabled:
            return True
            
        try:
            # Create annotation data
            timestamp_ms = int(datetime.fromisoformat(alert.timestamp).timestamp() * 1000)
            
            annotation = {
                'dashboardUID': self.dashboard_uid,
                'time': timestamp_ms,
                'timeEnd': timestamp_ms + 60000,  # 1 minute duration
                'tags': self.annotation_tags + [alert.severity.lower(), alert.category],
                'text': f"{alert.description} (Rule: {alert.rule_name})",
                'title': f"Security Alert: {alert.severity}"
            }
            
            # Send to Grafana API (if API key provided)
            if self.api_key:
                headers = {
                    'Authorization': f'Bearer {self.api_key}',
                    'Content-Type': 'application/json'
                }
                
                response = requests.post(
                    f"{self.url}/api/annotations",
                    headers=headers,
                    json=annotation,
                    timeout=10
                )
                response.raise_for_status()
                
            logging.info(f"Grafana annotation created for alert {alert.alert_id}")
            return True
            
        except Exception as e:
            logging.warning(f"Grafana notification failed: {e}")
            return False  # Don't fail the whole alert for Grafana issues


class NotificationDispatcher:
    """Main notification dispatcher that coordinates all notification channels"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        
        # Initialize notification handlers
        self.handlers = []
        
        if 'console' in config:
            self.handlers.append(ConsoleNotifier(config['console']))
            
        if 'logfile' in config:
            self.handlers.append(LogFileNotifier(config['logfile']))
            
        if 'email' in config:
            self.handlers.append(EmailNotifier(config['email']))
            
        if 'webhook' in config:
            self.handlers.append(WebhookNotifier(config['webhook']))
            
        if 'grafana' in config:
            self.handlers.append(GrafanaNotifier(config['grafana']))
            
        logging.info(f"Initialized {len(self.handlers)} notification handlers")
        
    def send_alert(self, alert) -> bool:
        """Send alert through all configured notification channels"""
        success_count = 0
        total_handlers = len(self.handlers)
        
        for handler in self.handlers:
            try:
                if handler.send(alert):
                    success_count += 1
            except Exception as e:
                logging.error(f"Notification handler failed: {e}")
                
        # Consider successful if at least one handler worked
        success = success_count > 0
        
        if not success:
            logging.error(f"All notification handlers failed for alert {alert.alert_id}")
        elif success_count < total_handlers:
            logging.warning(f"Some notification handlers failed ({success_count}/{total_handlers})")
            
        return success


def main():
    """Test notification system"""
    import argparse
    from dataclasses import dataclass
    
    # Define Alert class for testing (avoid circular import)
    @dataclass
    class Alert:
        alert_id: str
        rule_name: str
        severity: str
        description: str
        category: str
        timestamp: str
        session_id: str
        context: dict
        raw_log: dict
        escalation_count: int = 0
    
    parser = argparse.ArgumentParser(description="Claude Agent Telemetry Notification Dispatcher")
    parser.add_argument('--test', action='store_true', help='Send test alert')
    parser.add_argument('--config', default='config/alerts/security-rules.yaml',
                        help='Path to configuration file')
    
    args = parser.parse_args()
    
    if args.test:
        # Load configuration
        import yaml
        with open(args.config, 'r') as f:
            config = yaml.safe_load(f)
            
        # Create test alert
        test_alert = Alert(
            alert_id="test123",
            rule_name="test_rule",
            severity="MEDIUM",
            description="Test security alert",
            category="test",
            timestamp=datetime.now().isoformat(),
            session_id="test-session",
            context={"test_field": "test_value"},
            raw_log={"test": "data"}
        )
        
        # Send test alert
        dispatcher = NotificationDispatcher(config.get('notifications', {}))
        success = dispatcher.send_alert(test_alert)
        
        print(f"Test alert sent: {'SUCCESS' if success else 'FAILED'}")
        return 0 if success else 1
        
    print("Use --test to send a test alert")
    return 0


if __name__ == '__main__':
    sys.exit(main())