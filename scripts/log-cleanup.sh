#!/bin/bash
"""
Log Cleanup and Rotation Script
Optimizes log storage and maintains manageable file sizes
"""

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$PROJECT_DIR/logs"

# Configuration
MAX_LOG_SIZE_MB=10
KEEP_ROTATED_LOGS=5
DATE_SUFFIX=$(date +%Y%m%d_%H%M%S)

echo "🧹 Starting log cleanup and rotation..."

# Function to rotate log if oversized
rotate_log() {
    local log_file="$1"
    local max_size_bytes=$((MAX_LOG_SIZE_MB * 1024 * 1024))
    
    if [[ -f "$log_file" ]] && [[ $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0) -gt $max_size_bytes ]]; then
        echo "📁 Rotating oversized log: $log_file"
        
        # Create rotated filename
        local base_name=$(basename "$log_file" .log)
        local rotated_file="${log_file%.*}_${DATE_SUFFIX}.log"
        
        # Rotate the log
        mv "$log_file" "$rotated_file"
        touch "$log_file"
        
        # Compress rotated log
        gzip "$rotated_file"
        echo "   ✅ Rotated and compressed: ${rotated_file}.gz"
        
        # Clean old rotated logs
        find "$(dirname "$log_file")" -name "${base_name}_*.log.gz" -type f | \
            sort -r | tail -n +$((KEEP_ROTATED_LOGS + 1)) | \
            xargs -r rm -f
    fi
}

# Function to truncate debug logs
truncate_debug_log() {
    local log_file="$1"
    local keep_lines="${2:-1000}"
    
    if [[ -f "$log_file" ]] && [[ $(wc -l < "$log_file") -gt $keep_lines ]]; then
        echo "✂️  Truncating debug log: $log_file (keeping last $keep_lines lines)"
        tail -n "$keep_lines" "$log_file" > "${log_file}.tmp"
        mv "${log_file}.tmp" "$log_file"
    fi
}

# Rotate service logs
echo "🔄 Checking service logs for rotation..."
rotate_log "$LOGS_DIR/loki.log"
rotate_log "$LOGS_DIR/grafana.log"
rotate_log "$LOGS_DIR/dashboard.log"

# Truncate alert logs (keep recent entries)
echo "✂️  Truncating alert logs..."
truncate_debug_log "$PROJECT_DIR/data/alerts/alert-engine.log" 500
truncate_debug_log "$PROJECT_DIR/scripts/data/alerts/security-alerts.log" 500

# Clean temporary files
echo "🗑️  Cleaning temporary files..."
find "$PROJECT_DIR" -name "*.tmp" -type f -delete 2>/dev/null || true
find "$PROJECT_DIR" -name "*.temp" -type f -delete 2>/dev/null || true
find "$PROJECT_DIR" -name ".DS_Store" -type f -delete 2>/dev/null || true

# Analytics cleanup (keep recent models and features)
echo "🧠 Cleaning old ML artifacts..."
ANALYTICS_DIR="$PROJECT_DIR/data/analytics"

if [[ -d "$ANALYTICS_DIR/models" ]]; then
    # Keep only latest + 2 most recent timestamped models
    find "$ANALYTICS_DIR/models" -name "*_20*.joblib" -type f | \
        grep -v "_latest.joblib" | sort -r | tail -n +7 | \
        xargs -r rm -f
fi

if [[ -d "$ANALYTICS_DIR/features" ]]; then
    # Keep only latest + 3 most recent feature sets
    find "$ANALYTICS_DIR/features" -name "*_20*.csv" -type f | \
        grep -v "latest_" | sort -r | tail -n +10 | \
        xargs -r rm -f
fi

# Telemetry data optimization
echo "📊 Optimizing telemetry data..."
TELEMETRY_FILE="$PROJECT_DIR/data/logs/claude-telemetry.jsonl"

if [[ -f "$TELEMETRY_FILE" ]]; then
    # Archive old telemetry data (keep last 30 days of entries)
    CUTOFF_DATE=$(date -d '30 days ago' '+%Y-%m-%d' 2>/dev/null || date -v-30d '+%Y-%m-%d' 2>/dev/null || echo "2024-07-01")
    
    # Count total and recent entries
    TOTAL_ENTRIES=$(wc -l < "$TELEMETRY_FILE")
    RECENT_ENTRIES=$(awk -v cutoff="$CUTOFF_DATE" '
        /timestamp/ {
            if (match($0, /"timestamp":"([^"]+)"/, arr)) {
                if (arr[1] >= cutoff) print
            }
        }
    ' "$TELEMETRY_FILE" | wc -l)
    
    echo "   📈 Telemetry: $TOTAL_ENTRIES total entries, $RECENT_ENTRIES recent"
    
    # If more than 50K entries, archive old ones
    if [[ $TOTAL_ENTRIES -gt 50000 ]]; then
        echo "   📦 Archiving old telemetry entries..."
        ARCHIVE_FILE="$PROJECT_DIR/data/logs/claude-telemetry-archive-${DATE_SUFFIX}.jsonl"
        
        awk -v cutoff="$CUTOFF_DATE" '
            /timestamp/ {
                if (match($0, /"timestamp":"([^"]+)"/, arr)) {
                    if (arr[1] >= cutoff) print > "/tmp/recent.jsonl"
                    else print > "/tmp/archive.jsonl"
                } else print > "/tmp/recent.jsonl"
            }
            !/timestamp/ { print > "/tmp/recent.jsonl" }
        ' "$TELEMETRY_FILE"
        
        if [[ -f "/tmp/archive.jsonl" ]] && [[ -s "/tmp/archive.jsonl" ]]; then
            mv "/tmp/archive.jsonl" "$ARCHIVE_FILE"
            gzip "$ARCHIVE_FILE"
            echo "   ✅ Archived $(wc -l < "$ARCHIVE_FILE.gz" | tr -d ' ') old entries"
        fi
        
        if [[ -f "/tmp/recent.jsonl" ]]; then
            mv "/tmp/recent.jsonl" "$TELEMETRY_FILE"
            echo "   ✅ Kept $RECENT_ENTRIES recent entries"
        fi
    fi
fi

# Report final sizes
echo ""
echo "📊 Post-cleanup storage report:"
echo "   $(du -sh "$LOGS_DIR" | cut -f1) - Service logs"
echo "   $(du -sh "$PROJECT_DIR/data" | cut -f1) - Data directory"
if [[ -d "$ANALYTICS_DIR" ]]; then
    echo "   $(du -sh "$ANALYTICS_DIR" | cut -f1) - ML analytics"
fi

echo ""
echo "✅ Log cleanup completed!"
echo "💡 Run this script weekly or add to cron for automated maintenance"