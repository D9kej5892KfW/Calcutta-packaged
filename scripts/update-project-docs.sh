#!/bin/bash
# Update Project Documentation with Telemetry Information
# Usage: ./update-project-docs.sh <project-path> <project-name>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELEMETRY_ROOT="$(dirname "$SCRIPT_DIR")"

# Usage function
usage() {
    echo "Usage: $0 <project-path> <project-name>"
    echo ""
    echo "Updates project documentation with telemetry information."
    echo ""
    echo "Arguments:"
    echo "  project-path    Path to the project directory"
    echo "  project-name    Name of the project in telemetry system"
    echo ""
    echo "Examples:"
    echo "  $0 /home/user/my-project 'My Project'"
    echo "  $0 \$(pwd) 'Current Project'"
    echo ""
    exit 1
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Generate telemetry documentation section
generate_telemetry_docs() {
    local project_path="$1"
    local project_name="$2"
    local github_repo="https://github.com/D9kej5892KfW/Calcutta-multi"
    
    cat << EOF
## 📊 **Project Telemetry**

This project is connected to the Claude Agent Telemetry system for monitoring and analytics.

### **Telemetry Status**
- ✅ **Connected**: This project sends telemetry data to centralized Loki server
- 🏷️ **Project Label**: \`"$project_name"\`
- 🖥️ **Dashboard**: http://localhost:3000 (filter by project name)
- 📁 **Project Path**: \`$project_path\`

### **What Gets Monitored**
All Claude Code tool usage in this project is automatically captured:
- File operations (Read, Write, Edit)
- Command executions (Bash)
- Search operations (Grep, Glob)
- Task delegations and AI interactions
- SuperClaude framework usage (personas, flags, MCP servers)

### **View Telemetry Data**
\`\`\`bash
# Open Grafana dashboards
open http://localhost:3000

# Filter by this project in LogQL queries:
{service="claude-telemetry", project="$project_name"}

# Check telemetry system status
~/tools/agent-telemetry/scripts/status.sh
\`\`\`

### **Management Commands**
\`\`\`bash
# View all connected projects
~/tools/agent-telemetry/scripts/list-connected-projects.sh

# Check this project's connection status  
~/tools/agent-telemetry/scripts/list-connected-projects.sh --status

# Disconnect this project (if needed)
~/tools/agent-telemetry/scripts/disconnect-project.sh "$project_path"

# Reconnect this project
~/tools/agent-telemetry/scripts/connect-project.sh "$project_path" "$project_name"
\`\`\`

### **Telemetry Files in This Project**
- \`.claude/hooks/telemetry-hook.sh\` - Project-specific telemetry hook
- \`.claude/settings.json\` - Claude Code hook configuration  
- \`.telemetry-enabled\` - Telemetry activation marker

### **Telemetry System**
- **Repository**: $github_repo
- **Installation**: \`~/tools/agent-telemetry/\` (Reference Installation)
- **Documentation**: See main telemetry repository README for full setup guide

---

EOF
}

# Update or create CLAUDE.md file
update_claude_md() {
    local project_path="$1"
    local project_name="$2"
    local claude_md="$project_path/CLAUDE.md"
    local temp_file="$project_path/.claude_md_temp"
    
    log_info "Updating project documentation"
    
    # Generate new telemetry section
    local telemetry_section
    telemetry_section=$(generate_telemetry_docs "$project_path" "$project_name")
    
    if [[ -f "$claude_md" ]]; then
        # Check if telemetry section already exists
        if grep -q "## 📊 \*\*Project Telemetry\*\*" "$claude_md"; then
            log_info "Updating existing telemetry section in CLAUDE.md"
            
            # Remove old telemetry section and add new one
            awk '
                /^## 📊 \*\*Project Telemetry\*\*/ { skip = 1 }
                /^## [^📊]/ && skip { skip = 0 }
                !skip { print }
            ' "$claude_md" > "$temp_file"
            
            # Add new section
            echo "$telemetry_section" >> "$temp_file"
            
            # Add any content that came after the old telemetry section
            awk '
                /^## 📊 \*\*Project Telemetry\*\*/ { skip = 1; next }
                /^## [^📊]/ && skip { skip = 0 }
                !skip && found_next { print }
                /^## [^📊]/ && skip { found_next = 1 }
            ' "$claude_md" >> "$temp_file"
            
            mv "$temp_file" "$claude_md"
        else
            log_info "Adding telemetry section to existing CLAUDE.md"
            echo -e "\n$telemetry_section" >> "$claude_md"
        fi
    else
        log_info "Creating new CLAUDE.md with telemetry section"
        cat > "$claude_md" << EOF
# Project Documentation

$telemetry_section
EOF
    fi
    
    log_success "CLAUDE.md updated with telemetry information"
}

# Main function
main() {
    local project_path="$1"
    local project_name="$2"
    
    # Validate arguments
    if [[ -z "$project_path" ]] || [[ -z "$project_name" ]]; then
        log_error "Both project path and project name are required"
        usage
    fi
    
    # Convert to absolute path
    project_path=$(realpath "$project_path")
    
    # Validate project path
    if [[ ! -d "$project_path" ]]; then
        log_error "Project directory does not exist: $project_path"
        exit 1
    fi
    
    log_info "Updating documentation for project: $project_name"
    log_info "Project path: $project_path"
    echo ""
    
    # Update documentation
    update_claude_md "$project_path" "$project_name"
    
    echo ""
    log_success "Project documentation updated!"
    log_info "Documentation file: $project_path/CLAUDE.md"
    echo ""
    echo -e "${BLUE}The CLAUDE.md file now includes:${NC}"
    echo "• Telemetry connection status and project label"
    echo "• Instructions for viewing telemetry data"
    echo "• Management commands for this project"
    echo "• Links to main telemetry system documentation"
}

# Handle arguments
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

# Run main function
main "$@"