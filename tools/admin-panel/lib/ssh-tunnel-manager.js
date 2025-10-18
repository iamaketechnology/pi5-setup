// =============================================================================
// PI5 Control Center - SSH Tunnel Manager
// =============================================================================
// Manages SSH tunnels to Pi services
// Version: 1.0.0
// =============================================================================

const { spawn } = require('child_process');
const fs = require('fs').promises;
const path = require('path');
const supabaseClient = require('./supabase-client');

const activeTunnels = new Map(); // Map of tunnel ID -> tunnel process info
const dataDir = path.join(__dirname, '../data');
const tunnelsFile = path.join(dataDir, 'tunnels.json');

// =============================================================================
// Initialize SSH Tunnel Manager
// =============================================================================

async function initTunnelManager() {
  // Ensure data directory exists
  try {
    await fs.mkdir(dataDir, { recursive: true });
  } catch (error) {
    console.warn('Data directory already exists or cannot be created');
  }

  // Load saved tunnels from file
  await loadTunnelsFromFile();

  // Start auto-start tunnels
  const tunnels = await getTunnels();
  for (const tunnel of tunnels) {
    if (tunnel.autoStart && tunnel.status !== 'active') {
      try {
        await startTunnel(tunnel.id);
        console.log(`Auto-started tunnel: ${tunnel.name}`);
      } catch (error) {
        console.error(`Failed to auto-start tunnel ${tunnel.name}:`, error.message);
      }
    }
  }

  console.log('SSH Tunnel Manager initialized');
  console.log(`  ${activeTunnels.size} active tunnel(s)`);
}

// =============================================================================
// Tunnel CRUD Operations
// =============================================================================

/**
 * Create a new tunnel
 */
async function createTunnel(tunnelData) {
  const tunnel = {
    id: generateId(),
    name: tunnelData.name,
    service: tunnelData.service,
    localPort: parseInt(tunnelData.localPort),
    remotePort: parseInt(tunnelData.remotePort),
    host: tunnelData.host || 'pi5.local',
    username: tunnelData.username || 'pi',
    autoStart: tunnelData.autoStart || false,
    favorite: tunnelData.favorite || false,
    status: 'inactive',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };

  // Validate ports
  if (tunnel.localPort < 1 || tunnel.localPort > 65535) {
    throw new Error('Invalid local port');
  }
  if (tunnel.remotePort < 1 || tunnel.remotePort > 65535) {
    throw new Error('Invalid remote port');
  }

  // Check if local port is already in use
  const tunnels = await getTunnels();
  const portInUse = tunnels.some(t =>
    t.localPort === tunnel.localPort &&
    t.status === 'active' &&
    t.id !== tunnel.id
  );
  if (portInUse) {
    throw new Error(`Local port ${tunnel.localPort} is already in use by another tunnel`);
  }

  // Save to database or file
  if (supabaseClient.isEnabled()) {
    try {
      const { data, error } = await supabaseClient.getClient()
        .from('ssh_tunnels')
        .insert([tunnel])
        .select()
        .single();

      if (error) throw error;
      return data;
    } catch (error) {
      console.warn('Failed to save to Supabase, using file storage:', error.message);
      await saveTunnelToFile(tunnel);
      return tunnel;
    }
  } else {
    await saveTunnelToFile(tunnel);
    return tunnel;
  }
}

/**
 * Get all tunnels
 */
async function getTunnels() {
  if (supabaseClient.isEnabled()) {
    try {
      const { data, error } = await supabaseClient.getClient()
        .from('ssh_tunnels')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;

      // Update status from active processes
      return data.map(tunnel => ({
        ...tunnel,
        status: activeTunnels.has(tunnel.id) ? 'active' : 'inactive',
        pid: activeTunnels.get(tunnel.id)?.process?.pid,
        uptime: activeTunnels.get(tunnel.id)?.startTime
          ? Math.floor((Date.now() - activeTunnels.get(tunnel.id).startTime) / 1000)
          : undefined
      }));
    } catch (error) {
      console.warn('Failed to load from Supabase, using file storage:', error.message);
      return await loadTunnelsFromFile();
    }
  } else {
    return await loadTunnelsFromFile();
  }
}

/**
 * Get tunnel by ID
 */
async function getTunnel(tunnelId) {
  const tunnels = await getTunnels();
  return tunnels.find(t => t.id === tunnelId);
}

/**
 * Update tunnel
 */
