#!/bin/bash
# Setup hyly-extension tools for a specific project
# Usage: ./setup-project.sh [project-path] [--dry-run]

set -euo pipefail

# Parse arguments
PROJECT_PATH="${1:-$(pwd)}"
DRY_RUN=false

if [[ "${2:-}" == "--dry-run" ]] || [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    if [[ "${1:-}" == "--dry-run" ]]; then
        PROJECT_PATH="$(pwd)"
    fi
    echo "🔍 DRY RUN MODE - No changes will be made"
fi

# Script directory and extension root
SCRIPT_DIR="$(dirname "$0")"
EXTENSION_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$PROJECT_PATH/.claude"

echo "🚀 Hyly Extension Tools - Setup Project"
echo "📁 Extension root: $EXTENSION_ROOT"
echo "📁 Project path: $PROJECT_PATH"
echo "🎯 Target: $TARGET_DIR"
echo ""

# Validate project path
if [ ! -d "$PROJECT_PATH" ]; then
    echo "❌ Project path does not exist: $PROJECT_PATH"
    exit 1
fi

# Create target directories
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$TARGET_DIR"/{commands,scripts,agents}
fi

# Function to create symlinks or show what would be created
link_files() {
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
            local relative_source=$(realpath --relative-to="$TARGET_DIR/$target_subdir" "$file")
            
            if [ "$DRY_RUN" = true ]; then
                echo "  🔗 Would link: $basename_file → $relative_source"
            else
                # Remove existing symlink or file
                rm -f "$target_file" 2>/dev/null || true
                ln -s "$relative_source" "$target_file"
                echo "  ✅ Linked: $basename_file → $relative_source"
            fi
        fi
    done
    
    if [ $files_found -eq 0 ]; then
        echo "  ℹ️  No files found in $source_dir matching $pattern"
    fi
}

# Link commands
echo "🔗 Linking Commands..."
link_files "$EXTENSION_ROOT/tools/workflow" "commands" "*.md"
link_files "$EXTENSION_ROOT/tools/workflow" "commands" "*.sh"

# Link scripts  
echo ""
echo "🔗 Linking Scripts..."
link_files "$EXTENSION_ROOT/tools/common" "scripts" "*"
link_files "$EXTENSION_ROOT/tools/postgres" "scripts" "*"

# Link agents
echo ""
echo "🔗 Linking Agents..."
link_files "$EXTENSION_ROOT/.claude/agents" "agents" "*"

# Link .claude commands/scripts if they exist
if [ -d "$EXTENSION_ROOT/.claude/commands" ]; then
    echo ""
    echo "🔗 Linking .claude Commands..."
    link_files "$EXTENSION_ROOT/.claude/commands" "commands" "*"
fi

if [ -d "$EXTENSION_ROOT/.claude/scripts" ]; then
    echo ""
    echo "🔗 Linking .claude Scripts..."
    link_files "$EXTENSION_ROOT/.claude/scripts" "scripts" "*"
fi

# Create project-specific CLAUDE.md if it doesn't exist
CLAUDE_MD="$PROJECT_PATH/CLAUDE.md"
if [ ! -f "$CLAUDE_MD" ] && [ "$DRY_RUN" = false ]; then
    echo ""
    echo "📝 Creating project CLAUDE.md..."
    cat > "$CLAUDE_MD" << 'EOF'
# Project Claude Configuration

## Hyly Extension Tools

This project is configured with hyly-extension tools for n8n workflow development.

### Available Tools
- `n8nwf-01-upload.sh` - Upload and verify workflows
- `n8nwf-02-execute.sh` - Execute workflows via CLI
- `n8nwf-03-analyze.sh` - Analyze execution results
- `n8nwf-04-validate.md` - Validate fix drafts
- `n8nwf-05-mergefix.md` - Merge validated fixes

### Workflow Development Cycle
1. Download workflow → fix-draft → fix → edit
2. Upload → execute → analyze → validate
3. Repeat until NO ERRORS status achieved

### File Naming Convention
All lifecycle files follow: `YYYYMMDD-HHMMSS-{workflowId}-{stage}-{description}.{ext}`

EOF
    echo "  ✅ Created: CLAUDE.md with tool documentation"
elif [ "$DRY_RUN" = true ] && [ ! -f "$CLAUDE_MD" ]; then
    echo ""
    echo "📝 Would create: CLAUDE.md with tool documentation"
fi

echo ""
if [ "$DRY_RUN" = true ]; then
    echo "🔍 Dry run complete - no changes made"
    echo "💡 Run without --dry-run to perform actual setup"
else
    echo "✅ Project setup complete!"
    echo "🎯 Tools linked in: $TARGET_DIR"
    echo "📝 Project configured with CLAUDE.md"
    echo ""
    echo "Available commands:"
    find "$TARGET_DIR/commands" -name "n8nwf-*" -exec basename {} \; 2>/dev/null | sort || echo "  (none yet)"
fi