/**
 * Enhanced Execution Analysis Handlers
 * Extracted from src/mcp/handlers-n8n-manager.ts (hyly customizations)
 */

import { McpToolResponse } from '../../../src/types/mcp';
import { N8nApiError } from '../../../src/services/n8n-api-client';
import { getN8nApiClient, getUserFriendlyErrorMessage } from '../../../src/mcp/handlers-n8n-manager';

export async function handleGetExecutionData(args: any): Promise<McpToolResponse> {
  try {
    const client = getN8nApiClient();
    if (!client) {
      return {
        success: false,
        error: 'n8n API not configured. Please set N8N_API_URL and N8N_API_KEY environment variables.'
      };
    }

    const { id, includeData = true } = args;
    if (!id) {
      return {
        success: false,
        error: 'Execution ID is required'
      };
    }

    const executionData = await client.getExecutionData(id, includeData);
    
    return {
      success: true,
      data: executionData,
      message: `Execution data retrieved for execution ${id}`
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

export async function handleAnalyzeExecutionPath(args: any): Promise<McpToolResponse> {
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
        error: 'Execution ID is required'
      };
    }

    const pathAnalysis = await client.analyzeExecutionPath(id);
    
    return {
      success: true,
      data: pathAnalysis,
      message: `Execution path analyzed for execution ${id}`
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

export async function handleGetNodeOutput(args: any): Promise<McpToolResponse> {
  try {
    const client = getN8nApiClient();
    if (!client) {
      return {
        success: false,
        error: 'n8n API not configured. Please set N8N_API_URL and N8N_API_KEY environment variables.'
      };
    }

    const { executionId, nodeId, outputIndex = 0 } = args;
    if (!executionId || !nodeId) {
      return {
        success: false,
        error: 'Both executionId and nodeId are required'
      };
    }

    const nodeOutput = await client.getNodeOutput(executionId, nodeId, outputIndex);
    
    return {
      success: true,
      data: nodeOutput,
      message: `Node output retrieved for ${nodeId} in execution ${executionId}`
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