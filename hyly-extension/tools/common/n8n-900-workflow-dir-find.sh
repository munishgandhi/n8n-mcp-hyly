#!/bin/bash
# Find n8n workflow directory based on git branch name
# Branch format: system-feature-vX.Y -> apps/system/feature/vX.Y/
# Output: Full path to workflow directory or "." if not found
# Usage: ./n8n-900-workflow-dir-find.sh

set -e

# Get current branch
BRANCH=$(git branch --show-current)
REPO_ROOT=$(git rev-parse --show-toplevel)

# Special case for claude-agents branch
if [ "$BRANCH" = "claude-agents" ]; then
    echo "$REPO_ROOT/.claude"
    exit 0
fi

# Check for workflow branch pattern: system-feature-vX.Y
if [[ "$BRANCH" =~ ^([a-zA-Z0-9-]+)-([a-zA-Z0-9-]+)-v([0-9]+\.[0-9]+)$ ]]; then
    SYSTEM="${BASH_REMATCH[1]}"
    FEATURE="${BASH_REMATCH[2]}"
    VERSION="${BASH_REMATCH[3]}"
    
    # Build expected directory path
    WORKFLOW_DIR="apps/$SYSTEM/$FEATURE/v$VERSION"
    ACTUAL_DIR="$REPO_ROOT/$WORKFLOW_DIR"
    
    if [ -d "$ACTUAL_DIR" ]; then
        echo "$ACTUAL_DIR"
    else
        echo "."
    fi
else
    # Not on a workflow branch
    echo "."
fi