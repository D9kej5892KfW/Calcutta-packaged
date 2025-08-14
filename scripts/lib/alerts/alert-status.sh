#!/bin/bash
# Check alert engine status

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ALERT_ENGINE="$PROJECT_DIR/scripts/lib/alerts/alert-engine.py"

echo "Alert Engine Status:"
echo "==================="

# Check if alert engine process is running
if pgrep -f "alert-engine.py" >/dev/null; then
    echo "✅ Alert engine is running"
    
    # Show process info
    echo "Process info:"
    ps aux | grep "[a]lert-engine.py" | while read line; do
        echo "  $line"
    done
else
    echo "❌ Alert engine is not running"
fi

# Check alert configuration
if [[ -f "$PROJECT_DIR/config/alerts/security-rules.yaml" ]]; then
    echo "✅ Alert rules configuration found"
else
    echo "❌ Alert rules configuration missing"
fi

# Check recent alerts
if [[ -f "$PROJECT_DIR/data/alerts/alert-engine.log" ]]; then
    echo ""
    echo "Recent alerts (last 10):"
    tail -10 "$PROJECT_DIR/data/alerts/alert-engine.log" 2>/dev/null || echo "No recent alerts"
else
    echo "❌ No alert logs found"
fi