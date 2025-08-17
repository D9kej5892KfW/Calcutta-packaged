#!/bin/bash
# Stop Grafana server

# Source the common path utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../common/paths.sh" || {
    echo "FATAL: Could not load path utilities" >&2
    exit 1
}

PID_FILE="$(get_grafana_pid)"

if [[ -f "$PID_FILE" ]]; then
    PID=$(<"$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping Grafana (PID: $PID)..."
        kill "$PID"
        sleep 3
        if kill -0 "$PID" 2>/dev/null; then
            echo "Force killing Grafana..."
            kill -9 "$PID"
        fi
        rm -f "$PID_FILE"
        echo "Grafana stopped"
    else
        echo "Grafana not running"
        rm -f "$PID_FILE"
    fi
else
    echo "Grafana PID file not found. Attempting to find Grafana process..."
    # Try to find Grafana process by name
    PID=$(pgrep -f "grafana.*server" 2>/dev/null | head -1)
    if [[ -n "$PID" ]]; then
        echo "Found Grafana process (PID: $PID)"
        echo "Stopping Grafana (PID: $PID)..."
        kill "$PID"
        sleep 3
        if kill -0 "$PID" 2>/dev/null; then
            echo "Force killing Grafana..."
            kill -9 "$PID"
        fi
        echo "Grafana stopped"
    else
        echo "No Grafana process found."
    fi
fi
