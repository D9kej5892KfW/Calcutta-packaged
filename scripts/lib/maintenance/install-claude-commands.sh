#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}[INFO]${NC} Installing Claude Code Agent Telemetry commands..."

# Get absolute path to telemetry system
TELEMETRY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "${BLUE}[INFO]${NC} Telemetry system location: $TELEMETRY_ROOT"

# Create Claude config directory if it doesn't exist
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

# Check if COMMANDS.md exists, create if not
COMMANDS_FILE="$CLAUDE_DIR/COMMANDS.md"
if [[ ! -f "$COMMANDS_FILE" ]]; then
    echo -e "${BLUE}[INFO]${NC} Creating new COMMANDS.md file"
    cat > "$COMMANDS_FILE" << 'EOF'
# Claude Code Custom Commands

This file contains custom command definitions for Claude Code.

EOF
fi

# Check if telemetry commands are already installed
if grep -q "Agent Telemetry System Commands" "$COMMANDS_FILE"; then
    echo -e "${YELLOW}[WARNING]${NC} Telemetry commands already installed. Updating..."
    # Remove old telemetry section
    sed -i '/# Agent Telemetry System Commands/,/^$/d' "$COMMANDS_FILE"
fi

# Add telemetry commands
echo -e "${BLUE}[INFO]${NC} Adding telemetry commands to Claude Code configuration"
cat >> "$COMMANDS_FILE" << EOF

# Agent Telemetry System Commands

**\`/telemetry [flags]\`** - Activate project telemetry | Auto-Persona: DevOps | Script: \`$TELEMETRY_ROOT/scripts/connect-project.sh\`

**\`/telemetry-start\`** - Start telemetry services (Loki + Grafana) | Auto-Persona: DevOps | Script: \`$TELEMETRY_ROOT/scripts/start-loki.sh && $TELEMETRY_ROOT/scripts/start-grafana.sh\`

**\`/telemetry-stop\`** - Stop telemetry services | Auto-Persona: DevOps | Script: \`$TELEMETRY_ROOT/scripts/stop-loki.sh && $TELEMETRY_ROOT/scripts/stop-grafana.sh\`

**\`/telemetry-status\`** - Check telemetry system status | Auto-Persona: DevOps | Script: \`$TELEMETRY_ROOT/scripts/status.sh\`

**\`/telemetry-dashboard\`** - Open Grafana dashboard | Auto-Persona: DevOps | Script: \`open http://localhost:3000 || xdg-open http://localhost:3000 || sensible-browser http://localhost:3000\`

**\`/telemetry-list\`** - List connected projects | Auto-Persona: DevOps | Script: \`$TELEMETRY_ROOT/scripts/list-connected-projects.sh\`

**\`/telemetry-disconnect\`** - Disconnect current project | Auto-Persona: DevOps | Script: \`$TELEMETRY_ROOT/scripts/disconnect-project.sh "\$(pwd)"\`

**\`/telemetry-logs\`** - View recent telemetry logs | Auto-Persona: DevOps | Script: \`tail -f $TELEMETRY_ROOT/data/logs/claude-telemetry.jsonl\`

EOF

# Verify installation
echo -e "${BLUE}[INFO]${NC} Verifying installation..."
if grep -q "/telemetry" "$COMMANDS_FILE"; then
    echo -e "${GREEN}[SUCCESS]${NC} Claude Code telemetry commands installed successfully!"
else
    echo -e "${RED}[ERROR]${NC} Installation failed"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Configuration file: $COMMANDS_FILE"
echo ""
echo -e "${GREEN}Available commands (use from any directory):${NC}"
echo -e "  ${BLUE}/telemetry${NC}            - Connect current project to telemetry"
echo -e "  ${BLUE}/telemetry-start${NC}      - Start monitoring services"
echo -e "  ${BLUE}/telemetry-stop${NC}       - Stop monitoring services"
echo -e "  ${BLUE}/telemetry-status${NC}     - Check system status"
echo -e "  ${BLUE}/telemetry-dashboard${NC}  - Open Grafana dashboard"
echo -e "  ${BLUE}/telemetry-list${NC}       - List connected projects"
echo -e "  ${BLUE}/telemetry-disconnect${NC} - Disconnect current project"
echo -e "  ${BLUE}/telemetry-logs${NC}       - View live telemetry logs"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo -e "1. Navigate to any project directory"
echo -e "2. Run ${BLUE}/telemetry${NC} to connect it to the monitoring system"
echo -e "3. Use ${BLUE}/telemetry-start${NC} to begin monitoring"
echo -e "4. View dashboards with ${BLUE}/telemetry-dashboard${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Restart any active Claude Code sessions for commands to take effect"
echo -e "${YELLOW}Tip:${NC} Use ${BLUE}/telemetry-logs${NC} to see real-time monitoring of your Claude Code usage"