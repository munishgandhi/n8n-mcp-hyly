#!/bin/bash

# n8n-000-common.sh - Common functions for n8n agents
# Source this file in agent scripts to use shared functionality

# =============================================================================
# OUTPUT HELPERS
# =============================================================================

info() { echo "ℹ️  $*"; }
success() { echo "✅ $*"; }
error() { echo "❌ $*" >&2; exit 1; }
warning() { echo "⚠️  $*" >&2; }

# =============================================================================
# DIRECTORY FUNCTIONS
# =============================================================================

# Get current workflow directory from git branch
get_workflow_dir() {
    local repo_root=$(git rev-parse --show-toplevel)
    "$repo_root/.claude/toolbox-n8n/n8n-900-workflow-dir-find.sh"
}

# =============================================================================
# TIMESTAMP FUNCTIONS
# =============================================================================

# Generate Eastern timezone timestamp (YYYYMMDD-HHMMSS)
generate_timestamp() {
    TZ=America/New_York date +"%Y%m%d-%H%M%S"
}

# Update workflow name with timestamp
update_workflow_name() {
    local base_name="$1"
    local timestamp=$(generate_timestamp)
    
    # Check if name already has version timestamp (vYYYYMMDD-HHMMSS pattern)
    if [[ ! $base_name =~ v[0-9]{8}-[0-9]{6} ]]; then
        echo "$base_name v$timestamp"
    else
        # Update existing timestamp to current time
        echo "$base_name" | sed "s/v[0-9]\{8\}-[0-9]\{6\}/v$timestamp/"
    fi
}

# =============================================================================
# BROWSER DISPLAY
# =============================================================================

# Open file in browser (WSL-compatible)
open_in_browser() {
    local file_path="$1"
    local full_path=$(realpath "$file_path")
    
    info "🌐 Opening browser for: $(basename "$file_path")"
    
    if grep -qi microsoft /proc/version 2>/dev/null; then
        # WSL - use PowerShell with better error handling and unique process
        local timestamp=$(date +%s)
        local cmd="Start-Process chrome -ArgumentList 'file://wsl.localhost/Ubuntu$full_path?t=$timestamp' -WindowStyle Normal"
        
        if powershell.exe -Command "$cmd" 2>&1; then
            success "Browser opened successfully"
        else
            warning "Chrome browser open failed, trying default browser..."
            # Fallback to generic Start-Process
            if powershell.exe -Command "Start-Process 'file://wsl.localhost/Ubuntu$full_path?t=$timestamp'" 2>&1; then
                success "Browser opened with default handler"
            else
                warning "All browser opening attempts failed. File location: $full_path"
                info "Try manually opening: file://wsl.localhost/Ubuntu$full_path"
            fi
        fi
    elif command -v xdg-open > /dev/null; then
        xdg-open "$full_path" 2>&1 && \
        success "Browser opened with xdg-open"
    elif command -v open > /dev/null; then
        open "$full_path" 2>&1 && \
        success "Browser opened with open"
    else
        warning "No browser opener found. View file at: $full_path"
    fi
}

# =============================================================================
# HTML GENERATION
# =============================================================================

