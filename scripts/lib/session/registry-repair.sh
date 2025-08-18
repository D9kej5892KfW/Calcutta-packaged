#!/bin/bash
# Registry Repair Tool
# Synchronizes registry with actual .claude configurations and fixes inconsistencies

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
    echo "Repair registry by synchronizing with actual .claude configurations."
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -n, --dry-run   Show what would be done without making changes"
    echo "  -v, --verbose   Show detailed information"
    echo "  -f, --force     Force repair even if registry seems healthy"
    echo ""
    echo "What this script does:"
    echo "  1. Scans for .claude directories with telemetry hooks"
    echo "  2. Validates registry entries against actual configurations"
    echo "  3. Adds missing projects to registry"
    echo "  4. Removes invalid registry entries"
    echo "  5. Updates process information and session details"
    echo ""
    exit 1
}

# Find all projects with telemetry configurations
discover_telemetry_projects() {
    local search_paths=("$HOME/claude-code" "$HOME" "/home" "/Users")
    local discovered_projects=()
    
    log_info "Scanning for projects with telemetry configuration..."
    
    for search_path in "${search_paths[@]}"; do
        if [[ -d "$search_path" ]]; then
            # Find projects with telemetry hooks
            while IFS= read -r -d '' hook_file; do
                local project_path=$(dirname "$(dirname "$hook_file")")
                local project_name=$(basename "$project_path")
                
                # Validate it's a real telemetry hook
                if [[ -f "$project_path/.claude/settings.json" ]] && \
                   grep -q "telemetry-hook" "$project_path/.claude/settings.json" 2>/dev/null; then
                    discovered_projects+=("$project_path|$project_name")
                fi
            done < <(find "$search_path" -name "telemetry-hook.sh" -path "*/.claude/hooks/*" -print0 2>/dev/null)
        fi
    done
    
    printf '%s\n' "${discovered_projects[@]}"
}

# Check if project exists in registry
project_in_registry() {
    local project_path="$1"
    if [[ -f "$REGISTRY_FILE" ]]; then
        grep -q "^$project_path|" "$REGISTRY_FILE" 2>/dev/null
    else
        return 1
    fi
}

# Validate registry entry
validate_registry_entry() {
    local project_path="$1"
    local issues=()
    
    # Check if project directory exists
    if [[ ! -d "$project_path" ]]; then
        issues+=("directory_missing")
    fi
    
    # Check for telemetry hook
    if [[ ! -f "$project_path/.claude/hooks/telemetry-hook.sh" ]]; then
        issues+=("hook_missing")
    fi
    
    # Check for Claude settings
    if [[ ! -f "$project_path/.claude/settings.json" ]]; then
        issues+=("settings_missing")
    elif ! grep -q "telemetry-hook" "$project_path/.claude/settings.json" 2>/dev/null; then
        issues+=("settings_not_configured")
    fi
    
    # Check for telemetry marker
    if [[ ! -f "$project_path/.telemetry-enabled" ]]; then
        issues+=("not_enabled")
    fi
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo "valid"
    else
        echo "invalid:${issues[*]}"
    fi
}

