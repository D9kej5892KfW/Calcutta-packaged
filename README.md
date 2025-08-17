# Claude Agent Telemetry

> **Production-ready monitoring for [Claude Code](https://claude.ai/code) AI development workflows**  
> Real-time telemetry, security analysis, and ML-powered behavioral insights for solo developers

[![Setup](https://img.shields.io/badge/setup-one%20command-brightgreen)](#quick-start)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macOS-blue)](#requirements)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Production Ready](https://img.shields.io/badge/status-production%20ready-success)](docs/claude-agent-telemetry.md)

## 🎯 What Is This?

**Claude Code** is Anthropic's official CLI that lets you work with Claude AI directly from your terminal. This telemetry system **monitors your Claude Code usage** to help you:

- **📊 Understand your AI workflow** - Which tools do you use most? How efficient are your patterns?
- **🔍 Optimize productivity** - Identify bottlenecks, track improvements, analyze delegation patterns  
- **🛡️ Monitor security boundaries** - Detect when Claude accesses files outside your project scope
- **🧠 Learn from behavioral insights** - ML-powered analysis of your development patterns over time

**Perfect for**: Solo developers, small teams, anyone wanting visibility into their Claude Code workflows  
**Not for**: Enterprise security auditing, complex multi-tenant environments

## ✨ Features

- **🔍 Complete Activity Monitoring** - Every Claude tool usage captured and analyzed
- **🛡️ Security Boundary Enforcement** - Real-time detection of out-of-scope access
- **🧠 ML-Powered Analytics** - Behavioral pattern analysis with anomaly detection
- **📊 Live Dashboards** - Real-time Grafana visualizations with 34K+ data points
- **🚀 Zero-Config Setup** - One command installation with automatic dependency management
- **🔗 Multi-Project Support** - Monitor unlimited projects from central installation

## 🚀 Quick Start

### **Method 1: NPM Package (Recommended)**
```bash
# 1. Install from NPM registry
npm install -g claude-agent-telemetry

# 2. Setup system
claude-telemetry setup

# 3. Start monitoring
claude-telemetry start

# 4. Open dashboard
claude-telemetry dashboard
```

### **Method 2: Direct Repository**
```bash
# 1. Clone and setup (one command!)
git clone https://github.com/D9kej5892KfW/Calcutta-multi.git claude-telemetry
cd claude-telemetry
npm run setup

# 2. Start monitoring
npm start

# 3. Open dashboard
npm run dashboard
```

**That's it!** Your Claude Code activity is now being monitored in real-time.

## ⚡ **Quick Setup for Each Project**

**After initial installation, you need to connect each project you want to monitor:**

```bash
# Navigate to any project
cd /path/to/your-project

# Connect it (creates .claude/ hooks)
claude-telemetry connect

# Use Claude normally - telemetry automatic!
claude
```

**One connection per project** - then telemetry works automatically every time you use Claude in that directory! 🎯

## 📦 What You Get

### **Instant Setup**
- ✅ **Automated dependency installation** (Python, system tools)
- ✅ **Pre-built binaries** (Loki, Grafana) - no compilation needed
- ✅ **Health validation** - comprehensive system checks
- ✅ **Claude Code integration** - automatic hook configuration

### **Production Features**
- ✅ **34K+ telemetry entries** processed and analyzed
- ✅ **Sub-second queries** with efficient data storage (7.2MB for full dataset)
- ✅ **Real-time dashboards** with customizable time windows
- ✅ **Security monitoring** with 12+ detection rules
- ✅ **Cross-platform** Linux and macOS support

## 📸 See It In Action

![Dashboard Overview](screenshots/Basic-dashboard-1.png)
*Real-time monitoring of Claude Code tool usage and performance metrics*

![Security Monitoring](screenshots/Basic-dashboard-2.png)  
*Security boundary detection and behavioral analysis*

![Analytics Dashboard](screenshots/Basic-dashboard-3.png)
*ML-powered insights and productivity patterns*

## 📋 Commands

### **npm Interface (Recommended)**
| Command | Description |
|---------|-------------|
| `npm run setup` | **One-time setup** - installs everything automatically |
| `npm start` | **Start monitoring** - Loki + Grafana services |
| `npm stop` | **Stop monitoring** - clean shutdown |
| `npm run dashboard` | **Open Grafana** - launches browser to dashboard |
| `npm run connect` | **Connect project** - add current directory to monitoring |
| `npm run status` | **Check health** - validate all services |
| `npm run logs` | **Live stream** - watch telemetry in real-time |
| `npm run health` | **Health check** - comprehensive system validation |
| `npm test` | **End-to-end test** - validate complete data flow |

### **Direct CLI Interface**
```bash
# Core operations
./scripts/claude-telemetry setup              # Complete system setup
./scripts/claude-telemetry start              # Start monitoring services
./scripts/claude-telemetry stop               # Stop all services
./scripts/claude-telemetry status             # Check system health
./scripts/claude-telemetry dashboard          # Open Grafana dashboard

# Project management
./scripts/claude-telemetry connect [path]     # Connect project to telemetry
./scripts/claude-telemetry disconnect [path]  # Disconnect project
./scripts/claude-telemetry projects           # List connected projects

# Analytics & maintenance
./scripts/claude-telemetry analytics          # Process ML data
./scripts/claude-telemetry backup             # Backup telemetry data
./scripts/claude-telemetry cleanup            # Clean logs
./scripts/claude-telemetry alerts start       # Start alert engine

# Advanced usage
./scripts/claude-telemetry --help             # Show all commands
./scripts/claude-telemetry --dry-run status   # Preview actions
```

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Claude Code   │───▶│  Telemetry Hook  │───▶│  Loki Storage   │
│   Tool Usage    │    │  (Pre/Post Tool) │    │  + Local Backup │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│    Grafana      │◀───│  Query Engine    │◀───│   Loki Server   │
│   Dashboard     │    │  (LogQL/HTTP)    │    │   (Port 3100)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

**Data Flow**: Claude Tool → Hook → Loki → Grafana → Insights

## 📊 Monitoring Capabilities

### **Tools Monitored**
- **File Operations**: `Read`, `Write`, `Edit`, `MultiEdit`
- **Command Execution**: `Bash`, shell commands with arguments
- **Code Analysis**: `Grep`, `Glob`, search patterns
- **AI Operations**: `Task` delegation, `WebFetch`, `WebSearch`
- **Task Management**: `TodoWrite`, progress tracking

### **Security Features**
- **Boundary Detection**: Flags access outside project scope
- **Command Monitoring**: Captures all shell executions
- **Session Tracking**: Correlates activities by session ID
- **Risk Scoring**: ML-based behavioral analysis

### **Analytics Pipeline**
- **Real-time Processing**: Live telemetry ingestion
- **Feature Extraction**: 16+ behavioral patterns
- **Anomaly Detection**: Isolation Forest models
- **Trend Analysis**: Historical pattern recognition

## 🌐 Dashboards

Access comprehensive monitoring at **http://localhost:3000** (admin/admin):

- **📈 Performance Dashboard** - Tool usage, response times, activity rates
- **🔒 Security Dashboard** - Boundary violations, command patterns, risk alerts
- **🧠 Analytics Dashboard** - Behavioral insights, anomaly detection, trends
- **📊 System Dashboard** - Service health, data processing, storage metrics

## 🔧 Advanced Usage

### **Project Connection & Monitoring**

**⚠️ IMPORTANT**: You must connect each project individually to enable telemetry monitoring.

#### **How It Works:**
1. **Telemetry runs globally** (one installation monitors multiple projects)
2. **Each project needs connection** (creates Claude Code hooks)
3. **Claude automatically sends data** (no changes to your workflow)

#### **Setup for Each Project:**
```bash
# 1. Start telemetry services (if not running)
claude-telemetry start

# 2. Navigate to your project
cd /path/to/your-project

# 3. Connect THIS project (one-time setup)
claude-telemetry connect

# 4. Use Claude normally - telemetry works automatically!
claude
```

#### **When You Need to Connect:**
- ✅ **New projects** you want to monitor
- ✅ **Each directory** where you'll use Claude Code
- ✅ **After moving to a different project**
- ❌ **NOT needed** for already connected projects
- ❌ **NOT needed** when restarting Claude in same project

#### **Managing Connected Projects:**
```bash
# List all monitored projects
claude-telemetry projects

# Check if current project is connected
ls .claude/ 2>/dev/null && echo "Connected!" || echo "Need to connect"

# Disconnect a project (optional)
claude-telemetry disconnect /path/to/project

# View project-specific data in Grafana
# Filter: project="your-project-name"
```

### **Custom Queries**
```bash
# All activity for a specific project
curl -G "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={service="claude-telemetry", project="my-project"}'

# Security violations
curl -G "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={service="claude-telemetry"} |= "outside_project_scope.*true"'
```

### **Data Export**
```bash
# Export telemetry data
cp data/logs/claude-telemetry.jsonl /path/to/backup/

# Analytics data
tar -czf telemetry-backup.tar.gz data/analytics/
```

## 🛠️ Troubleshooting

### **Setup Issues**
```bash
npm run health     # Comprehensive health check
npm run validate   # Validate installation
npm run setup      # Re-run setup if needed
```

### **Service Issues**
```bash
npm run status     # Check service status
npm restart        # Restart all services
npm run logs       # View live telemetry
```

### **Common Problems**

| Problem | Solution |
|---------|----------|
| "Loki not ready" | `npm restart` |
| "Missing dependencies" | `npm run setup` |
| "Permission denied" | `chmod +x scripts/*.sh` |
| "Python import error" | Check virtual environment: `source venv/bin/activate` |

### **Complete Cleanup & Shutdown**

When you need to completely stop and clean up your telemetry environment:

```bash
# 1. Stop telemetry services
npx claude-telemetry stop

# 2. Verify services are stopped
npx claude-telemetry status

# 3. Check for any remaining processes
ps aux | grep -E 'loki|grafana' | grep -v grep

# 4. Kill any stubborn processes if found
# pkill loki
# pkill grafana

# 5. Verify ports are free
netstat -tlnp 2>/dev/null | grep -E ':300[01]|:9096|:3100' || echo "All ports free"

# 6. Exit the test directory
cd ~

# 7. Clean up test directory (optional)
rm -rf /tmp/test-claude-telemetry*
```

**Complete System Reset** (if needed):
```bash
# Remove cached binaries (requires re-download next time)
rm -rf ~/.claude-telemetry/

# Remove NPM package completely
npm uninstall -g claude-agent-telemetry
npm cache clean --force
rm -rf ~/.npm/_npx/
```

This ensures a completely clean environment for fresh testing or troubleshooting.

### **Fresh Installation Testing**

For testing or development, here's the complete workflow from cleanup to fresh install:

```bash
# 1. Complete cleanup (if needed)
npx claude-telemetry stop 2>/dev/null || true
pkill loki grafana 2>/dev/null || true
npm uninstall -g claude-agent-telemetry 2>/dev/null || true
npm cache clean --force
rm -rf ~/.npm/_npx/ ~/.claude-telemetry/
rm -rf /tmp/test-claude-telemetry*

# 2. Create fresh test environment
mkdir /tmp/test-claude-telemetry-clean
cd /tmp/test-claude-telemetry-clean

# 3. Fresh installation
npm install claude-agent-telemetry
npx claude-telemetry setup

# 4. Test functionality
npx claude-telemetry start
npx claude-telemetry status
npx claude-telemetry dashboard

# 5. Test stop functionality
npx claude-telemetry stop
curl http://localhost:3100/ready 2>/dev/null || echo "✅ Loki stopped"
curl http://localhost:3000/api/health 2>/dev/null || echo "✅ Grafana stopped"
```

Perfect for validating package functionality or troubleshooting issues.

## 📋 Requirements

### **Prerequisites**
- **[Claude Code](https://claude.ai/code) installed and working** - This is what we monitor!
- **Linux or macOS** - Windows support coming soon
- **Internet connection** - For initial setup only

### **Automatic (handled by setup)**
- Python 3.8+ with pip
- System tools: `curl`, `jq`  
- ~1.6GB disk space

> **New to Claude Code?** Get started at [claude.ai/code](https://claude.ai/code) - it's Anthropic's official CLI for AI-powered development.

## 🔐 Security & Privacy

- **Local-only**: All data stays on your machine
- **No external transmission**: Zero network dependencies after setup
- **Metadata-only**: Tool usage patterns, not file contents
- **Configurable**: Easy enable/disable per project
- **Audit trail**: Complete activity history for compliance

## 📖 Documentation

- **Setup Guide**: This README
- **Architecture Deep-dive**: `docs/claude-agent-telemetry.md`
- **Dashboard Guide**: `docs/dashboard/`
- **API Reference**: Loki LogQL and HTTP API documentation

## 🚀 Getting Started

1. **Install Claude Code** (if you haven't): Visit [claude.ai/code](https://claude.ai/code)
2. **Clone this repo**: `git clone https://github.com/D9kej5892KfW/Calcutta-multi.git`
3. **Run setup**: `npm run setup` 
4. **Start monitoring**: `npm start`
5. **Open dashboard**: `npm run dashboard`

## 🏗️ Third-Party Software

This package downloads and uses the following open-source software:

- **[Grafana](https://github.com/grafana/grafana)** - Licensed under Apache 2.0 License
- **[Loki](https://github.com/grafana/loki)** - Licensed under Apache 2.0 License

These components are downloaded from their official release channels and used as intended by their creators. See their respective repositories for full license terms.

### Disclaimer

This package downloads third-party binaries. Users are responsible for complying with the licenses of downloaded software.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature-name`
3. Test changes: `npm test`
4. Submit pull request

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 💡 Pro Tips

- **Use `npm run logs`** to watch live telemetry during development
- **Filter by project** in Grafana: `{project="your-project-name"}`
- **Health checks** are your friend: `npm run health` for quick diagnostics
- **Export data** regularly for long-term analysis and backup

**Ready to monitor your Claude Code activities like a pro? Run `npm run setup` and get started in under 2 minutes!** 🚀