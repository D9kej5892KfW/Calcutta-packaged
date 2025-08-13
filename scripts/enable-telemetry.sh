#!/bin/bash
# Simple telemetry enabler for Claude Code projects
# Usage: ./enable-telemetry.sh [project-name] [project-path]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONNECT_SCRIPT="$SCRIPT_DIR/connect-project.sh"

# Get current directory if no path provided
PROJECT_PATH="${2:-$(pwd)}"
PROJECT_NAME="${1:-$(basename "$PROJECT_PATH")}"

echo "🔧 Enabling telemetry for project: $PROJECT_NAME"
echo "📁 Project path: $PROJECT_PATH"

# Check if Loki is running, start if needed
if ! curl -s "http://localhost:3100/ready" > /dev/null 2>&1; then
    echo "🚀 Starting Loki telemetry server..."
    "$SCRIPT_DIR/start-loki.sh"
    sleep 2
fi

# Connect the project
"$CONNECT_SCRIPT" "$PROJECT_PATH" "$PROJECT_NAME"

echo ""
echo "✅ Telemetry enabled! Usage:"
echo "   • Dashboard: http://localhost:3000"
echo "   • Filter by: project=\"$PROJECT_NAME\""
echo "   • Status: $SCRIPT_DIR/status.sh"