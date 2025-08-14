#!/bin/bash
# Check status of Claude Agent Telemetry system

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="$PROJECT_DIR/logs/loki.pid"
LOKI_URL="http://localhost:3100"

echo "Claude Agent Telemetry - System Status"
echo "======================================="

# Check Loki process
echo "Loki Service:"
if [[ -f "$PID_FILE" ]] && kill -0 "$(<"$PID_FILE")" 2>/dev/null; then
    LOKI_PID=$(<"$PID_FILE")
    echo "  Status: Running (PID: $LOKI_PID)"
    
    # Check HTTP endpoint
    if curl -s "$LOKI_URL/ready" >/dev/null; then
        echo "  HTTP API: Available at $LOKI_URL"
    else
        echo "  HTTP API: Not responding"
    fi
else
    echo "  Status: Not running"
fi

# Check telemetry configuration
echo
echo "Telemetry Configuration:"
if [[ -f "$PROJECT_DIR/config/.telemetry-enabled" ]]; then
    echo "  Telemetry: Enabled"
else
    echo "  Telemetry: Disabled"
fi

if [[ -f "$PROJECT_DIR/config/claude/hooks/telemetry-hook.sh" ]]; then
    echo "  Hook Script: Present"
else
    echo "  Hook Script: Missing"
fi

if [[ -f "$PROJECT_DIR/config/claude/settings.json" ]]; then
    echo "  Claude Config: Present"
else
    echo "  Claude Config: Missing"
fi

# Check data directories
echo
echo "Data Status:"
if [[ -f "$PROJECT_DIR/data/logs/claude-telemetry.jsonl" ]]; then
    LOG_SIZE=$(wc -l < "$PROJECT_DIR/data/logs/claude-telemetry.jsonl")
    echo "  Telemetry Logs: $LOG_SIZE entries"
else
    echo "  Telemetry Logs: No data"
fi

if [[ -d "$PROJECT_DIR/data/loki" ]]; then
    LOKI_SIZE=$(du -sh "$PROJECT_DIR/data/loki" 2>/dev/null | cut -f1)
    echo "  Loki Data: $LOKI_SIZE"
else
    echo "  Loki Data: No data"
fi

# Recent activity
echo
echo "Recent Activity:"
if [[ -f "$PROJECT_DIR/data/logs/claude-telemetry.jsonl" ]]; then
    LAST_ENTRY=$(tail -n 1 "$PROJECT_DIR/data/logs/claude-telemetry.jsonl" 2>/dev/null | jq -r '.timestamp' 2>/dev/null)
    if [[ "$LAST_ENTRY" != "null" && -n "$LAST_ENTRY" ]]; then
        echo "  Last Entry: $LAST_ENTRY"
    else
        echo "  Last Entry: Unable to parse"
    fi
else
    echo "  Last Entry: No data"
fi