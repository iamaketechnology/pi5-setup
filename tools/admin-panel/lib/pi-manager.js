// =============================================================================
// PI5 Control Center - Pi Manager Module
// =============================================================================
// Manages multiple Pi connections and switches between them
// Version: 4.0.0 (Supabase-enabled)
// =============================================================================

const { NodeSSH } = require('node-ssh');
const supabaseClient = require('./supabase-client');

const connections = new Map(); // Map of Pi ID -> SSH connection
let config = null; // Fallback config from config.js
let currentPiId = null;
let pisCache = []; // Cache Pis from database
let lastCacheRefresh = 0;
const CACHE_TTL = 30000; // 30 seconds

// =============================================================================
// Initialize Pi Manager
// =============================================================================

async function initPiManager(appConfig) {
  config = appConfig;

  // Try to load from Supabase first
  if (supabaseClient.isEnabled()) {
    try {
      await refreshPisCache();

      if (pisCache.length > 0) {
        // Use first active Pi as default
        const activePi = pisCache.find(pi => pi.status === 'active');
        currentPiId = activePi ? activePi.id : pisCache[0].id;

        console.log('Pi Manager initialized (Supabase mode)');
        console.log(`  ${pisCache.length} Pi(s) from database`);
        console.log(`  Default Pi: ${currentPiId}`);
        return;
      }
    } catch (error) {
      console.warn('Failed to load Pis from Supabase, falling back to config.js:', error.message);
    }
  }

  // Fallback to config.js
  currentPiId = config.defaultPi;
  console.log('Pi Manager initialized (config.js fallback)');
  console.log(`  ${config.pis.length} Pi(s) configured`);
  console.log(`  Default Pi: ${currentPiId}`);
}

// =============================================================================
// Get SSH Connection (with auto-connect)
// =============================================================================

async function getSSH(piId = null) {
  const targetPiId = piId || currentPiId;

  // Check if already connected
  if (connections.has(targetPiId)) {
    const ssh = connections.get(targetPiId);
    if (ssh.isConnected()) {
      return ssh;
    }
    // Connection lost, remove it
    connections.delete(targetPiId);
  }

  // Get Pi config
  const piConfig = getPiConfig(targetPiId);
  if (!piConfig) {
    throw new Error(`Pi not found: ${targetPiId}`);
  }

  // Create new connection
  const ssh = new NodeSSH();

  // Increase max listeners to handle concurrent commands
  ssh.connection?.setMaxListeners?.(50);

  try {
    await ssh.connect(piConfig);
    connections.set(targetPiId, ssh);

    // Set max listeners after connection
    if (ssh.connection) {
      ssh.connection.setMaxListeners(50);
    }

    console.log(`✅ SSH connected to ${piConfig.name} (${piConfig.host})`);
    return ssh;
  } catch (error) {
    console.error(`❌ SSH connection failed to ${piConfig.name}:`, error.message);
    throw error;
  }
}

// =============================================================================
// Refresh Pis Cache from Supabase
// =============================================================================

async function refreshPisCache() {
  if (!supabaseClient.isEnabled()) {
    return;
  }

  const now = Date.now();
  if (now - lastCacheRefresh < CACHE_TTL && pisCache.length > 0) {
    return; // Cache still valid
  }

  try {
    const pis = await supabaseClient.getPis();

    // Transform Supabase pis to pi-manager format
    pisCache = pis
      .filter(pi => pi.status === 'active') // Only active Pis
      .map(pi => ({
        id: pi.id,
        name: pi.name,
        host: pi.hostname,
        username: 'pi', // Default for Raspberry Pi
        privateKey: require('os').homedir() + '/.ssh/id_rsa',
        tags: pi.tags || [],
        color: pi.metadata?.color || '#6b7280',
        remoteTempDir: '/tmp'
      }));

    lastCacheRefresh = now;
    console.log(`  Pis cache refreshed: ${pisCache.length} active Pi(s)`);
  } catch (error) {
    console.error('  Failed to refresh Pis cache:', error.message);
    throw error;
  }
}

// =============================================================================
// Get Pi Configuration
// =============================================================================

function getPiConfig(piId) {
  // Try cache first (Supabase mode)
  if (pisCache.length > 0) {
    return pisCache.find(pi => pi.id === piId);
  }

  // Fallback to config.js
  return config.pis.find(pi => pi.id === piId);
}

// =============================================================================
// Get All Pis
// =============================================================================

async function getAllPis() {
  // Refresh cache if needed
  if (supabaseClient.isEnabled()) {
    try {
      await refreshPisCache();
    } catch (error) {
      console.warn('Failed to refresh Pis cache:', error.message);
    }
  }

  // Return from cache or config.js
  const pis = pisCache.length > 0 ? pisCache : config.pis;

  return pis.map(pi => ({
    id: pi.id,
    name: pi.name,
    host: pi.host,
    tags: pi.tags || [],
    color: pi.color || '#6b7280',
    connected: connections.has(pi.id) && connections.get(pi.id).isConnected()
  }));
}

