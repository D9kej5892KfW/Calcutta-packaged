#!/bin/bash
# Start Loki service for Claude Agent Telemetry
# Uses portable path resolution - works from any directory depth

# Source the common path utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../common/paths.sh" || {
    echo "FATAL: Could not load path utilities" >&2
    exit 1
}

# Use the portable path functions
LOKI_CONFIG="$(get_loki_config)"
LOKI_LOG="$(get_loki_log)"
PID_FILE="$(get_loki_pid)"
LOKI_BIN="$(get_loki_bin)"
DATA_DIR="$(get_data_dir)"
LOGS_DIR="$(get_logs_dir)"

# Check if Loki is already running
if [[ -f "$PID_FILE" ]] && kill -0 "$(<"$PID_FILE")" 2>/dev/null; then
    echo "Loki is already running (PID: $(<"$PID_FILE"))"
    exit 1
fi

# Ensure required directories exist
echo "Setting up Loki directories..."
mkdir -p "$DATA_DIR/loki/chunks" "$DATA_DIR/loki/rules" "$LOGS_DIR"

# Validate that required files exist
if [[ ! -x "$LOKI_BIN" ]]; then
    echo "FATAL: Loki binary not found or not executable: $LOKI_BIN" >&2
    exit 1
fi

if [[ ! -f "$LOKI_CONFIG" ]]; then
    echo "FATAL: Loki configuration not found: $LOKI_CONFIG" >&2
    exit 1
fi

# Start Loki
echo "Starting Loki server..."
echo "  Binary: $LOKI_BIN"
echo "  Config: $LOKI_CONFIG"
echo "  Log:    $LOKI_LOG"

"$LOKI_BIN" -config.file="$LOKI_CONFIG" > "$LOKI_LOG" 2>&1 &
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