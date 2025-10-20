// =============================================================================
// Stats & Health Module
// =============================================================================
// Version: 1.0.0
// Description: Dashboard statistics and service health checks
// =============================================================================

/**
 * Calculate stats from notifications
 */
function calculateStats(notifications) {
  const now = Date.now();
  const last24h = notifications.filter(n =>
    now - new Date(n.timestamp).getTime() < 86400000
  );
  const last7d = notifications.filter(n =>
    now - new Date(n.timestamp).getTime() < 604800000
  );

  const successCount = last24h.filter(n => n.status === 'success').length;
  const errorCount = last24h.filter(n => n.status === 'error').length;
  const pendingCount = last24h.filter(n => n.status === 'pending').length;

  const successRate = last24h.length > 0
    ? ((successCount / last24h.length) * 100).toFixed(1)
    : '0.0';

  // Group by workflow
  const workflowStats = {};
  last24h.forEach(n => {
    const workflow = n.workflow || 'Unknown';
    if (!workflowStats[workflow]) {
      workflowStats[workflow] = { total: 0, success: 0, error: 0 };
    }
    workflowStats[workflow].total++;
    if (n.status === 'success') workflowStats[workflow].success++;
    if (n.status === 'error') workflowStats[workflow].error++;
  });

  // Timeline data (last 7 days)
  const timeline = generateTimeline(last7d);

  return {
    last24h: {
      total: last24h.length,
      success: successCount,
      error: errorCount,
      pending: pendingCount,
      successRate: `${successRate}%`
    },
    last7d: {
      total: last7d.length
    },
    workflows: workflowStats,
    timeline
  };
}

/**
 * Generate timeline data for charts
 */
function generateTimeline(notifications) {
  const timeline = {};
  const now = Date.now();

  // Last 7 days
  for (let i = 6; i >= 0; i--) {
    const date = new Date(now - i * 86400000);
    const dateKey = date.toISOString().split('T')[0];
    timeline[dateKey] = { success: 0, error: 0, pending: 0, total: 0 };
  }

  notifications.forEach(n => {
    const dateKey = n.timestamp.split('T')[0];
    if (timeline[dateKey]) {
      timeline[dateKey].total++;
      timeline[dateKey][n.status] = (timeline[dateKey][n.status] || 0) + 1;
    }
  });

  return Object.entries(timeline).map(([date, stats]) => ({
    date,
    ...stats
  }));
}

/**
 * Check service health
 */
async function checkServiceHealth(serviceUrl) {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 5000);

    const response = await fetch(serviceUrl, {
      method: 'GET',
      signal: controller.signal
    });

    clearTimeout(timeout);

    return {
      status: response.ok ? 'healthy' : 'unhealthy',
      statusCode: response.status,
      responseTime: response.headers.get('x-response-time') || 'N/A'
    };
  } catch (error) {
    if (error.name === 'AbortError') {
      return { status: 'timeout', error: 'Request timeout' };
    }
    return { status: 'unreachable', error: error.message };
  }
}

/**
 * Check Docker container health
 */
async function checkDockerHealth() {
  try {
    // Note: Requires Docker socket access
    // Alternative: Use SSH to Pi and run docker commands
    return {
      status: 'unknown',
      message: 'Docker health check requires SSH or socket access'
    };
  } catch (error) {
    return {
      status: 'error',
      error: error.message
    };
  }
}

/**
 * Register stats routes
 */
function registerStatsRoutes(app, notifications) {
  // Get dashboard stats
  app.get('/api/stats', (req, res) => {
    const stats = calculateStats(notifications);
    res.json(stats);
  });

  // Get timeline data
  app.get('/api/stats/timeline', (req, res) => {
    const days = parseInt(req.query.days) || 7;
    const now = Date.now();
    const filtered = notifications.filter(n =>
      now - new Date(n.timestamp).getTime() < days * 86400000
    );
    const timeline = generateTimeline(filtered);
    res.json({ timeline });
  });

  // Health check all services
  app.get('/api/health/services', async (req, res) => {
    const n8nUrl = process.env.N8N_URL || 'http://n8n:5678';
    const supabaseUrl = process.env.SUPABASE_URL || 'http://kong:8000';

    const [n8nHealth, supabaseHealth] = await Promise.all([
      checkServiceHealth(`${n8nUrl}/healthz`),
      checkServiceHealth(`${supabaseUrl}/health`)
    ]);

    res.json({
      services: {
        n8n: {
          name: 'n8n',
          url: n8nUrl,
          ...n8nHealth
        },
        supabase: {
          name: 'Supabase',
          url: supabaseUrl,
          ...supabaseHealth
        },
        docker: await checkDockerHealth()
      },
      timestamp: new Date().toISOString()
    });
  });

  // Quick action: Restart service (via webhook to n8n)
  app.post('/api/actions/restart/:service', async (req, res) => {
    const { service } = req.params;

    console.log(`[Action] Restart requested for: ${service}`);

    // This would trigger an n8n workflow to restart the service
    // Or directly execute SSH command if implemented

    res.json({
      success: true,
      message: `Restart request sent for ${service}`,
      note: 'Requires n8n workflow or SSH implementation'
    });
  });
}

module.exports = {
  calculateStats,
  generateTimeline,
  checkServiceHealth,
  registerStatsRoutes
};
