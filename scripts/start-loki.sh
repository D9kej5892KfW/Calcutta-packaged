#!/bin/bash
# Start Loki service for Claude Agent Telemetry

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOKI_CONFIG="$PROJECT_DIR/config/loki/loki.yaml"
LOKI_LOG="$PROJECT_DIR/logs/loki.log"
PID_FILE="$PROJECT_DIR/logs/loki.pid"

# Check if Loki is already running
if [[ -f "$PID_FILE" ]] && kill -0 "$(<"$PID_FILE")" 2>/dev/null; then
    echo "Loki is already running (PID: $(<"$PID_FILE"))"
    exit 1
fi

# Ensure data directories exist
mkdir -p "$PROJECT_DIR/data/loki/chunks" "$PROJECT_DIR/data/loki/rules" "$PROJECT_DIR/logs"

# Start Loki
echo "Starting Loki server..."
"$PROJECT_DIR/bin/loki" -config.file="$LOKI_CONFIG" > "$LOKI_LOG" 2>&1 &
LOKI_PID=$!

# Save PID
echo "$LOKI_PID" > "$PID_FILE"

# Wait a moment and check if it started successfully
sleep 3
if kill -0 "$LOKI_PID" 2>/dev/null; then
    echo "Loki started successfully (PID: $LOKI_PID)"
    echo "Logs: $LOKI_LOG"
    echo "API: http://localhost:3100"
else
    echo "Failed to start Loki. Check logs: $LOKI_LOG"
    rm -f "$PID_FILE"
    exit 1
fi