async function updateTunnel(tunnelId, updates) {
  const tunnel = await getTunnel(tunnelId);
  if (!tunnel) {
    throw new Error('Tunnel not found');
  }

  // Stop tunnel if it's running
  if (tunnel.status === 'active') {
    await stopTunnel(tunnelId);
  }

  const updatedTunnel = {
    ...tunnel,
    ...updates,
    updatedAt: new Date().toISOString()
  };

  if (supabaseClient.isEnabled()) {
    try {
      const { data, error } = await supabaseClient.getClient()
        .from('ssh_tunnels')
        .update(updatedTunnel)
        .eq('id', tunnelId)
        .select()
        .single();

      if (error) throw error;
      return data;
    } catch (error) {
      console.warn('Failed to update in Supabase, using file storage:', error.message);
      await updateTunnelInFile(tunnelId, updatedTunnel);
      return updatedTunnel;
    }
  } else {
    await updateTunnelInFile(tunnelId, updatedTunnel);
    return updatedTunnel;
  }
}

/**
 * Delete tunnel
 */
async function deleteTunnel(tunnelId) {
  const tunnel = await getTunnel(tunnelId);
  if (!tunnel) {
    throw new Error('Tunnel not found');
  }

  // Stop tunnel if it's running
  if (tunnel.status === 'active') {
    await stopTunnel(tunnelId);
  }

  if (supabaseClient.isEnabled()) {
    try {
      const { error } = await supabaseClient.getClient()
        .from('ssh_tunnels')
        .delete()
        .eq('id', tunnelId);

      if (error) throw error;
    } catch (error) {
      console.warn('Failed to delete from Supabase, using file storage:', error.message);
      await deleteTunnelFromFile(tunnelId);
    }
  } else {
    await deleteTunnelFromFile(tunnelId);
  }

  return { success: true };
}

// =============================================================================
// Tunnel Process Management
// =============================================================================

/**
 * Start SSH tunnel
 */
async function startTunnel(tunnelId) {
  const tunnel = await getTunnel(tunnelId);
  if (!tunnel) {
    throw new Error('Tunnel not found');
  }

  // Check if already running
  if (activeTunnels.has(tunnelId)) {
    throw new Error('Tunnel already running');
  }

  // Check if local port is available
  const tunnels = await getTunnels();
  const portInUse = tunnels.some(t =>
    t.localPort === tunnel.localPort &&
    t.status === 'active' &&
    t.id !== tunnelId
  );
  if (portInUse) {
    throw new Error(`Local port ${tunnel.localPort} is already in use`);
  }

  // Build SSH command
  const sshArgs = [
    '-L', `${tunnel.localPort}:localhost:${tunnel.remotePort}`,
    '-N', // No command execution
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'ServerAliveInterval=60',
    '-o', 'ServerAliveCountMax=3',
    `${tunnel.username}@${tunnel.host}`
  ];

  console.log(`Starting SSH tunnel: ssh ${sshArgs.join(' ')}`);

  // Spawn SSH process
  const process = spawn('ssh', sshArgs, {
    detached: false,
    stdio: ['ignore', 'pipe', 'pipe']
  });

  const tunnelInfo = {
    process,
    tunnel,
    startTime: Date.now(),
    output: []
  };

  // Handle process output
  process.stdout.on('data', (data) => {
    const line = data.toString().trim();
    if (line) {
      tunnelInfo.output.push({ type: 'stdout', message: line, timestamp: Date.now() });
      console.log(`[Tunnel ${tunnel.name}] ${line}`);
    }
  });

  process.stderr.on('data', (data) => {
    const line = data.toString().trim();
    if (line) {
      tunnelInfo.output.push({ type: 'stderr', message: line, timestamp: Date.now() });
      console.error(`[Tunnel ${tunnel.name}] ${line}`);
    }
  });

  // Handle process exit
  process.on('exit', (code, signal) => {
    console.log(`Tunnel ${tunnel.name} exited with code ${code} (signal: ${signal})`);
    activeTunnels.delete(tunnelId);
  });

  process.on('error', (error) => {
    console.error(`Tunnel ${tunnel.name} error:`, error);
    activeTunnels.delete(tunnelId);
  });

  // Store tunnel info
  activeTunnels.set(tunnelId, tunnelInfo);

  // Wait a bit to check if tunnel started successfully
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      if (process.exitCode !== null) {
        reject(new Error('Tunnel failed to start'));
      } else {
        resolve();
      }
    }, 2000);

    process.on('exit', (code) => {
      clearTimeout(timeout);
      if (code !== 0) {
        reject(new Error(`SSH process exited with code ${code}`));
      }
    });
  });

  return {
    id: tunnelId,
    pid: process.pid,
    status: 'active',
    localPort: tunnel.localPort,
    remotePort: tunnel.remotePort
  };
}

