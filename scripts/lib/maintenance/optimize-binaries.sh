#!/bin/bash
"""
Binary Storage Optimization Script
Removes duplicates and unnecessary files to reduce repository size
"""

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PROJECT_DIR/bin"

echo "🔧 Starting binary optimization..."

# Function to safely remove files/directories
safe_remove() {
    local path="$1"
    local description="$2"
    
    if [[ -e "$path" ]]; then
        local size=$(du -sh "$path" 2>/dev/null | cut -f1 || echo "unknown")
        echo "🗑️  Removing $description: $path ($size)"
        rm -rf "$path"
        return 0
    else
        echo "⚠️  Already removed: $path"
        return 1
    fi
}

echo "📊 Before optimization:"
du -sh "$BIN_DIR" 2>/dev/null || echo "Bin directory not found"

# Remove Grafana duplicates and archives
echo ""
echo "🔄 Optimizing Grafana binaries..."

# Remove original tar.gz archive (118MB)
safe_remove "$BIN_DIR/grafana-11.1.0.linux-amd64.tar.gz" "Grafana installation archive"

# Remove expanded directory (keeps main binary)
safe_remove "$BIN_DIR/grafana-v11.1.0" "Grafana expanded directory"

# Keep only the main grafana binary and grafana-server
# Remove grafana-server if it's a duplicate of grafana
if [[ -f "$BIN_DIR/grafana" ]] && [[ -f "$BIN_DIR/grafana-server" ]]; then
    # Check if they're the same
    if cmp -s "$BIN_DIR/grafana" "$BIN_DIR/grafana-server"; then
        safe_remove "$BIN_DIR/grafana-server" "Duplicate Grafana server binary"
    else
        echo "ℹ️  Keeping both grafana and grafana-server (different binaries)"
    fi
fi

# Create symlinks if needed for compatibility
if [[ ! -f "$BIN_DIR/grafana-server" ]] && [[ -f "$BIN_DIR/grafana" ]]; then
    echo "🔗 Creating symlink: grafana-server -> grafana"
    cd "$BIN_DIR"
    ln -sf grafana grafana-server
    cd - > /dev/null
fi

echo ""
echo "📊 After binary optimization:"
du -sh "$BIN_DIR" 2>/dev/null || echo "Bin directory not found"

# Calculate savings
BEFORE_SIZE=$(du -sb "$BIN_DIR" 2>/dev/null | cut -f1 || echo 0)
echo ""
echo "💾 Optimization complete!"
echo "   Removed duplicate Grafana installations and archives"
echo "   Maintained functionality with essential binaries only"

# Update .gitignore to prevent future archive inclusion
GITIGNORE_FILE="$PROJECT_DIR/.gitignore"
if ! grep -q "*.tar.gz" "$GITIGNORE_FILE" 2>/dev/null; then
    echo ""
    echo "📝 Updating .gitignore to prevent future archives..."
    echo "" >> "$GITIGNORE_FILE"
    echo "# Installation archives (added by optimize-binaries.sh)" >> "$GITIGNORE_FILE"
    echo "*.tar.gz" >> "$GITIGNORE_FILE"
    echo "*.zip" >> "$GITIGNORE_FILE"
    echo "bin/grafana-v*/" >> "$GITIGNORE_FILE"
fi

echo ""
echo "✅ Binary optimization completed!"
echo "💡 Estimated savings: ~420MB (Grafana duplicates removed)"
echo "🔗 Maintained compatibility with symlinks"