# Create unified n8n HTML report with consistent styling
create_n8n_html_report() {
    local html_file="$1"
    local title="$2"
    local status_text="$3"
    local workflow_id="$4"
    local workflow_name="$5"
    local timestamp="$6"
    local script_name="$7"
    
    cat > "$html_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            max-width: 1200px; 
            margin: 0 auto; 
            padding: 20px; 
            background: #f8f9fa; 
            line-height: 1.6;
        }
        .container { 
            background: white; 
            border-radius: 12px; 
            padding: 30px; 
            box-shadow: 0 4px 6px rgba(0,0,0,0.1); 
        }
        
        /* Unified header with status and workflow info */
        .header { 
            text-align: center; 
            padding: 20px;
            margin-bottom: 30px; 
            border: 2px solid #28a745;
            border-radius: 8px;
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
        }
        .status-line {
            font-size: 20px;
            font-weight: bold;
            color: #28a745;
            margin-bottom: 10px;
        }
        .workflow-info {
            font-size: 16px;
            color: #666;
        }
        .workflow-info a {
            color: #007bff;
            text-decoration: none;
            font-weight: bold;
        }
        .workflow-info a:hover {
            text-decoration: underline;
        }
        .separator {
            margin: 0 10px;
            color: #ccc;
        }
        
        /* Info table layout */
        .info-table {
            width: 100%;
            margin: 20px 0;
        }
        .info-row {
            display: flex;
            padding: 8px 0;
            border-bottom: 1px solid #eee;
        }
        .info-row:last-child {
            border-bottom: none;
        }
        .info-label {
            flex: 0 0 150px;
            text-align: right;
            padding-right: 15px;
            font-weight: 600;
            color: #666;
        }
        .info-value {
            flex: 1;
            color: #333;
        }
        .info-value code {
            display: block;
            margin: 2px 0;
            background: #f4f4f4; 
            padding: 2px 6px; 
            border-radius: 3px; 
            font-family: 'Consolas', 'Monaco', monospace;
        }
        
        /* Notes section */
        .notes-section {
            margin-top: 20px;
            padding: 15px;
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 6px;
        }
        .notes-header {
            font-size: 14px;
            color: #6c757d;
            text-transform: uppercase;
            font-weight: 600;
            margin-bottom: 10px;
        }
        .notes-content {
            color: #333;
            line-height: 1.6;
        }
        .notes-content div {
            margin: 4px 0;
        }
        
        /* Footer */
        .footer {
            text-align: center; 
            margin-top: 30px; 
            padding-top: 20px;
            border-top: 1px solid #dee2e6;
            color: #6c757d;
            font-style: italic;
            font-size: 14px;
        }
        
        /* Mobile responsive */
        @media (max-width: 768px) {
            .info-label {
                flex: 0 0 120px;
                font-size: 12px;
            }
            .workflow-info {
                font-size: 14px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="status-line">$status_text</div>
            <div class="workflow-info">
                <a href="http://localhost:5678/workflow/$workflow_id" target="_blank">$workflow_id</a>
                <span class="separator">|</span>
                <span>$workflow_name</span>
                <span class="separator">|</span>
                <span>$timestamp EST</span>
            </div>
        </div>
EOF
    
    echo "$html_file"
}

# Start info table section
start_info_table() {
    local html_file="$1"
    
    cat >> "$html_file" << EOF
        <div class="info-table">
EOF
}

# End info table section
end_info_table() {
    local html_file="$1"
    
    cat >> "$html_file" << EOF
        </div>
EOF
}

# Add info table row to HTML report
add_info_row() {
    local html_file="$1"
    local label="$2"
    local value="$3"
    
    cat >> "$html_file" << EOF
            <div class="info-row">
                <span class="info-label">$label:</span>
                <span class="info-value">$value</span>
            </div>
EOF
}

# Add notes section to HTML report
add_notes_section() {
    local html_file="$1"
    local header="$2"
    shift 2
    local notes=("$@")
    
    cat >> "$html_file" << EOF
        
        <div class="notes-section">
            <div class="notes-header">$header</div>
            <div class="notes-content">
EOF
    
    for note in "${notes[@]}"; do
        echo "                <div>$note</div>" >> "$html_file"
    done
    
    cat >> "$html_file" << EOF
            </div>
        </div>
EOF
}

# Finalize HTML report with footer
finalize_html_report() {
    local html_file="$1"
    local script_name="$2"
    
    cat >> "$html_file" << EOF
        
        <div class="footer">
            Generated by $script_name at $(date)
        </div>
    </div>
</body>
</html>
EOF
}

# Legacy function for backward compatibility - now deprecated
create_html_report() {
    local md_file="$1"
    local title="${2:-Report}"
    local html_file="${md_file%.md}.html"
    
    # Basic HTML template with styling
    cat > "$html_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            max-width: 1200px; 
            margin: 0 auto; 
            padding: 20px; 
            background: #f8f9fa; 
            line-height: 1.6;
        }
        .container { 
            background: white; 
            border-radius: 12px; 
            padding: 30px; 
            box-shadow: 0 4px 6px rgba(0,0,0,0.1); 
        }
        h1 { 
            color: #2c3e50; 
            border-bottom: 3px solid #28a745; 
            padding-bottom: 10px; 
        }
        h2 { 
            color: #34495e; 
            margin-top: 25px; 
        }
        .success { color: #28a745; font-weight: bold; }
        .error { color: #dc3545; font-weight: bold; }
        .warning { color: #ffc107; font-weight: bold; }
        code { 
            background: #f4f4f4; 
            padding: 2px 6px; 
            border-radius: 3px; 
            font-family: 'Consolas', 'Monaco', monospace;
        }
        pre { 
            background: #1e1e1e; 
            color: #d4d4d4;
            padding: 15px; 
            border-radius: 5px; 
            overflow-x: auto;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 15px 0;
        }
        th, td {
            border: 1px solid #dee2e6;
            padding: 12px;
            text-align: left;
        }
        th {
            background-color: #f8f9fa;
            font-weight: 600;
        }
        ul {
            list-style-type: none;
            padding-left: 0;
        }
        li {
            padding: 5px 0;
        }
        .timestamp {
            color: #6c757d;
            font-style: italic;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #dee2e6;
        }
        
        /* Compact report styling */
        .workflow-info {
            font-size: 16px;
            color: #666;
            margin-top: 10px;
        }
        .workflow-info a {
            color: #007bff;
            text-decoration: none;
            font-weight: bold;
        }
        .workflow-info a:hover {
            text-decoration: underline;
        }
        .separator {
            margin: 0 10px;
            color: #ccc;
        }
        
        /* Status line header */
        .status-line {
            text-align: center;
            font-size: 18px;
            font-weight: bold;
            color: #28a745;
            background: #f8f9fa;
            padding: 10px;
            border-radius: 6px;
            margin-bottom: 15px;
            border: 2px solid #28a745;
        }
        
        /* Info table layout */
        .info-table {
            width: 100%;
            margin: 20px 0;
        }
        .info-row {
            display: flex;
            padding: 8px 0;
            border-bottom: 1px solid #eee;
        }
        .info-row:last-child {
            border-bottom: none;
        }
        .info-label {
            flex: 0 0 150px;
            text-align: right;
            padding-right: 15px;
            font-weight: 600;
            color: #666;
        }
        .info-value {
            flex: 1;
            color: #333;
        }
        .info-value code {
            display: block;
            margin: 2px 0;
        }
        
        /* Notes section */
        .notes-section {
            margin-top: 20px;
            padding: 15px;
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 6px;
        }
        .notes-header {
            font-size: 14px;
            color: #6c757d;
            text-transform: uppercase;
            font-weight: 600;
            margin-bottom: 10px;
        }
        .notes-content {
            color: #333;
            line-height: 1.6;
        }
        .notes-content div {
            margin: 4px 0;
        }
        
        /* Mobile responsive */
        @media (max-width: 768px) {
            .info-label {
                flex: 0 0 120px;
                font-size: 12px;
            }
            .workflow-info {
                font-size: 14px;
            }
        }
    </style>
</head>
<body>
<div class="container">
EOF

    # Simple markdown to HTML conversion using sed
    # Handle headers, lists, code blocks, and special characters
    sed -e 's/^# \(.*\)/<h1>\1<\/h1>/g' \
        -e 's/^## \(.*\)/<h2>\1<\/h2>/g' \
        -e 's/^### \(.*\)/<h3>\1<\/h3>/g' \
        -e 's/^- \(.*\)/<li>\1<\/li>/g' \
        -e 's/^\* \(.*\)/<li>\1<\/li>/g' \
        -e 's/`\([^`]*\)`/<code>\1<\/code>/g' \
        -e 's/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g' \
        -e 's/✅/<span class="success">✅<\/span>/g' \
        -e 's/❌/<span class="error">❌<\/span>/g' \
        -e 's/⚠️/<span class="warning">⚠️<\/span>/g' \
        -e 's/^$/\<br\>/g' \
        "$md_file" >> "$html_file"
    
    echo '</div></body></html>' >> "$html_file"
    
    echo "$html_file"
}

# =============================================================================
# JSON HELPERS
# =============================================================================

# Extract node count from workflow JSON
extract_node_count() {
    local json_file="$1"
    jq '.nodes | length' "$json_file" 2>/dev/null || echo "0"
}

# Extract connection count from workflow JSON
extract_connection_count() {
    local json_file="$1"
    jq '.connections | to_entries | map(select(.value | type == "object") | .value | to_entries | map(.value | length) | add) | add' "$json_file" 2>/dev/null || echo "0"
}

# =============================================================================
# USAGE DISPLAY
# =============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "n8n-000-common.sh - Common functions for n8n agents"
    echo ""
    echo "This script provides helper functions and should be sourced:"
    echo "  source \"$(realpath "$0")\""
    echo ""
    echo "Available functions:"
    echo "  Output:     info, success, error, warning"
    echo "  Timestamp:  generate_timestamp, update_workflow_name"
    echo "  Browser:    open_in_browser"
    echo "  HTML:       create_html_report"
    echo "  JSON:       extract_node_count, extract_connection_count"
    exit 0
fi