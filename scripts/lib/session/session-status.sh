#!/bin/bash
# Show Active Telemetry Sessions and Process Status
# Displays all telemetry sessions with their projects and running processes

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
    echo "Show active telemetry sessions and their process status."
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -v, --verbose   Show detailed process information"
    echo "  -o, --orphaned  Show only orphaned sessions"
    echo "  -a, --all       Show all sessions including inactive"
    echo ""
    exit 1
}

# Check if path looks like temp/test directory
is_orphaned_path() {
    local path="$1"
    [[ "$path" =~ /tmp/ ]] || [[ "$path" =~ test.*telemetry ]] || [[ "$path" != "$TELEMETRY_ROOT" ]]
}

# Get process details
get_process_details() {
    local pids="$1"
    local details=()
    
    if [[ -z "$pids" ]] || [[ "$pids" == "none" ]]; then
        echo "Not running"
        return
    fi
    
    for pid in $pids; do
        if kill -0 "$pid" 2>/dev/null; then
            local cmd=$(ps -p "$pid" -o cmd --no-headers 2>/dev/null | cut -c1-60)
            local mem=$(ps -p "$pid" -o rss --no-headers 2>/dev/null || echo "0")
            local mem_mb=$((mem / 1024))
            details+=("PID $pid (${mem_mb}MB) - $cmd")
        else
            details+=("PID $pid (DEAD)")
        fi
    done
    
    printf '%s\n' "${details[@]}"
}

# Get session health status
get_session_health() {
    local loki_pids="$1"
    local grafana_pids="$2"
    local installation_path="$3"
    
    local loki_running=false
    local grafana_running=false
    local issues=()
    
    # Check Loki
    if check_process_running "$loki_pids"; then
        loki_running=true
    else
        issues+=("Loki not running")
    fi
    
    # Check Grafana
    if check_process_running "$grafana_pids"; then
        grafana_running=true
    else
        issues+=("Grafana not running")
    fi
    
    # Check installation path
    if [[ ! -d "$installation_path" ]]; then
        issues+=("Installation path missing")
    elif is_orphaned_path "$installation_path"; then
        issues+=("Orphaned location")
    fi
    
    # Return status
    if [[ $loki_running == true ]] && [[ $grafana_running == true ]] && [[ ${#issues[@]} -eq 0 ]]; then
        echo "HEALTHY"
    elif [[ $loki_running == true ]] || [[ $grafana_running == true ]]; then
        if [[ ${#issues[@]} -gt 0 ]]; then
            echo "DEGRADED (${issues[*]})"
        else
            echo "PARTIAL"
        fi
    else
        echo "FAILED (${issues[*]})"
    fi
}

# Display session information
display_session() {
    local session_id="$1"
    local verbose="$2"
    local projects=()
    local loki_pids=""
    local grafana_pids=""
    local installation_path=""
    
    # Collect all projects in this session
    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
            eval "$(parse_registry_line "$line")"
            if [[ "$session_id" == "$session_id" ]]; then
                projects+=("$project_name ($project_path)")
                loki_pids="$loki_pids"
                grafana_pids="$grafana_pids"
                installation_path="$installation_path"
            fi
        fi
    done < "$REGISTRY_FILE"
    
    # Session header
    local health=$(get_session_health "$loki_pids" "$grafana_pids" "$installation_path")
    local orphaned_marker=""
    if is_orphaned_path "$installation_path"; then
        orphaned_marker=" ${RED}[ORPHANED]${NC}"
    fi
    
    echo -e "${PURPLE}Session: $session_id${orphaned_marker}"
    
    # Health status with color coding
    case "$health" in
        "HEALTHY")
            echo -e "${CYAN}Status:${NC} ${GREEN}$health${NC}"
            ;;
        "PARTIAL"|"DEGRADED"*)
            echo -e "${CYAN}Status:${NC} ${YELLOW}$health${NC}"
            ;;
        "FAILED"*)
            echo -e "${CYAN}Status:${NC} ${RED}$health${NC}"
            ;;
    esac
    
    echo -e "${CYAN}Installation:${NC} $installation_path"
    echo -e "${CYAN}Projects (${#projects[@]}):${NC}"
    
    # List projects
    for project in "${projects[@]}"; do
        echo "  └── $project"
    done
    
    # Process details
    echo -e "${CYAN}Services:${NC}"
    if [[ "$verbose" == "true" ]]; then
        echo "  Loki:"
        if [[ -n "$loki_pids" ]] && [[ "$loki_pids" != "none" ]]; then
            while IFS= read -r detail; do
                echo "    └── $detail"
            done <<< "$(get_process_details "$loki_pids")"
        else
            echo "    └── Not running"
        fi
        
        echo "  Grafana:"
        if [[ -n "$grafana_pids" ]] && [[ "$grafana_pids" != "none" ]]; then
            while IFS= read -r detail; do
                echo "    └── $detail"
            done <<< "$(get_process_details "$grafana_pids")"
        else
            echo "    └── Not running"
        fi
    else
        # Simplified view
        if check_process_running "$loki_pids"; then
            echo "  └── Loki: ${GREEN}Running${NC} (PIDs: $loki_pids)"
        else
            echo "  └── Loki: ${RED}Not running${NC}"
        fi
        
        if check_process_running "$grafana_pids"; then
            echo "  └── Grafana: ${GREEN}Running${NC} (PIDs: $grafana_pids)"
        else
            echo "  └── Grafana: ${RED}Not running${NC}"
        fi
    fi
    
    echo ""
}

# Main function
main() {
    local verbose=false
    local show_orphaned_only=false
    local show_all=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -o|--orphaned)
                show_orphaned_only=true
                shift
                ;;
            -a|--all)
                show_all=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    echo -e "${BLUE}Telemetry Session Status${NC}"
    echo "========================"
    echo ""
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        log_warning "No registry found"
        echo "No connected projects found."
        echo ""
        echo "To connect a project:"
        echo "$TELEMETRY_ROOT/scripts/lib/projects/connect-project.sh /path/to/project"
        return 1
    fi
    
    # Get all unique sessions
    local sessions=($(grep -v '^#' "$REGISTRY_FILE" 2>/dev/null | cut -d'|' -f7 | sort -u || true))
    
    if [[ ${#sessions[@]} -eq 0 ]]; then
        log_warning "No sessions found in registry"
        return 1
    fi
    
    local displayed_sessions=0
    
    # Display each session
    for session_id in "${sessions[@]}"; do
        if [[ -z "$session_id" ]]; then
            continue
        fi
        
        # Get session details for filtering
        local first_line=$(grep "|$session_id|" "$REGISTRY_FILE" | head -1)
        eval "$(parse_registry_line "$first_line")"
        
        # Apply filters
        if [[ "$show_orphaned_only" == "true" ]] && ! is_orphaned_path "$installation_path"; then
            continue
        fi
        
        display_session "$session_id" "$verbose"
        ((displayed_sessions++))
    done
    
    # Summary
    echo "========================"
    echo -e "${BLUE}Summary:${NC} $displayed_sessions session(s) displayed"
    
    # Suggest actions for orphaned sessions
    local orphaned_count=$(grep -v '^#' "$REGISTRY_FILE" 2>/dev/null | while read line; do
        eval "$(parse_registry_line "$line")"
        if is_orphaned_path "$installation_path"; then
            echo "1"
        fi
    done | wc -l)
    
    if [[ $orphaned_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Found $orphaned_count project(s) using orphaned sessions${NC}"
        echo "Consider running cleanup: $SCRIPT_DIR/cleanup-orphaned.sh"
    fi
}

main "$@"