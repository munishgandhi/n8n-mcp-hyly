#!/bin/bash
# test-cli-update.sh - Test proper CLI workflow update method

set -euo pipefail

CONTAINER_NAME="hyly-n8n-app"
WORKFLOW_ID="KQxYbOJgGEEuzVT0"

echo "====================================="
echo "n8n CLI Update Test (Proper Method)"
echo "====================================="
echo ""

# Method: Export → Modify → Import with replacement
echo "Testing CLI workflow update via export → modify → import"
echo ""

# Step 1: Export existing workflow
echo "Step 1: Export existing workflow"
START_TIME=$(date +%s.%N)

TEMP_DIR="/tmp/n8n-cli-test"
mkdir -p "$TEMP_DIR"

# Export to container tmp first
docker exec "$CONTAINER_NAME" n8n export:workflow \
    --id="$WORKFLOW_ID" \
    --output="/tmp/exported.json" >/dev/null 2>&1

# Copy to host
docker cp "$CONTAINER_NAME:/tmp/exported.json" "$TEMP_DIR/original.json"
docker exec "$CONTAINER_NAME" rm -f "/tmp/exported.json"

EXPORT_TIME=$(date +%s.%N)
EXPORT_DURATION=$(echo "$EXPORT_TIME - $START_TIME" | bc)
echo "Export duration: ${EXPORT_DURATION}s"
echo ""

# Step 2: Modify the workflow
echo "Step 2: Modify workflow content"
MODIFY_START=$(date +%s.%N)

# Read and modify the workflow JSON (CLI export returns array, take first element)
jq '.[0].name = "CLI UPDATE TEST v" + (now | strftime("%Y%m%d-%H%M%S")) | 
    .[0].nodes[1].parameters.jsCode = "return [{ method: \"CLI\", timestamp: new Date().toISOString(), test: \"update\" }];"' \
    "$TEMP_DIR/original.json" > "$TEMP_DIR/modified.json"

MODIFY_END=$(date +%s.%N)
MODIFY_DURATION=$(echo "$MODIFY_END - $MODIFY_START" | bc)
echo "Modify duration: ${MODIFY_DURATION}s"
echo ""

# Step 3: Import modified workflow back (this will create new workflow)
echo "Step 3: Import modified workflow"
IMPORT_START=$(date +%s.%N)

# Copy modified file to container
docker cp "$TEMP_DIR/modified.json" "$CONTAINER_NAME:/tmp/modified.json"

# Import the modified workflow
IMPORT_RESULT=$(docker exec "$CONTAINER_NAME" n8n import:workflow \
    --input="/tmp/modified.json" 2>&1)

IMPORT_END=$(date +%s.%N)
IMPORT_DURATION=$(echo "$IMPORT_END - $IMPORT_START" | bc)

echo "Import duration: ${IMPORT_DURATION}s"
echo "Import result: $IMPORT_RESULT"

# Clean up container temp file
docker exec "$CONTAINER_NAME" rm -f "/tmp/modified.json"

# Step 4: Check what happened
echo ""
echo "Step 4: Verify results"

# Check if original workflow still exists
ORIGINAL_NAME=$(curl -s -H "X-N8N-API-KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJlZWU0ZGZiNC0yNWZkLTQ4NjItOTg1Yi1mMjU0OTU3ZmFjMGIiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzU2NjEyMTEzfQ.G4qJ7wf3IfRMVOungfYmF01Fu06_JrgKuuqHdUHYQQU" \
    "http://localhost:5678/api/v1/workflows/$WORKFLOW_ID" | jq -r '.name' 2>/dev/null || echo "unknown")

echo "Original workflow ($WORKFLOW_ID): $ORIGINAL_NAME"

# List recent workflows to see if new one was created
echo ""
echo "Recent workflows:"
curl -s -H "X-N8N-API-KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJlZWU0ZGZiNC0yNWZkLTQ4NjItOTg1Yi1mMjU0OTU3ZmFjMGIiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzU2NjEyMTEzfQ.G4qJ7wf3IfRMVOungfYmF01Fu06_JrgKuuqHdUHYQQU" \
    "http://localhost:5678/api/v1/workflows?limit=3" | jq -r '.data[] | "\(.id): \(.name)"' 2>/dev/null || echo "Failed to get workflows"

# Calculate total CLI time
TOTAL_END=$(date +%s.%N)
TOTAL_DURATION=$(echo "$TOTAL_END - $START_TIME" | bc)

echo ""
echo "====================================="
echo "CLI Update Summary"
echo "====================================="
echo "Export time:    ${EXPORT_DURATION}s"
echo "Modify time:    ${MODIFY_DURATION}s"
echo "Import time:    ${IMPORT_DURATION}s"
echo "Total time:     ${TOTAL_DURATION}s"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"

echo "Note: CLI import creates NEW workflows, doesn't update existing ones"
echo "For true updates, API is the only method that modifies existing workflows in-place"