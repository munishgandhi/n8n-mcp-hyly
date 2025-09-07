#!/bin/bash
# Install hyly-extension tools to user's ~/.claude directory
# Usage: ./install-to-user.sh [--dry-run]

set -euo pipefail

# Script directory and extension root
SCRIPT_DIR="$(dirname "$0")"
EXTENSION_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$HOME/.claude"

# Parse arguments
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "🔍 DRY RUN MODE - No changes will be made"
fi

echo "🚀 Hyly Extension Tools - Install to User"
echo "📁 Extension root: $EXTENSION_ROOT"
echo "🎯 Target: $TARGET_DIR"
echo ""

# Create target directories
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$TARGET_DIR"/{commands,scripts,agents}
fi

# Function to install or show what would be installed
install_files() {
    local source_dir="$1"
    local target_subdir="$2"
    local pattern="$3"
    
    if [ ! -d "$source_dir" ]; then
        echo "⚠️  Source directory not found: $source_dir"
        return 0
    fi
    
    local files_found=0
    for file in "$source_dir"/$pattern; do
        if [ -f "$file" ]; then
            files_found=$((files_found + 1))
            local basename_file=$(basename "$file")
            local target_file="$TARGET_DIR/$target_subdir/$basename_file"
            
            if [ "$DRY_RUN" = true ]; then
                echo "  📋 Would install: $basename_file → $target_subdir/"
            else
                cp "$file" "$target_file"
                chmod +x "$target_file" 2>/dev/null || true
                echo "  ✅ Installed: $basename_file → $target_subdir/"
            fi
        fi
    done
    
    if [ $files_found -eq 0 ]; then
        echo "  ℹ️  No files found in $source_dir matching $pattern"
    fi
}

# Install commands
echo "📦 Installing Commands..."
install_files "$EXTENSION_ROOT/tools/workflow" "commands" "*.md"
install_files "$EXTENSION_ROOT/tools/workflow" "commands" "*.sh"

# Install scripts  
echo ""
echo "📦 Installing Scripts..."
install_files "$EXTENSION_ROOT/tools/common" "scripts" "*"
install_files "$EXTENSION_ROOT/tools/postgres" "scripts" "*"

# Install agents
echo ""
echo "📦 Installing Agents..."
install_files "$EXTENSION_ROOT/.claude/agents" "agents" "*"

# Install .claude commands/scripts if they exist
if [ -d "$EXTENSION_ROOT/.claude/commands" ]; then
    echo ""
    echo "📦 Installing .claude Commands..."
    install_files "$EXTENSION_ROOT/.claude/commands" "commands" "*"
fi

if [ -d "$EXTENSION_ROOT/.claude/scripts" ]; then
    echo ""
    echo "📦 Installing .claude Scripts..."
    install_files "$EXTENSION_ROOT/.claude/scripts" "scripts" "*"
fi

echo ""
if [ "$DRY_RUN" = true ]; then
    echo "🔍 Dry run complete - no changes made"
    echo "💡 Run without --dry-run to perform actual installation"
else
    echo "✅ Installation complete!"
    echo "🎯 Tools available in: $TARGET_DIR"
    echo ""
    echo "Available commands:"
    find "$TARGET_DIR/commands" -name "n8nwf-*" -exec basename {} \; 2>/dev/null | sort || echo "  (none yet)"
fi

echo ""
echo "📝 Note: Restart Claude Code or run 'source ~/.bashrc' to use new tools"