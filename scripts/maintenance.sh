#!/bin/bash
"""
Comprehensive Maintenance Script for Claude Agent Telemetry
Automated optimization and maintenance tasks
"""

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔧 Claude Agent Telemetry - Comprehensive Maintenance"
echo "=================================================="

# Function to show storage before/after
show_storage() {
    echo "📊 Current storage usage:"
    du -sh "$PROJECT_DIR" 2>/dev/null | grep -E "^\S+\s+\." | head -1 || echo "Unable to calculate"
    du -sh "$PROJECT_DIR"/{bin,venv,logs,data,.git} 2>/dev/null | sort -hr || echo "Detailed breakdown unavailable"
    echo ""
}

echo "BEFORE MAINTENANCE:"
show_storage

# 1. Log cleanup and rotation
echo "1️⃣ Running log cleanup and rotation..."
if [[ -x "$SCRIPT_DIR/log-cleanup.sh" ]]; then
    "$SCRIPT_DIR/log-cleanup.sh"
else
    echo "⚠️  Log cleanup script not found or not executable"
fi
echo ""

# 2. Binary optimization (if user confirms)
echo "2️⃣ Binary optimization available..."
if [[ -x "$SCRIPT_DIR/optimize-binaries.sh" ]]; then
    echo "   This will remove ~420MB of duplicate Grafana binaries"
    echo "   Run manually: ./scripts/optimize-binaries.sh"
else
    echo "⚠️  Binary optimization script not found"
fi
echo ""

# 3. Git maintenance
echo "3️⃣ Running Git maintenance..."
if git -C "$PROJECT_DIR" status >/dev/null 2>&1; then
    echo "🔄 Git garbage collection..."
    git -C "$PROJECT_DIR" gc --prune=now >/dev/null 2>&1 || echo "⚠️  Git gc failed"
    
    echo "📊 Git repository size:"
    du -sh "$PROJECT_DIR/.git" 2>/dev/null || echo "Unable to calculate git size"
else
    echo "⚠️  Not a git repository or git not available"
fi
echo ""

# 4. Service status check
echo "4️⃣ Checking service status..."
if [[ -x "$SCRIPT_DIR/status.sh" ]]; then
    "$SCRIPT_DIR/status.sh" 2>/dev/null || echo "Status check completed with warnings"
else
    echo "ℹ️  Service status script not found"
fi
echo ""

# 5. Disk space analysis
echo "5️⃣ Disk space analysis..."
df -h "$PROJECT_DIR" 2>/dev/null | tail -1 | awk '{
    print "   💾 Disk usage: " $3 " used / " $2 " total (" $5 " full)"
    if (substr($5, 1, length($5)-1) > 80) 
        print "   ⚠️  Warning: Disk usage over 80%"
    else 
        print "   ✅ Disk usage healthy"
}'
echo ""

echo "AFTER MAINTENANCE:"
show_storage

echo "✅ Maintenance completed!"
echo ""
echo "📋 Manual optimization options:"
echo "   • Binary cleanup: ./scripts/optimize-binaries.sh (~420MB savings)"
echo "   • Git push: git push calcutta-multi main"
echo "   • Weekly automation: Add to cron: 0 2 * * 0 $PWD/scripts/maintenance.sh"
echo ""
echo "💡 Next steps:"
echo "   • Monitor service logs: tail -f logs/loki.log"
echo "   • Check dashboard: http://localhost:3000"
echo "   • Review ML analytics: data/analytics/latest_behavioral_profiles.csv"