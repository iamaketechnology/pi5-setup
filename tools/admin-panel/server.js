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
const { glob } = require('glob');

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
const scheduler = require('./lib/scheduler');
const notifications = require('./lib/notifications');
const auth = require('./lib/auth');
const servicesInfo = require('./lib/services-info');
const networkManager = require('./lib/network-manager');

// Initialize Express
const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.use(express.json());

// Initialize authentication middleware
const sessionMiddleware = auth.initAuth(config);
if (sessionMiddleware) {
  app.use(sessionMiddleware);
}

app.use(express.static(path.join(__dirname, 'public')));

// Initialize modules
db.initDatabase(config.paths.database);
piManager.initPiManager(config);
notifications.initNotifications(config);
servicesInfo.initServicesInfo(piManager, config);

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

app.post('/api/auth/login', async (req, res) => {
  const { username, password } = req.body;

  const result = await auth.login(username, password);

  if (result.success) {
    req.session.user = result.user;
    res.json({ success: true, user: result.user });
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
    version: '3.3.0',
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

app.get('/api/pis', (req, res) => {
  const pis = piManager.getAllPis();
  const currentPi = piManager.getCurrentPi();
  res.json({ pis, current: currentPi });
});

app.post('/api/pis/select', (req, res) => {
  try {
    const { piId } = req.body;
    const piConfig = piManager.setCurrentPi(piId);
    res.json({ success: true, pi: piConfig });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
});

app.post('/api/pis/:piId/test', async (req, res) => {
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

app.get('/api/status', async (req, res) => {
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

app.get('/api/scripts', async (req, res) => {
  try {
    const scripts = await discoverScripts();
    res.json({ scripts });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/system/stats', async (req, res) => {
  try {
    const { piId } = req.query;
    const stats = await getSystemStats(piId);
    res.json(stats);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/execute', async (req, res) => {
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
// HTTP Routes - Execution History
// =============================================================================

app.get('/api/history', (req, res) => {
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

app.get('/api/history/:id', (req, res) => {
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

app.get('/api/history/stats', (req, res) => {
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

app.get('/api/scheduler/tasks', (req, res) => {
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

app.post('/api/scheduler/tasks', async (req, res) => {
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

app.put('/api/scheduler/tasks/:id', async (req, res) => {
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

app.delete('/api/scheduler/tasks/:id', (req, res) => {
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

app.get('/api/docker/containers', async (req, res) => {
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

app.post('/api/docker/:action/:container', async (req, res) => {
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

app.get('/api/docker/logs/:container', async (req, res) => {
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

app.post('/api/notifications/test', async (req, res) => {
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

app.get('/api/services/discover', async (req, res) => {
  try {
    const { piId } = req.query;
    const services = await servicesInfo.discoverServices(piId);
    res.json({ services });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/services/:serviceName/credentials', async (req, res) => {
  try {
    const { serviceName } = req.params;
    const { piId } = req.query;
    const credentials = await servicesInfo.getServiceCredentials(serviceName, piId);
    res.json({ credentials });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/services/:serviceName/commands', (req, res) => {
  try {
    const { serviceName } = req.params;
    const commands = servicesInfo.getServiceCommands(serviceName);
    res.json({ commands });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/services/:serviceName/command', async (req, res) => {
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
app.post('/api/execute-command', async (req, res) => {
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
app.get('/api/services/:serviceName/paths', (req, res) => {
  try {
    const { serviceName } = req.params;
    const paths = servicesInfo.getServicePaths(serviceName);
    res.json({ paths });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get service maintenance commands
app.get('/api/services/:serviceName/maintenance', (req, res) => {
  try {
    const { serviceName } = req.params;
    const commands = servicesInfo.getMaintenanceCommands(serviceName);
    res.json({ commands });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get service backup info
app.get('/api/services/:serviceName/backup', (req, res) => {
  try {
    const { serviceName } = req.params;
    const backup = servicesInfo.getBackupInfo(serviceName);
    res.json({ backup });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Check setup status
app.get('/api/setup/status', async (req, res) => {
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
app.get('/api/network/interfaces', async (req, res) => {
  try {
    const { piId } = req.query;
    const interfaces = await networkManager.getNetworkInterfaces(piId);
    res.json({ interfaces });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get bandwidth stats for an interface
app.get('/api/network/bandwidth', async (req, res) => {
  try {
    const { piId, interface: iface } = req.query;
    const stats = await networkManager.getBandwidthStats(piId, iface || 'eth0');
    res.json({ stats });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get active connections
app.get('/api/network/connections', async (req, res) => {
  try {
    const { piId } = req.query;
    const connections = await networkManager.getActiveConnections(piId);
    res.json({ connections });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get firewall status
app.get('/api/network/firewall', async (req, res) => {
  try {
    const { piId } = req.query;
    const firewall = await networkManager.getFirewallStatus(piId);
    res.json({ firewall });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get public IP and location
app.get('/api/network/public-ip', async (req, res) => {
  try {
    const { piId } = req.query;
    const publicIP = await networkManager.getPublicIP(piId);
    res.json({ publicIP });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Test ping
app.post('/api/network/ping', async (req, res) => {
  try {
    const { piId, host, count } = req.body;
    const result = await networkManager.testPing(piId, host, count);
    res.json({ result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Test DNS
app.post('/api/network/dns', async (req, res) => {
  try {
    const { piId, domain } = req.body;
    const result = await networkManager.testDNS(piId, domain);
    res.json({ result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get listening ports
app.get('/api/network/ports', async (req, res) => {
  try {
    const { piId } = req.query;
    const ports = await networkManager.getListeningPorts(piId);
    res.json({ ports });
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
  console.log('🚀 PI5 Control Center v3.0');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`📍 URL: http://${HOST}:${PORT}`);
  console.log(`🎯 Current Pi: ${piManager.getCurrentPiConfig().name}`);
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
  server.close();
});