/**
 * Stop SSH tunnel
 */
async function stopTunnel(tunnelId) {
  const tunnelInfo = activeTunnels.get(tunnelId);
  if (!tunnelInfo) {
    throw new Error('Tunnel not running');
  }

  const { process, tunnel } = tunnelInfo;

  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      // Force kill if still alive
      try {
        process.kill('SIGKILL');
      } catch (error) {
        console.warn('Failed to force kill tunnel:', error.message);
      }
      resolve({ success: true, forced: true });
    }, 5000);

    process.on('exit', () => {
      clearTimeout(timeout);
      activeTunnels.delete(tunnelId);
      console.log(`Tunnel ${tunnel.name} stopped`);
      resolve({ success: true, forced: false });
    });

    // Try graceful shutdown first
    try {
      process.kill('SIGTERM');
    } catch (error) {
      clearTimeout(timeout);
      reject(error);
    }
  });
}

/**
 * Get tunnel logs
 */
async function getTunnelLogs(tunnelId, limit = 50) {
  const tunnelInfo = activeTunnels.get(tunnelId);
  if (!tunnelInfo) {
    return [];
  }

  return tunnelInfo.output.slice(-limit);
}

// =============================================================================
// File Storage (Fallback)
// =============================================================================

async function loadTunnelsFromFile() {
  try {
    const data = await fs.readFile(tunnelsFile, 'utf8');
    const tunnels = JSON.parse(data);

    // Update status from active processes
    return tunnels.map(tunnel => ({
      ...tunnel,
      status: activeTunnels.has(tunnel.id) ? 'active' : 'inactive',
      pid: activeTunnels.get(tunnel.id)?.process?.pid,
      uptime: activeTunnels.get(tunnel.id)?.startTime
        ? Math.floor((Date.now() - activeTunnels.get(tunnel.id).startTime) / 1000)
        : undefined
    }));
  } catch (error) {
    if (error.code === 'ENOENT') {
      return [];
    }
    throw error;
  }
}

async function saveTunnelToFile(tunnel) {
  const tunnels = await loadTunnelsFromFile();
  tunnels.push(tunnel);
  await fs.writeFile(tunnelsFile, JSON.stringify(tunnels, null, 2));
}

async function updateTunnelInFile(tunnelId, updatedTunnel) {
  const tunnels = await loadTunnelsFromFile();
  const index = tunnels.findIndex(t => t.id === tunnelId);
  if (index === -1) {
    throw new Error('Tunnel not found');
  }
  tunnels[index] = updatedTunnel;
  await fs.writeFile(tunnelsFile, JSON.stringify(tunnels, null, 2));
}

async function deleteTunnelFromFile(tunnelId) {
  const tunnels = await loadTunnelsFromFile();
  const filtered = tunnels.filter(t => t.id !== tunnelId);
  await fs.writeFile(tunnelsFile, JSON.stringify(filtered, null, 2));
}

// =============================================================================
// Utilities
// =============================================================================

function generateId() {
  return `tunnel_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Cleanup all tunnels on exit
 */
async function cleanup() {
  console.log('Stopping all SSH tunnels...');
  const tunnelIds = Array.from(activeTunnels.keys());

  for (const tunnelId of tunnelIds) {
    try {
      await stopTunnel(tunnelId);
    } catch (error) {
      console.error(`Failed to stop tunnel ${tunnelId}:`, error.message);
    }
  }
}

// Cleanup on process exit
process.on('exit', () => {
  const tunnelIds = Array.from(activeTunnels.keys());
  for (const tunnelId of tunnelIds) {
    const tunnelInfo = activeTunnels.get(tunnelId);
    if (tunnelInfo?.process) {
      try {
        tunnelInfo.process.kill('SIGTERM');
      } catch (error) {
        console.warn(`Failed to kill tunnel ${tunnelId}:`, error.message);
      }
    }
  }
});

process.on('SIGINT', async () => {
  await cleanup();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await cleanup();
  process.exit(0);
});

// =============================================================================
// Module Exports
// =============================================================================

module.exports = {
  initTunnelManager,
  createTunnel,
  getTunnels,
  getTunnel,
  updateTunnel,
  deleteTunnel,
  startTunnel,
  stopTunnel,
  getTunnelLogs,
  cleanup
};
