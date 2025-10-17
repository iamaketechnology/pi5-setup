// =============================================================================
// PI5 Control Center - Server v3.0
// =============================================================================
// Complete management dashboard with Multi-Pi, History, Scheduler, Notifications
// Author: PI5-SETUP Project
// Version: 3.0.0
// =============================================================================

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { glob } = require('glob');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { version: appVersion } = require('./package.json');

// Load configuration
let config;
try {
  config = require('./config.js');
} catch (error) {
  console.error('❌ config.js not found. Copy config.example.js to config.js and configure it.');
  process.exit(1);
}

// Import modules
const db = require('./lib/database');
const piManager = require('./lib/pi-manager');
const supabaseClient = require('./lib/supabase-client');
const sqlSource = require('./lib/sql-source');
const scheduler = require('./lib/scheduler');
const notifications = require('./lib/notifications');
const auth = require('./lib/auth');
const servicesInfo = require('./lib/services-info');
const networkManager = require('./lib/network-manager');
const sshTunnelManager = require('./lib/ssh-tunnel-manager');

// Initialize Express
const app = express();
const server = http.createServer(app);
const io = new Server(server);

// Respect proxy headers (needed for secure cookies behind reverse proxies)
app.set('trust proxy', 1);

app.use(express.json());
app.use(helmet({
  contentSecurityPolicy: false, // Disabled due to dynamic inline scripts; revisit when CSP ready
  crossOriginEmbedderPolicy: false
}));

const loginLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false
});

const sensitiveLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false
});

const authOnly = [auth.requireAuth];
const adminOnly = [auth.requireAuth, auth.requireAdmin, sensitiveLimiter];

// Initialize authentication middleware
const sessionMiddleware = auth.initAuth(config);
if (sessionMiddleware) {
  app.use(sessionMiddleware);
}

app.use(express.static(path.join(__dirname, 'public')));

// Initialize modules (async wrapper for piManager)
db.initDatabase(config.paths.database);
notifications.initNotifications(config);
servicesInfo.initServicesInfo(piManager, config);

// Initialize piManager and sshTunnelManager asynchronously
(async () => {
  try {
    await piManager.initPiManager(config);
    await sshTunnelManager.initTunnelManager();
  } catch (error) {
    console.error('Failed to initialize managers:', error.message);
  }
})();

// =============================================================================
// Script Discovery
// =============================================================================

function getScriptType(scriptPath) {
  if (scriptPath.includes('/maintenance/')) return 'maintenance';
  if (scriptPath.includes('/utils/')) return 'utils';
  if (scriptPath.includes('common-scripts/')) return 'common';
  if (scriptPath.includes('/scripts/') && scriptPath.match(/\d+-.*-deploy\.sh$/)) return 'deploy';
  if (scriptPath.includes('-test.sh') || scriptPath.includes('diagnose')) return 'test';
  return 'other';
}

function getCategoryMeta(type) {
  const categories = {
    'deploy': { icon: '🚀', label: 'Déploiement', color: '#3b82f6' },
    'maintenance': { icon: '🔧', label: 'Maintenance', color: '#f59e0b' },
    'utils': { icon: '⚙️', label: 'Configuration', color: '#8b5cf6' },
    'test': { icon: '🧪', label: 'Tests', color: '#10b981' },
    'common': { icon: '📦', label: 'Commun', color: '#6366f1' },
    'other': { icon: '📄', label: 'Autre', color: '#6b7280' }
  };
  return categories[type] || categories.other;
}

async function discoverScripts() {
  const scripts = [];
  const projectRoot = config.paths.projectRoot;

  const allPatterns = [
    '*/*/scripts/*-deploy.sh',
    '*/*/scripts/maintenance/*.sh',
    '*/*/scripts/utils/*.sh',
    'common-scripts/*.sh',
    '*/*/scripts/*-test.sh',
    '*/*/scripts/*/diagnose*.sh'
  ];

  for (const pattern of allPatterns) {
    try {
      const matches = await glob(pattern, { cwd: projectRoot });

      for (const match of matches) {
        if (match.includes('_') && match.includes('-common.sh')) continue;

        const fullPath = path.join(projectRoot, match);
        const parts = match.split('/');
        const filename = parts[parts.length - 1];

        let category = parts[0];
        let service = parts.length > 1 ? parts[1] : 'common';

        if (match.startsWith('common-scripts/')) {
          category = 'common-scripts';
          service = 'system';
        }

        const scriptType = getScriptType(match);
        const meta = getCategoryMeta(scriptType);

        scripts.push({
          id: Buffer.from(match).toString('base64'),
          name: filename.replace(/\.sh$/, '').replace(/^\d+-/, '').replace(/-/g, ' '),
          filename,
          category,
          service,
          type: scriptType,
          icon: meta.icon,
          typeLabel: meta.label,
          color: meta.color,
          path: match,
          fullPath
        });
      }
    } catch (error) {
      console.error(`Error discovering pattern ${pattern}:`, error.message);
    }
  }

  return scripts.sort((a, b) => {
    if (a.type !== b.type) return a.type.localeCompare(b.type);
    if (a.category !== b.category) return a.category.localeCompare(b.category);
    return a.service.localeCompare(b.service);
  });
}

// =============================================================================
// System Stats Helper
// =============================================================================

