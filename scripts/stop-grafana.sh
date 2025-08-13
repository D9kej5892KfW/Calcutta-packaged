#\!/bin/bash
# Stop Grafana server

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="$PROJECT_DIR/logs/grafana.pid"

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
    echo "Grafana PID file not found"
fi
EOF < /dev/null
