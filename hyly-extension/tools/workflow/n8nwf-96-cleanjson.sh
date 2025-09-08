#!/bin/bash
# n8nwf-96-cleanjson.sh - Clean and validate raw JSON files
#
# JSON CLEANING UTILITY
# =====================
# Usage: n8nwf-96-cleanjson.sh <input_file> [output_file]
#
# Purpose: Clean malformed JSON extracted from databases, APIs, or other sources
# 
# Features:
# - Remove leading/trailing whitespace
# - Fix common JSON formatting issues
# - Validate JSON syntax
# - Pretty-print output
# - Handle large files efficiently
#
# Examples:
#   ./n8nwf-96-cleanjson.sh raw-data.json clean-data.json
#   ./n8nwf-96-cleanjson.sh malformed.json  # outputs to malformed-clean.json
#   cat raw.json | ./n8nwf-96-cleanjson.sh -  # read from stdin
#

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/n8nwf-99-common.sh"

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <input_file> [output_file]"
    echo ""
    echo "Clean and validate raw JSON files"
    echo ""
    echo "Arguments:"
    echo "  <input_file>   Input JSON file to clean (use '-' for stdin)"
    echo "  [output_file]  Output file (default: {input}-clean.json)"
    echo ""
    echo "Examples:"
    echo "  $0 raw-data.json clean-data.json"
    echo "  $0 malformed.json  # outputs to malformed-clean.json"
    echo "  cat raw.json | $0 -  # read from stdin"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-}"

# Handle stdin input
if [[ "$INPUT_FILE" == "-" ]]; then
    INPUT_FILE="/tmp/json-clean-input-$$.json"
    cat > "$INPUT_FILE"
    CLEANUP_INPUT=true
else
    CLEANUP_INPUT=false
fi

# Generate output filename if not provided
if [[ -z "$OUTPUT_FILE" ]]; then
    if [[ "$INPUT_FILE" == "/tmp/json-clean-input-"* ]]; then
        OUTPUT_FILE="/tmp/json-clean-output-$$.json"
        CLEANUP_OUTPUT=false  # We'll cat it to stdout
    else
        # Remove extension and add -clean.json
        BASE_NAME="${INPUT_FILE%.*}"
        EXTENSION="${INPUT_FILE##*.}"
        if [[ "$EXTENSION" == "json" ]]; then
            OUTPUT_FILE="${BASE_NAME}-clean.json"
        else
            OUTPUT_FILE="${INPUT_FILE}-clean.json"
        fi
        CLEANUP_OUTPUT=false
    fi
else
    CLEANUP_OUTPUT=false
fi

# =============================================================================
# JSON CLEANING FUNCTIONS
# =============================================================================

# Function to detect and report JSON issues
analyze_json() {
    local input_file="$1"
    
    info "Analyzing input JSON file: $(basename "$input_file")"
    
    # Check if file exists and is readable
    if [[ ! -f "$input_file" ]]; then
        error "Input file does not exist: $input_file"
    fi
    
    if [[ ! -r "$input_file" ]]; then
        error "Input file is not readable: $input_file"
    fi
    
    # Get file size
    local file_size=$(wc -c < "$input_file")
    info "File size: $(numfmt --to=iec "$file_size")"
    
    # Check for leading/trailing whitespace
    local first_char=$(head -c 1 "$input_file")
    local last_char=$(tail -c 1 "$input_file")
    
    if [[ "$first_char" =~ [[:space:]] ]]; then
        warning "File has leading whitespace"
    fi
    
    if [[ "$last_char" =~ [[:space:]] ]]; then
        warning "File has trailing whitespace"
    fi
    
    # Try to parse with jq
    if jq . "$input_file" >/dev/null 2>&1; then
        success "JSON is already valid"
        return 0
    else
        warning "JSON has syntax errors - will attempt to clean"
        return 1
    fi
}

# Function to clean common JSON issues
clean_json() {
    local input_file="$1"
    local output_file="$2"
    
    info "Cleaning JSON..."
    
    # Step 1: Remove leading/trailing whitespace from each line
    debug "Step 1: Removing whitespace"
    local temp1="/tmp/json-clean-step1-$$.json"
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$input_file" > "$temp1"
    
    # Step 2: Remove completely empty lines
    debug "Step 2: Removing empty lines"
    local temp2="/tmp/json-clean-step2-$$.json"
    grep -v '^$' "$temp1" > "$temp2" || cp "$temp1" "$temp2"
    
    # Step 3: Try to fix common JSON issues
    debug "Step 3: Fixing common JSON issues"
    local temp3="/tmp/json-clean-step3-$$.json"
    
    # Remove trailing commas before } or ]
    sed 's/,[[:space:]]*\([}\]]\)/\1/g' "$temp2" > "$temp3"
    
    # Step 4: Validate and pretty-print with jq
    debug "Step 4: Validating and pretty-printing"
    if jq . "$temp3" > "$output_file" 2>/dev/null; then
        success "JSON cleaned and validated successfully"
        
        # Cleanup temp files
        rm -f "$temp1" "$temp2" "$temp3"
        return 0
    else
        error "Unable to clean JSON - syntax errors remain. Check input file format."
    fi
}

# Function to compare before/after
compare_results() {
    local input_file="$1"
    local output_file="$2"
    
    local input_size=$(wc -c < "$input_file")
    local output_size=$(wc -c < "$output_file")
    
    info "Cleaning results:"
    echo "  📥 Input size:  $(numfmt --to=iec "$input_size")"
    echo "  📤 Output size: $(numfmt --to=iec "$output_size")"
    
    if [[ "$output_size" -lt "$input_size" ]]; then
        local saved=$((input_size - output_size))
        echo "  💾 Space saved: $(numfmt --to=iec "$saved") ($(echo "scale=1; $saved * 100 / $input_size" | bc -l)%)"
    fi
    
    # Count JSON objects/arrays in output
    local json_type=$(jq -r 'type' "$output_file" 2>/dev/null || echo "unknown")
    case "$json_type" in
        "object")
            local key_count=$(jq 'keys | length' "$output_file" 2>/dev/null || echo "0")
            echo "  🔑 Object with $key_count keys"
            ;;
        "array")
            local item_count=$(jq 'length' "$output_file" 2>/dev/null || echo "0")
            echo "  📋 Array with $item_count items"
            ;;
        *)
            echo "  📄 JSON type: $json_type"
            ;;
    esac
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

info "Starting JSON cleaning process"

# Analyze input
if analyze_json "$INPUT_FILE"; then
    # JSON is already clean, just pretty-print it
    info "Input JSON is already valid - creating pretty-printed version"
    jq . "$INPUT_FILE" > "$OUTPUT_FILE"
else
    # Clean the JSON
    clean_json "$INPUT_FILE" "$OUTPUT_FILE"
fi

# Compare results
compare_results "$INPUT_FILE" "$OUTPUT_FILE"

# Handle output
if [[ "$INPUT_FILE" == "/tmp/json-clean-input-"* && -z "${2:-}" ]]; then
    # Stdin input, no output file specified - output to stdout
    cat "$OUTPUT_FILE"
    rm -f "$OUTPUT_FILE"
else
    success "Clean JSON saved to: $OUTPUT_FILE"
fi

# Cleanup
if [[ "$CLEANUP_INPUT" == "true" ]]; then
    rm -f "$INPUT_FILE"
fi

echo ""
info "✅ JSON cleaning completed successfully!"

exit 0