async function getSystemStats(piId = null) {
  try {
    const targetPi = piId || piManager.getCurrentPi();
    const piConfig = piManager.getPiConfig(targetPi);

    const [cpu, mem, temp, disk, uptime, dockerStats] = await Promise.all([
      piManager.executeCommand("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1", targetPi),
      piManager.executeCommand("free -m | awk 'NR==2{printf \"%.0f/%.0f/%.0f\", $3,$2,($3/$2)*100}'", targetPi),
      piManager.executeCommand("vcgencmd measure_temp | cut -d'=' -f2 | cut -d\"'\" -f1", targetPi),
      piManager.executeCommand("df -h / | awk 'NR==2{printf \"%s/%s/%s\", $3,$2,$5}'", targetPi),
      piManager.executeCommand("uptime -p", targetPi),
      piManager.executeCommand("docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' 2>/dev/null || echo ''", targetPi)
    ]);

    const memParts = mem.stdout.split('/');
    const memUsed = parseInt(memParts[0]) || 0;
    const memTotal = parseInt(memParts[1]) || 0;
    const memPercent = parseInt(memParts[2]) || 0;

    const diskParts = disk.stdout.split('/');
    const diskUsed = diskParts[0] || '0G';
    const diskTotal = diskParts[1] || '0G';
    const diskPercent = parseInt(diskParts[2]) || 0;

    const dockerContainers = dockerStats.stdout
      .split('\n')
      .filter(Boolean)
      .map(line => {
        const [name, cpu, mem] = line.split('\t');
        return { name, cpu, mem };
      });

    const stats = {
      cpu: parseFloat(cpu.stdout) || 0,
      memory: {
        used: memUsed,
        total: memTotal,
        percent: memPercent
      },
      temperature: parseFloat(temp.stdout) || 0,
      disk: {
        used: diskUsed,
        total: diskTotal,
        percent: diskPercent
      },
      uptime: uptime.stdout.replace('up ', ''),
      docker: dockerContainers,
      piId: targetPi,
      piName: piConfig.name
    };

    // Save to history
    db.saveStatsHistory(targetPi, stats);

    return stats;
  } catch (error) {
    console.error('Error fetching system stats:', error.message);
    return {
      cpu: 0,
      memory: { used: 0, total: 0, percent: 0 },
      temperature: 0,
      disk: { used: '0G', total: '0G', percent: 0 },
      uptime: 'unknown',
      docker: [],
      error: error.message
    };
  }
}

// =============================================================================
// Script Execution Helper
// =============================================================================

async function executeScript(scriptPath, piId = null, triggeredBy = 'manual') {
  const targetPi = piId || piManager.getCurrentPi();
  const piConfig = piManager.getPiConfig(targetPi);
  const startTime = Date.now();

  const localPath = path.join(config.paths.projectRoot, scriptPath);

  if (!fs.existsSync(localPath)) {
    throw new Error('Script not found');
  }

  const remotePath = `${piConfig.remoteTempDir}/${path.basename(scriptPath)}`;

  // Create execution record
  const executionId = db.createExecution({
    piId: targetPi,
    scriptPath,
    scriptName: path.basename(scriptPath),
    scriptType: getScriptType(scriptPath),
    startedAt: startTime,
    triggeredBy
  });

  let output = '';
  let error = '';

  try {
    // Upload script
    await piManager.uploadFile(localPath, remotePath, targetPi);

    // Execute
    const result = await piManager.executeCommand(`sudo bash ${remotePath}`, targetPi, {
      onStdout: (chunk) => {
        const data = chunk.toString('utf8');
        output += data;
        // Broadcast via WebSocket
        io.emit('log', { type: 'stdout', data, executionId });
      },
      onStderr: (chunk) => {
        const data = chunk.toString('utf8');
        error += data;
        io.emit('log', { type: 'stderr', data, executionId });
      }
    });

    const endTime = Date.now();
    const success = result.code === 0;

    // Update execution record
    db.updateExecution(executionId, {
      endedAt: endTime,
      duration: endTime - startTime,
      exitCode: result.code,
      status: success ? 'success' : 'failed',
      output: output || result.stdout,
      error: error || result.stderr
    });

    // Send notification
    if (!success) {
      notifications.sendNotification('execution.failed', {
        script: scriptPath,
        pi: piConfig.name,
        error: error || result.stderr,
        duration: endTime - startTime,
        exitCode: result.code
      });
    } else {
      notifications.sendNotification('execution.success', {
        script: scriptPath,
        pi: piConfig.name,
        duration: endTime - startTime,
        exitCode: result.code
      });
    }

    return {
      success,
      exitCode: result.code,
      output: output || result.stdout,
      error: error || result.stderr,
      duration: endTime - startTime,
      executionId
    };
  } catch (err) {
    const endTime = Date.now();

    db.updateExecution(executionId, {
      endedAt: endTime,
      duration: endTime - startTime,
      exitCode: -1,
      status: 'failed',
      error: err.message
    });

    notifications.sendNotification('execution.failed', {
      script: scriptPath,
      pi: piConfig.name,
      error: err.message,
      duration: endTime - startTime
    });

    throw err;
  }
}

// Initialize scheduler with execution function
scheduler.initScheduler(executeScript);

// =============================================================================
// HTTP Routes - Authentication
// =============================================================================