// =============================================================================
// Set Current Pi
// =============================================================================

function setCurrentPi(piId) {
  const piConfig = getPiConfig(piId);
  if (!piConfig) {
    throw new Error(`Pi not found: ${piId}`);
  }

  currentPiId = piId;
  console.log(`🔄 Switched to Pi: ${piConfig.name}`);
  return piConfig;
}

// =============================================================================
// Get Current Pi
// =============================================================================

function getCurrentPi() {
  return currentPiId;
}

function getCurrentPiConfig() {
  return getPiConfig(currentPiId);
}

// =============================================================================
// Execute Command
// =============================================================================

async function executeCommand(command, piId = null, options = {}) {
  const ssh = await getSSH(piId);
  const targetPiId = piId || currentPiId;
  const piConfig = getPiConfig(targetPiId);

  return new Promise((resolve, reject) => {
    ssh.execCommand(command, {
      cwd: piConfig.remoteTempDir,
      onStdout: options.onStdout,
      onStderr: options.onStderr
    }).then(result => {
      resolve(result);
    }).catch(error => {
      reject(error);
    });
  });
}

// =============================================================================
// Upload File
// =============================================================================

async function uploadFile(localPath, remotePath, piId = null) {
  const ssh = await getSSH(piId);

  await ssh.putFile(localPath, remotePath);
  console.log(`📤 File uploaded to ${piId || currentPiId}: ${remotePath}`);
}

// =============================================================================
// Test Connection
// =============================================================================

async function testConnection(piId) {
  try {
    const ssh = await getSSH(piId);
    const result = await ssh.execCommand('echo "Connection OK"');

    return {
      success: result.code === 0,
      message: result.stdout || result.stderr,
      piId
    };
  } catch (error) {
    return {
      success: false,
      message: error.message,
      piId
    };
  }
}

// =============================================================================
// Disconnect
// =============================================================================

function disconnect(piId) {
  const ssh = connections.get(piId);
  if (ssh) {
    ssh.dispose();
    connections.delete(piId);
    console.log(`🔌 Disconnected from ${piId}`);
    return true;
  }
  return false;
}

// =============================================================================
// Disconnect All
// =============================================================================

function disconnectAll() {
  console.log('🔌 Disconnecting all Pis...');

  for (const [piId, ssh] of connections.entries()) {
    ssh.dispose();
  }

  connections.clear();
  console.log('✅ All Pis disconnected');
}

// =============================================================================
// Pair Pi (activate with token)
// =============================================================================

async function pairPi(token) {
  if (!supabaseClient.isEnabled()) {
    throw new Error('Supabase not configured');
  }

  // Find Pi by token
  const pi = await supabaseClient.getPiByToken(token);
  if (!pi) {
    throw new Error('Invalid token or Pi not found');
  }

  if (pi.status === 'active') {
    return {
      success: true,
      message: 'Pi already paired',
      pi: {
        id: pi.id,
        name: pi.name,
        hostname: pi.hostname
      }
    };
  }

  // Test SSH connection before activating
  try {
    const piConfig = {
      id: pi.id,
      name: pi.name,
      host: pi.hostname,
      username: 'pi',
      privateKey: require('os').homedir() + '/.ssh/id_rsa'
    };

    const ssh = new NodeSSH();
    await ssh.connect(piConfig);

    // Test command
    const result = await ssh.execCommand('echo "Connection OK"');
    ssh.dispose();

    if (result.code !== 0) {
      throw new Error('SSH test command failed');
    }

    // Activate Pi
    await supabaseClient.updatePi(pi.id, {
      status: 'active',
      token: null, // Clear token after pairing
      last_seen: new Date().toISOString()
    });

    // Refresh cache
    await refreshPisCache();

    return {
      success: true,
      message: 'Pi paired successfully',
      pi: {
        id: pi.id,
        name: pi.name,
        hostname: pi.hostname
      }
    };
  } catch (error) {
    return {
      success: false,
      message: `SSH connection failed: ${error.message}`,
      pi: {
        id: pi.id,
        name: pi.name,
        hostname: pi.hostname
      }
    };
  }
}

// =============================================================================
// Export Functions
// =============================================================================

module.exports = {
  initPiManager,
  getSSH,
  getPiConfig,
  getAllPis,
  setCurrentPi,
  getCurrentPi,
  getCurrentPiConfig,
  executeCommand,
  uploadFile,
  testConnection,
  disconnect,
  disconnectAll,
  refreshPisCache,
  pairPi
};
