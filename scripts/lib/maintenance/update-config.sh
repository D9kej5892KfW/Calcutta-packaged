#!/bin/bash
# Update system configuration

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

echo "Updating Claude Agent Telemetry configuration..."

# Update file permissions
echo "▶ Updating script permissions..."
find "$PROJECT_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
chmod +x "$PROJECT_DIR/setup.sh"
chmod +x "$PROJECT_DIR/config/claude/hooks/telemetry-hook.sh" 2>/dev/null || true

# Create missing directories
echo "▶ Creating missing directories..."
mkdir -p "$PROJECT_DIR/data/loki/chunks"
mkdir -p "$PROJECT_DIR/data/loki/rules"
mkdir -p "$PROJECT_DIR/data/logs"
mkdir -p "$PROJECT_DIR/data/grafana"
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/data/alerts"

# Update configuration files if needed
echo "▶ Validating configuration files..."

# Check Loki config
if [[ ! -f "$PROJECT_DIR/config/loki/loki.yaml" ]]; then
    echo "⚠️ Loki configuration missing"
else
    echo "✅ Loki configuration found"
fi

# Check Grafana config
if [[ ! -f "$PROJECT_DIR/config/grafana/grafana.ini" ]]; then
    echo "⚠️ Grafana configuration missing"
else
    echo "✅ Grafana configuration found"
fi

# Check Claude Code integration
if [[ ! -f "$PROJECT_DIR/config/claude/settings.json" ]]; then
    echo "⚠️ Claude Code integration missing"
else
    echo "✅ Claude Code integration found"
fi

echo "✅ Configuration update complete"