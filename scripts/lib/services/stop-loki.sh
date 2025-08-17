#!/bin/bash
# Stop Loki service for Claude Agent Telemetry
# Uses portable path resolution - works from any directory depth

# Source the common path utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../common/paths.sh" || {
    echo "FATAL: Could not load path utilities" >&2
    exit 1
}

PID_FILE="$(get_loki_pid)"

if [[ ! -f "$PID_FILE" ]]; then
    echo "Loki PID file not found. Attempting to find Loki process..."
    # Try to find Loki process by name
    LOKI_PID=$(pgrep -f "loki.*-config.file" 2>/dev/null | head -1)
    if [[ -n "$LOKI_PID" ]]; then
        echo "Found Loki process (PID: $LOKI_PID)"
    else
        echo "No Loki process found."
        exit 1
    fi
else
    LOKI_PID=$(<"$PID_FILE")
fi

if ! kill -0 "$LOKI_PID" 2>/dev/null; then
    echo "Loki process (PID: $LOKI_PID) is not running"
    rm -f "$PID_FILE"
    exit 1
fi

echo "Stopping Loki (PID: $LOKI_PID)..."
if kill "$LOKI_PID"; then
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
    kill -9 "$LOKI_PID"
    rm -f "$PID_FILE"
    echo "Loki stopped (forced)"
else
    echo "Failed to stop Loki"
    exit 1
fi