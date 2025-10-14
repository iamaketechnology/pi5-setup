// =============================================================================
// PI5 Control Center - Pi Manager Module
// =============================================================================
// Manages multiple Pi connections and switches between them
// Version: 3.0.0
// =============================================================================

const { NodeSSH } = require('node-ssh');

const connections = new Map(); // Map of Pi ID -> SSH connection
let config = null;
let currentPiId = null;

// =============================================================================
// Initialize Pi Manager
// =============================================================================

function initPiManager(appConfig) {
  config = appConfig;
  currentPiId = config.defaultPi;

  console.log('🔗 Pi Manager initialized');
  console.log(`  • ${config.pis.length} Pi(s) configured`);
  console.log(`  • Default Pi: ${currentPiId}`);
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
// Get Pi Configuration
// =============================================================================

function getPiConfig(piId) {
  return config.pis.find(pi => pi.id === piId);
}

// =============================================================================
// Get All Pis
// =============================================================================

function getAllPis() {
  return config.pis.map(pi => ({
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
  disconnectAll
};
