#!/bin/bash
# List Connected Projects in Claude Agent Telemetry System
# Usage: ./list-connected-projects.sh [options]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory (where agent-telemetry is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TELEMETRY_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
REGISTRY_FILE="$TELEMETRY_ROOT/data/connected-projects.txt"
LOKI_URL="http://localhost:3100"

# Usage function
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "List all projects connected to the Claude Agent Telemetry system."
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -v, --verbose   Show detailed information about each project"
    echo "  -s, --status    Check connection status for each project"
    echo "  -q, --quiet     Show only project names (one per line)"
    echo ""
    echo "Examples:"
    echo "  $0              # List all connected projects"
    echo "  $0 -v           # Show detailed information"
    echo "  $0 -s           # Check status of connections"
    echo "  $0 -q           # Quiet mode for scripting"
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

# Check if Loki is running
check_loki_status() {
    if curl -s -f "$LOKI_URL/ready" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Validate project connection
validate_project_connection() {
    local project_path="$1"
    local issues=()
    
    # Check if project directory exists
    if [[ ! -d "$project_path" ]]; then
        issues+=("Directory not found")
    fi
    
    # Check for telemetry hook
    if [[ ! -f "$project_path/.claude/hooks/telemetry-hook.sh" ]]; then
        issues+=("Hook missing")
    fi
    
    # Check for Claude settings
    if [[ ! -f "$project_path/.claude/settings.json" ]]; then
        issues+=("Settings missing")
    elif ! grep -q "telemetry-hook" "$project_path/.claude/settings.json" 2>/dev/null; then
        issues+=("Settings not configured")
    fi
    
    # Check for telemetry marker
    if [[ ! -f "$project_path/.telemetry-enabled" ]]; then
        issues+=("Not enabled")
    fi
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo "OK"
    else
        echo "Issues: ${issues[*]}"
    fi
}

# Get telemetry data count for project
get_project_telemetry_count() {
    local project_name="$1"
    
    if ! check_loki_status; then
        echo "N/A (Loki offline)"
        return
    fi
    
    # Query Loki for project data count (last 24 hours)
    local query='{service="claude-telemetry",project="'"$project_name"'"}'
    local start_time=$(date -d "1 day ago" +%s)000000000
    local end_time=$(date +%s)000000000
    
    local count=$(curl -s -G "$LOKI_URL/loki/api/v1/query" \
        --data-urlencode "query=count_over_time($query[24h])" \
        --data-urlencode "time=$end_time" | \
        jq -r '.data.result[0].value[1] // "0"' 2>/dev/null || echo "0")
    
    echo "$count"
}

# Format project information
format_project_info() {
    local project_path="$1"
    local project_name="$2"
    local connected_date="$3"
    local verbose="$4"
    local check_status="$5"
    local quiet="$6"
    
    if [[ "$quiet" == "true" ]]; then
        echo "$project_name"
        return
    fi
    
    local project_basename=$(basename "$project_path")
    
    # Basic information
    echo -e "${CYAN}Project:${NC} $project_name"
    echo -e "${CYAN}Path:${NC} $project_path"
    echo -e "${CYAN}Connected:${NC} $connected_date"
    
    if [[ "$verbose" == "true" ]] || [[ "$check_status" == "true" ]]; then
        # Detailed information
        echo -e "${CYAN}Directory:${NC} $project_basename"
        
        if [[ "$check_status" == "true" ]]; then
            local status=$(validate_project_connection "$project_path")
            if [[ "$status" == "OK" ]]; then
                echo -e "${CYAN}Status:${NC} ${GREEN}Connected${NC}"
            else
                echo -e "${CYAN}Status:${NC} ${RED}Issues found - $status${NC}"
            fi
            
            # Get telemetry count
            local telemetry_count=$(get_project_telemetry_count "$project_name")
            echo -e "${CYAN}Data (24h):${NC} $telemetry_count events"
        fi
        
        if [[ "$verbose" == "true" ]]; then
            # Show file status
            local hook_status="❌"
            local settings_status="❌"
            local marker_status="❌"
            
            if [[ -f "$project_path/.claude/hooks/telemetry-hook.sh" ]]; then
                hook_status="✅"
            fi
            
            if [[ -f "$project_path/.claude/settings.json" ]] && grep -q "telemetry-hook" "$project_path/.claude/settings.json" 2>/dev/null; then
                settings_status="✅"
            fi
            
            if [[ -f "$project_path/.telemetry-enabled" ]]; then
                marker_status="✅"
            fi
            
            echo -e "${CYAN}Files:${NC} Hook $hook_status Settings $settings_status Enabled $marker_status"
        fi
    fi
    
    echo ""
}

# List projects from registry
list_projects_from_registry() {
    local verbose="$1"
    local check_status="$2"
    local quiet="$3"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        if [[ "$quiet" != "true" ]]; then
            log_warning "No project registry found"
            echo "No projects have been connected yet."
            echo ""
            echo "To connect a project:"
            echo "$SCRIPT_DIR/connect-project.sh /path/to/project"
        fi
        return 1
    fi
    
    local project_count=0
    
    while IFS='|' read -r project_path project_name connected_date || [[ -n "$project_path" ]]; do
        if [[ -n "$project_path" ]]; then
            format_project_info "$project_path" "$project_name" "$connected_date" "$verbose" "$check_status" "$quiet"
            ((project_count++))
        fi
    done < "$REGISTRY_FILE"
    
    if [[ "$quiet" != "true" ]]; then
        if [[ $project_count -eq 0 ]]; then
            log_info "No connected projects found"
        else
            echo -e "${BLUE}Total connected projects:${NC} $project_count"
            
            if [[ "$check_status" == "true" ]]; then
                local loki_status="❌ Offline"
                if check_loki_status; then
                    loki_status="✅ Running"
                fi
                echo -e "${BLUE}Loki server:${NC} $loki_status"
            fi
        fi
        
        echo ""
        echo -e "${BLUE}Management commands:${NC}"
        echo "• Connect new project: $SCRIPT_DIR/connect-project.sh /path/to/project"
        echo "• Disconnect project: $SCRIPT_DIR/disconnect-project.sh /path/to/project"
        echo "• View dashboards: http://localhost:3000"
    fi
    
    return 0
}

# Discover projects by scanning for telemetry configurations
discover_projects() {
    local search_paths=("$HOME" "/home" "/Users")
    local found_projects=()
    
    echo -e "${YELLOW}[DISCOVERY]${NC} Scanning for projects with telemetry configuration..."
    echo ""
    
    for search_path in "${search_paths[@]}"; do
        if [[ -d "$search_path" ]]; then
            # Find projects with telemetry hooks
            while IFS= read -r -d '' hook_file; do
                local project_path=$(dirname "$(dirname "$hook_file")")
                local project_name=$(basename "$project_path")
                
                # Skip if already in registry
                if [[ -f "$REGISTRY_FILE" ]] && grep -q "^$project_path|" "$REGISTRY_FILE" 2>/dev/null; then
                    continue
                fi
                
                found_projects+=("$project_path|$project_name")
            done < <(find "$search_path" -name "telemetry-hook.sh" -path "*/.claude/hooks/*" -print0 2>/dev/null)
        fi
    done
    
    if [[ ${#found_projects[@]} -gt 0 ]]; then
        echo -e "${CYAN}Found unregistered projects with telemetry:${NC}"
        echo ""
        
        for project_info in "${found_projects[@]}"; do
            IFS='|' read -r project_path project_name <<< "$project_info"
            echo -e "${CYAN}Project:${NC} $project_name"
            echo -e "${CYAN}Path:${NC} $project_path"
            local status=$(validate_project_connection "$project_path")
            if [[ "$status" == "OK" ]]; then
                echo -e "${CYAN}Status:${NC} ${GREEN}Configured but not registered${NC}"
            else
                echo -e "${CYAN}Status:${NC} ${YELLOW}$status${NC}"
            fi
            echo ""
        done
        
        echo "To register these projects, run:"
        echo "$SCRIPT_DIR/connect-project.sh <project-path>"
    else
        echo "No unregistered projects found."
    fi
}

# Main function
main() {
    local verbose=false
    local check_status=false
    local quiet=false
    local discovery=false
    
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
            -s|--status)
                check_status=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            -d|--discover)
                discovery=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    if [[ "$quiet" != "true" ]]; then
        echo -e "${BLUE}Claude Agent Telemetry - Connected Projects${NC}"
        echo "=================================================="
        echo ""
    fi
    
    # List registered projects
    list_projects_from_registry "$verbose" "$check_status" "$quiet"
    
    # Discovery mode
    if [[ "$discovery" == "true" ]] && [[ "$quiet" != "true" ]]; then
        echo ""
        echo "=================================================="
        discover_projects
    fi
}

# Run main function
main "$@"