#!/bin/bash
# Start all Claude Agent Telemetry services

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Starting Claude Agent Telemetry services..."

# Start Loki first
echo "▶ Starting Loki log aggregation service..."
"$PROJECT_DIR/scripts/start-loki.sh"

# Wait for Loki to be ready
echo "⏳ Waiting for Loki to be ready..."
sleep 3

# Start Grafana
echo "▶ Starting Grafana dashboard service..."
"$PROJECT_DIR/scripts/start-grafana.sh"

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