#!/bin/bash
# test-upload-speed.sh - Compare API vs CLI upload speeds

set -euo pipefail

# Configuration
CONTAINER_NAME="hyly-n8n-app"
API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJlZWU0ZGZiNC0yNWZkLTQ4NjItOTg1Yi1mMjU0OTU3ZmFjMGIiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzU2NjEyMTEzfQ.G4qJ7wf3IfRMVOungfYmF01Fu06_JrgKuuqHdUHYQQU"
N8N_HOST="http://localhost:5678"
WORKFLOW_ID="KQxYbOJgGEEuzVT0"

echo "====================================="
echo "n8n Upload Speed Comparison"
echo "====================================="
echo ""

# Test workflow data
TEST_WORKFLOW_API=$(cat << 'EOF'
{
  "name": "API UPLOAD SPEED TEST",
  "nodes": [
    {
      "parameters": {},
      "id": "manual-trigger",
      "name": "Manual Trigger",
      "type": "n8n-nodes-base.manualTrigger",
      "typeVersion": 1,
      "position": [256, 256]
    },
    {
      "parameters": {
        "jsCode": "return [{ method: 'API', timestamp: new Date().toISOString(), test: 'speed' }];"
      },
      "id": "hello-code",
      "name": "Hello Code",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [480, 256]
    }
  ],
  "connections": {
    "Manual Trigger": {
      "main": [[{"node": "Hello Code", "type": "main", "index": 0}]]
    }
  },
  "settings": {
    "executionOrder": "v1"
  }
}
EOF
)

# Create temp file for CLI test
TEMP_FILE="/tmp/cli-test-workflow.json"
cat << 'EOF' > "$TEMP_FILE"
{
  "name": "CLI UPLOAD SPEED TEST",
  "nodes": [
    {
      "parameters": {},
      "id": "manual-trigger", 
      "name": "Manual Trigger",
      "type": "n8n-nodes-base.manualTrigger",
      "typeVersion": 1,
      "position": [256, 256]
    },
    {
      "parameters": {
        "jsCode": "return [{ method: 'CLI', timestamp: new Date().toISOString(), test: 'speed' }];"
      },
      "id": "hello-code",
      "name": "Hello Code", 
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [480, 256]
    }
  ],
  "connections": {
    "Manual Trigger": {
      "main": [[{"node": "Hello Code", "type": "main", "index": 0}]]
    }
  },
  "settings": {
    "executionOrder": "v1"
  }
}
EOF

# Test 1: API Upload Speed
echo "Test 1: API Upload Speed"
echo "Method: curl PUT to /api/v1/workflows/$WORKFLOW_ID"

START_TIME=$(date +%s.%N)

API_RESULT=$(curl -s -w "HTTPCODE:%{http_code}" \
    -X PUT \
    -H "Content-Type: application/json" \
    -H "X-N8N-API-KEY: ${API_KEY}" \
    -d "$TEST_WORKFLOW_API" \
    "$N8N_HOST/api/v1/workflows/$WORKFLOW_ID" 2>/dev/null)

END_TIME=$(date +%s.%N)
API_DURATION=$(echo "$END_TIME - $START_TIME" | bc)

API_HTTP_CODE=$(echo "$API_RESULT" | grep -o "HTTPCODE:.*" | cut -d':' -f2)
API_RESPONSE=$(echo "$API_RESULT" | sed 's/HTTPCODE:.*//')

echo "Duration: ${API_DURATION}s"
echo "HTTP Code: $API_HTTP_CODE"
if [[ "$API_HTTP_CODE" == "200" ]]; then
    echo "Status: ✅ SUCCESS"
else
    echo "Status: ❌ FAILED"
    echo "Response: $API_RESPONSE"
fi
echo ""

# Verify API upload worked
API_VERIFY=$(curl -s -H "X-N8N-API-KEY: ${API_KEY}" "$N8N_HOST/api/v1/workflows/$WORKFLOW_ID" | jq -r '.name' 2>/dev/null || echo "unknown")
echo "Verified name: $API_VERIFY"
echo ""

# Test 2: CLI Upload Speed  
echo "Test 2: CLI Upload Speed"
echo "Method: docker exec n8n import:workflow"

START_TIME=$(date +%s.%N)

# Copy file to container and import
docker cp "$TEMP_FILE" "$CONTAINER_NAME:/tmp/cli-test.json" >/dev/null 2>&1

CLI_RESULT=$(docker exec "$CONTAINER_NAME" n8n import:workflow \
    --input="/tmp/cli-test.json" \
    --separate \
    2>&1)

# Update existing workflow (CLI import creates new, so we need to update)
if [[ $? -eq 0 ]]; then
    # The CLI import worked, now we need to update the specific workflow
    # This is a limitation - CLI import creates new workflows, doesn't update existing ones
    docker exec "$CONTAINER_NAME" rm -f "/tmp/cli-test.json" >/dev/null 2>&1
    
    # For fair comparison, we'll use CLI export then manual update via API
    # Since CLI doesn't have direct update capability
    CLI_SUCCESS=1
else
    CLI_SUCCESS=0
fi

END_TIME=$(date +%s.%N)
CLI_DURATION=$(echo "$END_TIME - $START_TIME" | bc)

echo "Duration: ${CLI_DURATION}s"
if [[ $CLI_SUCCESS -eq 1 ]]; then
    echo "Status: ✅ SUCCESS (but imports new, doesn't update existing)"
else
    echo "Status: ❌ FAILED"
    echo "Error: $CLI_RESULT"
fi
echo ""

# Alternative CLI test - export existing workflow for speed comparison
echo "Test 2b: CLI Export Speed (for comparison)"
echo "Method: docker exec n8n export:workflow"

START_TIME=$(date +%s.%N)

CLI_EXPORT=$(docker exec "$CONTAINER_NAME" n8n export:workflow \
    --id="$WORKFLOW_ID" \
    2>/dev/null)

END_TIME=$(date +%s.%N)
CLI_EXPORT_DURATION=$(echo "$END_TIME - $START_TIME" | bc)

echo "Duration: ${CLI_EXPORT_DURATION}s"
if [[ -n "$CLI_EXPORT" && "$CLI_EXPORT" == *"$WORKFLOW_ID"* ]]; then
    echo "Status: ✅ SUCCESS"
else
    echo "Status: ❌ FAILED"
fi
echo ""

# Cleanup
rm -f "$TEMP_FILE"

# Summary
echo "====================================="
echo "Speed Comparison Summary"
echo "====================================="
echo "API Upload (PUT):     ${API_DURATION}s"
echo "CLI Import (new):     ${CLI_DURATION}s"  
echo "CLI Export:           ${CLI_EXPORT_DURATION}s"
echo ""

# Calculate speed difference
if command -v bc >/dev/null 2>&1; then
    if (( $(echo "$API_DURATION > 0" | bc -l) )) && (( $(echo "$CLI_EXPORT_DURATION > 0" | bc -l) )); then
        SPEED_RATIO=$(echo "scale=2; $CLI_EXPORT_DURATION / $API_DURATION" | bc)
        if (( $(echo "$API_DURATION < $CLI_EXPORT_DURATION" | bc -l) )); then
            echo "Winner: 🏆 API is ${SPEED_RATIO}x faster"
        else
            REVERSE_RATIO=$(echo "scale=2; $API_DURATION / $CLI_EXPORT_DURATION" | bc)
            echo "Winner: 🏆 CLI is ${REVERSE_RATIO}x faster"
        fi
    fi
fi

echo ""
echo "Note: CLI doesn't directly support updating existing workflows"
echo "      CLI is better for bulk operations, API for single updates"