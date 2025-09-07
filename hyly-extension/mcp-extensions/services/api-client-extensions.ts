/**
 * N8n API Client Extensions
 * Extracted from src/services/n8n-api-client.ts (hyly customizations)
 * 
 * These are new methods added to the N8nApiClient class for enhanced workflow management
 */

import { Workflow } from '../../../src/types/n8n-api';
import { N8nApiError, handleN8nApiError } from '../../../src/services/n8n-api-client';

export class N8nApiClientExtensions {
  private client: any; // Will be the axios instance from N8nApiClient
  
  constructor(client: any) {
    this.client = client;
  }

  // Workflow Activation Methods
  async activateWorkflow(id: string): Promise<Workflow> {
    try {
      const response = await this.client.post(`/workflows/${id}/activate`);
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async deactivateWorkflow(id: string): Promise<Workflow> {
    try {
      const response = await this.client.post(`/workflows/${id}/deactivate`);
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  // Enhanced Execution Analysis Methods
  async getExecutionData(id: string, includeData = true): Promise<any> {
    try {
      const response = await this.client.get(`/executions/${id}`, {
        params: { includeData }
      });
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async analyzeExecutionPath(id: string): Promise<any> {
    try {
      // Get full execution data
      const execution = await this.getExecutionData(id, true);
      
      if (!execution.data) {
        return {
          executionId: id,
          error: 'No execution data available',
          analysis: null
        };
      }

      const runData = execution.data.resultData?.runData;
      if (!runData) {
        return {
          executionId: id,
          error: 'No run data available',
          analysis: null
        };
      }

      // Analyze execution path
      const nodeNames = Object.keys(runData);
      const pathAnalysis = {
        executionId: id,
        totalNodes: nodeNames.length,
        executedNodes: nodeNames,
        nodeExecutionOrder: [],
        nodeStatuses: {},
        executionFlow: []
      };

      // Build execution flow
      for (const nodeName of nodeNames) {
        const nodeData = runData[nodeName];
        if (nodeData && nodeData.length > 0) {
          const nodeRun = nodeData[0];
          pathAnalysis.nodeStatuses[nodeName] = {
            status: nodeRun.executionStatus || 'unknown',
            startTime: nodeRun.startTime,
            executionTime: nodeRun.executionTime,
            dataCount: nodeRun.data?.main?.[0]?.length || 0
          };
        }
      }

      return pathAnalysis;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async getNodeOutput(executionId: string, nodeId: string, outputIndex = 0): Promise<any> {
    try {
      const execution = await this.getExecutionData(executionId, true);
      const runData = execution.data?.resultData?.runData;
      
      if (!runData || !runData[nodeId]) {
        return {
          error: `Node '${nodeId}' not found in execution ${executionId}`,
          nodeId,
          executionId,
          output: null
        };
      }

      const nodeData = runData[nodeId];
      if (!nodeData || nodeData.length === 0) {
        return {
          error: `No execution data for node '${nodeId}'`,
          nodeId,
          executionId,
          output: null
        };
      }

      const nodeRun = nodeData[0];
      const outputs = nodeRun.data?.main;
      
      if (!outputs || !outputs[outputIndex]) {
        return {
          error: `No output at index ${outputIndex} for node '${nodeId}'`,
          nodeId,
          executionId,
          outputIndex,
          availableOutputs: outputs?.length || 0,
          output: null
        };
      }

      return {
        nodeId,
        executionId,
        outputIndex,
        output: outputs[outputIndex],
        executionStatus: nodeRun.executionStatus,
        executionTime: nodeRun.executionTime
      };
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  // Status and Debugging Methods
  async getWorkflowStatus(id: string): Promise<any> {
    try {
      const workflow = await this.client.get(`/workflows/${id}`);
      
      // Get recent executions
      const executions = await this.client.get('/executions', {
        params: { workflowId: id, limit: 5 }
      });

      return {
        workflowId: id,
        name: workflow.data.name,
        active: workflow.data.active,
        nodes: workflow.data.nodes?.length || 0,
        recentExecutions: executions.data.data.map((exec: any) => ({
          id: exec.id,
          status: exec.status,
          startedAt: exec.startedAt,
          stoppedAt: exec.stoppedAt,
          mode: exec.mode
        }))
      };
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async listWebhookRegistrations(workflowId?: string): Promise<any> {
    try {
      const params = workflowId ? { workflowId } : {};
      const response = await this.client.get('/webhooks', { params });
      
      return {
        webhooks: response.data || [],
        count: response.data?.length || 0,
        filteredBy: workflowId ? `workflow ${workflowId}` : 'all workflows'
      };
    } catch (error) {
      // Webhook endpoint might not exist, return empty result
      return {
        webhooks: [],
        count: 0,
        error: 'Webhook registration endpoint not available',
        filteredBy: workflowId ? `workflow ${workflowId}` : 'all workflows'
      };
    }
  }

  async getDatabaseStats(includeExecutions = true, includeWorkflows = true): Promise<any> {
    try {
      const stats: any = {
        timestamp: new Date().toISOString(),
        includeExecutions,
        includeWorkflows
      };

      if (includeWorkflows) {
        const workflows = await this.client.get('/workflows', { params: { limit: 1 } });
        stats.workflows = {
          total: workflows.data.count || 0,
          active: 0 // Would need additional call to count active
        };
      }

      if (includeExecutions) {
        const executions = await this.client.get('/executions', { params: { limit: 1 } });
        stats.executions = {
          total: executions.data.count || 0,
          recent: 0 // Would need additional call for recent count
        };
      }

      return stats;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }
}