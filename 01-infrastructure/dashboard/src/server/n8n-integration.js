// =============================================================================
// n8n Integration Module
// =============================================================================
// Version: 1.0.0
// Description: n8n API integration for triggering workflows and fetching stats
// =============================================================================

/**
 * n8n Service
 * Handles communication with n8n API
 */
class N8nService {
  constructor() {
    this.baseUrl = process.env.N8N_URL || 'http://n8n:5678';
    this.apiKey = process.env.N8N_API_KEY || '';
  }

  /**
   * Fetch headers for n8n API requests
   */
  getHeaders() {
    const headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };

    if (this.apiKey) {
      headers['X-N8N-API-KEY'] = this.apiKey;
    }

    return headers;
  }

  /**
   * Get all workflows
   */
  async getWorkflows() {
    try {
      const response = await fetch(`${this.baseUrl}/api/v1/workflows`, {
        method: 'GET',
        headers: this.getHeaders()
      });

      if (!response.ok) {
        throw new Error(`n8n API error: ${response.status} ${response.statusText}`);
      }

      const data = await response.json();
      return {
        success: true,
        workflows: data.data || []
      };
    } catch (error) {
      console.error('[n8n] Failed to fetch workflows:', error);
      return {
        success: false,
        error: error.message,
        workflows: []
      };
    }
  }

  /**
   * Get workflow by ID
   */
  async getWorkflow(workflowId) {
    try {
      const response = await fetch(`${this.baseUrl}/api/v1/workflows/${workflowId}`, {
        method: 'GET',
        headers: this.getHeaders()
      });

      if (!response.ok) {
        throw new Error(`n8n API error: ${response.status}`);
      }

      const data = await response.json();
      return {
        success: true,
        workflow: data
      };
    } catch (error) {
      console.error(`[n8n] Failed to fetch workflow ${workflowId}:`, error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Trigger workflow execution (POST webhook)
   */
  async triggerWorkflow(workflowId, data = {}) {
    try {
      // Method 1: Via API (requires API key)
      if (this.apiKey) {
        const response = await fetch(`${this.baseUrl}/api/v1/workflows/${workflowId}/execute`, {
          method: 'POST',
          headers: this.getHeaders(),
          body: JSON.stringify(data)
        });

        if (!response.ok) {
          throw new Error(`n8n API error: ${response.status}`);
        }

        const result = await response.json();
        return {
          success: true,
          executionId: result.executionId,
          data: result
        };
      }

      // Method 2: Via webhook (no API key needed)
      const response = await fetch(`${this.baseUrl}/webhook/${workflowId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
      });

      if (!response.ok) {
        throw new Error(`Webhook error: ${response.status}`);
      }

      return {
        success: true,
        message: 'Workflow triggered via webhook'
      };
    } catch (error) {
      console.error(`[n8n] Failed to trigger workflow ${workflowId}:`, error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Get workflow executions (history)
   */
  async getExecutions(workflowId, limit = 10) {
    try {
      const url = workflowId
        ? `${this.baseUrl}/api/v1/executions?workflowId=${workflowId}&limit=${limit}`
        : `${this.baseUrl}/api/v1/executions?limit=${limit}`;

      const response = await fetch(url, {
        method: 'GET',
        headers: this.getHeaders()
      });

      if (!response.ok) {
        throw new Error(`n8n API error: ${response.status}`);
      }

      const data = await response.json();
      return {
        success: true,
        executions: data.data || []
      };
    } catch (error) {
      console.error('[n8n] Failed to fetch executions:', error);
      return {
        success: false,
        error: error.message,
        executions: []
      };
    }
  }

  /**
   * Check n8n health
   */
  async checkHealth() {
    try {
      const response = await fetch(`${this.baseUrl}/healthz`, {
        method: 'GET',
        timeout: 5000
      });

      return {
        status: response.ok ? 'healthy' : 'unhealthy',
        statusCode: response.status
      };
    } catch (error) {
      return {
        status: 'unreachable',
        error: error.message
      };
    }
  }
}

/**
 * Register n8n integration routes
 */
function registerN8nRoutes(app, n8nService, io) {
  // Get all workflows
  app.get('/api/n8n/workflows', async (req, res) => {
    const result = await n8nService.getWorkflows();
    res.json(result);
  });

  // Get specific workflow
  app.get('/api/n8n/workflows/:id', async (req, res) => {
    const result = await n8nService.getWorkflow(req.params.id);
    res.json(result);
  });

  // Trigger workflow
  app.post('/api/n8n/workflows/:id/trigger', async (req, res) => {
    const { id } = req.params;
    const data = req.body;

    console.log(`[n8n] Triggering workflow ${id}`);

    const result = await n8nService.triggerWorkflow(id, data);

    if (result.success) {
      // Broadcast notification to all clients
      io.emit('notification', {
        id: Date.now(),
        timestamp: new Date().toISOString(),
        workflow: `Workflow ${id}`,
        status: 'info',
        message: 'Workflow déclenché manuellement',
        executionId: result.executionId
      });
    }

    res.json(result);
  });

  // Get workflow executions
  app.get('/api/n8n/executions', async (req, res) => {
    const { workflowId, limit } = req.query;
    const result = await n8nService.getExecutions(workflowId, parseInt(limit) || 10);
    res.json(result);
  });

  // Health check
  app.get('/api/n8n/health', async (req, res) => {
    const health = await n8nService.checkHealth();
    res.json(health);
  });
}

module.exports = {
  N8nService,
  registerN8nRoutes
};
