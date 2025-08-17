#!/bin/bash
# Portable Path Resolution for Claude Agent Telemetry
# Uses marker file strategy to find project root from any script depth

# Find telemetry project root by searching upward for unique markers
find_telemetry_root() {
    local start_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local dir="$start_dir"
    local max_depth=20  # Prevent infinite loops
    local depth=0
    
    while [[ "$dir" != "/" ]] && [[ $depth -lt $max_depth ]]; do
        # Check for telemetry project markers
        if [[ -f "$dir/package.json" ]] && 
           grep -q "claude-agent-telemetry" "$dir/package.json" 2>/dev/null; then
            # Additional validation for npm vs traditional installation
            if [[ -f "$dir/bin/loki" ]] || [[ -f "$dir/setup.js" ]]; then
                echo "$dir"
                return 0
            fi
        fi
        
        # Go up one directory level
        dir="$(dirname "$dir")"
        ((depth++))
    done
    
    # Error reporting
    cat >&2 << EOF
FATAL: Telemetry project root not found

Search started from: $start_dir
Searched $depth levels up to: $dir

Could not find directory containing:
  - package.json with "claude-agent-telemetry"
  - bin/loki executable OR setup.js file
  - Expected telemetry project structure

This script must be run from within the telemetry project directory.
For npm installations: Use 'npx claude-telemetry' commands from any directory.
For traditional installations: cd to your telemetry project and run the script from there.
EOF
    return 1
}

# Auto-detect NPM mode if not already set
if [[ -z "${CLAUDE_TELEMETRY_NPM_MODE:-}" ]]; then
    SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
    if [[ "$SCRIPT_PATH" == *"node_modules"* ]] || [[ "$SCRIPT_PATH" == *".npm"* ]]; then
        export CLAUDE_TELEMETRY_NPM_MODE="true"
    fi
fi

# Initialize and cache the telemetry root path
if [[ -z "$TELEMETRY_ROOT" ]]; then
    TELEMETRY_ROOT="$(find_telemetry_root)" || exit 1
    export TELEMETRY_ROOT
fi

# Path helper functions - these provide consistent access to project paths
get_telemetry_root() { echo "$TELEMETRY_ROOT"; }
get_loki_bin() { 
    # Check if we're in npm mode and use Node.js to get binary path
    if [[ "${CLAUDE_TELEMETRY_NPM_MODE:-}" == "true" ]] && command -v node >/dev/null 2>&1; then
        node -e "
            const BinaryManager = require('$TELEMETRY_ROOT/lib/binary-manager');
            const manager = new BinaryManager();
            manager.getBinaryPath('loki').then(path => console.log(path)).catch(() => console.log('$TELEMETRY_ROOT/bin/loki'));
        " 2>/dev/null || echo "$TELEMETRY_ROOT/bin/loki"
    else
        echo "$TELEMETRY_ROOT/bin/loki"
    fi
}

get_grafana_bin() { 
    # Check if we're in npm mode and use Node.js to get binary path
    if [[ "${CLAUDE_TELEMETRY_NPM_MODE:-}" == "true" ]] && command -v node >/dev/null 2>&1; then
        node -e "
            const BinaryManager = require('$TELEMETRY_ROOT/lib/binary-manager');
            const manager = new BinaryManager();
            manager.getBinaryPath('grafana').then(path => console.log(path)).catch(() => console.log('$TELEMETRY_ROOT/bin/grafana'));
        " 2>/dev/null || echo "$TELEMETRY_ROOT/bin/grafana"
    else
        echo "$TELEMETRY_ROOT/bin/grafana"
    fi
}
get_config_dir() { echo "$TELEMETRY_ROOT/config"; }
get_logs_dir() { echo "$TELEMETRY_ROOT/logs"; }
get_data_dir() { echo "$TELEMETRY_ROOT/data"; }
get_scripts_dir() { echo "$TELEMETRY_ROOT/scripts"; }
get_lib_dir() { echo "$TELEMETRY_ROOT/scripts/lib"; }

# Specialized config paths
get_loki_config() { echo "$TELEMETRY_ROOT/config/loki/loki.yaml"; }
get_grafana_config() { echo "$TELEMETRY_ROOT/config/grafana/grafana.ini"; }
get_loki_log() { echo "$TELEMETRY_ROOT/logs/loki.log"; }
get_grafana_log() { echo "$TELEMETRY_ROOT/logs/grafana.log"; }
get_loki_pid() { echo "$TELEMETRY_ROOT/logs/loki.pid"; }
get_grafana_pid() { echo "$TELEMETRY_ROOT/logs/grafana.pid"; }

# Validation function to ensure project structure is intact
validate_telemetry_paths() {
    local errors=0
    
    echo "Validating telemetry project structure..."
    
    # Check critical files exist
    local critical_paths=(
        "$(get_loki_bin):Loki binary"
        "$(get_grafana_bin):Grafana binary" 
        "$(get_loki_config):Loki configuration"
        "$(get_config_dir):Config directory"
        "$(get_logs_dir):Logs directory"
    )
    
    for path_desc in "${critical_paths[@]}"; do
        local path="${path_desc%:*}"
        local desc="${path_desc#*:}"
        
        if [[ ! -e "$path" ]]; then
            echo "ERROR: Missing $desc: $path" >&2
            ((errors++))
        else
            echo "✓ Found $desc: $path"
        fi
    done
    
    if [[ $errors -gt 0 ]]; then
        echo "FATAL: $errors critical path(s) missing from telemetry project" >&2
        return 1
    fi
    
    echo "✓ All telemetry paths validated successfully"
    return 0
}

# Debug function to show all resolved paths
show_telemetry_paths() {
    echo "Telemetry Project Paths:"
    echo "======================="
    echo "Root:           $(get_telemetry_root)"
    echo "Loki Binary:    $(get_loki_bin)"
    echo "Grafana Binary: $(get_grafana_bin)"
    echo "Config Dir:     $(get_config_dir)"
    echo "Logs Dir:       $(get_logs_dir)"
    echo "Data Dir:       $(get_data_dir)"
    echo "Loki Config:    $(get_loki_config)"
    echo "Grafana Config: $(get_grafana_config)"
}