#!/bin/bash
# test-n8n-upload.sh - Test n8n API upload following the working pattern

set -euo pipefail

# Configuration (following hyly-n8n-app-api.sh pattern)
CONTAINER_NAME="hyly-n8n-app"
HOST_PORT=5678
API_KEY="${N8N_API_KEY:-}"

# Get API key from vc-mgr if not set
if [[ -z "$API_KEY" ]]; then
    API_KEY=$(grep N8N_API_KEY /home/mg/src/vc-mgr/.env 2>/dev/null | cut -d'=' -f2 || echo '')
fi

if [[ -z "$API_KEY" ]]; then
    echo "❌ ERROR: No API key found"
    exit 1
fi

echo "====================================="
echo "n8n API Upload Test"
echo "====================================="
echo ""

# Test 1: Health Check (following exact pattern from hyly-n8n-app-api.sh)
echo "Test 1: Health Endpoint"
echo "Expected: 200"
HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${HOST_PORT}/healthz 2>/dev/null || echo "000")
echo "Actual: $HEALTH_CODE"
if [[ "$HEALTH_CODE" == "200" ]]; then
    echo "Status: ✅ PASS"
else
    echo "Status: ❌ FAIL"
    exit 1
fi
echo ""

# Test 2: API Authentication Test (following exact pattern)
echo "Test 2: API Authentication"
echo "Expected: 401 without key"
UNAUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${HOST_PORT}/api/v1/workflows 2>/dev/null || echo "000")
echo "Actual: $UNAUTH_CODE"
if [[ "$UNAUTH_CODE" == "401" ]]; then
    echo "Status: ✅ PASS - Auth required"
else
    echo "Status: ❌ FAIL - Auth not required"
fi
echo ""

# Test 3: GET Workflow (following exact pattern from hyly-n8n-app-api.sh)
echo "Test 3: GET Workflow KQxYbOJgGEEuzVT0"
echo "Expected: 200"
WORKFLOW_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-N8N-API-KEY: ${API_KEY}" http://localhost:${HOST_PORT}/api/v1/workflows/KQxYbOJgGEEuzVT0 2>/dev/null || echo "000")
echo "Actual: $WORKFLOW_CODE"
if [[ "$WORKFLOW_CODE" == "200" ]]; then
    echo "Status: ✅ PASS"
    
    # Get current workflow name
    CURRENT_NAME=$(curl -s -H "X-N8N-API-KEY: ${API_KEY}" http://localhost:${HOST_PORT}/api/v1/workflows/KQxYbOJgGEEuzVT0 2>/dev/null | jq -r '.name' || echo "unknown")
    echo "Current name: $CURRENT_NAME"
    
else
    echo "Status: ❌ FAIL"
    exit 1
fi
echo ""

# Test 4: PUT Workflow Update (the actual upload test)
echo "Test 4: PUT Workflow Update"
echo "Expected: 200"

# Create test workflow data (minimal update - just change name)
TEST_WORKFLOW=$(cat << 'EOF'
{
  "name": "TEST UPLOAD v20250907-214500",
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
        "jsCode": "return [{ message: 'Test Upload Success', timestamp: new Date().toISOString() }];"
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

# Make PUT request (following curl pattern from working scripts)
PUT_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X PUT \
    -H "Content-Type: application/json" \
    -H "X-N8N-API-KEY: ${API_KEY}" \
    -d "$TEST_WORKFLOW" \
    http://localhost:${HOST_PORT}/api/v1/workflows/KQxYbOJgGEEuzVT0 2>/dev/null || echo "000")

echo "Actual: $PUT_CODE"
if [[ "$PUT_CODE" == "200" ]]; then
    echo "Status: ✅ PASS - Upload successful"
    
    # Verify the update worked
    echo ""
    echo "Verification: Checking updated workflow name"
    UPDATED_NAME=$(curl -s -H "X-N8N-API-KEY: ${API_KEY}" http://localhost:${HOST_PORT}/api/v1/workflows/KQxYbOJgGEEuzVT0 2>/dev/null | jq -r '.name' || echo "unknown")
    echo "Updated name: $UPDATED_NAME"
    
    if [[ "$UPDATED_NAME" == "TEST UPLOAD v20250907-214500" ]]; then
        echo "Verification: ✅ PASS - Name updated correctly"
    else
        echo "Verification: ❌ FAIL - Name not updated"
    fi
    
else
    echo "Status: ❌ FAIL - Upload failed"
    
    # Get error response
    ERROR_RESPONSE=$(curl -s \
        -X PUT \
        -H "Content-Type: application/json" \
        -H "X-N8N-API-KEY: ${API_KEY}" \
        -d "$TEST_WORKFLOW" \
        http://localhost:${HOST_PORT}/api/v1/workflows/KQxYbOJgGEEuzVT0 2>/dev/null || echo "curl failed")
    echo "Error response: $ERROR_RESPONSE"
fi
echo ""

echo "====================================="
echo "Test Complete"
echo "====================================="