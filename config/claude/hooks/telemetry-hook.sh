#!/bin/bash
# Claude Code Telemetry Hook - Project Scoped
# Receives JSON input via stdin and logs tool usage for agent-telemetry project

# Read JSON input from stdin
JSON_INPUT=$(cat)

# Get current project path
PROJECT_PATH="${PWD}"

# Only activate telemetry in the agent-telemetry project
if [[ "$PROJECT_PATH" != *"agent-telemetry"* ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check for telemetry-enabled marker (optional additional control)
if [[ -f "$PROJECT_PATH/config/.telemetry-enabled" ]]; then
    TELEMETRY_ENABLED=true
else
    TELEMETRY_ENABLED=false
fi

# Extract data from JSON input
TIMESTAMP=$(date -Iseconds)
PROJECT_NAME=$(basename "$PROJECT_PATH")

# Parse Claude Code's JSON structure
TOOL_NAME=$(echo "$JSON_INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
SESSION_ID=$(echo "$JSON_INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
HOOK_EVENT=$(echo "$JSON_INPUT" | jq -r '.hook_event_name // "unknown"' 2>/dev/null || echo "unknown")

# Enhanced Phase 3: SuperClaude Context Detection
detect_superclaude_context() {
    local input_text="$1"
    local personas=""
    local flags=""
    local commands=""
    local mcp_servers=""
    local reasoning_level="none"
    local workflow_type="standard"
    
    # Detect SuperClaude commands
    if echo "$input_text" | grep -qE '/(analyze|build|implement|improve|design|task|troubleshoot|explain|document|cleanup|test|git|estimate|index|load|spawn)'; then
        commands=$(echo "$input_text" | grep -oE '/(analyze|build|implement|improve|design|task|troubleshoot|explain|document|cleanup|test|git|estimate|index|load|spawn)' | tr '\n' ',' | sed 's/,$//')
        workflow_type="superclaude"
    fi
    
    # Detect personas
    if echo "$input_text" | grep -qE -- '--persona-(architect|frontend|backend|analyzer|security|mentor|refactorer|performance|qa|devops|scribe)'; then
        personas=$(echo "$input_text" | grep -oE -- '--persona-(architect|frontend|backend|analyzer|security|mentor|refactorer|performance|qa|devops|scribe)' | tr '\n' ',' | sed 's/,$//')
    fi
    
    # Detect reasoning levels
    if echo "$input_text" | grep -qE -- '--ultrathink'; then
        reasoning_level="ultra"
    elif echo "$input_text" | grep -qE -- '--think-hard'; then
        reasoning_level="hard"
    elif echo "$input_text" | grep -qE -- '--think'; then
        reasoning_level="standard"
    fi
    
    # Detect MCP server flags
    if echo "$input_text" | grep -qE -- '--(seq|sequential|c7|context7|magic|play|playwright|all-mcp)'; then
        mcp_servers=$(echo "$input_text" | grep -oE -- '--(seq|sequential|c7|context7|magic|play|playwright|all-mcp)' | tr '\n' ',' | sed 's/,$//')
    fi
    
    # Detect general flags
    if echo "$input_text" | grep -qE -- '--(uc|ultracompressed|plan|validate|safe-mode|verbose|delegate|wave-mode|loop|introspect)'; then
        flags=$(echo "$input_text" | grep -oE -- '--(uc|ultracompressed|plan|validate|safe-mode|verbose|delegate|wave-mode|loop|introspect)' | tr '\n' ',' | sed 's/,$//')
    fi
    
    # Return JSON structure
    jq -n \
        --arg commands "$commands" \
        --arg personas "$personas" \
        --arg reasoning_level "$reasoning_level" \
        --arg mcp_servers "$mcp_servers" \
        --arg flags "$flags" \
        --arg workflow_type "$workflow_type" \
        '{
            commands: $commands,
            personas: $personas,
            reasoning_level: $reasoning_level,
            mcp_servers: $mcp_servers,
            flags: $flags,
            workflow_type: $workflow_type
        }'
}

# Extract user prompt context from transcript if available
USER_PROMPT=""
TRANSCRIPT_PATH=$(echo "$JSON_INPUT" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
    # Get the last user message from transcript
    USER_PROMPT=$(tail -20 "$TRANSCRIPT_PATH" | grep '"role":"user"' | tail -1 | jq -r '.content // ""' 2>/dev/null || echo "")
fi

# Detect SuperClaude context
SUPERCLAUDE_CONTEXT=$(detect_superclaude_context "$USER_PROMPT" || echo '{}')

# Enhanced Phase 3: Comprehensive Tool Coverage
case "$TOOL_NAME" in
  "Read")
    FILE_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
    EVENT_TYPE="file_read"
    TOOL_CONTEXT=$(echo "$JSON_INPUT" | jq -r '.tool_input | {file_path, limit, offset}' 2>/dev/null || echo '{}')
    ;;
  "Write")
    FILE_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
    EVENT_TYPE="file_write"
    CONTENT_LENGTH=$(echo "$JSON_INPUT" | jq -r '.tool_input.content // "" | length' 2>/dev/null || echo "0")
    TOOL_CONTEXT=$(jq -n --arg content_length "$CONTENT_LENGTH" '{content_length: ($content_length | tonumber)}' 2>/dev/null || echo '{}')
    ;;
  "Edit"|"MultiEdit")
    FILE_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
    EVENT_TYPE="file_edit"
    OLD_STRING=$(echo "$JSON_INPUT" | jq -r '.tool_input.old_string // ""' 2>/dev/null || echo "")
    NEW_STRING=$(echo "$JSON_INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || echo "")
    REPLACE_ALL=$(echo "$JSON_INPUT" | jq -r '.tool_input.replace_all // false' 2>/dev/null || echo "false")
    TOOL_CONTEXT=$(jq -n \
        --arg old_length "${#OLD_STRING}" \
        --arg new_length "${#NEW_STRING}" \
        --argjson replace_all "$REPLACE_ALL" \
        '{old_length: ($old_length | tonumber), new_length: ($new_length | tonumber), replace_all: $replace_all}' 2>/dev/null || echo '{}')
    ;;
  "Bash")
    COMMAND=$(echo "$JSON_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
    DESCRIPTION=$(echo "$JSON_INPUT" | jq -r '.tool_input.description // ""' 2>/dev/null || echo "")
    EVENT_TYPE="command_execution"
    FILE_PATH=""
    TOOL_CONTEXT=$(jq -n --arg command "$COMMAND" --arg description "$DESCRIPTION" '{command: $command, description: $description}' 2>/dev/null || echo '{}')
    ;;
  "Grep")
    PATTERN=$(echo "$JSON_INPUT" | jq -r '.tool_input.pattern // ""' 2>/dev/null || echo "")
    SEARCH_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.path // ""' 2>/dev/null || echo "")
    OUTPUT_MODE=$(echo "$JSON_INPUT" | jq -r '.tool_input.output_mode // "files_with_matches"' 2>/dev/null || echo "files_with_matches")
    EVENT_TYPE="code_search"
    FILE_PATH="$SEARCH_PATH"
    TOOL_CONTEXT=$(jq -n --arg pattern "$PATTERN" --arg output_mode "$OUTPUT_MODE" '{pattern: $pattern, output_mode: $output_mode}' 2>/dev/null || echo '{}')
    ;;
  "Glob")
    PATTERN=$(echo "$JSON_INPUT" | jq -r '.tool_input.pattern // ""' 2>/dev/null || echo "")
    SEARCH_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.path // ""' 2>/dev/null || echo "")
    EVENT_TYPE="file_search"
    FILE_PATH="$SEARCH_PATH"
    TOOL_CONTEXT=$(jq -n --arg pattern "$PATTERN" '{pattern: $pattern}' 2>/dev/null || echo '{}')
    ;;
  "LS")
    LIST_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.path // ""' 2>/dev/null || echo "")
    EVENT_TYPE="directory_list"
    FILE_PATH="$LIST_PATH"
    TOOL_CONTEXT=$(jq -n --arg path "$LIST_PATH" '{path: $path}' 2>/dev/null || echo '{}')
    ;;
  "TodoWrite")
    TODO_COUNT=$(echo "$JSON_INPUT" | jq -r '.tool_input.todos // [] | length' 2>/dev/null || echo "0")
    EVENT_TYPE="task_management"
    FILE_PATH=""
    TOOL_CONTEXT=$(jq -n --arg todo_count "$TODO_COUNT" '{todo_count: ($todo_count | tonumber)}' 2>/dev/null || echo '{}')
    ;;
  "Task")
    TASK_DESCRIPTION=$(echo "$JSON_INPUT" | jq -r '.tool_input.description // ""' 2>/dev/null || echo "")
    SUBAGENT_TYPE=$(echo "$JSON_INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null || echo "")
    EVENT_TYPE="sub_agent_delegation"
    FILE_PATH=""
    TOOL_CONTEXT=$(jq -n --arg description "$TASK_DESCRIPTION" --arg subagent_type "$SUBAGENT_TYPE" '{description: $description, subagent_type: $subagent_type}' 2>/dev/null || echo '{}')
    ;;
  "WebFetch")
    URL=$(echo "$JSON_INPUT" | jq -r '.tool_input.url // ""' 2>/dev/null || echo "")
    WEB_PROMPT=$(echo "$JSON_INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null || echo "")
    EVENT_TYPE="web_fetch"
    FILE_PATH=""
    TOOL_CONTEXT=$(jq -n --arg url "$URL" --arg prompt "$WEB_PROMPT" '{url: $url, prompt: $prompt}' 2>/dev/null || echo '{}')
    ;;
  "WebSearch")
    QUERY=$(echo "$JSON_INPUT" | jq -r '.tool_input.query // ""' 2>/dev/null || echo "")
    EVENT_TYPE="web_search"
    FILE_PATH=""
    TOOL_CONTEXT=$(jq -n --arg query "$QUERY" '{query: $query}' 2>/dev/null || echo '{}')
    ;;
  "NotebookRead"|"NotebookEdit")
    NOTEBOOK_PATH=$(echo "$JSON_INPUT" | jq -r '.tool_input.notebook_path // ""' 2>/dev/null || echo "")
    EVENT_TYPE="notebook_operation"
    FILE_PATH="$NOTEBOOK_PATH"
    TOOL_CONTEXT=$(jq -n --arg notebook_path "$NOTEBOOK_PATH" '{notebook_path: $notebook_path}' 2>/dev/null || echo '{}')
    ;;
  *)
    FILE_PATH=""
    EVENT_TYPE="tool_usage"
    TOOL_CONTEXT="{}"
    ;;
