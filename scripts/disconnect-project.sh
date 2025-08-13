#!/bin/bash
# Disconnect Project from Claude Agent Telemetry System
# Usage: ./disconnect-project.sh <project-path>

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

# Usage function
usage() {
    echo "Usage: $0 <project-path>"
    echo ""
    echo "Disconnect a project from the Claude Agent Telemetry system."
    echo ""
    echo "Arguments:"
    echo "  project-path    Absolute path to the project directory"
    echo ""
    echo "Examples:"
    echo "  $0 /home/user/my-project"
    echo ""
    echo "What this script does:"
    echo "  1. Removes telemetry hook from the project"
    echo "  2. Cleans up Claude Code configuration"
    echo "  3. Disables telemetry collection"
    echo "  4. Removes project from telemetry registry"
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
}

# Check if project has telemetry configured
check_telemetry_exists() {
    local project_path="$1"
    
    local has_settings=false
    local has_hook=false
    local has_marker=false
    
    # Check for Claude settings
    if [[ -f "$project_path/.claude/settings.json" ]]; then
        if grep -q "telemetry-hook" "$project_path/.claude/settings.json" 2>/dev/null; then
            has_settings=true
        fi
    fi
    
    # Check for hook file
    if [[ -f "$project_path/.claude/hooks/telemetry-hook.sh" ]]; then
        has_hook=true
    fi
    
    # Check for telemetry marker
    if [[ -f "$project_path/.telemetry-enabled" ]]; then
        has_marker=true
    fi
    
    if [[ "$has_settings" == false ]] && [[ "$has_hook" == false ]] && [[ "$has_marker" == false ]]; then
        log_warning "No telemetry configuration found in project"
        log_info "Project may not be connected to telemetry system"
        return 1
    fi
    
    return 0
}

# Remove telemetry hook
remove_telemetry_hook() {
    local project_path="$1"
    local hook_file="$project_path/.claude/hooks/telemetry-hook.sh"
    
    if [[ -f "$hook_file" ]]; then
        log_info "Removing telemetry hook: $hook_file"
        rm "$hook_file"
        log_success "Telemetry hook removed"
        
        # Remove hooks directory if empty
        local hook_dir="$(dirname "$hook_file")"
        if [[ -d "$hook_dir" ]] && [[ -z "$(ls -A "$hook_dir" 2>/dev/null)" ]]; then
            rmdir "$hook_dir"
            log_success "Empty hooks directory removed"
        fi
    else
        log_info "No telemetry hook found to remove"
    fi
}

# Clean up Claude settings
cleanup_claude_settings() {
    local project_path="$1"
    local settings_file="$project_path/.claude/settings.json"
    
    if [[ ! -f "$settings_file" ]]; then
        log_info "No Claude settings file found"
        return
    fi
    
    log_info "Cleaning up Claude Code settings"
    
    # Check if settings only contain telemetry hooks
    if grep -q "telemetry-hook" "$settings_file" 2>/dev/null; then
        # Create backup
        cp "$settings_file" "$settings_file.backup.$(date +%s)"
        
        # Check if settings file only contains hooks
        local hook_count=$(jq -r '.hooks | length' "$settings_file" 2>/dev/null || echo 0)
        local total_keys=$(jq -r 'keys | length' "$settings_file" 2>/dev/null || echo 0)
        
        if [[ "$hook_count" -gt 0 ]] && [[ "$total_keys" -eq 1 ]]; then
            # Only hooks in settings, remove entire file
            rm "$settings_file"
            log_success "Claude settings file removed (contained only telemetry hooks)"
            
            # Remove .claude directory if empty
            local claude_dir="$(dirname "$settings_file")"
            if [[ -d "$claude_dir" ]] && [[ -z "$(ls -A "$claude_dir" 2>/dev/null)" ]]; then
                rmdir "$claude_dir"
                log_success "Empty .claude directory removed"
            fi
        else
            # Remove only telemetry hooks, keep other settings
            jq 'del(.hooks.PreToolUse[] | select(.hooks[]?.command | contains("telemetry-hook"))) | del(.hooks.PostToolUse[] | select(.hooks[]?.command | contains("telemetry-hook"))) | if .hooks.PreToolUse == [] then del(.hooks.PreToolUse) else . end | if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end | if .hooks == {} then del(.hooks) else . end' "$settings_file" > "$settings_file.tmp"
            mv "$settings_file.tmp" "$settings_file"
            log_success "Telemetry hooks removed from Claude settings"
        fi
    else
        log_info "No telemetry hooks found in Claude settings"
    fi
}

