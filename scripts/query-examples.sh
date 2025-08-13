#!/bin/bash
# Loki Query Examples for Claude Agent Telemetry

LOKI_URL="http://localhost:3100"
START_TIME=$(date -d '1 hour ago' +%s)000000000
END_TIME=$(date +%s)000000000

echo "Claude Agent Telemetry - Loki Query Examples"
echo "=============================================="

# Function to execute query
query_loki() {
    local query="$1"
    local desc="$2"
    
    echo
    echo "Query: $desc"
    echo "LogQL: $query"
    echo "---"
    
    curl -s -G "$LOKI_URL/loki/api/v1/query_range" \
        --data-urlencode "query=$query" \
        --data-urlencode "start=$START_TIME" \
        --data-urlencode "end=$END_TIME" | \
        jq -r '.data.result[]?.values[]?[1]' 2>/dev/null | head -5
    
    echo
}

# Check if Loki is running
if ! curl -s "$LOKI_URL/ready" >/dev/null; then
    echo "Error: Loki is not running or not accessible at $LOKI_URL"
    echo "Run: ./scripts/start-loki.sh"
    exit 1
fi

echo "Loki is running. Executing example queries..."

# All telemetry data
query_loki '{service="claude-telemetry"}' "All Claude telemetry data"

# File operations only
query_loki '{service="claude-telemetry", event="file_read"}' "File read operations"

# Specific tool usage
query_loki '{service="claude-telemetry", tool="Read"}' "Read tool usage"

# Commands executed
query_loki '{service="claude-telemetry", event="command_execution"}' "Command executions"

# Recent session activity
query_loki '{service="claude-telemetry"} |= "session_id"' "Recent session activity"

echo "For more queries, see: https://grafana.com/docs/loki/latest/logql/"