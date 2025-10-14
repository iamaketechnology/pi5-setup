// =============================================================================
// PI5 Admin Panel - SSH Configuration (Example)
// =============================================================================
// Copy this file to config.js and update with your Pi credentials
// config.js is gitignored for security
// =============================================================================

const fs = require('fs');
const path = require('path');
const os = require('os');

module.exports = {
  // Server configuration
  server: {
    port: 4000,
    host: 'localhost'
  },

  // Raspberry Pi SSH configuration
  pi: {
    host: '192.168.1.118',  // Your Pi IP or hostname (pi5.local)
    port: 22,
    username: 'pi',

    // Option 1: SSH Key authentication (recommended)
    privateKey: fs.readFileSync(path.join(os.homedir(), '.ssh', 'id_rsa'), 'utf8'),

    // Option 2: Password authentication (uncomment if needed)
    // password: 'your_password_here',

    // SSH options
    readyTimeout: 20000,
    keepaliveInterval: 10000
  },

  // Project paths
  paths: {
    // Local project root (where pi5-setup repo is)
    projectRoot: path.resolve(__dirname, '../..'),

    // Remote path on Pi where scripts are deployed
    remoteStacksDir: '/home/pi/stacks',
    remoteTempDir: '/tmp'
  },

  // Script discovery patterns
  scripts: {
    // Patterns to find deployment scripts
    patterns: [
      '01-infrastructure/*/scripts/*-deploy.sh',
      '02-securite/*/scripts/*-deploy.sh',
      '03-monitoring/*/scripts/*-deploy.sh',
      '04-developpement/*/scripts/*-deploy.sh'
    ]
  }
};
