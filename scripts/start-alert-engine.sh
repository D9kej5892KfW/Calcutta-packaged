#!/bin/bash
# Claude Agent Telemetry - Alert Engine Start Script
# Phase 6.1: Enhanced Security Alerting

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
ALERT_ENGINE="$SCRIPT_DIR/alert-engine.py"
CONFIG_FILE="$PROJECT_ROOT/config/alerts/security-rules.yaml"
PID_FILE="$PROJECT_ROOT/logs/alert-engine.pid"
LOG_FILE="$PROJECT_ROOT/logs/alert-engine-service.log"

# Ensure directories exist
mkdir -p "$(dirname "$PID_FILE")"
mkdir -p "$(dirname "$LOG_FILE")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if alert engine is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            # PID file exists but process is dead
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Function to start alert engine
start_alert_engine() {
    print_status "Starting Claude Agent Telemetry Alert Engine..."
    
    # Check if already running
    if is_running; then
        local pid=$(cat "$PID_FILE")
        print_warning "Alert engine is already running (PID: $pid)"
        return 0
    fi
    
    # Check prerequisites
    if [ ! -f "$ALERT_ENGINE" ]; then
        print_error "Alert engine script not found: $ALERT_ENGINE"
        return 1
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    # Check if Loki is running
    if ! curl -s http://localhost:3100/ready >/dev/null 2>&1; then
        print_warning "Loki service does not appear to be running"
        print_warning "Starting Loki service first..."
        
        if [ -f "$PROJECT_ROOT/scripts/start-loki.sh" ]; then
            "$PROJECT_ROOT/scripts/start-loki.sh"
            
            # Wait for Loki to be ready
            print_status "Waiting for Loki to be ready..."
            for i in {1..30}; do
                if curl -s http://localhost:3100/ready >/dev/null 2>&1; then
                    break
                fi
                sleep 1
            done
            
            if ! curl -s http://localhost:3100/ready >/dev/null 2>&1; then
                print_error "Loki failed to start within 30 seconds"
                return 1
            fi
        else
            print_error "Cannot start Loki automatically. Please start it manually."
            return 1
        fi
    fi
    
    # Test configuration
    print_status "Testing configuration..."
    if ! python3 "$ALERT_ENGINE" --config "$CONFIG_FILE" --test >/dev/null 2>&1; then
        print_error "Configuration test failed"
        return 1
    fi
    
    # Start alert engine in background
    print_status "Starting alert engine daemon..."
    cd "$PROJECT_ROOT"
    nohup python3 "$ALERT_ENGINE" --config "$CONFIG_FILE" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    
    # Save PID
    echo "$pid" > "$PID_FILE"
    
    # Wait a moment and check if it's still running
    sleep 2
    if ! kill -0 "$pid" 2>/dev/null; then
        print_error "Alert engine failed to start"
        rm -f "$PID_FILE"
        return 1
    fi
    
    print_status "Alert engine started successfully (PID: $pid)"
    print_status "Logs: $LOG_FILE"
    print_status "Configuration: $CONFIG_FILE"
    
    return 0
}

# Function to stop alert engine
stop_alert_engine() {
    print_status "Stopping Claude Agent Telemetry Alert Engine..."
    
    if ! is_running; then
        print_warning "Alert engine is not running"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    print_status "Stopping alert engine (PID: $pid)..."
    
    # Try graceful shutdown first
    if kill -TERM "$pid" 2>/dev/null; then
        # Wait up to 10 seconds for graceful shutdown
        for i in {1..10}; do
            if ! kill -0 "$pid" 2>/dev/null; then
                break
            fi
            sleep 1
        done
        
        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            print_warning "Graceful shutdown failed, forcing termination..."
            kill -KILL "$pid" 2>/dev/null || true
        fi
    fi
    
    # Clean up PID file
    rm -f "$PID_FILE"
    print_status "Alert engine stopped"
    
    return 0
}

# Function to show status
show_status() {
    echo "Claude Agent Telemetry Alert Engine Status"
    echo "=========================================="
    
    if is_running; then
        local pid=$(cat "$PID_FILE")
        print_status "Alert engine is running (PID: $pid)"
        
        # Show some runtime statistics
        if [ -f "$LOG_FILE" ]; then
            local log_size=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1)
            echo "  Log file: $LOG_FILE ($log_size)"
        fi
        
        # Check Loki connectivity
        if curl -s http://localhost:3100/ready >/dev/null 2>&1; then
            echo "  Loki service: ✅ Running"
        else
            echo "  Loki service: ❌ Not accessible"
        fi
        
        # Show recent alert count if alert manager is available
        if [ -f "$SCRIPT_DIR/alert-manager.py" ]; then
            echo "  Recent alerts (24h):"
            python3 "$SCRIPT_DIR/alert-manager.py" stats --days 1 2>/dev/null | grep "Total alerts:" || echo "    No recent alerts"
        fi
        
    else
        print_warning "Alert engine is not running"
    fi
    
    return 0
}

# Function to restart alert engine
restart_alert_engine() {
    print_status "Restarting Claude Agent Telemetry Alert Engine..."
    stop_alert_engine
    sleep 2
    start_alert_engine
}

# Main script logic
case "${1:-}" in
    start)
        start_alert_engine
        ;;
    stop)
        stop_alert_engine
        ;;
    restart)
        restart_alert_engine
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the alert engine"
        echo "  stop    - Stop the alert engine"
        echo "  restart - Restart the alert engine"
        echo "  status  - Show alert engine status"
        echo ""
        echo "Files:"
        echo "  Config: $CONFIG_FILE"
        echo "  Logs:   $LOG_FILE"
        echo "  PID:    $PID_FILE"
        exit 1
        ;;
esac