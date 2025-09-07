/**
 * Workflow Activation Handlers
 * Extracted from src/mcp/handlers-n8n-manager.ts (hyly customizations)
 */

import { McpToolResponse } from '../../../src/types/mcp';
import { N8nApiError } from '../../../src/services/n8n-api-client';
import { getN8nApiClient, getUserFriendlyErrorMessage } from '../../../src/mcp/handlers-n8n-manager';

export async function handleActivateWorkflow(args: any): Promise<McpToolResponse> {
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

    const workflow = await client.activateWorkflow(id);
    
    return {
      success: true,
      data: workflow,
      message: `Workflow "${workflow.name}" activated successfully`
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

export async function handleDeactivateWorkflow(args: any): Promise<McpToolResponse> {
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

    const workflow = await client.deactivateWorkflow(id);
    
    return {
      success: true,
      data: workflow,
      message: `Workflow "${workflow.name}" deactivated successfully`
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