# Disable telemetry marker
disable_telemetry() {
    local project_path="$1"
    local marker_file="$project_path/.telemetry-enabled"
    
    if [[ -f "$marker_file" ]]; then
        log_info "Disabling telemetry marker"
        rm "$marker_file"
        log_success "Telemetry marker removed"
    else
        log_info "No telemetry marker found"
    fi
}

# Remove from central registry
remove_from_registry() {
    local project_path="$1"
    local registry_file="$TELEMETRY_ROOT/data/connected-projects.txt"
    
    if [[ ! -f "$registry_file" ]]; then
        log_info "No project registry found"
        return
    fi
    
    log_info "Removing project from telemetry registry"
    
    # Remove project entry
    if grep -q "^$project_path|" "$registry_file" 2>/dev/null; then
        grep -v "^$project_path|" "$registry_file" > "$registry_file.tmp"
        mv "$registry_file.tmp" "$registry_file"
        log_success "Project removed from registry"
    else
        log_info "Project not found in registry"
    fi
}

# Send disconnect notification to Loki (optional)
send_disconnect_notification() {
    local project_path="$1"
    local project_name="$(basename "$project_path")"
    local loki_url="http://localhost:3100"
    
    log_info "Sending disconnect notification"
    
    # Create disconnect payload
    local disconnect_payload='{
        "streams": [
            {
                "stream": {
                    "service": "claude-telemetry",
                    "project": "'"$project_name"'",
                    "tool": "DisconnectEvent",
                    "event": "project_disconnect"
                },
                "values": [
                    ["'"$(date +%s%N)"'", "{\"timestamp\":\"'"$(date -Iseconds)"'\",\"message\":\"Project '"$project_name"' disconnected from telemetry\",\"action\":\"disconnect\"}"]
                ]
            }
        ]
    }'
    
    if curl -s -H "Content-Type: application/json" \
            -XPOST "$loki_url/loki/api/v1/push" \
            -d "$disconnect_payload" >/dev/null 2>&1; then
        log_success "Disconnect notification sent"
    else
        log_info "Could not send disconnect notification (Loki may not be running)"
    fi
}

# Main function
main() {
    local project_path="$1"
    
    # Validate arguments
    if [[ -z "$project_path" ]]; then
        log_error "Project path is required"
        usage
    fi
    
    # Convert to absolute path
    project_path=$(realpath "$project_path")
    local project_name=$(basename "$project_path")
    
    log_info "Disconnecting project: $project_name"
    log_info "Project path: $project_path"
    echo ""
    
    # Validation
    validate_project_path "$project_path"
    
    if ! check_telemetry_exists "$project_path"; then
        echo ""
        log_warning "Project does not appear to be connected to telemetry system"
        echo -n "Continue anyway? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Aborted by user"
            exit 0
        fi
    fi
    
    # Confirmation
    echo -n "Are you sure you want to disconnect '$project_name' from telemetry? [y/N]: "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Aborted by user"
        exit 0
    fi
    
    echo ""
    
    # Disconnect process
    send_disconnect_notification "$project_path"
    remove_telemetry_hook "$project_path"
    cleanup_claude_settings "$project_path"
    disable_telemetry "$project_path"
    remove_from_registry "$project_path"
    
    echo ""
    log_success "Project '$project_name' successfully disconnected from telemetry system!"
    echo ""
    echo -e "${BLUE}What was removed:${NC}"
    echo "• Telemetry hook: .claude/hooks/telemetry-hook.sh"
    echo "• Hook configuration from .claude/settings.json"
    echo "• Telemetry marker: .telemetry-enabled"
    echo "• Project entry from telemetry registry"
    echo ""
    echo -e "${BLUE}To reconnect later:${NC}"
    echo "$SCRIPT_DIR/connect-project.sh '$project_path'"
}

# Handle arguments
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

# Run main function
main "$@"