import axios, { AxiosInstance, AxiosRequestConfig, InternalAxiosRequestConfig } from 'axios';
import { logger } from '../utils/logger';
import {
  Workflow,
  WorkflowListParams,
  WorkflowListResponse,
  Execution,
  ExecutionListParams,
  ExecutionListResponse,
  Credential,
  CredentialListParams,
  CredentialListResponse,
  Tag,
  TagListParams,
  TagListResponse,
  HealthCheckResponse,
  Variable,
  WebhookRequest,
  WorkflowExport,
  WorkflowImport,
  SourceControlStatus,
  SourceControlPullResult,
  SourceControlPushResult,
} from '../types/n8n-api';
import { handleN8nApiError, logN8nError } from '../utils/n8n-errors';
import { cleanWorkflowForCreate, cleanWorkflowForUpdate } from './n8n-validation';

export interface N8nApiClientConfig {
  baseUrl: string;
  apiKey: string;
  timeout?: number;
  maxRetries?: number;
}

export class N8nApiClient {
  private client: AxiosInstance;
  private maxRetries: number;

  constructor(config: N8nApiClientConfig) {
    const { baseUrl, apiKey, timeout = 30000, maxRetries = 3 } = config;

    this.maxRetries = maxRetries;

    // Ensure baseUrl ends with /api/v1
    const apiUrl = baseUrl.endsWith('/api/v1') 
      ? baseUrl 
      : `${baseUrl.replace(/\/$/, '')}/api/v1`;

    this.client = axios.create({
      baseURL: apiUrl,
      timeout,
      headers: {
        'X-N8N-API-KEY': apiKey,
        'Content-Type': 'application/json',
      },
    });

    // Request interceptor for logging
    this.client.interceptors.request.use(
      (config: InternalAxiosRequestConfig) => {
        logger.debug(`n8n API Request: ${config.method?.toUpperCase()} ${config.url}`, {
          params: config.params,
          data: config.data,
        });
        return config;
      },
      (error: unknown) => {
        logger.error('n8n API Request Error:', error);
        return Promise.reject(error);
      }
    );

    // Response interceptor for logging
    this.client.interceptors.response.use(
      (response: any) => {
        logger.debug(`n8n API Response: ${response.status} ${response.config.url}`);
        return response;
      },
      (error: unknown) => {
        const n8nError = handleN8nApiError(error);
        logN8nError(n8nError, 'n8n API Response');
        return Promise.reject(n8nError);
      }
    );
  }

  // Health check to verify API connectivity
  async healthCheck(): Promise<HealthCheckResponse> {
    try {
      // First try the health endpoint
      const response = await this.client.get('/health');
      return response.data;
    } catch (error) {
      // If health endpoint doesn't exist, try listing workflows with limit 1
      // This is a fallback for older n8n versions
      try {
        await this.client.get('/workflows', { params: { limit: 1 } });
        return { 
          status: 'ok',
          features: {} // We can't determine features without proper health endpoint
        };
      } catch (fallbackError) {
        throw handleN8nApiError(fallbackError);
      }
    }
  }

