// =============================================================================
// PI5 Admin Panel - Server
// =============================================================================
// Local development tool to manage Pi deployments via SSH
// Author: PI5-SETUP Project
// Version: 1.0.0
// =============================================================================

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const { NodeSSH } = require('node-ssh');
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

// Initialize Express
const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// SSH connection singleton
let sshConnection = null;

// =============================================================================
// SSH Helper Functions
// =============================================================================

async function getSSH() {
  if (sshConnection && sshConnection.isConnected()) {
    return sshConnection;
  }

  const ssh = new NodeSSH();

  try {
    await ssh.connect(config.pi);
    sshConnection = ssh;
    console.log('✅ SSH connected to', config.pi.host);
    return ssh;
  } catch (error) {
    console.error('❌ SSH connection failed:', error.message);
    throw error;
  }
}

async function executeCommand(command, socket = null) {
  const ssh = await getSSH();

  return new Promise((resolve, reject) => {
    ssh.execCommand(command, {
      cwd: config.paths.remoteTempDir,
      onStdout: (chunk) => {
        const data = chunk.toString('utf8');
        console.log('[STDOUT]', data);
        if (socket) socket.emit('log', { type: 'stdout', data });
      },
      onStderr: (chunk) => {
        const data = chunk.toString('utf8');
        console.log('[STDERR]', data);
        if (socket) socket.emit('log', { type: 'stderr', data });
      }
    }).then(result => {
      resolve(result);
    }).catch(error => {
      reject(error);
    });
  });
}

// =============================================================================
// Script Discovery
// =============================================================================

async function discoverScripts() {
  const scripts = [];
  const projectRoot = config.paths.projectRoot;

  for (const pattern of config.scripts.patterns) {
    const matches = await glob(pattern, { cwd: projectRoot });

    for (const match of matches) {
      const fullPath = path.join(projectRoot, match);
      const parts = match.split('/');
      const category = parts[0]; // 01-infrastructure
      const service = parts[1];  // supabase
      const filename = parts[parts.length - 1]; // 01-supabase-deploy.sh

      scripts.push({
        id: Buffer.from(match).toString('base64'),
        name: filename.replace(/\.sh$/, '').replace(/^\d+-/, '').replace(/-/g, ' '),
        category,
        service,
        path: match,
        fullPath
      });
    }
  }

  return scripts.sort((a, b) => a.category.localeCompare(b.category) || a.service.localeCompare(b.service));
}

// =============================================================================
// HTTP Routes
// =============================================================================

app.get('/api/status', async (req, res) => {
  try {
    const ssh = await getSSH();
    res.json({
      connected: ssh.isConnected(),
      host: config.pi.host,
      username: config.pi.username
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

app.post('/api/execute', async (req, res) => {
  const { scriptPath } = req.body;

  if (!scriptPath) {
    return res.status(400).json({ error: 'scriptPath required' });
  }

  try {
    const localPath = path.join(config.paths.projectRoot, scriptPath);

    if (!fs.existsSync(localPath)) {
      return res.status(404).json({ error: 'Script not found' });
    }

    // Create execution ID
    const executionId = Date.now().toString();

    res.json({
      success: true,
      executionId,
      message: 'Script execution started. Connect to WebSocket for logs.'
    });

    // Execute in background (logs via WebSocket)
    setImmediate(async () => {
      const socket = io.sockets.sockets.values().next().value;

      try {
        if (socket) {
          socket.emit('execution-start', { executionId, scriptPath });
        }

        const ssh = await getSSH();

        // Upload script
        const remotePath = `${config.paths.remoteTempDir}/${path.basename(scriptPath)}`;
        await ssh.putFile(localPath, remotePath);

        if (socket) {
          socket.emit('log', { type: 'info', data: `✅ Script uploaded to ${remotePath}\n` });
        }

        // Execute
        const result = await executeCommand(`sudo bash ${remotePath}`, socket);

        if (socket) {
          socket.emit('execution-end', {
            executionId,
            success: result.code === 0,
            exitCode: result.code
          });
        }
      } catch (error) {
        if (socket) {
          socket.emit('log', { type: 'error', data: `❌ Error: ${error.message}\n` });
          socket.emit('execution-end', {
            executionId,
            success: false,
            error: error.message
          });
        }
      }
    });

  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/docker/containers', async (req, res) => {
  try {
    const result = await executeCommand('docker ps --format "{{json .}}"');

    if (result.code !== 0) {
      throw new Error(result.stderr);
    }

    const lines = result.stdout.trim().split('\n').filter(Boolean);
    const containers = lines.map(line => JSON.parse(line));

    res.json({ containers });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/docker/:action/:container', async (req, res) => {
  const { action, container } = req.params;

  const allowedActions = ['start', 'stop', 'restart'];
  if (!allowedActions.includes(action)) {
    return res.status(400).json({ error: 'Invalid action' });
  }

  try {
    const result = await executeCommand(`docker ${action} ${container}`);

    res.json({
      success: result.code === 0,
      output: result.stdout,
      error: result.stderr
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/docker/logs/:container', async (req, res) => {
  const { container } = req.params;
  const lines = req.query.lines || 100;

  try {
    const result = await executeCommand(`docker logs ${container} --tail ${lines}`);

    res.json({
      logs: result.stdout + result.stderr
    });
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
      const ssh = await getSSH();
      socket.emit('connection-status', {
        connected: ssh.isConnected(),
        host: config.pi.host
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
  console.log('🚀 PI5 Admin Panel');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`📍 URL: http://${HOST}:${PORT}`);
  console.log(`🎯 Target: ${config.pi.username}@${config.pi.host}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('🛑 Shutting down...');
  if (sshConnection) {
    sshConnection.dispose();
  }
  server.close();
});
