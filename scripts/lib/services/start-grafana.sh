#!/bin/bash
# Start Grafana for Claude Agent Telemetry Dashboard
# Uses portable path resolution - works from any directory depth

# Source the common path utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../common/paths.sh" || {
    echo "FATAL: Could not load path utilities" >&2
    exit 1
}

# Use the portable path functions
GRAFANA_CONFIG="$(get_grafana_config)"
GRAFANA_LOG="$(get_grafana_log)"
PID_FILE="$(get_grafana_pid)"
GRAFANA_BIN="$(get_grafana_bin)"
DATA_DIR="$(get_data_dir)"
LOGS_DIR="$(get_logs_dir)"

# Check if Grafana is already running
if [[ -f "$PID_FILE" ]] && kill -0 "$(<"$PID_FILE")" 2>/dev/null; then
    echo "Grafana is already running (PID: $(<"$PID_FILE"))"
    exit 1
fi

# Ensure required directories exist
echo "Setting up Grafana directories..."
mkdir -p "$DATA_DIR/grafana" "$LOGS_DIR"

# Validate that required files exist
if [[ ! -x "$GRAFANA_BIN" ]]; then
    echo "FATAL: Grafana binary not found or not executable: $GRAFANA_BIN" >&2
    exit 1
fi

if [[ ! -f "$GRAFANA_CONFIG" ]]; then
    echo "FATAL: Grafana configuration not found: $GRAFANA_CONFIG" >&2
    exit 1
fi

# Start Grafana
echo "Starting Grafana server..."
echo "  Binary: $GRAFANA_BIN"
echo "  Config: $GRAFANA_CONFIG"
echo "  Log:    $GRAFANA_LOG"

"$GRAFANA_BIN" --config="$GRAFANA_CONFIG" --homepath="$(get_telemetry_root)/bin/grafana-v11.1.0" > "$GRAFANA_LOG" 2>&1 &
GRAFANA_PID=$!

# Save PID
echo "$GRAFANA_PID" > "$PID_FILE"

# Wait a moment and check if it started successfully
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