esac

# Enhanced Phase 3: File Content Change Tracking
track_file_changes() {
    local file_path="$1"
    local tool_name="$2"
    local hook_event="$3"
    
    if [[ -z "$file_path" || ! -f "$file_path" ]]; then
        echo "{}"
        return
    fi
    
    local changes_dir="$PROJECT_PATH/data/changes"
    mkdir -p "$changes_dir"
    
    local file_hash=""
    local change_id=""
    local change_type="none"
    
    # Generate file hash for change tracking
    if command -v sha256sum >/dev/null 2>&1; then
        file_hash=$(sha256sum "$file_path" 2>/dev/null | cut -d' ' -f1)
    elif command -v shasum >/dev/null 2>&1; then
        file_hash=$(shasum -a 256 "$file_path" 2>/dev/null | cut -d' ' -f1)
    else
        file_hash=$(md5sum "$file_path" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
    fi
    
    # Create change tracking ID
    change_id="${SESSION_ID:0:8}_${TIMESTAMP//[:-]/}_$(basename "$file_path")"
    
    # Track pre-operation state for Write/Edit operations
    if [[ "$hook_event" == "PreToolUse" && ("$tool_name" == "Write" || "$tool_name" == "Edit" || "$tool_name" == "MultiEdit") ]]; then
        change_type="pre_change"
        # Store pre-change hash
        echo "$file_hash" > "$changes_dir/${change_id}.pre"
    fi
    
    # Track post-operation state and generate diff
    if [[ "$hook_event" == "PostToolUse" && ("$tool_name" == "Write" || "$tool_name" == "Edit" || "$tool_name" == "MultiEdit") ]]; then
        change_type="post_change"
        local pre_hash=""
        if [[ -f "$changes_dir/${change_id}.pre" ]]; then
            pre_hash=$(cat "$changes_dir/${change_id}.pre")
        fi
        
        # Generate diff information if file changed
        local diff_lines=0
        local lines_added=0
        local lines_removed=0
        
        if [[ -n "$pre_hash" && "$pre_hash" != "$file_hash" ]]; then
            # Create a simple diff summary (avoid storing full content)
            if [[ "$tool_name" == "Edit" || "$tool_name" == "MultiEdit" ]]; then
                # For Edit operations, we can estimate changes from old/new string lengths
                lines_added=$(echo "$NEW_STRING" | wc -l)
                lines_removed=$(echo "$OLD_STRING" | wc -l)
                diff_lines=$((lines_added + lines_removed))
            else
                # For Write operations, just mark as full file change
                diff_lines=$(wc -l < "$file_path" 2>/dev/null || echo 0)
                lines_added=$diff_lines
            fi
            
            # Store change summary
            jq -n \
                --arg change_id "$change_id" \
                --arg pre_hash "$pre_hash" \
                --arg post_hash "$file_hash" \
                --argjson diff_lines "$diff_lines" \
                --argjson lines_added "$lines_added" \
                --argjson lines_removed "$lines_removed" \
                '{
                    change_id: $change_id,
                    pre_hash: $pre_hash,
                    post_hash: $post_hash,
                    diff_lines: $diff_lines,
                    lines_added: $lines_added,
                    lines_removed: $lines_removed,
                    changed: true
                }' > "$changes_dir/${change_id}.summary"
        fi
        
        # Cleanup pre-change file
        rm -f "$changes_dir/${change_id}.pre"
    fi
    
    # Return change tracking info
    jq -n \
        --arg change_id "$change_id" \
        --arg file_hash "$file_hash" \
        --arg change_type "$change_type" \
        --argjson diff_lines "${diff_lines:-0}" \
        --argjson lines_added "${lines_added:-0}" \
        --argjson lines_removed "${lines_removed:-0}" \
        '{
            change_id: $change_id,
            file_hash: $file_hash,
            change_type: $change_type,
            diff_lines: $diff_lines,
            lines_added: $lines_added,
            lines_removed: $lines_removed
        }'
}

