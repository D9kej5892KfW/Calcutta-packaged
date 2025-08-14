#!/bin/bash
# Unified shutdown script for Claude Agent Telemetry System
# Stops all services cleanly and provides status feedback

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOKI_PID_FILE="$PROJECT_DIR/logs/loki.pid"
GRAFANA_PID_FILE="$PROJECT_DIR/logs/grafana.pid"

echo "🛑 Shutting down Claude Agent Telemetry System..."
echo "================================================"

# Function to stop a service gracefully
stop_service() {
    local service_name="$1"
    local pid_file="$2"
    local timeout="${3:-10}"
    
    if [[ ! -f "$pid_file" ]]; then
        echo "ℹ️  $service_name: Not running (no PID file)"
        return 0
    fi
    
    local pid=$(<"$pid_file")
    
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "ℹ️  $service_name: Not running (stale PID file)"
        rm -f "$pid_file"
        return 0
    fi
    
    echo "🔄 Stopping $service_name (PID: $pid)..."
    kill "$pid"
    
    # Wait for graceful shutdown
    for i in $(seq 1 $timeout); do
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "✅ $service_name stopped successfully"
            rm -f "$pid_file"
            return 0
        fi
        sleep 1
        if [[ $i -eq 5 ]]; then
            echo "   ⏳ Waiting for $service_name to shutdown gracefully..."
        fi
    done
    
    # Force kill if graceful shutdown failed
    echo "⚠️  Force stopping $service_name..."
    kill -9 "$pid" 2>/dev/null
    rm -f "$pid_file"
    echo "🔴 $service_name stopped (forced)"
    return 1
}

# Stop services in order
stop_service "Grafana" "$GRAFANA_PID_FILE" 5
stop_service "Loki" "$LOKI_PID_FILE" 10

# Verify all services are stopped
echo ""
echo "🔍 Verifying shutdown status..."

# Check for any remaining processes
REMAINING_LOKI=$(pgrep -f "loki.*config.file" 2>/dev/null || true)
REMAINING_GRAFANA=$(pgrep -f "grafana.*server" 2>/dev/null || true)

if [[ -n "$REMAINING_LOKI" ]]; then
    echo "⚠️  Warning: Loki processes still running (PIDs: $REMAINING_LOKI)"
    echo "   Run: kill $REMAINING_LOKI"
elif [[ -n "$REMAINING_GRAFANA" ]]; then
    echo "⚠️  Warning: Grafana processes still running (PIDs: $REMAINING_GRAFANA)"
    echo "   Run: kill $REMAINING_GRAFANA"
else
    echo "✅ All services stopped successfully"
fi

# Check API endpoints
echo ""
echo "🌐 Checking API endpoints..."
if curl -s --connect-timeout 2 "http://localhost:3100/ready" >/dev/null 2>&1; then
    echo "⚠️  Loki API still responding on port 3100"
else
    echo "✅ Loki API stopped (port 3100)"
fi

if curl -s --connect-timeout 2 "http://localhost:3000/api/health" >/dev/null 2>&1; then
    echo "⚠️  Grafana API still responding on port 3000"
else
    echo "✅ Grafana API stopped (port 3000)"
fi

echo ""
echo "🎯 Shutdown complete!"
echo ""
echo "💡 Quick reference:"
echo "   • Restart: ./scripts/start-loki.sh && ./scripts/start-grafana.sh"
echo "   • Status:  ./scripts/status.sh"
echo "   • Logs:    tail -f logs/loki.log"