#!/bin/bash
# Start Grafana for Claude Agent Telemetry Dashboard

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRAFANA_CONFIG="$PROJECT_DIR/config/grafana/grafana.ini"
GRAFANA_LOG="$PROJECT_DIR/logs/grafana.log"
PID_FILE="$PROJECT_DIR/logs/grafana.pid"

# Check if Grafana is already running
if [[ -f "$PID_FILE" ]] && kill -0 "$(<"$PID_FILE")" 2>/dev/null; then
    echo "Grafana is already running (PID: $(<"$PID_FILE"))"
    exit 1
fi

# Start Grafana
echo "Starting Grafana server..."
"$PROJECT_DIR/bin/grafana" server --config="$GRAFANA_CONFIG" --homepath="$PROJECT_DIR/bin/grafana-v11.1.0" > "$GRAFANA_LOG" 2>&1 &
GRAFANA_PID=$!

# Save PID
echo "$GRAFANA_PID" > "$PID_FILE"

# Wait and check if it started
sleep 5
if kill -0 "$GRAFANA_PID" 2>/dev/null; then
    echo "Grafana started successfully (PID: $GRAFANA_PID)"
    echo "Dashboard: http://localhost:3000"
    echo "Login: admin/admin"
else
    echo "Failed to start Grafana. Check logs: $GRAFANA_LOG"
    rm -f "$PID_FILE"
    exit 1
fi
