#!/bin/bash
# Quick shutdown alias - simple version of shutdown.sh
# Usage: ./scripts/stop-all.sh

# Source the common path utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../common/paths.sh" || {
    echo "FATAL: Could not load path utilities" >&2
    exit 1
}

echo "🛑 Stopping all telemetry services..."

# Stop both services quickly
"$PROJECT_DIR/scripts/stop-grafana.sh" 2>/dev/null
"$PROJECT_DIR/scripts/stop-loki.sh" 2>/dev/null

echo "✅ Shutdown complete!"
echo "💡 Use './scripts/status.sh' to verify or './scripts/shutdown.sh' for detailed shutdown"