  // Workflow Management
  async createWorkflow(workflow: Partial<Workflow>): Promise<Workflow> {
    try {
      const cleanedWorkflow = cleanWorkflowForCreate(workflow);
      const response = await this.client.post('/workflows', cleanedWorkflow);
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async getWorkflow(id: string): Promise<Workflow> {
    try {
      const response = await this.client.get(`/workflows/${id}`);
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async updateWorkflow(id: string, workflow: Partial<Workflow>): Promise<Workflow> {
    try {
      // First, try PUT method (newer n8n versions)
      const cleanedWorkflow = cleanWorkflowForUpdate(workflow as Workflow);
      try {
        const response = await this.client.put(`/workflows/${id}`, cleanedWorkflow);
        return response.data;
      } catch (putError: any) {
        // If PUT fails with 405 (Method Not Allowed), try PATCH
        if (putError.response?.status === 405) {
          logger.debug('PUT method not supported, falling back to PATCH');
          const response = await this.client.patch(`/workflows/${id}`, cleanedWorkflow);
          return response.data;
        }
        throw putError;
      }
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async deleteWorkflow(id: string): Promise<void> {
    try {
      await this.client.delete(`/workflows/${id}`);
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

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

  async listWorkflows(params: WorkflowListParams = {}): Promise<WorkflowListResponse> {
    try {
      const response = await this.client.get('/workflows', { params });
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  // Execution Management
  async getExecution(id: string, includeData = false): Promise<Execution> {
    try {
      const response = await this.client.get(`/executions/${id}`, {
        params: { includeData },
      });
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async listExecutions(params: ExecutionListParams = {}): Promise<ExecutionListResponse> {
    try {
      const response = await this.client.get('/executions', { params });
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async deleteExecution(id: string): Promise<void> {
    try {
      await this.client.delete(`/executions/${id}`);
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

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
          success: false,
          error: 'Execution data not available'
        };
      }

      // Parse execution data structure for forward walk
      const executionData = JSON.parse(execution.data);
      let runDataIndex = -1;
      
      // Find runData index in the execution data array
      for (let i = 0; i < executionData.length; i++) {
        if (typeof executionData[i] === 'object' && executionData[i].runData) {
          runDataIndex = parseInt(executionData[i].runData);
          break;
        }
      }

      if (runDataIndex === -1) {
        return {
          success: false,
          error: 'RunData index not found in execution'
        };
      }

      const runData = executionData[runDataIndex];
      const executionPath = [];

      // Analyze each node execution
      for (const [nodeName, nodeExecution] of Object.entries(runData)) {
        if (Array.isArray(nodeExecution) && nodeExecution.length > 0) {
          const nodeData = nodeExecution[0];
          
          executionPath.push({
            nodeName,
            startTime: nodeData.startTime,
            executionTime: nodeData.executionTime,
            hasError: !!nodeData.error,
            outputItems: nodeData.data ? Object.keys(nodeData.data).length : 0
          });
        }
      }

      return {
        success: true,
        executionId: id,
        path: executionPath.sort((a, b) => 
          new Date(a.startTime).getTime() - new Date(b.startTime).getTime()
        ),
        totalNodes: executionPath.length,
        totalTime: execution.stoppedAt ? 
          new Date(execution.stoppedAt).getTime() - new Date(execution.startedAt).getTime() : null
      };

    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async getNodeOutput(executionId: string, nodeId: string, outputIndex = 0): Promise<any> {
    try {
      // Get full execution data  
      const execution = await this.getExecutionData(executionId, true);
      
      if (!execution.data) {
        return {
          success: false,
          error: 'Execution data not available'
        };
      }

      const executionData = JSON.parse(execution.data);
      let runDataIndex = -1;
      
      // Find runData index
      for (let i = 0; i < executionData.length; i++) {
        if (typeof executionData[i] === 'object' && executionData[i].runData) {
          runDataIndex = parseInt(executionData[i].runData);
          break;
        }
      }

      if (runDataIndex === -1) {
        return {
          success: false,
          error: 'RunData index not found'
        };
      }

      const runData = executionData[runDataIndex];
      
      if (!runData[nodeId]) {
        return {
          success: false,
          error: `Node '${nodeId}' not found in execution`
        };
      }

      const nodeExecution = runData[nodeId];
      if (!Array.isArray(nodeExecution) || nodeExecution.length === 0) {
        return {
          success: false,
          error: `No execution data for node '${nodeId}'`
        };
      }

      const nodeData = nodeExecution[0];
      if (!nodeData.data || !nodeData.data.main || !nodeData.data.main[outputIndex]) {
        return {
          success: false,
          error: `No output data at index ${outputIndex} for node '${nodeId}'`
        };
      }

      // Get the actual output data
      const outputDataIndex = parseInt(nodeData.data.main[outputIndex][0]);
      const outputData = executionData[outputDataIndex];

      return {
        success: true,
        executionId,
        nodeId,
        outputIndex,
        data: outputData,
        metadata: {
          startTime: nodeData.startTime,
          executionTime: nodeData.executionTime,
          itemCount: Array.isArray(outputData) ? outputData.length : 1
        }
      };

    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  // Webhook Execution
  async triggerWebhook(request: WebhookRequest): Promise<any> {
    try {
      const { webhookUrl, httpMethod, data, headers, waitForResponse = true } = request;
      
      // Extract path from webhook URL
      const url = new URL(webhookUrl);
      const webhookPath = url.pathname;
      
      // Make request directly to webhook endpoint
      const config: AxiosRequestConfig = {
        method: httpMethod,
        url: webhookPath,
        headers: {
          ...headers,
          // Don't override API key header for webhook endpoints
          'X-N8N-API-KEY': undefined,
        },
        data: httpMethod !== 'GET' ? data : undefined,
        params: httpMethod === 'GET' ? data : undefined,
        // Webhooks might take longer
        timeout: waitForResponse ? 120000 : 30000,
      };

      // Create a new axios instance for webhook requests to avoid API interceptors
      const webhookClient = axios.create({
        baseURL: new URL('/', webhookUrl).toString(),
        validateStatus: (status) => status < 500, // Don't throw on 4xx
      });

      const response = await webhookClient.request(config);
      
      return {
        status: response.status,
        statusText: response.statusText,
        data: response.data,
        headers: response.headers,
      };
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  // Credential Management
  async listCredentials(params: CredentialListParams = {}): Promise<CredentialListResponse> {
    try {
      const response = await this.client.get('/credentials', { params });
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async getCredential(id: string): Promise<Credential> {
    try {
      const response = await this.client.get(`/credentials/${id}`);
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async createCredential(credential: Partial<Credential>): Promise<Credential> {
    try {
      const response = await this.client.post('/credentials', credential);
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async updateCredential(id: string, credential: Partial<Credential>): Promise<Credential> {
    try {
      const response = await this.client.patch(`/credentials/${id}`, credential);
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async deleteCredential(id: string): Promise<void> {
    try {
      await this.client.delete(`/credentials/${id}`);
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  // Tag Management
  async listTags(params: TagListParams = {}): Promise<TagListResponse> {
    try {
      const response = await this.client.get('/tags', { params });
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async createTag(tag: Partial<Tag>): Promise<Tag> {
    try {
      const response = await this.client.post('/tags', tag);
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async updateTag(id: string, tag: Partial<Tag>): Promise<Tag> {
    try {
      const response = await this.client.patch(`/tags/${id}`, tag);
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async deleteTag(id: string): Promise<void> {
    try {
      await this.client.delete(`/tags/${id}`);
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  // Source Control Management (Enterprise feature)
  async getSourceControlStatus(): Promise<SourceControlStatus> {
    try {
      const response = await this.client.get('/source-control/status');
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async pullSourceControl(force = false): Promise<SourceControlPullResult> {
    try {
      const response = await this.client.post('/source-control/pull', { force });
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async pushSourceControl(
    message: string,
    fileNames?: string[]
  ): Promise<SourceControlPushResult> {
    try {
      const response = await this.client.post('/source-control/push', {
        message,
        fileNames,
      });
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  // Variable Management (via Source Control API)
  async getVariables(): Promise<Variable[]> {
    try {
      const response = await this.client.get('/variables');
      return response.data.data || [];
    } catch (error) {
      // Variables might not be available in all n8n versions
      logger.warn('Variables API not available, returning empty array');
      return [];
    }
  }

  async createVariable(variable: Partial<Variable>): Promise<Variable> {
    try {
      const response = await this.client.post('/variables', variable);
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async updateVariable(id: string, variable: Partial<Variable>): Promise<Variable> {
    try {
      const response = await this.client.patch(`/variables/${id}`, variable);
      return response.data;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async deleteVariable(id: string): Promise<void> {
    try {
      await this.client.delete(`/variables/${id}`);
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async getWorkflowStatus(id: string): Promise<any> {
    try {
      const workflow = await this.getWorkflow(id);
      
      // Get recent executions to check activity
      const executions = await this.listExecutions({
        workflowId: id,
        limit: 5
      });

      return {
        success: true,
        workflowId: id,
        name: workflow.name,
        active: workflow.active,
        triggerCount: workflow.triggerCount || 0,
        hasWebhooks: workflow.nodes?.some(node => 
          node.type === 'n8n-nodes-base.webhook' || 
          node.type.includes('webhook')
        ) || false,
        recentExecutions: executions.data?.length || 0,
        lastExecution: executions.data?.[0] ? {
          id: executions.data[0].id,
          startedAt: executions.data[0].startedAt,
          finished: executions.data[0].finished,
          mode: executions.data[0].mode
        } : null,
        createdAt: workflow.createdAt,
        updatedAt: workflow.updatedAt
      };
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async listWebhookRegistrations(workflowId?: string): Promise<any> {
    try {
      // Get all active workflows with webhooks
      const workflows = await this.listWorkflows({ active: true });
      const webhookWorkflows = [];

      for (const workflow of workflows.data) {
        const hasWebhooks = workflow.nodes?.some(node => 
          node.type === 'n8n-nodes-base.webhook' || 
          node.type.includes('webhook')
        );

        if (hasWebhooks && (!workflowId || workflow.id === workflowId)) {
          const webhookNodes = workflow.nodes?.filter(node => 
            node.type === 'n8n-nodes-base.webhook' || 
            node.type.includes('webhook')
          ) || [];

          webhookWorkflows.push({
            workflowId: workflow.id,
            workflowName: workflow.name,
            active: workflow.active,
            webhooks: webhookNodes.map(node => ({
              nodeId: node.id,
              nodeName: node.name,
              path: node.parameters?.path || 'unknown',
              method: node.parameters?.httpMethod || 'GET',
              url: `${this.client.defaults.baseURL?.replace('/api/v1', '')}/webhook/${node.parameters?.path || 'unknown'}`
            }))
          });
        }
      }

      return {
        success: true,
        totalWebhooks: webhookWorkflows.reduce((sum, wf) => sum + wf.webhooks.length, 0),
        totalWorkflows: webhookWorkflows.length,
        registrations: webhookWorkflows
      };
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }

  async getDatabaseStats(includeExecutions = true, includeWorkflows = true): Promise<any> {
    try {
      const stats: any = {
        success: true,
        timestamp: new Date().toISOString()
      };

      if (includeWorkflows) {
        const allWorkflows = await this.listWorkflows();
        const activeWorkflows = allWorkflows.data.filter(w => w.active);
        
        stats.workflows = {
          total: allWorkflows.data.length,
          active: activeWorkflows.length,
          inactive: allWorkflows.data.length - activeWorkflows.length,
          withWebhooks: allWorkflows.data.filter(w => 
            w.nodes?.some(n => n.type.includes('webhook'))
          ).length
        };
      }

      if (includeExecutions) {
        // Get recent execution statistics
        const recentExecutions = await this.listExecutions({ limit: 100 });
        const executions = recentExecutions.data;
        
        const now = new Date();
        const last24h = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        const last7d = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

        const recent24h = executions.filter(e => 
          new Date(e.startedAt) > last24h
        );
        const recent7d = executions.filter(e => 
          new Date(e.startedAt) > last7d
        );

        stats.executions = {
          total: recentExecutions.count || executions.length,
          last24Hours: recent24h.length,
          last7Days: recent7d.length,
          successful: executions.filter(e => e.finished && !e.stoppedAt).length,
          failed: executions.filter(e => !e.finished || e.stoppedAt).length,
          byMode: executions.reduce((acc, e) => {
            acc[e.mode] = (acc[e.mode] || 0) + 1;
            return acc;
          }, {} as Record<string, number>)
        };
      }

      return stats;
    } catch (error) {
      throw handleN8nApiError(error);
    }
  }
}