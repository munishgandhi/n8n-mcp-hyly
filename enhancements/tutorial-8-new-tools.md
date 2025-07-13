# Tutorial: Using the 8 New Enhanced MCP Tools

This tutorial covers the 8 new MCP tools that enhance n8n workflow management by adding activation functionality, forward walk debugging, and SQLite-equivalent database operations.

## Prerequisites

- Enhanced n8n-MCP server running with the new tools
- n8n instance with API access configured
- Basic understanding of n8n workflows and executions

## Tool Categories

### 🔄 **Workflow Activation Tools (2 tools)**
Replace direct API calls with proper MCP tools for workflow activation management.

### 🔍 **Forward Walk Debugging Tools (3 tools)**  
Advanced execution analysis that replaces manual SQLite database queries.

### 📊 **SQLite-Equivalent Database Tools (3 tools)**
System visibility and monitoring tools that provide database-level insights.

---

## Workflow Activation Tools

### 1. `n8n_activate_workflow` - Activate a Workflow

**Purpose**: Activate a workflow to enable triggers and webhooks using the dedicated n8n activation endpoint.

**Before (Manual API)**:
```bash
curl -X POST "http://localhost:5678/api/v1/workflows/{id}/activate" \
  -H "X-N8N-API-KEY: your-api-key"
```

**Now (MCP Tool)**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "n8n_activate_workflow",
    "arguments": {
      "id": "workflow-id-here"
    }
  },
  "id": 1
}
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "id": "workflow-123",
    "name": "My Webhook Workflow",
    "active": true,
    "triggerCount": 2
  },
  "message": "Workflow 'My Webhook Workflow' activated successfully"
}
```

**Use Cases**:
- Activate workflows after creation or modification
- Enable webhook endpoints for testing
- Programmatic workflow lifecycle management

### 2. `n8n_deactivate_workflow` - Deactivate a Workflow

**Purpose**: Deactivate a workflow to disable triggers and webhooks.

**Usage**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "n8n_deactivate_workflow",
    "arguments": {
      "id": "workflow-id-here"
    }
  },
  "id": 1
}
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "id": "workflow-123",
    "name": "My Webhook Workflow",
    "active": false
  },
  "message": "Workflow 'My Webhook Workflow' deactivated successfully"
}
```

---

## Forward Walk Debugging Tools

### 3. `n8n_get_execution_data` - Get Detailed Execution Data

**Purpose**: Retrieve comprehensive execution data with full node outputs, replacing manual SQLite queries.

**Before (SQLite Query)**:
```sql
SELECT data FROM execution_entity WHERE id = 'execution-123';
-- Then manually parse JSON runData
```

**Now (MCP Tool)**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "n8n_get_execution_data",
    "arguments": {
      "id": "execution-123",
      "includeData": true
    }
  },
  "id": 1
}
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "id": "execution-123",
    "workflowId": "workflow-456",
    "status": "success",
    "startedAt": "2025-07-13T10:30:00.000Z",
    "stoppedAt": "2025-07-13T10:30:02.150Z",
    "runData": {
      "webhook-node": [
        {
          "data": {
            "main": [
              [
                {
                  "json": {
                    "headers": {"x-test": "value"},
                    "body": {"message": "test"}
                  }
                }
              ]
            ]
          },
          "source": [null]
        }
      ]
    }
  }
}
```

### 4. `n8n_analyze_execution_path` - Analyze Execution Flow

**Purpose**: Perform node-by-node execution analysis with data flow tracking.

**Usage**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "n8n_analyze_execution_path",
    "arguments": {
      "id": "execution-123",
      "nodeId": "webhook-node"  // optional: focus on specific node
    }
  },
  "id": 1
}
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "executionId": "execution-123",
    "executionPath": [
      {
        "nodeId": "webhook-node",
        "nodeName": "Webhook Trigger",
        "order": 1,
        "status": "success",
        "executionTime": 45,
        "inputData": [],
        "outputData": [
          {
            "json": {"message": "webhook received"}
          }
        ]
      },
      {
        "nodeId": "process-node",
        "nodeName": "Process Data",
        "order": 2,
        "status": "success", 
        "executionTime": 120,
        "inputData": [
          {
            "json": {"message": "webhook received"}
          }
        ],
        "outputData": [
          {
            "json": {"processed": true, "timestamp": "2025-07-13T10:30:01.000Z"}
          }
        ]
      }
    ],
    "summary": {
      "totalNodes": 2,
      "successfulNodes": 2,
      "failedNodes": 0,
      "totalExecutionTime": 165
    }
  }
}
```

