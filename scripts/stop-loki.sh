#!/bin/bash
# Stop Loki service for Claude Agent Telemetry

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="$PROJECT_DIR/logs/loki.pid"

if [[ ! -f "$PID_FILE" ]]; then
    echo "Loki PID file not found. Is Loki running?"
    exit 1
fi

LOKI_PID=$(<"$PID_FILE")

if ! kill -0 "$LOKI_PID" 2>/dev/null; then
    echo "Loki process (PID: $LOKI_PID) is not running"
    rm -f "$PID_FILE"
    exit 1
fi

echo "Stopping Loki (PID: $LOKI_PID)..."
kill "$LOKI_PID"

# Wait for graceful shutdown
for i in {1..10}; do
    if ! kill -0 "$LOKI_PID" 2>/dev/null; then
        echo "Loki stopped successfully"
        rm -f "$PID_FILE"
        exit 0
    fi
    sleep 1
done

# Force kill if graceful shutdown failed
echo "Forcing Loki shutdown..."
kill -9 "$LOKI_PID" 2>/dev/null
rm -f "$PID_FILE"
echo "Loki stopped (forced)"