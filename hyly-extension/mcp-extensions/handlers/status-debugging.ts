/**
 * Status and Debugging Handlers
 * Extracted from src/mcp/handlers-n8n-manager.ts (hyly customizations)
 */

import { McpToolResponse } from '../../../src/types/mcp';
import { N8nApiError } from '../../../src/services/n8n-api-client';
import { getN8nApiClient, getUserFriendlyErrorMessage } from '../../../src/mcp/handlers-n8n-manager';

export async function handleGetWorkflowStatus(args: any): Promise<McpToolResponse> {
  try {
    const client = getN8nApiClient();
    if (!client) {
      return {
        success: false,
        error: 'n8n API not configured. Please set N8N_API_URL and N8N_API_KEY environment variables.'
      };
    }

    const { id } = args;
    if (!id) {
      return {
        success: false,
        error: 'Workflow ID is required'
      };
    }

    const status = await client.getWorkflowStatus(id);
    
    return {
      success: true,
      data: status,
      message: `Workflow status retrieved for ${id}`
    };
  } catch (error) {
    if (error instanceof N8nApiError) {
      return {
        success: false,
        error: getUserFriendlyErrorMessage(error),
        code: error.code
      };
    }
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
}

export async function handleListWebhookRegistrations(args: any): Promise<McpToolResponse> {
  try {
    const client = getN8nApiClient();
    if (!client) {
      return {
        success: false,
        error: 'n8n API not configured. Please set N8N_API_URL and N8N_API_KEY environment variables.'
      };
    }

    const { workflowId } = args;
    const registrations = await client.listWebhookRegistrations(workflowId);
    
    return {
      success: true,
      data: registrations,
      message: workflowId ? 
        `Webhook registrations for workflow ${workflowId}` :
        'All webhook registrations listed'
    };
  } catch (error) {
    if (error instanceof N8nApiError) {
      return {
        success: false,
        error: getUserFriendlyErrorMessage(error),
        code: error.code
      };
    }
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
}

export async function handleGetDatabaseStats(args: any): Promise<McpToolResponse> {
  try {
    const client = getN8nApiClient();
    if (!client) {
      return {
        success: false,
        error: 'n8n API not configured. Please set N8N_API_URL and N8N_API_KEY environment variables.'
      };
    }

    const { includeExecutions = true, includeWorkflows = true } = args;
    const stats = await client.getDatabaseStats(includeExecutions, includeWorkflows);
    
    return {
      success: true,
      data: stats,
      message: 'Database statistics retrieved'
    };
  } catch (error) {
    if (error instanceof N8nApiError) {
      return {
        success: false,
        error: getUserFriendlyErrorMessage(error),
        code: error.code
      };
    }
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error occurred'
    };
  }
}