### 5. `n8n_get_node_output` - Extract Specific Node Output

**Purpose**: Get specific node output data from an execution.

**Usage**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "n8n_get_node_output",
    "arguments": {
      "executionId": "execution-123",
      "nodeId": "webhook-node",
      "outputIndex": 0  // optional, defaults to 0
    }
  },
  "id": 1
}
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "nodeId": "webhook-node",
    "nodeName": "Webhook Trigger",
    "outputIndex": 0,
    "data": [
      {
        "json": {
          "headers": {
            "content-type": "application/json",
            "x-forwarded-for": "127.0.0.1"
          },
          "body": {
            "message": "test webhook",
            "timestamp": "2025-07-13T10:30:00.000Z"
          },
          "query": {},
          "params": {}
        }
      }
    ]
  }
}
```

---

## SQLite-Equivalent Database Tools

### 6. `n8n_get_workflow_status` - Get Detailed Workflow Status

**Purpose**: Get comprehensive workflow status including activation state and webhook registrations.

**Before (Multiple SQLite Queries)**:
```sql
SELECT * FROM workflow_entity WHERE id = 'workflow-123';
SELECT COUNT(*) FROM execution_entity WHERE workflowId = 'workflow-123';
-- Manual webhook URL construction
```

**Now (MCP Tool)**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call",
  "params": {
    "name": "n8n_get_workflow_status",
    "arguments": {
      "id": "workflow-123"
    }
  },
  "id": 1
}
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "id": "workflow-123",
    "name": "Customer Webhook Processor",
    "active": true,
    "triggerCount": 1,
    "nodeCount": 5,
    "createdAt": "2025-07-10T15:30:00.000Z",
    "updatedAt": "2025-07-13T09:15:00.000Z",
    "recentExecutions": {
      "total": 47,
      "last24h": 12,
      "successRate": 0.96
    },
    "webhooks": [
      {
        "nodeId": "webhook-trigger",
        "method": "POST",
        "path": "customer-webhook",
        "url": "http://localhost:5678/webhook/customer-webhook"
      }
    ]
  }
}
```

### 7. `n8n_list_webhook_registrations` - List All Webhook Registrations

**Purpose**: Get complete webhook registry with URLs and associated workflows.

**Usage**:
```json
{
  "jsonrpc": "2.0", 
  "method": "tools/call",
  "params": {
    "name": "n8n_list_webhook_registrations",
    "arguments": {
      "workflowId": "workflow-123"  // optional: filter by workflow
    }
  },
  "id": 1
}
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "webhooks": [
      {
        "workflowId": "workflow-123",
        "workflowName": "Customer Processor",
        "nodeId": "webhook-trigger",
        "nodeName": "Customer Webhook",
        "method": "POST",
        "path": "customer-webhook",
        "fullUrl": "http://localhost:5678/webhook/customer-webhook",
        "active": true,
        "lastTriggered": "2025-07-13T10:30:00.000Z"
      },
      {
        "workflowId": "workflow-456", 
        "workflowName": "Order Processor",
        "nodeId": "order-webhook",
        "nodeName": "Order Webhook",
        "method": "POST",
        "path": "orders",
        "fullUrl": "http://localhost:5678/webhook/orders",
        "active": true,
        "lastTriggered": "2025-07-13T09:45:00.000Z"
      }
    ],
    "summary": {
      "totalWebhooks": 2,
      "activeWebhooks": 2,
      "inactiveWebhooks": 0
    }
  }
}
```

### 8. `n8n_get_database_stats` - Get Database Statistics

**Purpose**: Get comprehensive database statistics including execution counts, workflow metrics, and system health.

**Usage**:
```json
{
  "jsonrpc": "2.0",
  "method": "tools/call", 
  "params": {
    "name": "n8n_get_database_stats",
    "arguments": {
      "includeExecutions": true,
      "includeWorkflows": true
    }
  },
  "id": 1
}
```

