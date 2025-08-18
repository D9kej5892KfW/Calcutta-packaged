#!/bin/bash
# Cleanup Orphaned Telemetry Processes and Sessions
# Detects orphaned processes and migrates projects to main installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Source common utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../common/paths.sh" || {
    echo -e "${RED}[ERROR]${NC} Could not load path utilities" >&2
    exit 1
}

# Source registry helpers
source "$SCRIPT_DIR/registry-helpers.sh" || {
    echo -e "${RED}[ERROR]${NC} Could not load registry helpers" >&2
    exit 1
}

TELEMETRY_ROOT="$(get_telemetry_root)"
REGISTRY_FILE="$TELEMETRY_ROOT/data/connected-projects.txt"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Cleanup orphaned telemetry processes and migrate projects to main installation."
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -n, --dry-run   Show what would be done without making changes"
    echo "  -f, --force     Skip confirmation prompts"
    echo "  -k, --keep-data Keep telemetry data during migration"
    echo ""
    echo "What this script does:"
    echo "  1. Identifies orphaned sessions (running from temp/test locations)"
    echo "  2. Stops orphaned processes gracefully"
    echo "  3. Migrates projects to use main telemetry installation"
    echo "  4. Starts services from main installation"
    echo "  5. Updates project configurations"
    echo ""
    exit 1
}

# Check if path looks like orphaned location
is_orphaned_path() {
    local path="$1"
    [[ "$path" =~ /tmp/ ]] || [[ "$path" =~ test.*telemetry ]] || [[ "$path" != "$TELEMETRY_ROOT" ]]
}

# Get orphaned sessions
get_orphaned_sessions() {
    local orphaned_sessions=()
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        return 0
    fi
    
    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
            eval "$(parse_registry_line "$line")"
            if is_orphaned_path "$installation_path"; then
                if [[ ! " ${orphaned_sessions[@]} " =~ " $session_id " ]]; then
                    orphaned_sessions+=("$session_id")
                fi
            fi
        fi
    done < "$REGISTRY_FILE"
    
    printf '%s\n' "${orphaned_sessions[@]}"
}

# Get projects in session
get_session_projects() {
    local target_session="$1"
    local projects=()
    
    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
            eval "$(parse_registry_line "$line")"
            if [[ "$session_id" == "$target_session" ]]; then
                projects+=("$project_path|$project_name")
            fi
        fi
    done < "$REGISTRY_FILE"
    
    printf '%s\n' "${projects[@]}"
}

# Stop processes safely
stop_processes() {
    local pids="$1"
    local service_name="$2"
    local dry_run="$3"
    
    if [[ -z "$pids" ]] || [[ "$pids" == "none" ]]; then
        log_info "$service_name: No processes to stop"
        return 0
    fi
    
    log_info "Stopping $service_name (PIDs: $pids)"
    
    for pid in $pids; do
        if kill -0 "$pid" 2>/dev/null; then
            if [[ "$dry_run" == "true" ]]; then
                echo "  [DRY RUN] Would stop PID $pid"
            else
                log_info "Stopping PID $pid gracefully..."
                if kill -TERM "$pid" 2>/dev/null; then
                    # Wait for graceful shutdown
                    local count=0
                    while kill -0 "$pid" 2>/dev/null && [[ $count -lt 30 ]]; do
                        sleep 1
                        ((count++))
                    done
                    
                    if kill -0 "$pid" 2>/dev/null; then
                        log_warning "Process $pid did not stop gracefully, forcing..."
                        kill -KILL "$pid" 2>/dev/null || true
                    fi
                    log_success "Stopped PID $pid"
                else
                    log_warning "Could not stop PID $pid (may already be stopped)"
                fi
            fi
        else
            log_info "PID $pid already stopped"
        fi
    done
}

# Generate new session ID for main installation
generate_main_session_id() {
    local session_hash=$(echo "$TELEMETRY_ROOT" | md5sum | cut -c1-8)
    echo "session_$session_hash"
}

# Migrate project to main installation
migrate_project() {
    local project_path="$1"
    local project_name="$2"
    local connected_date="$3"
    local new_session_id="$4"
    local dry_run="$5"
    
    log_info "Migrating project: $project_name"
    
    # Update telemetry hook to point to main installation
    local hook_file="$project_path/.claude/hooks/telemetry-hook.sh"
    local template_file="$TELEMETRY_ROOT/templates/telemetry-hook-template.sh"
    
    if [[ -f "$template_file" ]]; then
        if [[ "$dry_run" == "true" ]]; then
            echo "  [DRY RUN] Would update hook: $hook_file"
        else
            log_info "Updating telemetry hook..."
            sed -e "s|{{PROJECT_NAME}}|$project_name|g" \
                -e "s|{{PROJECT_PATH}}|$project_path|g" \
                -e "s|{{TELEMETRY_SERVER_URL}}|http://localhost:3100|g" \
                -e "s|{{TELEMETRY_ENABLED}}|true|g" \
                "$template_file" > "$hook_file"
            chmod +x "$hook_file"
            log_success "Updated hook for $project_name"
        fi
    else
        log_warning "Template not found, hook may need manual update"
    fi
    
    # Update registry entry
    local new_line="$project_path|$project_name|$connected_date|||$TELEMETRY_ROOT|$new_session_id|active"
    
    if [[ "$dry_run" == "true" ]]; then
        echo "  [DRY RUN] Would update registry entry"
    else
        update_project_in_registry "$REGISTRY_FILE" "$project_path" "$new_line"
        log_success "Updated registry for $project_name"
    fi
}

