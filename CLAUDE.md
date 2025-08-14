# Project Documentation

## 📊 **Project Telemetry**

This project is connected to the Claude Agent Telemetry system for monitoring and analytics.

### **Telemetry Status**
- ✅ **Connected**: This project sends telemetry data to centralized Loki server
- 🏷️ **Project Label**: `"packaging"`
- 🖥️ **Dashboard**: http://localhost:3000 (filter by project name)
- 📁 **Project Path**: `/home/jeff/claude-code/packaging`

### **What Gets Monitored**
All Claude Code tool usage in this project is automatically captured:
- File operations (Read, Write, Edit)
- Command executions (Bash)
- Search operations (Grep, Glob)
- Task delegations and AI interactions
- SuperClaude framework usage (personas, flags, MCP servers)

### **View Telemetry Data**
```bash
# Open Grafana dashboards
open http://localhost:3000

# Filter by this project in LogQL queries:
{service="claude-telemetry", project="packaging"}

# Check telemetry system status
~/tools/agent-telemetry/scripts/status.sh
```

### **Management Commands**
```bash
# View all connected projects
~/tools/agent-telemetry/scripts/list-connected-projects.sh

# Check this project's connection status  
~/tools/agent-telemetry/scripts/list-connected-projects.sh --status

# Disconnect this project (if needed)
~/tools/agent-telemetry/scripts/disconnect-project.sh "/home/jeff/claude-code/packaging"

# Reconnect this project
~/tools/agent-telemetry/scripts/connect-project.sh "/home/jeff/claude-code/packaging" "packaging"
```

### **Telemetry Files in This Project**
- `.claude/hooks/telemetry-hook.sh` - Project-specific telemetry hook
- `.claude/settings.json` - Claude Code hook configuration  
- `.telemetry-enabled` - Telemetry activation marker

### **Telemetry System**
- **Repository**: https://github.com/D9kej5892KfW/Calcutta-multi
- **Installation**: `~/tools/agent-telemetry/` (Reference Installation)
- **Documentation**: See main telemetry repository README for full setup guide

---
