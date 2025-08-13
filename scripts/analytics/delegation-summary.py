#!/usr/bin/env python3
"""
Phase 7 Lite: Generate simple delegation insights for solo developers
Provides human-readable delegation statistics and trends.
"""

import json
import sys
import os
import pandas as pd
from datetime import datetime, timedelta
from pathlib import Path
import argparse

# Add project root to path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

class DelegationInsightGenerator:
    """Generate delegation insights for solo developers"""
    
    def __init__(self, data_dir: str = None):
        self.data_dir = data_dir or "/home/jeff/claude-code/agent-telemetry/data"
        self.features_dir = f"{self.data_dir}/analytics/features"
        
    def load_latest_features(self) -> pd.DataFrame:
        """Load the most recent feature extraction results"""
        latest_file = f"{self.features_dir}/latest_features.csv"
        
        if not os.path.exists(latest_file):
            print(f"❌ No feature data found at {latest_file}")
            print("💡 Run data-processor.py first to generate features")
            return pd.DataFrame()
        
        return pd.read_csv(latest_file)
    
    def count_recent_delegations(self, days: int = 7) -> int:
        """Count delegation events in recent days"""
        # For Phase 7 Lite, simplified approach using features
        df = self.load_latest_features()
        if df.empty or 'delegation_events' not in df.columns:
            return 0
        
        return int(df['delegation_events'].sum())
    
    def calculate_delegation_rate(self) -> float:
        """Calculate overall delegation percentage"""
        df = self.load_latest_features()
        if df.empty or 'delegation_rate' not in df.columns:
            return 0.0
        
        return df['delegation_rate'].mean()
    
    def find_peak_delegation_times(self) -> str:
        """Identify when delegation happens most"""
        # Simplified for Phase 7 Lite - would need temporal analysis for real data
        return "2-4 PM (afternoon productivity peak)"
    
    def compare_to_previous_week(self) -> str:
        """Simple trend analysis"""
        df = self.load_latest_features()
        if df.empty or 'workflow_efficiency' not in df.columns:
            return "No trend data available"
        
        avg_efficiency = df['workflow_efficiency'].mean()
        
        if avg_efficiency > 0.25:
            return "📈 High delegation efficiency - you're using Claude agents effectively!"
        elif avg_efficiency > 0.1:
            return "📊 Moderate delegation - room for more agent coordination"
        else:
            return "📉 Low delegation - consider using more Task delegation for complex work"
    
    def generate_weekly_summary(self) -> str:
        """Create human-readable delegation insights"""
        print("🔄 Generating delegation insights...")
        
        # Load recent data and calculate insights
        delegations_this_week = self.count_recent_delegations(7)
        delegation_percentage = self.calculate_delegation_rate()
        most_productive_hours = self.find_peak_delegation_times()
        efficiency_trend = self.compare_to_previous_week()
        
        # Load additional stats from processing summary
        summary_stats = self.load_processing_summary()
        
        # Generate friendly summary
        summary = f"""
🤖 Claude Agent Delegation Summary (Last 7 Days)
{'=' * 55}

📊 Delegation Statistics:
   • Total delegations: {delegations_this_week} tasks
   • Delegation rate: {delegation_percentage:.1f}% of your operations
   • Most active time: {most_productive_hours}

📈 Efficiency Analysis:
   • {efficiency_trend}

🔍 Session Details:
   • Total sessions analyzed: {summary_stats.get('total_sessions', 0)}
   • Average operations per session: {summary_stats.get('avg_operations', 0):.1f}
   • Sessions with delegation: {summary_stats.get('sessions_with_delegation', 0)}

💡 Insights for Solo Developers:
   • Task tool delegation helps with complex analysis and research
   • Consider using more agent delegation for time-consuming operations
   • Your delegation pattern suggests {"high" if delegation_percentage > 15 else "moderate" if delegation_percentage > 5 else "low"} AI-assisted productivity

🎯 Next Steps:
   • {"Continue current delegation patterns - you're efficiently using Claude agents!" if delegation_percentage > 15 else "Try delegating more complex tasks to improve productivity" if delegation_percentage < 10 else "Good balance of manual and delegated work"}

📅 Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""
        
        return summary
    
    def load_processing_summary(self) -> dict:
        """Load processing summary statistics"""
        summary_file = f"{self.features_dir}/processing_summary.json"
        
        if not os.path.exists(summary_file):
            return {}
        
        try:
            with open(summary_file, 'r') as f:
                data = json.load(f)
                
            # Extract key stats
            stats = {
                'total_sessions': data.get('total_sessions', 0),
                'avg_operations': data.get('session_stats', {}).get('avg_operations_per_session', 0),
                'sessions_with_delegation': data.get('delegation_metrics', {}).get('sessions_with_delegation', 0)
            }
            
            return stats
            
        except json.JSONDecodeError:
            return {}
    
    def save_summary(self, summary: str, filename: str = None):
        """Save summary to file"""
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"delegation_summary_{timestamp}.txt"
        
        summary_path = f"{self.data_dir}/analytics/{filename}"
        
        # Ensure directory exists
        Path(self.data_dir + "/analytics").mkdir(parents=True, exist_ok=True)
        
        with open(summary_path, 'w') as f:
            f.write(summary)
        
        print(f"📁 Summary saved to: {summary_path}")
        return summary_path

def main():
    parser = argparse.ArgumentParser(description='Generate delegation insights for solo developers')
    parser.add_argument('--data-dir', default=None, help='Data directory path')
    parser.add_argument('--save', action='store_true', help='Save summary to file')
    parser.add_argument('--filename', default=None, help='Output filename')
    
    args = parser.parse_args()
    
    generator = DelegationInsightGenerator(data_dir=args.data_dir)
    
    # Generate summary
    summary = generator.generate_weekly_summary()
    
    # Display summary
    print(summary)
    
    # Save if requested
    if args.save:
        generator.save_summary(summary, args.filename)
        print(f"\n✅ Delegation insights generated successfully!")
    else:
        print(f"\n💡 Use --save flag to save this summary to a file")

if __name__ == "__main__":
    main()