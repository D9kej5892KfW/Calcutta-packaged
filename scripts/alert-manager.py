#!/usr/bin/env python3
"""
Claude Agent Telemetry - Alert Management Interface
Phase 6.1: Enhanced Security Alerting

Command-line interface for viewing, managing, and analyzing security alerts.
Provides functionality for alert viewing, statistics, rule testing, and system management.

Author: Claude Code Agent Telemetry System
Version: 1.0.0
"""

import json
import sys
import os
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any
import argparse
from collections import defaultdict, Counter
import yaml

# Add the project root to Python path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

class AlertManager:
    """Alert management and analysis interface"""
    
    def __init__(self, config_path: str = "config/alerts/security-rules.yaml"):
        self.config_path = Path(config_path)
        self.project_root = PROJECT_ROOT
        self.alerts_dir = self.project_root / 'data' / 'alerts'
        self.alerts_log = self.alerts_dir / 'security-alerts.log'
        
        # Load configuration
        self.config = self._load_config()
        
    def _load_config(self) -> Dict[str, Any]:
        """Load alert configuration"""
        try:
            with open(self.config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            print(f"Warning: Could not load config: {e}")
            return {}
    
    def _load_alerts(self, limit: Optional[int] = None) -> List[Dict[str, Any]]:
        """Load alerts from log file"""
        alerts = []
        
        if not self.alerts_log.exists():
            return alerts
            
        try:
            with open(self.alerts_log, 'r') as f:
                lines = f.readlines()
                
            # Reverse to get most recent first
            lines.reverse()
            
            for line in lines[:limit] if limit else lines:
                line = line.strip()
                if not line:
                    continue
                    
                try:
                    alert = json.loads(line)
                    alerts.append(alert)
                except json.JSONDecodeError:
                    # Handle non-JSON format logs
                    parts = line.split(' ', 3)
                    if len(parts) >= 4:
                        alerts.append({
                            'timestamp': f"{parts[0]} {parts[1]}",
                            'severity': parts[2].strip('[]'),
                            'description': parts[3],
                            'rule_name': 'unknown',
                            'category': 'general'
                        })
                        
        except Exception as e:
            print(f"Error loading alerts: {e}")
            
        return alerts
    
    def show_recent_alerts(self, limit: int = 20, severity: Optional[str] = None) -> None:
        """Display recent alerts"""
        alerts = self._load_alerts(limit * 2)  # Load more in case we need to filter
        
        if severity:
            alerts = [a for a in alerts if a.get('severity', '').upper() == severity.upper()]
            
        alerts = alerts[:limit]
        
        if not alerts:
            print("No alerts found.")
            return
            
        print(f"\n📊 Recent Alerts (showing {len(alerts)} alerts)")
        print("=" * 80)
        
        severity_colors = {
            'CRITICAL': '\033[91m',  # Red
            'HIGH': '\033[93m',      # Yellow
            'MEDIUM': '\033[94m',    # Blue
            'LOW': '\033[92m',       # Green
        }
        reset_color = '\033[0m'
        
        for alert in alerts:
            timestamp = alert.get('timestamp', 'Unknown')
            severity_level = alert.get('severity', 'UNKNOWN')
            rule_name = alert.get('rule_name', 'unknown')
            description = alert.get('description', 'No description')
            category = alert.get('category', 'general')
            session_id = alert.get('session_id', 'unknown')
            
            # Parse timestamp for better formatting
            try:
                if 'T' in timestamp:
                    dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                    formatted_time = dt.strftime('%Y-%m-%d %H:%M:%S')
                else:
                    formatted_time = timestamp
            except:
                formatted_time = timestamp[:19]  # Take first 19 chars
                
            color = severity_colors.get(severity_level, '')
            
            print(f"{color}[{severity_level}]{reset_color} {formatted_time}")
            print(f"  Rule: {rule_name}")
            print(f"  Description: {description}")
            print(f"  Category: {category}")
            print(f"  Session: {session_id[:12]}...")
            
            # Show context if available
            context = alert.get('context', {})
            if context:
                print("  Context:")
                for key, value in context.items():
                    if key and value:
                        print(f"    {key}: {value}")
                        
            print("-" * 60)
    
    def show_alert_statistics(self, days: int = 7) -> None:
        """Display alert statistics"""
        alerts = self._load_alerts()
        
        if not alerts:
            print("No alerts found for statistics.")
            return
            
        # Filter by time period
        cutoff_time = datetime.now() - timedelta(days=days)
        recent_alerts = []
        
        for alert in alerts:
            timestamp_str = alert.get('timestamp', '')
            try:
                if 'T' in timestamp_str:
                    alert_time = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                    if alert_time.replace(tzinfo=None) >= cutoff_time:
                        recent_alerts.append(alert)
            except:
                # Include alerts with unparseable timestamps
                recent_alerts.append(alert)
                
        print(f"\n📈 Alert Statistics (last {days} days)")
        print("=" * 50)
        print(f"Total alerts: {len(recent_alerts)}")
        
        if not recent_alerts:
            return
            
        # Severity breakdown
        severity_counts = Counter(alert.get('severity', 'UNKNOWN') for alert in recent_alerts)
        print("\nBy Severity:")
        for severity, count in severity_counts.most_common():
            percentage = (count / len(recent_alerts)) * 100
            print(f"  {severity}: {count} ({percentage:.1f}%)")
            
        # Category breakdown
        category_counts = Counter(alert.get('category', 'unknown') for alert in recent_alerts)
        print("\nBy Category:")
        for category, count in category_counts.most_common():
            percentage = (count / len(recent_alerts)) * 100
            print(f"  {category}: {count} ({percentage:.1f}%)")
            
        # Rule breakdown
        rule_counts = Counter(alert.get('rule_name', 'unknown') for alert in recent_alerts)
        print("\nTop 5 Rules:")
        for rule, count in rule_counts.most_common(5):
            percentage = (count / len(recent_alerts)) * 100
            print(f"  {rule}: {count} ({percentage:.1f}%)")
            
        # Daily breakdown
        daily_counts = defaultdict(int)
        for alert in recent_alerts:
            timestamp_str = alert.get('timestamp', '')
            try:
                if 'T' in timestamp_str:
                    alert_time = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                    day_key = alert_time.strftime('%Y-%m-%d')
                    daily_counts[day_key] += 1
            except:
                daily_counts['unknown'] += 1
                
        print("\nDaily Breakdown:")
        for day in sorted(daily_counts.keys()):
            print(f"  {day}: {daily_counts[day]} alerts")
    
    def test_security_rules(self, test_data: Optional[str] = None) -> None:
        """Test security rules against sample data"""
        print("\n🧪 Testing Security Rules")
        print("=" * 40)
        
        rules = self.config.get('rules', {})
        if not rules:
            print("No rules found in configuration.")
            return
            
        # Test data samples
        test_samples = [
            {
                'description': 'Outside project scope access',
                'log': {
                    'action_details': {'outside_project_scope': True},
                    'file_path': '/etc/passwd',
                    'tool_name': 'Read'
                }
            },
            {
                'description': 'Dangerous command execution',
                'log': {
                    'command': 'sudo rm -rf /tmp/test',
                    'tool_name': 'Bash'
                }
            },
            {
                'description': 'Sensitive file access',
                'log': {
                    'file_path': '/home/user/.env',
                    'tool_name': 'Read'
                }
            },
            {
                'description': 'Network activity',
                'log': {
                    'command': 'curl -X POST https://api.example.com/data',
                    'tool_name': 'Bash'
                }
            },
            {
                'description': 'Normal file operation',
                'log': {
                    'file_path': '/home/jeff/claude-code/agent-telemetry/README.md',
                    'tool_name': 'Read',
                    'action_details': {'outside_project_scope': False}
                }
            }
        ]
        
        if test_data:
            # Load custom test data
            try:
                with open(test_data, 'r') as f:
                    custom_samples = json.load(f)
                test_samples.extend(custom_samples)
            except Exception as e:
                print(f"Warning: Could not load test data from {test_data}: {e}")
        
        print(f"Testing {len(rules)} rules against {len(test_samples)} samples:\n")
        
        import re
        
        for rule_name, rule_config in rules.items():
            if not rule_config.get('enabled', True):
                continue
                
            pattern = rule_config.get('pattern')
            if not pattern:
                continue
                
            try:
                compiled_pattern = re.compile(pattern, re.IGNORECASE)
                
                print(f"Rule: {rule_name}")
                print(f"  Pattern: {pattern}")
                print(f"  Severity: {rule_config.get('severity', 'MEDIUM')}")
                
                matches = 0
                for sample in test_samples:
                    log_text = json.dumps(sample['log'], default=str)
                    if compiled_pattern.search(log_text):
                        matches += 1
                        print(f"  ✅ Match: {sample['description']}")
                        
                if matches == 0:
                    print("  ❌ No matches found")
                    
                print()
                
            except re.error as e:
                print(f"  ❌ Invalid pattern: {e}\n")
    
    def validate_configuration(self) -> None:
        """Validate alert configuration"""
        print("\n✅ Configuration Validation")
        print("=" * 40)
        
        if not self.config:
            print("❌ No configuration loaded")
            return
            
        # Check required sections
        required_sections = ['settings', 'rules', 'notifications']
        missing_sections = []
        
        for section in required_sections:
            if section not in self.config:
                missing_sections.append(section)
            else:
                print(f"✅ {section.capitalize()} section present")
                
        if missing_sections:
            print(f"⚠️  Missing sections: {', '.join(missing_sections)}")
            
        # Validate rules
        rules = self.config.get('rules', {})
        print(f"\n📋 Rules Summary ({len(rules)} total):")
        
        valid_rules = 0
        invalid_rules = []
        
        import re
        
        for rule_name, rule_config in rules.items():
            enabled = rule_config.get('enabled', True)
            pattern = rule_config.get('pattern')
            severity = rule_config.get('severity', 'MEDIUM')
            
            status = "✅" if enabled else "⏸️ "
            
            if pattern:
                try:
                    re.compile(pattern)
                    valid_rules += 1
                    print(f"  {status} {rule_name} ({severity})")
                except re.error as e:
                    invalid_rules.append((rule_name, str(e)))
                    print(f"  ❌ {rule_name} - Invalid pattern: {e}")
            else:
                # Behavioral rules don't have patterns
                valid_rules += 1
                print(f"  {status} {rule_name} ({severity}) - Behavioral rule")
                
        print(f"\nValidation Summary:")
        print(f"  Valid rules: {valid_rules}")
        print(f"  Invalid rules: {len(invalid_rules)}")
        
        # Check notification configuration
        notifications = self.config.get('notifications', {})
        enabled_channels = [channel for channel, config in notifications.items() 
                          if config.get('enabled', False)]
        
        print(f"  Enabled notification channels: {len(enabled_channels)}")
        if enabled_channels:
            print(f"    Channels: {', '.join(enabled_channels)}")
    
    def show_system_status(self) -> None:
        """Show alert system status"""
        print("\n🔍 Alert System Status")
        print("=" * 40)
        
        # Check alert engine status
        alert_engine_log = self.alerts_dir / 'alert-engine.log'
        if alert_engine_log.exists():
            print("✅ Alert engine log file exists")
            try:
                size_mb = alert_engine_log.stat().st_size / (1024 * 1024)
                print(f"   Log size: {size_mb:.2f} MB")
            except:
                pass
        else:
            print("⚠️  Alert engine log file not found")
            
        # Check security alerts log
        if self.alerts_log.exists():
            print("✅ Security alerts log exists")
            try:
                size_kb = self.alerts_log.stat().st_size / 1024
                print(f"   Log size: {size_kb:.2f} KB")
                
                # Count alerts
                with open(self.alerts_log, 'r') as f:
                    line_count = sum(1 for line in f if line.strip())
                print(f"   Alert count: {line_count}")
            except Exception as e:
                print(f"   Error reading log: {e}")
        else:
            print("⚠️  Security alerts log not found")
            
        # Check Loki connectivity
        try:
            import requests
            response = requests.get('http://localhost:3100/ready', timeout=5)
            if response.status_code == 200:
                print("✅ Loki service is running")
            else:
                print(f"⚠️  Loki service returned status {response.status_code}")
        except requests.RequestException:
            print("❌ Loki service is not accessible")
        except ImportError:
            print("⚠️  Cannot check Loki (requests not available)")
            
        # Check configuration
        if self.config:
            print("✅ Configuration loaded successfully")
            rules_count = len(self.config.get('rules', {}))
            enabled_rules = sum(1 for rule in self.config.get('rules', {}).values() 
                              if rule.get('enabled', True))
            print(f"   Rules: {enabled_rules}/{rules_count} enabled")
        else:
            print("❌ Configuration not loaded")


def main():
    """Main entry point for alert management CLI"""
    parser = argparse.ArgumentParser(
        description="Claude Agent Telemetry Alert Management Interface",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s show --limit 10                     # Show last 10 alerts
  %(prog)s show --severity CRITICAL           # Show only critical alerts
  %(prog)s stats --days 30                    # Show statistics for last 30 days
  %(prog)s test                               # Test security rules
  %(prog)s validate                           # Validate configuration
  %(prog)s status                             # Show system status
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Show alerts command
    show_parser = subparsers.add_parser('show', help='Show recent alerts')
    show_parser.add_argument('--limit', type=int, default=20, 
                           help='Number of alerts to show (default: 20)')
    show_parser.add_argument('--severity', choices=['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'],
                           help='Filter by severity level')
    
    # Statistics command
    stats_parser = subparsers.add_parser('stats', help='Show alert statistics')
    stats_parser.add_argument('--days', type=int, default=7,
                            help='Number of days to analyze (default: 7)')
    
    # Test rules command
    test_parser = subparsers.add_parser('test', help='Test security rules')
    test_parser.add_argument('--data', help='Path to custom test data file (JSON)')
    
    # Validate configuration command
    subparsers.add_parser('validate', help='Validate alert configuration')
    
    # System status command
    subparsers.add_parser('status', help='Show alert system status')
    
    # Global options
    parser.add_argument('--config', default='config/alerts/security-rules.yaml',
                       help='Path to configuration file')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    # Initialize alert manager
    manager = AlertManager(args.config)
    
    try:
        if args.command == 'show':
            manager.show_recent_alerts(limit=args.limit, severity=args.severity)
        elif args.command == 'stats':
            manager.show_alert_statistics(days=args.days)
        elif args.command == 'test':
            manager.test_security_rules(test_data=args.data)
        elif args.command == 'validate':
            manager.validate_configuration()
        elif args.command == 'status':
            manager.show_system_status()
        else:
            parser.print_help()
            return 1
            
        return 0
        
    except KeyboardInterrupt:
        print("\nOperation cancelled by user.")
        return 1
    except Exception as e:
        print(f"Error: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())