# Get current process information
detect_current_processes() {
    local loki_pids=($(pgrep -f "loki.*-config.file" 2>/dev/null || true))
    local grafana_pids=($(pgrep -f "grafana.*server" 2>/dev/null || true))
    
    # Get installation paths from process cmdlines
    local loki_path=""
    local grafana_path=""
    
    if [[ ${#loki_pids[@]} -gt 0 ]]; then
        loki_path=$(ps -p "${loki_pids[0]}" -o cmd --no-headers | grep -o '\-config\.file=[^ ]*' | cut -d= -f2 | xargs dirname | xargs dirname)
    fi
    
    if [[ ${#grafana_pids[@]} -gt 0 ]]; then
        grafana_path=$(ps -p "${grafana_pids[0]}" -o cmd --no-headers | grep -o '\-\-config=[^ ]*' | cut -d= -f2 | xargs dirname | xargs dirname)
    fi
    
    # Use the detected path or default to telemetry root
    local installation_path="${loki_path:-${grafana_path:-$TELEMETRY_ROOT}}"
    
    echo "${loki_pids[*]}|${grafana_pids[*]}|$installation_path"
}

# Generate session ID
generate_session_id() {
    local installation_path="$1"
    local session_hash=$(echo "$installation_path" | md5sum | cut -c1-8)
    echo "session_$session_hash"
}

# Add missing project to registry
add_missing_project() {
    local project_path="$1"
    local project_name="$2"
    local process_info="$3"
    local dry_run="$4"
    
    IFS='|' read -r loki_pids grafana_pids installation_path <<< "$process_info"
    local session_id=$(generate_session_id "$installation_path")
    local connected_date=$(date -Iseconds)
    
    log_info "Adding missing project: $project_name"
    
    if [[ "$dry_run" == "true" ]]; then
        echo "  [DRY RUN] Would add: $project_path|$project_name|$connected_date|$loki_pids|$grafana_pids|$installation_path|$session_id|active"
    else
        # Create registry if it doesn't exist
        if [[ ! -f "$REGISTRY_FILE" ]]; then
            mkdir -p "$(dirname "$REGISTRY_FILE")"
            echo "# Enhanced Telemetry Registry Format" > "$REGISTRY_FILE"
            echo "# project_path|project_name|connected_date|loki_pids|grafana_pids|installation_path|session_id|status" >> "$REGISTRY_FILE"
        fi
        
        local new_line="$project_path|$project_name|$connected_date|$loki_pids|$grafana_pids|$installation_path|$session_id|active"
        echo "$new_line" >> "$REGISTRY_FILE"
        log_success "Added $project_name to registry"
    fi
}

# Remove invalid project from registry
remove_invalid_project() {
    local project_path="$1"
    local project_name="$2"
    local reason="$3"
    local dry_run="$4"
    
    log_warning "Removing invalid project: $project_name ($reason)"
    
    if [[ "$dry_run" == "true" ]]; then
        echo "  [DRY RUN] Would remove registry entry for: $project_path"
    else
        if [[ -f "$REGISTRY_FILE" ]]; then
            grep -v "^$project_path|" "$REGISTRY_FILE" > "${REGISTRY_FILE}.tmp" 2>/dev/null || touch "${REGISTRY_FILE}.tmp"
            mv "${REGISTRY_FILE}.tmp" "$REGISTRY_FILE"
            log_success "Removed $project_name from registry"
        fi
    fi
}

# Update existing project in registry
update_project_info() {
    local project_path="$1"
    local project_name="$2"
    local process_info="$3"
    local dry_run="$4"
    
    IFS='|' read -r loki_pids grafana_pids installation_path <<< "$process_info"
    local session_id=$(generate_session_id "$installation_path")
    
    # Get existing connected date
    local existing_line=$(grep "^$project_path|" "$REGISTRY_FILE" 2>/dev/null || echo "")
    local connected_date=$(date -Iseconds)
    
    if [[ -n "$existing_line" ]]; then
        eval "$(parse_registry_line "$existing_line")"
        connected_date="$connected_date"  # Use existing date
    fi
    
    log_info "Updating project info: $project_name"
    
    if [[ "$dry_run" == "true" ]]; then
        echo "  [DRY RUN] Would update: $project_path with current process info"
    else
        local new_line="$project_path|$project_name|$connected_date|$loki_pids|$grafana_pids|$installation_path|$session_id|active"
        update_project_in_registry "$REGISTRY_FILE" "$project_path" "$new_line"
        log_success "Updated $project_name in registry"
    fi
}

# Main repair function
main() {
    local dry_run=false
    local verbose=false
    local force=false
    
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
            -v|--verbose)
                verbose=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    echo -e "${BLUE}Registry Repair Tool${NC}"
    echo "===================="
    echo ""
    
    if [[ "$dry_run" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN MODE] - No changes will be made${NC}"
        echo ""
    fi
    
    # Detect current process information
    log_info "Detecting current process information..."
    local process_info=$(detect_current_processes)
    IFS='|' read -r current_loki_pids current_grafana_pids current_installation <<< "$process_info"
    
    echo -e "${CYAN}Current processes:${NC}"
    echo "  Loki PIDs: ${current_loki_pids:-none}"
    echo "  Grafana PIDs: ${current_grafana_pids:-none}"
    echo "  Installation: $current_installation"
    echo ""
    
    # Discover all projects with telemetry
    local discovered_projects=($(discover_telemetry_projects))
    log_info "Found ${#discovered_projects[@]} projects with telemetry configuration"
    
    local added_count=0
    local updated_count=0
    local removed_count=0
    
    # Check discovered projects against registry
    for project_info in "${discovered_projects[@]}"; do
        IFS='|' read -r project_path project_name <<< "$project_info"
        
        if project_in_registry "$project_path"; then
            # Project exists in registry - validate and update if needed
            local validation=$(validate_registry_entry "$project_path")
            if [[ "$validation" == "valid" ]]; then
                if [[ "$verbose" == "true" ]]; then
                    echo -e "${GREEN}✓${NC} $project_name: Registry entry valid"
                fi
                # Update process info
                update_project_info "$project_path" "$project_name" "$process_info" "$dry_run"
                ((updated_count++))
            else
                log_warning "$project_name: Registry entry has issues ($validation)"
                update_project_info "$project_path" "$project_name" "$process_info" "$dry_run"
                ((updated_count++))
            fi
        else
            # Project not in registry - add it
            echo -e "${YELLOW}+${NC} $project_name: Not in registry, adding"
            add_missing_project "$project_path" "$project_name" "$process_info" "$dry_run"
            ((added_count++))
        fi
    done
    
    # Check registry entries against discovered projects
    if [[ -f "$REGISTRY_FILE" ]]; then
        while IFS= read -r line; do
            if [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
                eval "$(parse_registry_line "$line")"
                
                # Check if this project was discovered
                local found=false
                for project_info in "${discovered_projects[@]}"; do
                    IFS='|' read -r discovered_path discovered_name <<< "$project_info"
                    if [[ "$discovered_path" == "$project_path" ]]; then
                        found=true
                        break
                    fi
                done
                
                if [[ "$found" == "false" ]]; then
                    local validation=$(validate_registry_entry "$project_path")
                    if [[ "$validation" != "valid" ]]; then
                        echo -e "${RED}-${NC} $project_name: Registry entry invalid ($validation)"
                        remove_invalid_project "$project_path" "$project_name" "$validation" "$dry_run"
                        ((removed_count++))
                    fi
                fi
            fi
        done < "$REGISTRY_FILE"
    fi
    
    echo ""
    echo "===================="
    echo -e "${BLUE}Repair Summary:${NC}"
    echo "• Projects added: $added_count"
    echo "• Projects updated: $updated_count"
    echo "• Projects removed: $removed_count"
    
    if [[ "$dry_run" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}Run without --dry-run to apply changes${NC}"
    elif [[ $((added_count + updated_count + removed_count)) -gt 0 ]]; then
        echo ""
        log_success "Registry repair completed"
        echo ""
        echo -e "${BLUE}Next steps:${NC}"
        echo "• Check session status: $SCRIPT_DIR/session-status.sh"
        echo "• Clean up orphaned processes: $SCRIPT_DIR/cleanup-orphaned.sh"
    else
        echo ""
        log_success "Registry is already in sync - no changes needed"
    fi
}

main "$@"