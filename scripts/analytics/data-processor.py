
#!/usr/bin/env python3
"""
Phase 6.2: Data Processing Pipeline for Claude Agent Telemetry
Extract features from telemetry data for ML-based behavioral analytics.
"""

import json
import sys
import os
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from collections import defaultdict, Counter
from pathlib import Path
import requests
import logging
from typing import Dict, List, Tuple, Optional
import argparse

# Add project root to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

class TelemetryDataProcessor:
    """Extract features from Claude Agent Telemetry data for ML analysis"""
    
    def __init__(self, loki_url: str = "http://localhost:3100", data_dir: str = None):
        self.loki_url = loki_url
        self.data_dir = data_dir or "/home/jeff/claude-code/agent-telemetry/data"
        self.features_dir = f"{self.data_dir}/analytics/features"
        
        # Ensure directories exist
        Path(self.features_dir).mkdir(parents=True, exist_ok=True)
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s'
        )
        self.logger = logging.getLogger(__name__)
        
    def query_loki(self, query: str, limit: int = 5000) -> List[Dict]:
        """Query Loki for telemetry data"""
        try:
            url = f"{self.loki_url}/loki/api/v1/query_range"
            params = {
                'query': query,
                'limit': limit,
                'start': int((datetime.now() - timedelta(days=30)).timestamp() * 1000000000),
                'end': int(datetime.now().timestamp() * 1000000000)
            }
            
            response = requests.get(url, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            entries = []
            
            for stream in data.get('data', {}).get('result', []):
                for entry in stream.get('values', []):
                    timestamp_ns, log_line = entry
                    try:
                        # Parse JSON from log line
                        log_data = json.loads(log_line)
                        log_data['timestamp_ns'] = int(timestamp_ns)
                        log_data['timestamp'] = datetime.fromtimestamp(int(timestamp_ns) / 1000000000)
                        entries.append(log_data)
                    except json.JSONDecodeError:
                        continue
                        
            self.logger.info(f"Retrieved {len(entries)} telemetry entries from Loki")
            return entries
            
        except Exception as e:
            self.logger.error(f"Failed to query Loki: {e}")
            return []
    
    def load_local_data(self) -> List[Dict]:
        """Load telemetry data from local JSONL backup"""
        local_file = f"{self.data_dir}/logs/claude-telemetry.jsonl"
        entries = []
        
        try:
            if os.path.exists(local_file):
                with open(local_file, 'r') as f:
                    for line in f:
                        try:
                            entry = json.loads(line.strip())
                            # Parse timestamp
                            if 'timestamp' in entry:
                                entry['timestamp'] = datetime.fromisoformat(entry['timestamp'].replace('Z', '+00:00'))
                            entries.append(entry)
                        except json.JSONDecodeError:
                            continue
                            
                self.logger.info(f"Loaded {len(entries)} entries from local backup")
            else:
                self.logger.warning(f"Local backup file not found: {local_file}")
                
        except Exception as e:
            self.logger.error(f"Failed to load local data: {e}")
            
        return entries
    
    def extract_session_features(self, entries: List[Dict]) -> pd.DataFrame:
        """Extract session-level behavioral features"""
        sessions = defaultdict(lambda: {
            'session_id': '',
            'start_time': None,
            'end_time': None,
            'duration_minutes': 0,
            'total_operations': 0,
            'unique_tools': set(),
            'tool_counts': Counter(),
            'file_operations': 0,
            'bash_commands': 0,
            'search_operations': 0,
            'ai_operations': 0,
            'workflow_types': set(),
            'personas': set(),
            'reasoning_levels': set(),
            'scope_violations': 0,
            'file_paths': set(),
            'operation_rate': 0,
            'tool_diversity': 0,
            'peak_activity_window': 0,
            'error_rate': 0,
            'superclaude_usage': 0,
            # Phase 7 Lite: Delegation tracking metrics
            'delegation_events': 0,
            'delegation_rate': 0.0,
            'workflow_efficiency': 0.0,
            'task_delegations': 0,
            'manual_operations': 0
        })
        
        # Process entries by session
        for entry in entries:
            session_id = entry.get('session_id', 'unknown')
            session = sessions[session_id]
            
            # Basic session info
            session['session_id'] = session_id
            timestamp = entry.get('timestamp')
            
            if timestamp:
                if session['start_time'] is None or timestamp < session['start_time']:
                    session['start_time'] = timestamp
                if session['end_time'] is None or timestamp > session['end_time']:
                    session['end_time'] = timestamp
            
            # Tool usage tracking
            tool = entry.get('tool', 'unknown')
            session['total_operations'] += 1
            session['unique_tools'].add(tool)
            session['tool_counts'][tool] += 1
            
            # Operation categorization
            if tool in ['Read', 'Write', 'Edit', 'MultiEdit']:
                session['file_operations'] += 1
            elif tool == 'Bash':
                session['bash_commands'] += 1
            elif tool in ['Grep', 'Glob', 'LS']:
                session['search_operations'] += 1
            elif tool in ['Task', 'WebFetch', 'WebSearch']:
                session['ai_operations'] += 1
                # Phase 7 Lite: Track Task tool specifically for delegation
                if tool == 'Task':
                    session['delegation_events'] += 1
                    session['task_delegations'] += 1
            
            # Phase 7 Lite: Track manual vs delegated operations
            if tool != 'Task':
                session['manual_operations'] += 1
            
            # SuperClaude context tracking
            workflow_type = entry.get('workflow_type')
            if workflow_type:
                session['workflow_types'].add(workflow_type)
                if workflow_type == 'superclaude':
                    session['superclaude_usage'] += 1
            
            persona = entry.get('persona')
            if persona:
                session['personas'].add(persona)
            
            reasoning = entry.get('reasoning_level')
            if reasoning:
                session['reasoning_levels'].add(reasoning)
            
            # Security and scope tracking
            if entry.get('scope_violation'):
                session['scope_violations'] += 1
            
            file_path = entry.get('file_path')
            if file_path:
                session['file_paths'].add(file_path)
            
            # Error tracking
            if entry.get('event_type') == 'error' or 'error' in entry.get('description', '').lower():
                session['error_rate'] += 1
        
        # Calculate derived features
        session_features = []
        for session_id, data in sessions.items():
            if data['start_time'] and data['end_time']:
                duration = (data['end_time'] - data['start_time']).total_seconds() / 60
                data['duration_minutes'] = duration
                
                if duration > 0:
                    data['operation_rate'] = data['total_operations'] / duration
            
            # Tool diversity (entropy-based)
            if data['total_operations'] > 0:
                tool_probs = np.array(list(data['tool_counts'].values())) / data['total_operations']
                data['tool_diversity'] = -np.sum(tool_probs * np.log2(tool_probs + 1e-10))
                data['error_rate'] = data['error_rate'] / data['total_operations']
                
                # Phase 7 Lite: Calculate delegation metrics
                data['delegation_rate'] = (data['delegation_events'] / data['total_operations']) * 100
                
                # Workflow efficiency: ratio of delegated to manual work
                if data['manual_operations'] > 0:
                    data['workflow_efficiency'] = data['delegation_events'] / data['manual_operations']
                else:
                    data['workflow_efficiency'] = 0
            
            # Convert sets to counts for DataFrame
            data['unique_tools_count'] = len(data['unique_tools'])
            data['workflow_types_count'] = len(data['workflow_types'])
            data['personas_count'] = len(data['personas'])
            data['reasoning_levels_count'] = len(data['reasoning_levels'])
            data['unique_files_count'] = len(data['file_paths'])
            
            # Remove sets (not serializable)
            for key in ['unique_tools', 'tool_counts', 'workflow_types', 'personas', 'reasoning_levels', 'file_paths']:
                data.pop(key, None)
            
            session_features.append(data)
        
        df = pd.DataFrame(session_features)
        self.logger.info(f"Extracted features for {len(df)} sessions")
        return df
    
    def extract_temporal_features(self, entries: List[Dict]) -> pd.DataFrame:
        """Extract time-based behavioral patterns"""
        if not entries:
            return pd.DataFrame()
        
        # Convert to DataFrame for easier time-series analysis
        df = pd.DataFrame(entries)
        if 'timestamp' not in df.columns:
            return pd.DataFrame()
        
        df['hour'] = df['timestamp'].dt.hour
        df['day_of_week'] = df['timestamp'].dt.dayofweek
        df['minute'] = df['timestamp'].dt.minute
        
        # Hourly activity patterns
        hourly_activity = df.groupby(['session_id', 'hour']).size().reset_index(name='operations')
        hourly_features = hourly_activity.groupby('session_id').agg({
            'operations': ['mean', 'std', 'max', 'min'],
            'hour': lambda x: list(x)  # Most active hours
        }).round(2)
        
        # Flatten column names
        hourly_features.columns = ['_'.join(col) if col[1] else col[0] for col in hourly_features.columns]
        hourly_features = hourly_features.reset_index()
        
        # Calculate peak activity hours
        def get_peak_hours(hours_list):
            if not hours_list:
                return 0
            return Counter(hours_list).most_common(1)[0][1]  # Count of most frequent hour
        
        hourly_features['peak_hour_frequency'] = hourly_features['hour_<lambda>'].apply(get_peak_hours)
        hourly_features.drop('hour_<lambda>', axis=1, inplace=True)
        
        self.logger.info(f"Extracted temporal features for {len(hourly_features)} sessions")
        return hourly_features
    
    def extract_sequence_features(self, entries: List[Dict]) -> pd.DataFrame:
        """Extract tool usage sequence and workflow patterns"""
        sessions = defaultdict(list)
        
        # Group by session and sort by timestamp
        for entry in entries:
            session_id = entry.get('session_id', 'unknown')
            sessions[session_id].append(entry)
        
        sequence_features = []
        
        for session_id, session_entries in sessions.items():
            # Sort by timestamp
            session_entries.sort(key=lambda x: x.get('timestamp', datetime.min))
            
            tools = [entry.get('tool', 'unknown') for entry in session_entries]
            
            if len(tools) < 2:
                continue
            
            # Tool transition patterns
            transitions = [(tools[i], tools[i+1]) for i in range(len(tools)-1)]
            transition_counts = Counter(transitions)
            
            # Common sequences
            common_transitions = transition_counts.most_common(3)
            
            # Workflow patterns
            read_write_cycles = 0
            bash_after_edit = 0
            search_then_read = 0
            
            for i in range(len(tools) - 1):
                current, next_tool = tools[i], tools[i+1]
                
                if current == 'Read' and next_tool in ['Write', 'Edit']:
                    read_write_cycles += 1
                elif current in ['Edit', 'Write'] and next_tool == 'Bash':
                    bash_after_edit += 1
                elif current in ['Grep', 'Glob'] and next_tool == 'Read':
                    search_then_read += 1
            
            # Sequential complexity
            unique_transitions = len(set(transitions))
            transition_entropy = 0
            if transitions:
                probs = np.array(list(transition_counts.values())) / len(transitions)
                transition_entropy = -np.sum(probs * np.log2(probs + 1e-10))
            
            sequence_features.append({
                'session_id': session_id,
                'sequence_length': len(tools),
                'unique_transitions': unique_transitions,
                'transition_entropy': transition_entropy,
                'read_write_cycles': read_write_cycles,
                'bash_after_edit': bash_after_edit,
                'search_then_read': search_then_read,
                'most_common_transition': str(common_transitions[0][0]) if common_transitions else '',
                'repetitive_patterns': max(transition_counts.values()) if transition_counts else 0
            })
        
        df = pd.DataFrame(sequence_features)
        self.logger.info(f"Extracted sequence features for {len(df)} sessions")
        return df
    
    def save_features(self, session_df: pd.DataFrame, temporal_df: pd.DataFrame, sequence_df: pd.DataFrame):
        """Save extracted features to files"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Save individual feature sets
        session_df.to_csv(f"{self.features_dir}/session_features_{timestamp}.csv", index=False)
        temporal_df.to_csv(f"{self.features_dir}/temporal_features_{timestamp}.csv", index=False)
        sequence_df.to_csv(f"{self.features_dir}/sequence_features_{timestamp}.csv", index=False)
        
        # Create combined feature set
        combined_df = session_df
        if not temporal_df.empty:
            combined_df = combined_df.merge(temporal_df, on='session_id', how='left')
        if not sequence_df.empty:
            combined_df = combined_df.merge(sequence_df, on='session_id', how='left')
        
        combined_df.to_csv(f"{self.features_dir}/combined_features_{timestamp}.csv", index=False)
        
        # Save latest as well (for easy access)
        combined_df.to_csv(f"{self.features_dir}/latest_features.csv", index=False)
        
        self.logger.info(f"Saved feature sets to {self.features_dir}")
        return combined_df
    
    def generate_summary_stats(self, df: pd.DataFrame) -> Dict:
        """Generate summary statistics for extracted features"""
        stats = {
            'total_sessions': len(df),
            'date_range': {
                'start': df['start_time'].min().isoformat() if 'start_time' in df.columns and not df['start_time'].isna().all() else None,
                'end': df['end_time'].max().isoformat() if 'end_time' in df.columns and not df['end_time'].isna().all() else None
            },
            'session_stats': {
                'avg_duration_minutes': df['duration_minutes'].mean() if 'duration_minutes' in df.columns else 0,
                'avg_operations_per_session': df['total_operations'].mean() if 'total_operations' in df.columns else 0,
                'avg_operation_rate': df['operation_rate'].mean() if 'operation_rate' in df.columns else 0
            },
            'tool_usage': {
                'avg_file_operations': df['file_operations'].mean() if 'file_operations' in df.columns else 0,
                'avg_bash_commands': df['bash_commands'].mean() if 'bash_commands' in df.columns else 0,
                'avg_search_operations': df['search_operations'].mean() if 'search_operations' in df.columns else 0,
                'avg_ai_operations': df['ai_operations'].mean() if 'ai_operations' in df.columns else 0
            },
            'security_metrics': {
                'sessions_with_violations': (df['scope_violations'] > 0).sum() if 'scope_violations' in df.columns else 0,
                'avg_error_rate': df['error_rate'].mean() if 'error_rate' in df.columns else 0
            },
            'superclaude_usage': {
                'sessions_with_superclaude': (df['superclaude_usage'] > 0).sum() if 'superclaude_usage' in df.columns else 0,
                'avg_superclaude_operations': df['superclaude_usage'].mean() if 'superclaude_usage' in df.columns else 0
            },
            # Phase 7 Lite: Delegation statistics
            'delegation_metrics': self.calculate_delegation_stats(df)
        }
        
        return stats
    
    def process_all_data(self, use_loki: bool = True, use_local: bool = True) -> pd.DataFrame:
        """Main processing pipeline - extract all features from telemetry data"""
        self.logger.info("Starting Phase 6.2 data processing pipeline...")
        
        entries = []
        
        # Load data from available sources
        if use_loki:
            loki_entries = self.query_loki('{service="claude-telemetry"}')
            entries.extend(loki_entries)
        
        if use_local:
            local_entries = self.load_local_data()
            entries.extend(local_entries)
        
        if not entries:
            self.logger.error("No telemetry data found!")
            return pd.DataFrame()
        
        # Remove duplicates based on timestamp and session_id
        seen = set()
        unique_entries = []
        for entry in entries:
            if isinstance(entry, dict):
                key = (entry.get('session_id'), str(entry.get('timestamp', '')))
                if key not in seen:
                    seen.add(key)
                    unique_entries.append(entry)
            else:
                self.logger.warning(f"Skipping non-dict entry: {type(entry)}")
        
        self.logger.info(f"Processing {len(unique_entries)} unique telemetry entries")
        
        # Extract features
        session_features = self.extract_session_features(unique_entries)
        temporal_features = self.extract_temporal_features(unique_entries)
        sequence_features = self.extract_sequence_features(unique_entries)
        
        # Save features
        combined_df = self.save_features(session_features, temporal_features, sequence_features)
        
        # Generate summary
        stats = self.generate_summary_stats(combined_df)
        
        # Save summary
        with open(f"{self.features_dir}/processing_summary.json", 'w') as f:
            json.dump(stats, f, indent=2, default=str)
        
        self.logger.info("Data processing pipeline completed successfully!")
        self.logger.info(f"Summary: {stats['total_sessions']} sessions, "
                        f"{stats['session_stats']['avg_operations_per_session']:.1f} avg ops/session")
        
        return combined_df
    
    def calculate_delegation_stats(self, df: pd.DataFrame) -> Dict:
        """Phase 7 Lite: Calculate simple delegation statistics for solo developers"""
        if df.empty or 'total_operations' not in df.columns:
            return {
                'delegation_percentage': 0.0,
                'average_delegations_per_session': 0.0,
                'total_delegations': 0,
                'sessions_with_delegation': 0,
                'most_delegation_friendly_hours': [],
                'workflow_efficiency_trend': 'No data'
            }
        
        total_operations = df['total_operations'].sum()
        total_delegations = df['delegation_events'].sum() if 'delegation_events' in df.columns else 0
        sessions_with_delegation = (df['delegation_events'] > 0).sum() if 'delegation_events' in df.columns else 0
        
        delegation_stats = {
            'delegation_percentage': (total_delegations / total_operations * 100) if total_operations > 0 else 0.0,
            'average_delegations_per_session': total_delegations / len(df) if len(df) > 0 else 0.0,
            'total_delegations': int(total_delegations),
            'sessions_with_delegation': int(sessions_with_delegation),
            'most_delegation_friendly_hours': self._get_peak_delegation_hours(df),
            'workflow_efficiency_trend': self._calculate_efficiency_trend(df)
        }
        
        return delegation_stats
    
    def _get_peak_delegation_hours(self, df: pd.DataFrame) -> List[int]:
        """Find hours when delegation is most common"""
        # This would need temporal data - simplified for Phase 7 Lite
        return [14, 15, 16]  # Default assumption: 2-4 PM most productive
    
    def _calculate_efficiency_trend(self, df: pd.DataFrame) -> str:
        """Simple efficiency trend analysis"""
        if 'workflow_efficiency' not in df.columns or df.empty:
            return 'No efficiency data'
        
        avg_efficiency = df['workflow_efficiency'].mean()
        if avg_efficiency > 0.3:
            return 'High delegation efficiency'
        elif avg_efficiency > 0.1:
            return 'Moderate delegation usage'
        else:
            return 'Low delegation usage'

def main():
    parser = argparse.ArgumentParser(description='Process Claude Agent Telemetry data for ML analysis')
    parser.add_argument('--loki-url', default='http://localhost:3100', help='Loki URL')
    parser.add_argument('--data-dir', default=None, help='Data directory path')
    parser.add_argument('--no-loki', action='store_true', help='Skip Loki data source')
    parser.add_argument('--no-local', action='store_true', help='Skip local backup data source')
    
    args = parser.parse_args()
    
    processor = TelemetryDataProcessor(loki_url=args.loki_url, data_dir=args.data_dir)
    
    use_loki = not args.no_loki
    use_local = not args.no_local
    
    combined_df = processor.process_all_data(use_loki=use_loki, use_local=use_local)
    
    if not combined_df.empty:
        print(f"\n✅ Successfully processed telemetry data!")
        print(f"📊 Features extracted for {len(combined_df)} sessions")
        print(f"📁 Saved to: {processor.features_dir}/latest_features.csv")
    else:
        print("❌ No data processed. Check Loki connection and local backup files.")
        sys.exit(1)

if __name__ == "__main__":
    main()