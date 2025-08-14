#!/bin/bash
# Stop alert engine

echo "Stopping alert engine..."

# Find and kill alert engine processes
if pgrep -f "alert-engine.py" >/dev/null; then
    pkill -f "alert-engine.py"
    echo "✅ Alert engine stopped"
else
    echo "⚠️ Alert engine was not running"
fi

# Clean up any pid files
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
rm -f "$PROJECT_DIR/logs/alert-engine.pid"