app.post('/api/auth/login', loginLimiter, async (req, res) => {
  const { username, password } = req.body;

  const result = await auth.login(username, password);

  if (result.success) {
    req.session.regenerate((err) => {
      if (err) {
        return res.status(500).json({ success: false, message: 'Session initialization failed' });
      }
      req.session.user = result.user;
      res.json({ success: true, user: result.user });
    });
  } else {
    res.status(401).json({ success: false, message: result.message });
  }
});

app.post('/api/auth/logout', (req, res) => {
  auth.logout(req);
  res.json({ success: true });
});

app.get('/api/auth/me', (req, res) => {
  const user = auth.getCurrentUser(req);
  res.json({ user, authEnabled: config.auth?.enabled || false });
});

// Get application configuration (NO HARDCODING!)
app.get('/api/config', (req, res) => {
  const appConfig = {
    version: appVersion,
    name: 'PI5 Control Center',

    // Feature flags based on what's actually enabled
    features: {
      multiPi: piManager.getAllPis().length > 1,
      authentication: config.auth?.enabled || false,
      notifications: config.notifications?.enabled || false,
      scheduler: config.scheduler?.enabled || false,
      monitoring: true,  // Always available
      networkMonitoring: true  // Always available
    },

    // Tabs configuration - dynamic based on features
    tabs: [
      { id: 'dashboard', name: '📊 Dashboard', enabled: true },
      { id: 'scripts', name: '📜 Scripts', enabled: true },
      { id: 'network', name: '🌐 Network', enabled: true },
      { id: 'docker', name: '🐳 Docker', enabled: true },
      { id: 'info', name: '📋 Info', enabled: true },
      { id: 'history', name: '📝 History', enabled: true },
      { id: 'scheduler', name: '⏰ Scheduler', enabled: config.scheduler?.enabled || false }
    ].filter(tab => tab.enabled),

    // Service categories (dynamic)
    serviceCategories: [
      { id: 'backend', name: 'Backend', icon: '🗄️' },
      { id: 'monitoring', name: 'Monitoring', icon: '📊' },
      { id: 'automation', name: 'Automation', icon: '🤖' },
      { id: 'proxy', name: 'Proxy', icon: '🔀' }
    ],

    // Refresh intervals (configurable)
    refreshIntervals: {
      systemStats: parseInt(process.env.REFRESH_SYSTEM_STATS) || 5000,
      bandwidth: parseInt(process.env.REFRESH_BANDWIDTH) || 5000,
      docker: parseInt(process.env.REFRESH_DOCKER) || 10000,
      connections: parseInt(process.env.REFRESH_CONNECTIONS) || 10000,
      history: parseInt(process.env.REFRESH_HISTORY) || 30000
    },

    // Server capabilities
    capabilities: {
      ssh: true,
      docker: true,
      firewall: true,
      systemd: true
    }
  };

  res.json(appConfig);
});

// =============================================================================
// HTTP Routes - Pi Management
// =============================================================================
// NOTE: Moved to "Pi Management (Supabase)" section below (async version)