# Start main telemetry services
start_main_services() {
    local dry_run="$1"
    
    log_info "Starting main telemetry services..."
    
    if [[ "$dry_run" == "true" ]]; then
        echo "  [DRY RUN] Would start Loki and Grafana from main installation"
        return 0
    fi
    
    # Start Loki
    if [[ -x "$TELEMETRY_ROOT/scripts/lib/services/start-loki.sh" ]]; then
        log_info "Starting Loki from main installation..."
        "$TELEMETRY_ROOT/scripts/lib/services/start-loki.sh" || log_warning "Failed to start Loki"
    else
        log_warning "Loki start script not found"
    fi
    
    # Wait a moment for Loki to start
    sleep 2
    
    # Start Grafana
    if [[ -x "$TELEMETRY_ROOT/scripts/lib/services/start-grafana.sh" ]]; then
        log_info "Starting Grafana from main installation..."
        "$TELEMETRY_ROOT/scripts/lib/services/start-grafana.sh" || log_warning "Failed to start Grafana"
    else
        log_warning "Grafana start script not found"
    fi
    
    log_success "Main services started"
}

# Update registry with new process IDs
update_registry_pids() {
    local session_id="$1"
    local dry_run="$2"
    
    if [[ "$dry_run" == "true" ]]; then
        echo "  [DRY RUN] Would detect new process PIDs and update registry"
        return 0
    fi
    
    log_info "Updating registry with new process IDs..."
    
    # Detect new processes
    sleep 3  # Wait for processes to fully start
    local loki_pids=($(pgrep -f "loki.*-config.file" 2>/dev/null || true))
    local grafana_pids=($(pgrep -f "grafana.*server" 2>/dev/null || true))
    
    # Update all projects in this session
    local temp_file="${REGISTRY_FILE}.tmp"
    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
            eval "$(parse_registry_line "$line")"
            if [[ "$session_id" == "$session_id" ]]; then
                # Update with new PIDs
                echo "$project_path|$project_name|$connected_date|${loki_pids[*]}|${grafana_pids[*]}|$installation_path|$session_id|active" >> "$temp_file"
            else
                echo "$line" >> "$temp_file"
            fi
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$REGISTRY_FILE"
    
    mv "$temp_file" "$REGISTRY_FILE"
    log_success "Registry updated with new process IDs"
}

# Cleanup orphaned session
cleanup_orphaned_session() {
    local session_id="$1"
    local dry_run="$2"
    local force="$3"
    
    echo -e "${PURPLE}Processing orphaned session: $session_id${NC}"
    
    # Get session details
    local first_line=$(grep "|$session_id|" "$REGISTRY_FILE" | head -1)
    eval "$(parse_registry_line "$first_line")"
    
    echo -e "${CYAN}Installation path:${NC} $installation_path"
    
    # Get all projects in this session
    local session_projects=($(get_session_projects "$session_id"))
    echo -e "${CYAN}Projects affected:${NC} ${#session_projects[@]}"
    
    for project_info in "${session_projects[@]}"; do
        IFS='|' read -r project_path project_name <<< "$project_info"
        echo "  └── $project_name ($project_path)"
    done
    
    echo ""
    
    # Confirmation
    if [[ "$force" != "true" ]] && [[ "$dry_run" != "true" ]]; then
        echo -n "Stop orphaned processes and migrate projects to main installation? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Skipped by user"
            return 0
        fi
    fi
    
    # Stop orphaned processes
    log_info "Stopping orphaned processes..."
    stop_processes "$loki_pids" "Loki" "$dry_run"
    stop_processes "$grafana_pids" "Grafana" "$dry_run"
    
    # Generate new session ID for main installation
    local new_session_id=$(generate_main_session_id)
    log_info "New session ID: $new_session_id"
    
    # Migrate each project
    log_info "Migrating projects to main installation..."
    for project_info in "${session_projects[@]}"; do
        IFS='|' read -r project_path project_name <<< "$project_info"
        
        # Get original connection date
        local project_line=$(grep "^$project_path|" "$REGISTRY_FILE")
        eval "$(parse_registry_line "$project_line")"
        
        migrate_project "$project_path" "$project_name" "$connected_date" "$new_session_id" "$dry_run"
    done
    
    # Start main services
    start_main_services "$dry_run"
    
    # Update registry with new PIDs
    update_registry_pids "$new_session_id" "$dry_run"
    
    log_success "Session $session_id cleanup completed"
}

# Main function
main() {
    local dry_run=false
    local force=false
    local keep_data=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -k|--keep-data)
                keep_data=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    echo -e "${BLUE}Orphaned Session Cleanup${NC}"
    echo "========================"
    echo ""
    
    if [[ "$dry_run" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN MODE] - No changes will be made${NC}"
        echo ""
    fi
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        log_warning "No registry found"
        echo "No connected projects found to clean up."
        return 0
    fi
    
    # Find orphaned sessions
    local orphaned_sessions=($(get_orphaned_sessions))
    
    if [[ ${#orphaned_sessions[@]} -eq 0 ]]; then
        log_success "No orphaned sessions found"
        echo "All sessions are using the main installation."
        return 0
    fi
    
    echo -e "${YELLOW}Found ${#orphaned_sessions[@]} orphaned session(s):${NC}"
    echo ""
    
    # Process each orphaned session
    for session_id in "${orphaned_sessions[@]}"; do
        cleanup_orphaned_session "$session_id" "$dry_run" "$force"
        echo ""
    done
    
    echo "========================"
    log_success "Orphaned cleanup completed"
    
    if [[ "$dry_run" != "true" ]]; then
        echo ""
        echo -e "${BLUE}Next steps:${NC}"
        echo "• Check session status: $SCRIPT_DIR/session-status.sh"
        echo "• Open dashboard: http://localhost:3000"
        echo "• Test telemetry: Use Claude in any connected project"
    fi
}

main "$@"