#!/bin/bash
# Connect Project to Claude Agent Telemetry System
# Usage: ./connect-project.sh <project-path> [project-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory (where agent-telemetry is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELEMETRY_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
DEFAULT_LOKI_URL="http://localhost:3100"

# Usage function
usage() {
    echo "Usage: $0 <project-path> [project-name]"
    echo ""
    echo "Connect a new project to the Claude Agent Telemetry system."
    echo ""
    echo "Arguments:"
    echo "  project-path    Absolute path to the project directory"
    echo "  project-name    Optional custom name for the project (defaults to directory name)"
    echo ""
    echo "Examples:"
    echo "  $0 /home/user/my-new-project"
    echo "  $0 /home/user/my-project 'My Custom Project'"
    echo ""
    echo "What this script does:"
    echo "  1. Creates a custom telemetry hook for the project"
    echo "  2. Sets up Claude Code configuration (settings.json)"
    echo "  3. Enables telemetry with project-specific labels"
    echo "  4. Validates connection to Loki server"
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

# Validation functions
validate_project_path() {
    local project_path="$1"
    
    if [[ ! -d "$project_path" ]]; then
        log_error "Project directory does not exist: $project_path"
        exit 1
    fi
    
    if [[ ! -w "$project_path" ]]; then
        log_error "Project directory is not writable: $project_path"
        exit 1
    fi
}

validate_loki_connection() {
    local loki_url="$1"
    
    log_info "Testing connection to Loki server at $loki_url"
    
    if ! curl -s -f "$loki_url/ready" >/dev/null 2>&1; then
        log_warning "Loki server is not responding at $loki_url"
        log_warning "Make sure to start Loki with: $TELEMETRY_ROOT/scripts/start-loki.sh"
        return 1
    fi
    
    log_success "Loki server is running and accessible"
    return 0
}

# Check if project is already connected
check_existing_connection() {
    local project_path="$1"
    
    if [[ -f "$project_path/.claude/settings.json" ]]; then
        if grep -q "telemetry-hook" "$project_path/.claude/settings.json" 2>/dev/null; then
            log_warning "Project appears to already have telemetry configured"
            echo -n "Overwrite existing configuration? [y/N]: "
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                log_info "Aborted by user"
                exit 0
            fi
        fi
    fi
}

# Create project-specific telemetry hook
create_telemetry_hook() {
    local project_path="$1"
    local project_name="$2"
    local loki_url="$3"
    
    local hook_dir="$project_path/.claude/hooks"
    local hook_file="$hook_dir/telemetry-hook.sh"
    local template_file="$TELEMETRY_ROOT/templates/telemetry-hook-template.sh"
    
    # Create directories
    mkdir -p "$hook_dir"
    
    # Copy and customize template
    log_info "Creating project-specific telemetry hook"
    
    sed -e "s|{{PROJECT_NAME}}|$project_name|g" \
        -e "s|{{PROJECT_PATH}}|$project_path|g" \
        -e "s|{{TELEMETRY_SERVER_URL}}|$loki_url|g" \
        -e "s|{{TELEMETRY_ENABLED}}|true|g" \
        "$template_file" > "$hook_file"
    
    # Make executable
    chmod +x "$hook_file"
    
    log_success "Telemetry hook created: $hook_file"
}

# Create or update Claude Code settings
setup_claude_settings() {
    local project_path="$1"
    
    local settings_dir="$project_path/.claude"
    local settings_file="$settings_dir/settings.json"
    local hook_file="$settings_dir/hooks/telemetry-hook.sh"
    
    # Create directory
    mkdir -p "$settings_dir"
    
    # Create settings.json
    log_info "Configuring Claude Code settings"
    
    cat > "$settings_file" << EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$hook_file"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$hook_file"
          }
        ]
      }
    ]
  }
}
EOF
    
    log_success "Claude Code settings configured: $settings_file"
}

# Enable telemetry marker
enable_telemetry() {
    local project_path="$1"
    local marker_file="$project_path/.telemetry-enabled"
    
    log_info "Enabling telemetry for project"
    
    cat > "$marker_file" << EOF
# Telemetry enabled for this project
# Connected to Claude Agent Telemetry system
# Created: $(date)
# Server: $DEFAULT_LOKI_URL
EOF
    
    log_success "Telemetry enabled: $marker_file"
}