app.post('/api/pis/select', ...authOnly, (req, res) => {
  try {
    const { piId } = req.body;
    const piConfig = piManager.setCurrentPi(piId);
    res.json({ success: true, pi: piConfig });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

app.post('/api/pis/:piId/test', ...authOnly, async (req, res) => {
  try {
    const { piId } = req.params;
    const result = await piManager.testConnection(piId);
    res.json(result);
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// =============================================================================
// HTTP Routes - Scripts & Execution
// =============================================================================

app.get('/api/status', ...authOnly, async (req, res) => {
  try {
    const currentPi = piManager.getCurrentPi();
    const piConfig = piManager.getCurrentPiConfig();
    const ssh = await piManager.getSSH();

    res.json({
      connected: ssh.isConnected(),
      host: piConfig.host,
      username: piConfig.username,
      piId: currentPi,
      piName: piConfig.name
    });
  } catch (error) {
    res.json({
      connected: false,
      error: error.message
    });
  }
});

app.get('/api/scripts', ...authOnly, async (req, res) => {
  try {
    const scripts = await discoverScripts();
    res.json({ scripts });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/setup-status', ...authOnly, async (req, res) => {
  try {
    const ssh = await piManager.getSSH();
    const status = {
      docker: false,
      network: { configured: false },
      security: { configured: false, services: [] },
      traefik: { running: false, containers: 0 },
      monitoring: { running: false, services: [] }
    };

    // Check Docker
    try {
      const dockerCheck = await ssh.execCommand('docker --version');
      status.docker = dockerCheck.code === 0;
    } catch (e) {}

    // Check Docker containers for Traefik & Monitoring
    try {
      const dockerPs = await ssh.execCommand('docker ps --format "{{.Names}}"');
      if (dockerPs.code === 0) {
        const containers = dockerPs.stdout.split('\n').filter(Boolean);

        // Traefik
        const traefikContainers = containers.filter(c => c.toLowerCase().includes('traefik'));
        status.traefik.running = traefikContainers.length > 0;
        status.traefik.containers = traefikContainers.length;

        // Monitoring
        const monitoringServices = [];
        if (containers.some(c => c.toLowerCase().includes('prometheus'))) monitoringServices.push('Prometheus');
        if (containers.some(c => c.toLowerCase().includes('grafana'))) monitoringServices.push('Grafana');
        if (containers.some(c => c.toLowerCase().includes('node-exporter') || c.toLowerCase().includes('node_exporter'))) monitoringServices.push('Node Exporter');
        status.monitoring.running = monitoringServices.length > 0;
        status.monitoring.services = monitoringServices;
      }
    } catch (e) {}

    // Check Security services
    try {
      const ufwCheck = await ssh.execCommand('systemctl is-active ufw 2>/dev/null || echo inactive');
      const fail2banCheck = await ssh.execCommand('systemctl is-active fail2ban 2>/dev/null || echo inactive');

      const securityServices = [];
      if (ufwCheck.stdout.trim() === 'active') securityServices.push('UFW');
      if (fail2banCheck.stdout.trim() === 'active') securityServices.push('Fail2ban');

      status.security.configured = securityServices.length > 0;
      status.security.services = securityServices;
    } catch (e) {}

    // Check Network config (static IP detection)
    try {
      const hostnameCheck = await ssh.execCommand('hostname');
      const ipCheck = await ssh.execCommand('hostname -I | awk \'{print $1}\'');

      status.network.hostname = hostnameCheck.stdout.trim();
      status.network.ip = ipCheck.stdout.trim();
      status.network.configured = status.network.hostname !== 'raspberrypi' && !!status.network.ip;
    } catch (e) {}

    res.json({ status });
  } catch (error) {
    console.error('Setup status check error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/system/stats', ...authOnly, async (req, res) => {
  try {
    const { piId } = req.query;
    const stats = await getSystemStats(piId);
    res.json(stats);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/execute', ...adminOnly, async (req, res) => {
  const { scriptPath, piId } = req.body;

  if (!scriptPath) {
    return res.status(400).json({ error: 'scriptPath required' });
  }

  try {
    const executionId = Date.now().toString();

    res.json({
      success: true,
      executionId,
      message: 'Script execution started. Connect to WebSocket for logs.'
    });

    setImmediate(async () => {
      try {
        io.emit('execution-start', { executionId, scriptPath, piId });
        const result = await executeScript(scriptPath, piId, 'manual');
        io.emit('execution-end', {
          executionId,
          success: result.success,
          exitCode: result.exitCode
        });
      } catch (error) {
        io.emit('log', { type: 'error', data: `❌ Error: ${error.message}\n` });
        io.emit('execution-end', {
          executionId,
          success: false,
          error: error.message
        });
      }
    });

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// =============================================================================
// HTTP Routes - Pi Management (Supabase)
// =============================================================================

// Get all Pis (from Supabase or config.js fallback)
app.get('/api/pis', ...authOnly, async (req, res) => {
  try {
    const pis = await piManager.getAllPis();
    const currentPi = piManager.getCurrentPi();
    res.json({ pis, current: currentPi });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Pair Pi with token
app.post('/api/pis/pair', ...adminOnly, async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({ error: 'Token required' });
    }

    const result = await piManager.pairPi(token);

    if (result.success) {
      res.json({
        success: true,
        message: result.message,
        pi: result.pi
      });
    } else {
      res.status(400).json({
        success: false,
        error: result.message,
        pi: result.pi
      });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Refresh Pis cache
app.post('/api/pis/refresh', ...authOnly, async (req, res) => {
  try {
    await piManager.refreshPisCache();
    const pis = await piManager.getAllPis();
    res.json({
      success: true,
      message: 'Pis cache refreshed',
      pis
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// =============================================================================
// HTTP Routes - Execution History
// =============================================================================

app.get('/api/history', ...authOnly, (req, res) => {
  try {
    const { piId, status, scriptType, search, limit = 50 } = req.query;

    const executions = db.getExecutions({
      piId,
      status,
      scriptType,
      search,
      limit: parseInt(limit)
    });

    // Calculate stats
    const stats = {
      total: executions.length,
      success: executions.filter(e => e.status === 'success').length,
      failed: executions.filter(e => e.status === 'failed').length,
      running: executions.filter(e => e.status === 'running').length,
      avgDuration: '-'
    };

    const completedExecs = executions.filter(e => e.duration);
    if (completedExecs.length > 0) {
      const avgMs = completedExecs.reduce((sum, e) => sum + e.duration, 0) / completedExecs.length;
      stats.avgDuration = `${Math.round(avgMs / 1000)}s`;
    }

    res.json({ executions, stats });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/history/:id', ...authOnly, (req, res) => {
  try {
    const execution = db.getExecutionById(req.params.id);

    if (!execution) {
      return res.status(404).json({ error: 'Execution not found' });
    }

    res.json(execution);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/history/stats', ...authOnly, (req, res) => {
  try {
    const { piId } = req.query;
    const stats = db.getExecutionStats(piId);
    res.json({ stats });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// =============================================================================
// HTTP Routes - Scheduler
// =============================================================================

app.get('/api/scheduler/tasks', ...authOnly, (req, res) => {
  try {
    const { piId, enabled } = req.query;
    const tasks = db.getScheduledTasks({
      piId,
      enabled: enabled !== undefined ? enabled === 'true' : undefined
    });

    res.json({ tasks });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/scheduler/tasks', ...adminOnly, async (req, res) => {
  try {
    const { name, piId, scriptPath, cron, enabled } = req.body;

    const taskId = db.createScheduledTask({
      name,
      pi_id: piId,
      script_path: scriptPath,
      cron_expression: cron,
      enabled: enabled !== false
    });

    if (enabled !== false) {
      const task = db.getScheduledTaskById(taskId);
      scheduler.scheduleTask(task, executeScript);
    }

    res.json({ success: true, id: taskId });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.put('/api/scheduler/tasks/:id', ...adminOnly, async (req, res) => {
  try {
    const { id } = req.params;
    const updates = req.body;

    db.updateScheduledTask(id, updates);

    // Reschedule if enabled changed
    if (updates.enabled !== undefined) {
      scheduler.stopTask(id);

      if (updates.enabled) {
        const task = db.getScheduledTaskById(id);
        scheduler.scheduleTask(task, executeScript);
      }
    }

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.delete('/api/scheduler/tasks/:id', ...adminOnly, (req, res) => {
  try {
    const { id } = req.params;

    scheduler.stopTask(id);
    db.deleteScheduledTask(id);

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// =============================================================================
// HTTP Routes - Stats History (for graphs)
// =============================================================================

app.get('/api/stats/history', (req, res) => {
  try {
    const { piId, hours = 24, interval = 300 } = req.query;
    const targetPi = piId || piManager.getCurrentPi();

    const history = db.getStatsHistory(targetPi, {
      hours: parseInt(hours),
      interval: parseInt(interval)
    });

    res.json({ history });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// =============================================================================
// HTTP Routes - Docker
// =============================================================================

app.get('/api/docker/containers', ...authOnly, async (req, res) => {
  try {
    const { piId } = req.query;
    const result = await piManager.executeCommand('docker ps -a --format "{{json .}}"', piId);

    if (result.code !== 0) {
      throw new Error(result.stderr);
    }

    const lines = result.stdout.trim().split('\n').filter(Boolean);
    const containers = lines.map(line => JSON.parse(line));

    res.json({ containers });
  } catch (error) {
    res.status(500).json({ error: error.message, containers: [] });
  }
});

app.post('/api/docker/:action/:container', ...adminOnly, async (req, res) => {
  const { action, container } = req.params;
  const { piId } = req.query;

  const allowedActions = ['start', 'stop', 'restart'];
  if (!allowedActions.includes(action)) {
    return res.status(400).json({ success: false, error: 'Invalid action' });
  }

  try {
    const result = await piManager.executeCommand(`docker ${action} ${container}`, piId);

    res.json({
      success: result.code === 0,
      output: result.stdout,
      error: result.stderr
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/api/docker/logs/:container', ...authOnly, async (req, res) => {
  const { container } = req.params;
  const { piId } = req.query;
  const lines = req.query.lines || 100;

  try {
    const result = await piManager.executeCommand(`docker logs ${container} --tail ${lines}`, piId);

    res.json({
      logs: result.stdout + result.stderr
    });
  } catch (error) {
    res.status(500).json({ error: error.message, logs: '' });
  }
});

// =============================================================================
// HTTP Routes - Notifications
// =============================================================================

app.post('/api/notifications/test', ...adminOnly, async (req, res) => {
  try {
    const result = await notifications.testNotification();
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// =============================================================================
// HTTP Routes - Services Info
// =============================================================================

app.get('/api/services/discover', ...authOnly, async (req, res) => {
  try {
    const { piId } = req.query;
    const services = await servicesInfo.discoverServices(piId);
    res.json({ services });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/services/:serviceName/credentials', ...adminOnly, async (req, res) => {
  try {
    const { serviceName } = req.params;
    const { piId } = req.query;
    const credentials = await servicesInfo.getServiceCredentials(serviceName, piId);
    res.json({ credentials });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/services/:serviceName/commands', ...adminOnly, (req, res) => {
  try {
    const { serviceName } = req.params;
    const commands = servicesInfo.getServiceCommands(serviceName);
    res.json({ commands });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/services/:serviceName/command', ...adminOnly, async (req, res) => {
  try {
    const { serviceName } = req.params;
    const { command, piId } = req.body;

    if (!command) {
      return res.status(400).json({ error: 'command required' });
    }

    const result = await piManager.executeCommand(command, piId);

    res.json({
      success: result.code === 0,
      output: result.stdout,
      error: result.stderr,
      exitCode: result.code
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Execute arbitrary command (for quick commands in Info tab)
app.post('/api/execute-command', ...adminOnly, async (req, res) => {
  try {
    const { command, piId } = req.body;

    if (!command) {
      return res.status(400).json({ error: 'command required' });
    }

    const result = await piManager.executeCommand(command, piId);

    res.json({
      success: result.code === 0,
      output: result.stdout,
      error: result.stderr,
      exitCode: result.code
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get service file paths
app.get('/api/services/:serviceName/paths', ...adminOnly, (req, res) => {
  try {
    const { serviceName } = req.params;
    const paths = servicesInfo.getServicePaths(serviceName);
    res.json({ paths });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get service maintenance commands
app.get('/api/services/:serviceName/maintenance', ...adminOnly, (req, res) => {
  try {
    const { serviceName } = req.params;
    const commands = servicesInfo.getMaintenanceCommands(serviceName);
    res.json({ commands });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get service backup info
app.get('/api/services/:serviceName/backup', ...adminOnly, (req, res) => {
  try {
    const { serviceName } = req.params;
    const backup = servicesInfo.getBackupInfo(serviceName);
    res.json({ backup });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Check setup status
app.get('/api/setup/status', ...authOnly, async (req, res) => {
  try {
    const { piId } = req.query;
    const ssh = await piManager.getSSH(piId);

    const status = {
      docker: false,
      network: false,
      security: false,
      traefik: false,
      monitoring: false
    };

    // Check Docker
    try {
      const dockerCheck = await ssh.execCommand('docker --version');
      status.docker = dockerCheck.code === 0;
    } catch (e) {}

    // Check Network (static IP - look for static config)
    try {
      const netCheck = await ssh.execCommand('cat /etc/dhcpcd.conf | grep -E "^interface|^static ip_address"');
      status.network = netCheck.code === 0 && netCheck.stdout.includes('static');
    } catch (e) {}

    // Check Security (UFW, Fail2ban)
    try {
      const ufwCheck = await ssh.execCommand('sudo ufw status');
      const f2bCheck = await ssh.execCommand('systemctl is-active fail2ban');
      status.security = ufwCheck.code === 0 && ufwCheck.stdout.includes('active') &&
                        f2bCheck.stdout.trim() === 'active';
    } catch (e) {}

    // Check Traefik
    try {
      const traefikCheck = await ssh.execCommand('docker ps --filter "name=traefik" --format "{{.Names}}"');
      status.traefik = traefikCheck.stdout.includes('traefik');
    } catch (e) {}

    // Check Monitoring (Prometheus, Grafana)
    try {
      const prometheusCheck = await ssh.execCommand('docker ps --filter "name=prometheus" --format "{{.Names}}"');
      const grafanaCheck = await ssh.execCommand('docker ps --filter "name=grafana" --format "{{.Names}}"');
      status.monitoring = prometheusCheck.stdout.includes('prometheus') && grafanaCheck.stdout.includes('grafana');
    } catch (e) {}

    res.json({ status });
  } catch (error) {
    res.status(500).json({ error: error.message, status: {} });
  }
});

// =============================================================================
// Network Monitoring API
// =============================================================================

// Get network interfaces
app.get('/api/network/interfaces', ...authOnly, async (req, res) => {
  try {
    const { piId } = req.query;
    const interfaces = await networkManager.getNetworkInterfaces(piId);
    res.json({ interfaces });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get bandwidth stats for an interface
app.get('/api/network/bandwidth', ...authOnly, async (req, res) => {
  try {
    const { piId, interface: iface } = req.query;
    const stats = await networkManager.getBandwidthStats(piId, iface || 'eth0');
    res.json({ stats });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get active connections
app.get('/api/network/connections', ...authOnly, async (req, res) => {
  try {
    const { piId } = req.query;
    const connections = await networkManager.getActiveConnections(piId);
    res.json({ connections });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get firewall status
app.get('/api/network/firewall', ...authOnly, async (req, res) => {
  try {
    const { piId } = req.query;
    const firewall = await networkManager.getFirewallStatus(piId);
    res.json({ firewall });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get public IP and location
app.get('/api/network/public-ip', ...authOnly, async (req, res) => {
  try {
    const { piId } = req.query;
    const publicIP = await networkManager.getPublicIP(piId);
    res.json({ publicIP });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Test ping
app.post('/api/network/ping', ...adminOnly, async (req, res) => {
  try {
    const { piId, host, count } = req.body;
    const result = await networkManager.testPing(piId, host, count);
    res.json({ result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Test DNS
app.post('/api/network/dns', ...adminOnly, async (req, res) => {
  try {
    const { piId, domain } = req.body;
    const result = await networkManager.testDNS(piId, domain);
    res.json({ result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get listening ports
app.get('/api/network/ports', ...authOnly, async (req, res) => {
  try {
    const { piId } = req.query;
    const ports = await networkManager.getListeningPorts(piId);
    res.json({ ports });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// =============================================================================
// Bootstrap Routes - Pi Onboarding
// =============================================================================

// Get Control Center SSH public key
app.get('/api/bootstrap/pubkey', (req, res) => {
  try {
    const fs = require('fs');
    const os = require('os');
    const pubkeyPath = path.join(os.homedir(), '.ssh', 'id_rsa.pub');

    if (fs.existsSync(pubkeyPath)) {
      const pubkey = fs.readFileSync(pubkeyPath, 'utf8');
      res.type('text/plain').send(pubkey);
    } else {
      res.status(404).json({
        success: false,
        error: 'SSH public key not found. Generate one with: ssh-keygen -t rsa'
      });
    }
  } catch (error) {
    console.error('Error reading public key:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Register new Pi (bootstrap)
app.post('/api/bootstrap/register', async (req, res) => {
  try {
    const { token, hostname, ip_address, mac_address, metadata } = req.body;

    if (!token || !hostname) {
      return res.status(400).json({
        success: false,
        error: 'Token and hostname are required'
      });
    }

    console.log('📝 Pi registration received:', {
      token,
      hostname,
      ip: ip_address,
      mac: mac_address
    });

    // Save to Supabase if enabled
    if (supabaseClient.isEnabled()) {
      try {
        // Check if Pi already exists with this hostname
        const existingPi = await supabaseClient.getPiByHostname(hostname);

        if (existingPi) {
          // Update existing Pi with new token
          await supabaseClient.updatePi(existingPi.id, {
            token,
            ip_address,
            mac_address,
            status: 'pending',
            metadata: metadata || {},
            last_seen: new Date().toISOString()
          });

          console.log(`✅ Updated existing Pi: ${hostname}`);
        } else {
          // Create new Pi
          const piData = {
            name: hostname,
            hostname,
            ip_address,
            mac_address,
            token,
            status: 'pending',
            tags: ['bootstrap', 'pending-pairing'],
            metadata: metadata || {},
            last_seen: new Date().toISOString()
          };

          await supabaseClient.createPi(piData);
          console.log(`✅ Registered new Pi: ${hostname}`);
        }

        res.json({
          success: true,
          message: 'Pi registered successfully in Supabase. Use token to pair.',
          token
        });

      } catch (dbError) {
        console.error('Supabase error:', dbError);
        // Fallback: acknowledge but warn
        res.json({
          success: true,
          message: 'Pi registration acknowledged (database unavailable). Use token to pair manually.',
          token,
          warning: 'Database storage failed'
        });
      }
    } else {
      // Supabase not configured, just acknowledge
      res.json({
        success: true,
        message: 'Pi registered. Use token to pair in Control Center (manual pairing required).',
        token,
        warning: 'Supabase not configured'
      });
    }

  } catch (error) {
    console.error('Error registering Pi:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// =============================================================================
// Database Routes - Supabase Schema Installation
// =============================================================================

// Check database status
app.get('/api/database/status', ...authOnly, async (req, res) => {
  try {
    const ssh = await piManager.getSSH();

    if (!ssh) {
      return res.json({
        success: false,
        error: 'No Pi connected',
        schema_exists: false
      });
    }

    // Get Postgres password
    const pgPassResult = await ssh.execCommand(
      'docker exec supabase-db env | grep "^POSTGRES_PASSWORD=" | cut -d"=" -f2'
    );
    const pgPassword = pgPassResult.stdout.trim();

    if (!pgPassword) {
      throw new Error('Failed to retrieve Postgres password');
    }

    // Check if schema exists
    const checkSchemaCmd = `docker exec -e PGPASSWORD="${pgPassword}" supabase-db psql -U postgres -d postgres -t -c "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'control_center');"`;

    const schemaResult = await ssh.execCommand(checkSchemaCmd);
    const schemaExists = schemaResult.stdout.trim() === 't';

    let tableCount = 0;
    let piCount = 0;
    let piNames = '';

    if (schemaExists) {
      // Count tables
      const countTablesCmd = `docker exec -e PGPASSWORD="${pgPassword}" supabase-db psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'control_center';"`;

      const tablesResult = await ssh.execCommand(countTablesCmd);
      tableCount = parseInt(tablesResult.stdout.trim()) || 0;

      // Count Pis
      const countPisCmd = `docker exec -e PGPASSWORD="${pgPassword}" supabase-db psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM control_center.pis;"`;

      const pisResult = await ssh.execCommand(countPisCmd);
      piCount = parseInt(pisResult.stdout.trim()) || 0;

      // Get Pi names
      const getPiNamesCmd = `docker exec -e PGPASSWORD="${pgPassword}" supabase-db psql -U postgres -d postgres -t -c "SELECT string_agg(name, ', ') FROM control_center.pis;"`;

      const namesResult = await ssh.execCommand(getPiNamesCmd);
      piNames = namesResult.stdout.trim() || 'Aucun';
    }

    res.json({
      success: true,
      schema_exists: schemaExists,
      table_count: tableCount,
      pi_count: piCount,
      pi_names: piNames
    });

  } catch (error) {
    console.error('Error checking database status:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Install database schema
app.post('/api/database/install', ...adminOnly, async (req, res) => {
  try {
    const ssh = await piManager.getSSH();

    if (!ssh) {
      return res.json({
        success: false,
        error: 'No Pi connected'
      });
    }

    const supabaseDir = path.join(__dirname, 'supabase');

    // Get Postgres password from container
    const pgPassResult = await ssh.execCommand(
      'docker exec supabase-db env | grep "^POSTGRES_PASSWORD=" | cut -d"=" -f2'
    );
    const pgPassword = pgPassResult.stdout.trim();

    if (!pgPassword) {
      throw new Error('Failed to retrieve Postgres password');
    }

    // Helper function to execute SQL from configured source (local or GitHub)
    const executeSqlFile = async (filename, description) => {
      console.log(`Executing ${filename} from ${sqlSource.getConfig().source}...`);

      // Get SQL content from configured source (local files or GitHub)
      const sqlContent = await sqlSource.getSqlContent(filename);

      // Create temporary local file
      const tmpDir = os.tmpdir();
      const localTmpFile = path.join(tmpDir, `pi5-${filename}`);
      fs.writeFileSync(localTmpFile, sqlContent, 'utf8');

      // Upload to Pi
      const remoteTmpFile = `/tmp/${filename}`;
      await ssh.putFile(localTmpFile, remoteTmpFile);

      // Execute SQL from temp file
      const command = `cat ${remoteTmpFile} | docker exec -i -e PGPASSWORD="${pgPassword}" supabase-db psql -U postgres -d postgres -f -`;

      const result = await ssh.execCommand(command);

      // Log output for debugging
      console.log(`  ${filename} result: code=${result.code}`);
      if (result.stdout) console.log(`  stdout: ${result.stdout.substring(0, 200)}`);
      if (result.stderr) console.log(`  stderr: ${result.stderr.substring(0, 200)}`);

      // Cleanup
      await ssh.execCommand(`rm -f ${remoteTmpFile}`);
      fs.unlinkSync(localTmpFile);

      if (result.code !== 0) {
        throw new Error(`${description} failed: ${result.stderr}`);
      }

      return result;
    };

    // Execute all SQL files directly from local project
    await executeSqlFile('schema.sql', 'Schema installation');
    await executeSqlFile('policies.sql', 'Policies installation');
    await executeSqlFile('seed.sql', 'Seed installation');

    // Execute expose-schema.sql
    console.log('Exposing control_center schema to PostgREST API...');
    try {
      await executeSqlFile('expose-schema.sql', 'Schema exposure');
    } catch (error) {
      console.warn('Warning: Schema exposure failed:', error.message);
      // Don't fail, just warn - the schema is still usable via service_role
    }

    // Count installed Pis
    const countPisCmd = `docker exec -e PGPASSWORD="${pgPassword}" supabase-db psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM control_center.pis;"`;

    const pisResult = await ssh.execCommand(countPisCmd);
    const piCount = parseInt(pisResult.stdout.trim()) || 0;

    console.log(`✅ Installation completed: ${piCount} Pi(s) migrated to Supabase`);

    res.json({
      success: true,
      message: 'Schema installed successfully',
      pi_count: piCount
    });

  } catch (error) {
    console.error('Error installing database schema:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// =============================================================================
// HTTP Routes - SSH Tunnels
// =============================================================================

// GET /api/ssh-tunnels - Get all tunnels
app.get('/api/ssh-tunnels', ...authOnly, async (req, res) => {
  try {
    const tunnels = await sshTunnelManager.getTunnels();
    res.json({ tunnels });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/ssh-tunnels/:id - Get tunnel by ID
app.get('/api/ssh-tunnels/:id', ...authOnly, async (req, res) => {
  try {
    const { id } = req.params;
    const tunnel = await sshTunnelManager.getTunnel(id);

    if (!tunnel) {
      return res.status(404).json({ error: 'Tunnel not found' });
    }

    res.json({ tunnel });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/ssh-tunnels - Create new tunnel
app.post('/api/ssh-tunnels', ...adminOnly, async (req, res) => {
  try {
    const tunnel = await sshTunnelManager.createTunnel(req.body);
    res.json({
      success: true,
      tunnel,
      message: 'Tunnel created successfully'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/ssh-tunnels/:id/start - Start tunnel
app.post('/api/ssh-tunnels/:id/start', ...adminOnly, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await sshTunnelManager.startTunnel(id);
    res.json({
      success: true,
      tunnel: result,
      message: 'Tunnel started successfully'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/ssh-tunnels/:id/stop - Stop tunnel
app.post('/api/ssh-tunnels/:id/stop', ...adminOnly, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await sshTunnelManager.stopTunnel(id);
    res.json({
      success: true,
      message: 'Tunnel stopped successfully'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// PUT /api/ssh-tunnels/:id - Update tunnel
app.put('/api/ssh-tunnels/:id', ...adminOnly, async (req, res) => {
  try {
    const { id } = req.params;
    const tunnel = await sshTunnelManager.updateTunnel(id, req.body);
    res.json({
      success: true,
      tunnel,
      message: 'Tunnel updated successfully'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/ssh-tunnels/:id - Delete tunnel
app.delete('/api/ssh-tunnels/:id', ...adminOnly, async (req, res) => {
  try {
    const { id } = req.params;
    await sshTunnelManager.deleteTunnel(id);
    res.json({
      success: true,
      message: 'Tunnel deleted successfully'
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/ssh-tunnels/:id/logs - Get tunnel logs
app.get('/api/ssh-tunnels/:id/logs', ...authOnly, async (req, res) => {
  try {
    const { id } = req.params;
    const limit = parseInt(req.query.limit) || 50;
    const logs = await sshTunnelManager.getTunnelLogs(id, limit);
    res.json({ logs });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// =============================================================================
// WebSocket Events
// =============================================================================

io.on('connection', (socket) => {
  console.log('🔌 Client connected:', socket.id);

  socket.on('disconnect', () => {
    console.log('🔌 Client disconnected:', socket.id);
  });

  socket.on('test-connection', async () => {
    try {
      const currentPi = piManager.getCurrentPi();
      const piConfig = piManager.getCurrentPiConfig();
      const ssh = await piManager.getSSH();

      socket.emit('connection-status', {
        connected: ssh.isConnected(),
        host: piConfig.host,
        piId: currentPi,
        piName: piConfig.name
      });
    } catch (error) {
      socket.emit('connection-status', {
        connected: false,
        error: error.message
      });
    }
  });
});

// =============================================================================
// Server Startup
// =============================================================================

const PORT = config.server.port;
const HOST = config.server.host;

server.listen(PORT, HOST, () => {
  console.log('');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`🚀 PI5 Control Center v${appVersion}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`📍 URL: http://${HOST}:${PORT}`);
  const currentPiConfig = piManager.getCurrentPiConfig();
  console.log(`🎯 Current Pi: ${currentPiConfig?.name || 'N/A'}`);
  console.log(`📊 Database: ${config.paths.database}`);
  console.log(`🔒 Auth: ${config.auth?.enabled ? 'Enabled' : 'Disabled'}`);
  console.log(`📢 Notifications: ${config.notifications?.enabled ? 'Enabled' : 'Disabled'}`);
  console.log(`📅 Scheduler: ${config.scheduler?.enabled ? 'Enabled' : 'Disabled'}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('🛑 Shutting down...');
  scheduler.stopAll();
  piManager.disconnectAll();
  await sshTunnelManager.cleanup();
  server.close();
});