**Example Response**:
```json
{
  "success": true,
  "data": {
    "workflows": {
      "total": 15,
      "active": 8,
      "inactive": 7,
      "withWebhooks": 5
    },
    "executions": {
      "total": 1847,
      "last24h": 156,
      "last7days": 982,
      "successRate": 0.94,
      "avgExecutionTime": 1250,
      "byStatus": {
        "success": 1736,
        "error": 89,
        "waiting": 22
      }
    },
    "performance": {
      "avgExecutionTime": 1250,
      "medianExecutionTime": 890,
      "slowestExecution": {
        "id": "exec-slow-123",
        "duration": 15670,
        "workflowName": "Heavy Data Processor"
      }
    },
    "system": {
      "databaseSize": "45.2 MB",
      "oldestExecution": "2025-06-15T10:00:00.000Z",
      "newestExecution": "2025-07-13T10:30:00.000Z"
    }
  }
}
```

---

## Integration Patterns

### 1. Workflow Lifecycle Management

```javascript
// Complete workflow activation workflow
async function activateAndTest(workflowId) {
  // 1. Check current status
  const status = await mcpCall('n8n_get_workflow_status', {id: workflowId});
  
  // 2. Activate if needed
  if (!status.data.active) {
    await mcpCall('n8n_activate_workflow', {id: workflowId});
  }
  
  // 3. Get webhook URLs for testing
  const webhooks = await mcpCall('n8n_list_webhook_registrations', {workflowId});
  
  return webhooks.data.webhooks;
}
```

### 2. Execution Debugging Workflow

```javascript
// Complete execution analysis workflow
async function debugExecution(executionId) {
  // 1. Get full execution data
  const execution = await mcpCall('n8n_get_execution_data', {
    id: executionId, 
    includeData: true
  });
  
  // 2. Analyze execution path
  const analysis = await mcpCall('n8n_analyze_execution_path', {
    id: executionId
  });
  
  // 3. Extract specific node outputs if needed
  const nodeOutput = await mcpCall('n8n_get_node_output', {
    executionId: executionId,
    nodeId: 'problem-node'
  });
  
  return {execution, analysis, nodeOutput};
}
```

### 3. System Monitoring

```javascript
// System health monitoring
async function systemHealthCheck() {
  // 1. Get database statistics
  const stats = await mcpCall('n8n_get_database_stats', {
    includeExecutions: true,
    includeWorkflows: true
  });
  
  // 2. Check webhook registrations
  const webhooks = await mcpCall('n8n_list_webhook_registrations', {});
  
  // 3. Alert on issues
  if (stats.data.executions.successRate < 0.9) {
    console.warn('Low success rate detected:', stats.data.executions.successRate);
  }
  
  return {stats, webhooks};
}
```

---

## Error Handling

All tools return standardized error responses:

```json
{
  "success": false,
  "error": "Description of what went wrong",
  "code": "ERROR_CODE", 
  "details": {
    "additionalInfo": "value"
  }
}
```

Common error codes:
- `AUTHENTICATION_ERROR` - n8n API key issues
- `NOT_FOUND` - Workflow/execution doesn't exist
- `VALIDATION_ERROR` - Invalid parameters
- `API_ERROR` - n8n API communication issues

---

## Best Practices

### 1. **Always Check Status First**
Before activating workflows, check current status to avoid unnecessary API calls.

### 2. **Use Execution Analysis for Debugging**
Replace manual SQLite queries with `n8n_analyze_execution_path` for better structured debugging.

### 3. **Monitor System Health**
Use `n8n_get_database_stats` regularly to monitor system performance and execution success rates.

### 4. **Batch Operations**
When working with multiple workflows, batch status checks before making changes.

### 5. **Error Handling**
Always handle authentication errors gracefully and provide fallback mechanisms.

---

## Migration from Direct API/SQLite

### From Direct API Calls:
```bash
# OLD
curl -X POST "http://localhost:5678/api/v1/workflows/{id}/activate" \
  -H "X-N8N-API-KEY: key"

# NEW 
mcpCall('n8n_activate_workflow', {id: 'workflow-id'})
```

### From SQLite Queries:
```sql
-- OLD
SELECT data FROM execution_entity WHERE id = 'exec-123';

-- NEW
mcpCall('n8n_get_execution_data', {id: 'exec-123', includeData: true})
```

These new tools provide a complete replacement for manual n8n management operations while offering better error handling, structured responses, and integration with the MCP ecosystem.