# Get file info and change tracking
FILE_SIZE=0
OUTSIDE_SCOPE="false"
FILE_CHANGES="{}"

if [[ -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
    FILE_SIZE=$(stat -c%s "$FILE_PATH" 2>/dev/null || stat -f%z "$FILE_PATH" 2>/dev/null || echo 0)
    if [[ "$FILE_PATH" != "$PROJECT_PATH"* ]]; then
        OUTSIDE_SCOPE="true"
    fi
    
    # Track file changes for Write/Edit operations
    if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" || "$TOOL_NAME" == "MultiEdit" ]]; then
        FILE_CHANGES=$(track_file_changes "$FILE_PATH" "$TOOL_NAME" "$HOOK_EVENT" 2>/dev/null || echo '{}')
    fi
fi

# Escape JSON strings to prevent parsing errors
escape_json_string() {
    local input="$1"
    # Escape backslashes first, then quotes, then other special characters
    echo "$input" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g; s/$/\\n/g' | tr -d '\n'
}

# Enhanced Phase 3: Create comprehensive telemetry log entry with error handling
LOG_ENTRY=$(jq -n \
  --arg timestamp "$TIMESTAMP" \
  --arg level "INFO" \
  --arg event_type "$EVENT_TYPE" \
  --arg hook_event "$HOOK_EVENT" \
  --arg session_id "$SESSION_ID" \
  --arg project_path "$PROJECT_PATH" \
  --arg project_name "$PROJECT_NAME" \
  --arg tool_name "$TOOL_NAME" \
  --arg telemetry_enabled "$TELEMETRY_ENABLED" \
  --arg file_path "$FILE_PATH" \
  --arg size_bytes "$FILE_SIZE" \
  --arg outside_scope "$OUTSIDE_SCOPE" \
  --arg command "${COMMAND:-}" \
  --arg search_pattern "${PATTERN:-}" \
  --arg search_path "${SEARCH_PATH:-}" \
  --arg tool_context "${TOOL_CONTEXT:-{}}" \
  --arg superclaude_context "${SUPERCLAUDE_CONTEXT:-{}}" \
  --arg file_changes "${FILE_CHANGES:-{}}" \
  --arg user_prompt "${USER_PROMPT:-}" \
  --arg raw_input "$JSON_INPUT" \
  '{
    timestamp: $timestamp,
    level: $level,
    event_type: $event_type,
    hook_event: $hook_event,
    session_id: $session_id,
    project_path: $project_path,
    project_name: $project_name,
    tool_name: $tool_name,
    telemetry_enabled: ($telemetry_enabled == "true"),
    action_details: {
      file_path: $file_path,
      size_bytes: ($size_bytes | tonumber),
      outside_project_scope: ($outside_scope == "true"),
      command: $command,
      search_pattern: $search_pattern,
      search_path: $search_path,
      tool_context: ($tool_context | fromjson)
    },
    superclaude_context: ($superclaude_context | fromjson),
    file_changes: ($file_changes | fromjson),
    metadata: {
      claude_version: "4.0",
      telemetry_version: "2.0.0",
      user_id: "jeff",
      scope: "project",
      user_prompt_preview: ($user_prompt | if length > 200 then .[0:200] + "..." else . end)
    },
    raw_input: ($raw_input | fromjson)
  }' 2>/dev/null || echo '{
    "timestamp": "'$TIMESTAMP'",
    "level": "ERROR",
    "event_type": "telemetry_error",
    "tool_name": "'$TOOL_NAME'",
    "session_id": "'$SESSION_ID'",
    "error": "Failed to create telemetry entry"
  }')

# Create logs directory if it doesn't exist (minimal backup only)
mkdir -p "$PROJECT_PATH/data/logs"

# Keep minimal backup log (crash recovery only)
echo "$LOG_ENTRY" >> "$PROJECT_PATH/data/logs/claude-telemetry.jsonl"

# Send to Loki if enabled
if [[ "$TELEMETRY_ENABLED" == "true" ]]; then
    # Create Loki-compatible log entry
    LOKI_TIMESTAMP="${TIMESTAMP}Z"
    LOKI_TIMESTAMP_NS=$(date -d "$TIMESTAMP" +%s%N)
    
    # Extract SuperClaude context for Loki labels
    SC_WORKFLOW=$(echo "$SUPERCLAUDE_CONTEXT" | jq -r '.workflow_type // "standard"')
    SC_PERSONAS=$(echo "$SUPERCLAUDE_CONTEXT" | jq -r '.personas // ""' | tr ',' '_')
    SC_REASONING=$(echo "$SUPERCLAUDE_CONTEXT" | jq -r '.reasoning_level // "none"')
    SC_COMMANDS=$(echo "$SUPERCLAUDE_CONTEXT" | jq -r '.commands // ""' | tr ',' '_')
    
    # Create enhanced log message for Loki
    LOG_MESSAGE="tool:$TOOL_NAME event:$EVENT_TYPE session:$SESSION_ID workflow:$SC_WORKFLOW"
    if [[ -n "$SC_PERSONAS" && "$SC_PERSONAS" != "" ]]; then
        LOG_MESSAGE="$LOG_MESSAGE personas:$SC_PERSONAS"
    fi
    if [[ -n "$SC_REASONING" && "$SC_REASONING" != "none" ]]; then
        LOG_MESSAGE="$LOG_MESSAGE reasoning:$SC_REASONING"
    fi
    
    LOKI_PAYLOAD=$(cat <<EOF
{
  "streams": [
    {
      "stream": {
        "service": "claude-telemetry",
        "project": "$PROJECT_NAME",
        "tool": "$TOOL_NAME",
        "event": "$EVENT_TYPE",
        "session": "$SESSION_ID",
        "scope": "project",
        "workflow": "$SC_WORKFLOW",
        "reasoning": "$SC_REASONING",
        "hook_event": "$HOOK_EVENT",
        "version": "2.0.0"
      },
      "values": [
        ["$LOKI_TIMESTAMP_NS", "$LOG_MESSAGE"]
      ]
    }
  ]
}
EOF
)
    
    # Debug: Log the payload being sent
    echo "=== DEBUG $(date) ===" >> /tmp/loki_debug.log
    echo "PAYLOAD: $LOKI_PAYLOAD" >> /tmp/loki_debug.log
    
    # Send to Loki (fire and forget, don't block if Loki is down)
    curl -s -H "Content-Type: application/json" \
         -XPOST "http://localhost:3100/loki/api/v1/push" \
         -d "$LOKI_PAYLOAD" >> /tmp/loki_debug.log 2>&1 &
fi

# Return success to continue tool execution
echo '{"continue": true}'
exit 0