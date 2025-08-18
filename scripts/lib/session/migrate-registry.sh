#!/bin/bash
# Migrate Registry to Enhanced Format
# Upgrades connected-projects.txt to include process tracking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Source common utilities
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/../common/paths.sh" || {
    echo -e "${RED}[ERROR]${NC} Could not load path utilities" >&2
    exit 1
}

TELEMETRY_ROOT="$(get_telemetry_root)"
REGISTRY_FILE="$TELEMETRY_ROOT/data/connected-projects.txt"
BACKUP_FILE="$REGISTRY_FILE.backup.$(date +%Y%m%d_%H%M%S)"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if registry needs migration
check_registry_format() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        log_info "No existing registry found - will create new format"
        return 0
    fi
    
    # Check if already migrated (contains session info)
    if head -1 "$REGISTRY_FILE" | grep -q '|.*|.*|.*|.*|.*|'; then
        log_info "Registry already in enhanced format"
        return 1
    fi
    
    log_info "Registry needs migration from old format"
    return 0
}

# Detect current running processes
detect_running_processes() {
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
    
    echo "${loki_pids[*]}|${grafana_pids[*]}|${loki_path:-$TELEMETRY_ROOT}|${grafana_path:-$TELEMETRY_ROOT}"
}

# Generate session ID based on installation path
generate_session_id() {
    local installation_path="$1"
    local session_hash=$(echo "$installation_path" | md5sum | cut -c1-8)
    echo "session_$session_hash"
}

# Migrate existing registry
migrate_registry() {
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        create_new_registry
        return
    fi
    
    log_info "Backing up existing registry to: $BACKUP_FILE"
    cp "$REGISTRY_FILE" "$BACKUP_FILE"
    
    log_info "Detecting current running processes..."
    local process_info=$(detect_running_processes)
    IFS='|' read -r loki_pids grafana_pids loki_path grafana_path <<< "$process_info"
    
    # Use the installation path from detected processes, or default to main installation
    local installation_path="${loki_path:-$TELEMETRY_ROOT}"
    local session_id=$(generate_session_id "$installation_path")
    
    log_info "Detected installation: $installation_path"
    log_info "Session ID: $session_id"
    log_info "Loki PIDs: ${loki_pids:-none}"
    log_info "Grafana PIDs: ${grafana_pids:-none}"
    
    local temp_file="${REGISTRY_FILE}.tmp"
    
    # Migrate each line
    while IFS='|' read -r project_path project_name connected_date || [[ -n "$project_path" ]]; do
        if [[ -n "$project_path" ]]; then
            # Enhanced format: project_path|project_name|connected_date|loki_pids|grafana_pids|installation_path|session_id|status
            echo "$project_path|$project_name|$connected_date|$loki_pids|$grafana_pids|$installation_path|$session_id|active" >> "$temp_file"
        fi
    done < "$REGISTRY_FILE"
    
    mv "$temp_file" "$REGISTRY_FILE"
    log_success "Registry migrated to enhanced format"
}

# Create new registry with enhanced format
create_new_registry() {
    mkdir -p "$(dirname "$REGISTRY_FILE")"
    
    # Create header comment
    cat > "$REGISTRY_FILE" << 'EOF'
# Enhanced Telemetry Registry Format
# project_path|project_name|connected_date|loki_pids|grafana_pids|installation_path|session_id|status
EOF
    
    log_success "Created new enhanced registry"
}

# Add helper functions for registry manipulation
add_registry_helpers() {
    local helpers_file="$TELEMETRY_ROOT/scripts/lib/session/registry-helpers.sh"
    mkdir -p "$(dirname "$helpers_file")"
    
    cat > "$helpers_file" << 'EOF'
#!/bin/bash
# Registry Helper Functions

# Parse registry line into variables
parse_registry_line() {
    local line="$1"
    IFS='|' read -r project_path project_name connected_date loki_pids grafana_pids installation_path session_id status <<< "$line"
    echo "project_path='$project_path'"
    echo "project_name='$project_name'"
    echo "connected_date='$connected_date'"
    echo "loki_pids='$loki_pids'"
    echo "grafana_pids='$grafana_pids'"
    echo "installation_path='$installation_path'"
    echo "session_id='$session_id'"
    echo "status='$status'"
}

# Update project in registry
update_project_in_registry() {
    local registry_file="$1"
    local project_path="$2"
    local new_line="$3"
    
    if [[ -f "$registry_file" ]]; then
        grep -v "^$project_path|" "$registry_file" > "${registry_file}.tmp" 2>/dev/null || touch "${registry_file}.tmp"
        echo "$new_line" >> "${registry_file}.tmp"
        mv "${registry_file}.tmp" "$registry_file"
    else
        echo "$new_line" > "$registry_file"
    fi
}

# Get projects by session
get_projects_by_session() {
    local registry_file="$1"
    local session_id="$2"
    
    if [[ -f "$registry_file" ]]; then
        grep "|$session_id|" "$registry_file" 2>/dev/null || true
    fi
}

# Check if processes are running
check_process_running() {
    local pids="$1"
    if [[ -z "$pids" ]] || [[ "$pids" == "none" ]]; then
        return 1
    fi
    
    for pid in $pids; do
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}
EOF
    
    chmod +x "$helpers_file"
    log_success "Created registry helper functions"
}

# Main function
main() {
    echo -e "${BLUE}Registry Migration Tool${NC}"
    echo "=================================="
    echo ""
    
    if ! check_registry_format; then
        log_info "Registry is already in enhanced format"
        return 0
    fi
    
    migrate_registry
    add_registry_helpers
    
    echo ""
    log_success "Registry migration completed!"
    echo ""
    echo -e "${BLUE}Enhanced registry features:${NC}"
    echo "• Process tracking (PIDs and installation paths)"
    echo "• Session management (group projects by shared services)"
    echo "• Status tracking (active/inactive/orphaned)"
    echo ""
    echo -e "${BLUE}Available commands:${NC}"
    echo "• Session status: $TELEMETRY_ROOT/scripts/lib/session/session-status.sh"
    echo "• Cleanup orphaned: $TELEMETRY_ROOT/scripts/lib/session/cleanup-orphaned.sh"
    echo "• Registry repair: $TELEMETRY_ROOT/scripts/lib/session/registry-repair.sh"
}

main "$@"