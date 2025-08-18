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
