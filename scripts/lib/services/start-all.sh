#!/bin/bash
# Start all Claude Agent Telemetry services
# Uses portable path resolution - works from any directory depth

# Source the common path utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../common/paths.sh" || {
    echo "FATAL: Could not load path utilities" >&2
    exit 1
}

echo "🚀 Starting Claude Agent Telemetry services..."

# Start Loki first
echo "▶ Starting Loki log aggregation service..."
"$SCRIPT_DIR/start-loki.sh"

# Wait for Loki to be ready
echo "⏳ Waiting for Loki to be ready..."
sleep 3

# Start Grafana
echo "▶ Starting Grafana dashboard service..."
"$SCRIPT_DIR/start-grafana.sh"

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
sleep 5

echo ""
echo "✅ All services started successfully!"
echo ""
echo "📊 Dashboard: http://localhost:3000 (admin/admin)"
echo "🔍 Loki API: http://localhost:3100"
echo ""
echo "💡 Pro tip: Use 'npm run status' to check service health"