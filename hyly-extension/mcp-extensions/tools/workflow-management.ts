/**
 * Workflow Management Tool Definitions
 * Extracted from src/mcp/tools-n8n-manager.ts (hyly customizations)
 */

import { ToolDefinition } from '../../../src/types/mcp';

export const workflowManagementTools: ToolDefinition[] = [
  // Workflow Activation Tools
  {
    name: 'n8n_activate_workflow',
    description: `Activate workflow to enable triggers and webhooks. Uses dedicated activation endpoint.`,
    inputSchema: {
      type: 'object',
      properties: {
        id: {
          type: 'string',
          description: 'Workflow ID to activate'
        }
      },
      required: ['id']
    }
  },
  {
    name: 'n8n_deactivate_workflow', 
    description: `Deactivate workflow to disable triggers and webhooks.`,
    inputSchema: {
      type: 'object',
      properties: {
        id: {
          type: 'string',
          description: 'Workflow ID to deactivate'
        }
      },
      required: ['id']
    }
  },

  // Enhanced Execution Analysis Tools  
  {
    name: 'n8n_get_execution_data',
    description: `Get detailed execution data with full node outputs and forward walk analysis.`,
    inputSchema: {
      type: 'object',
      properties: {
        id: {
          type: 'string',
          description: 'Execution ID to analyze'
        },
        includeData: {
          type: 'boolean',
          description: 'Include full execution data (default: true)',
          default: true
        }
      },
      required: ['id']
    }
  },
  {
    name: 'n8n_analyze_execution_path',
    description: `Analyze execution path and flow for debugging workflow logic.`,
    inputSchema: {
      type: 'object',
      properties: {
        id: {
          type: 'string',
          description: 'Execution ID to analyze'
        }
      },
      required: ['id']
    }
  },
  {
    name: 'n8n_get_node_output',
    description: `Get specific node output from execution for detailed analysis.`,
    inputSchema: {
      type: 'object',
      properties: {
        executionId: {
          type: 'string',
          description: 'Execution ID containing the node'
        },
        nodeId: {
          type: 'string',
          description: 'Node ID to get output from'
        },
        outputIndex: {
          type: 'number',
          description: 'Output index (default: 0)',
          default: 0
        }
      },
      required: ['executionId', 'nodeId']
    }
  },

  // Status and Debugging Tools
  {
    name: 'n8n_get_workflow_status',
    description: `Get comprehensive workflow status including activation state and recent executions.`,
    inputSchema: {
      type: 'object',
      properties: {
        id: {
          type: 'string',
          description: 'Workflow ID to check status'
        }
      },
      required: ['id']
    }
  },
  {
    name: 'n8n_list_webhook_registrations',
    description: `List webhook registrations for workflows to debug trigger issues.`,
    inputSchema: {
      type: 'object',
      properties: {
        workflowId: {
          type: 'string',
          description: 'Optional workflow ID to filter registrations'
        }
      }
    }
  },
  {
    name: 'n8n_get_database_stats',
    description: `Get database statistics for performance analysis and debugging.`,
    inputSchema: {
      type: 'object',
      properties: {
        includeExecutions: {
          type: 'boolean',
          description: 'Include execution statistics (default: true)',
          default: true
        },
        includeWorkflows: {
          type: 'boolean',
          description: 'Include workflow statistics (default: true)',
          default: true
        }
      }
    }
  }
];