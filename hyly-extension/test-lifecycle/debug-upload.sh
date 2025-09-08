#!/bin/bash
# debug-upload.sh - Debug the upload issue

cd /home/mg/src/n8n-mcp-hyly/hyly-extension/test-lifecycle

# Load the workflow
WORKFLOW_JSON=$(cat "20250907-204253-KQxYbOJgGEEuzVT0-01-edited.json")

echo "=== Original workflow keys ==="
echo "$WORKFLOW_JSON" | jq 'keys'

echo ""
echo "=== Prepared for upload (cleaned) ==="
CLEANED=$(echo "$WORKFLOW_JSON" | jq '{
    name: .name,
    nodes: .nodes,
    connections: .connections,
    settings: .settings,
    staticData: .staticData,
    pinData: (.pinData // {})
}')

echo "$CLEANED" | jq 'keys'

echo ""
echo "=== Our successful manual test used ==="
cat << 'EOF' | jq 'keys'
{
  "name": "TEST UPLOAD",
  "nodes": [
    {
      "parameters": {},
      "id": "manual-trigger",
      "name": "Manual Trigger",
      "type": "n8n-nodes-base.manualTrigger",
      "typeVersion": 1,
      "position": [256, 256]
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

echo ""
echo "=== Test with minimal structure ==="
MINIMAL=$(echo "$WORKFLOW_JSON" | jq '{
    name: .name,
    nodes: .nodes,
    connections: .connections,
    settings: .settings
}')

echo "Testing API call with minimal structure..."
API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJlZWU0ZGZiNC0yNWZkLTQ4NjItOTg1Yi1mMjU0OTU3ZmFjMGIiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwiaWF0IjoxNzU2NjEyMTEzfQ.G4qJ7wf3IfRMVOungfYmF01Fu06_JrgKuuqHdUHYQQU"

RESULT=$(curl -s "http://localhost:5678/api/v1/workflows/KQxYbOJgGEEuzVT0" \
    -X PUT \
    -H "Content-Type: application/json" \
    -H "X-N8N-API-KEY: $API_KEY" \
    -d "$MINIMAL" 2>/dev/null)

echo "Result: $RESULT"