# Record connection in central registry
record_connection() {
    local project_path="$1"
    local project_name="$2"
    
    local registry_file="$TELEMETRY_ROOT/data/connected-projects.txt"
    mkdir -p "$(dirname "$registry_file")"
    
    # Remove existing entry if present
    if [[ -f "$registry_file" ]]; then
        grep -v "^$project_path|" "$registry_file" > "$registry_file.tmp" 2>/dev/null || touch "$registry_file.tmp"
        mv "$registry_file.tmp" "$registry_file"
    fi
    
    # Add new entry
    echo "$project_path|$project_name|$(date -Iseconds)" >> "$registry_file"
    
    log_success "Project registered in telemetry system"
}

# Test telemetry connection
test_telemetry() {
    local project_path="$1"
    local project_name="$2"
    
    log_info "Testing telemetry connection"
    
    # Create test payload
    local test_payload='{
        "streams": [
            {
                "stream": {
                    "service": "claude-telemetry",
                    "project": "'"$project_name"'",
                    "tool": "ConnectionTest",
                    "event": "connection_test"
                },
                "values": [
                    ["'"$(date +%s%N)"'", "{\"timestamp\":\"'"$(date -Iseconds)"'\",\"message\":\"Connection test from '"$project_name"'\",\"status\":\"success\"}"]
                ]
            }
        ]
    }'
    
    if curl -s -H "Content-Type: application/json" \
            -XPOST "$DEFAULT_LOKI_URL/loki/api/v1/push" \
            -d "$test_payload" >/dev/null 2>&1; then
        log_success "Test telemetry data sent successfully"
    else
        log_warning "Failed to send test data (Loki may not be running)"
    fi
}

# Main function
main() {
    local project_path="$1"
    local project_name="$2"
    
    # Validate arguments
    if [[ -z "$project_path" ]]; then
        log_error "Project path is required"
        usage
    fi
    
    # Convert to absolute path
    project_path=$(realpath "$project_path")
    
    # Default project name to directory name
    if [[ -z "$project_name" ]]; then
        project_name=$(basename "$project_path")
    fi
    
    log_info "Connecting project: $project_name"
    log_info "Project path: $project_path"
    log_info "Telemetry server: $DEFAULT_LOKI_URL"
    echo ""
    
    # Validation
    validate_project_path "$project_path"
    check_existing_connection "$project_path"
    
    # Connection setup
    create_telemetry_hook "$project_path" "$project_name" "$DEFAULT_LOKI_URL"
    setup_claude_settings "$project_path"
    enable_telemetry "$project_path"
    record_connection "$project_path" "$project_name"
    
    # Test connection (optional)
    if validate_loki_connection "$DEFAULT_LOKI_URL"; then
        test_telemetry "$project_path" "$project_name"
    fi
    
    # Update project documentation
    log_info "Updating project documentation"
    if [[ -x "$SCRIPT_DIR/update-project-docs.sh" ]]; then
        "$SCRIPT_DIR/update-project-docs.sh" "$project_path" "$project_name" 2>/dev/null || log_warning "Could not update project documentation"
    fi
    
    echo ""
    log_success "Project '$project_name' successfully connected to telemetry system!"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Navigate to your project: cd '$project_path'"
    echo "2. Check CLAUDE.md for telemetry documentation and management commands"
    echo "3. Use Claude Code normally - all tool usage will be monitored"
    echo "4. View telemetry in Grafana: http://localhost:3000"
    echo "5. Filter by project: Use 'project=\"$project_name\"' in dashboard queries"
    echo ""
    echo -e "${BLUE}Management commands:${NC}"
    echo "• List connected projects: $SCRIPT_DIR/list-connected-projects.sh"
    echo "• Disconnect project: $SCRIPT_DIR/disconnect-project.sh '$project_path'"
    echo "• Start monitoring services: $TELEMETRY_ROOT/scripts/start-loki.sh && $TELEMETRY_ROOT/scripts/start-grafana.sh"
}

# Handle arguments
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

# Run main function
main "$@"