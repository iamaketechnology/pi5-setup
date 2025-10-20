// =============================================================================
// SSH Emulator Manager - Backend Service (Professional Edition)
// =============================================================================
// Manages SSH configurations and Pi emulators with robust error handling,
// validation, logging, and security features
// Version: 2.0.0
// Author: PI5-SETUP Project
// =============================================================================

const { exec } = require('child_process');
const { promisify } = require('util');
const path = require('path');
const fs = require('fs').promises;
const fsSync = require('fs');
const os = require('os');

const execAsync = promisify(exec);

// =============================================================================
// Configuration & Constants
// =============================================================================

const CONFIG = {
  SSH: {
    CONNECT_TIMEOUT: 5000,
    MAX_BACKUP_FILES: 10,
    ALLOWED_KEYS: ['HostName', 'Port', 'User', 'IdentityFile', 'PreferredAuthentications']
  },
  EMULATOR: {
    DEPLOY_TIMEOUT: 120000,
    START_TIMEOUT: 30000,
    STOP_TIMEOUT: 30000,
    CONTAINER_NAME_PATTERN: /pi-emulator/
  },
  NETWORK: {
    SCAN_TIMEOUT: 30000,
    SCAN_METHODS: ['nmap', 'arp']
  }
};

// =============================================================================
// Utility Functions
// =============================================================================

/**
 * Logger with structured output
 */
const Logger = {
  info: (msg, data = {}) => console.log('[SSH-EMULATOR-MGR]', msg, data),
  error: (msg, error = {}) => console.error('[SSH-EMULATOR-MGR] ERROR:', msg, error),
  warn: (msg, data = {}) => console.warn('[SSH-EMULATOR-MGR] WARN:', msg, data),
  debug: (msg, data = {}) => {
    if (process.env.DEBUG === 'true') {
      console.debug('[SSH-EMULATOR-MGR] DEBUG:', msg, data);
    }
  }
};

/**
 * Validate hostname/IP
 */
function validateHostname(hostname) {
  if (!hostname || typeof hostname !== 'string') {
    return { valid: false, error: 'Hostname is required' };
  }

  // IP address pattern
  const ipPattern = /^(\d{1,3}\.){3}\d{1,3}$/;
  // Hostname pattern (including .local)
  const hostnamePattern = /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.?$/;

  if (ipPattern.test(hostname)) {
    const parts = hostname.split('.');
    const valid = parts.every(p => parseInt(p) <= 255);
    return valid ? { valid: true } : { valid: false, error: 'Invalid IP address' };
  }

  if (hostnamePattern.test(hostname)) {
    return { valid: true };
  }

  return { valid: false, error: 'Invalid hostname format' };
}

/**
 * Validate SSH port
 */
function validatePort(port) {
  const portNum = parseInt(port);
  if (isNaN(portNum) || portNum < 1 || portNum > 65535) {
    return { valid: false, error: 'Port must be between 1 and 65535' };
  }
  return { valid: true, port: portNum };
}

/**
 * Validate alias (no spaces, alphanumeric + dash/underscore)
 */
function validateAlias(alias) {
  if (!alias || typeof alias !== 'string') {
    return { valid: false, error: 'Alias is required' };
  }

  const aliasPattern = /^[a-zA-Z0-9_-]+$/;
  if (!aliasPattern.test(alias)) {
    return { valid: false, error: 'Alias can only contain letters, numbers, dashes, and underscores' };
  }

  if (alias.length > 64) {
    return { valid: false, error: 'Alias must be less than 64 characters' };
  }

  return { valid: true };
}

/**
 * Safe command execution with timeout
 */
async function safeExec(command, options = {}) {
  const defaultOptions = {
    timeout: 30000,
    maxBuffer: 1024 * 1024 * 10 // 10MB
  };

  try {
    Logger.debug('Executing command', { command, options });
    const result = await execAsync(command, { ...defaultOptions, ...options });
    Logger.debug('Command succeeded', { command, stdout: result.stdout.substring(0, 200) });
    return { success: true, ...result };
  } catch (error) {
    Logger.error('Command failed', { command, error: error.message });
    return {
      success: false,
      error: error.message,
      stdout: error.stdout || '',
      stderr: error.stderr || '',
      code: error.code
    };
  }
}

// =============================================================================
// SSH Emulator Manager Class
// =============================================================================

class SshEmulatorManager {
  constructor() {
    this.projectRoot = path.resolve(__dirname, '../../..');
    this.emulatorPath = path.join(this.projectRoot, 'tools/pi-emulator');
    this.sshConfigPath = path.join(os.homedir(), '.ssh/config');

    Logger.info('SshEmulatorManager initialized', {
      projectRoot: this.projectRoot,
      emulatorPath: this.emulatorPath,
      sshConfigPath: this.sshConfigPath
    });
  }

  // ===========================================================================
  // SSH Configuration Management
  // ===========================================================================

  /**
   * Get current SSH configuration with detailed parsing
   */
  async getSSHConfig() {
    try {
      // Ensure .ssh directory exists
      const sshDir = path.dirname(this.sshConfigPath);
      if (!fsSync.existsSync(sshDir)) {
        Logger.warn('SSH directory does not exist', { sshDir });
        return { success: true, hosts: [], raw: '', path: this.sshConfigPath };
      }

      // Check if config file exists
      if (!fsSync.existsSync(this.sshConfigPath)) {
        Logger.info('SSH config file does not exist yet', { path: this.sshConfigPath });
        return { success: true, hosts: [], raw: '', path: this.sshConfigPath };
      }

      const content = await fs.readFile(this.sshConfigPath, 'utf8');
      const hosts = this.parseSSHConfig(content);

      Logger.info('SSH config loaded', { hostCount: hosts.length });

      return {
        success: true,
        hosts,
        raw: content,
        path: this.sshConfigPath
      };
    } catch (error) {
      Logger.error('Error reading SSH config', error);
      return {
        success: false,
        hosts: [],
        raw: '',
        error: error.message
      };
    }
  }

  /**
   * Parse SSH config file into structured data
   */
  parseSSHConfig(content) {
    const hosts = [];
    const lines = content.split('\n');
    let currentHost = null;
    let lineNumber = 0;

    for (const line of lines) {
      lineNumber++;
      const trimmed = line.trim();

      // Skip empty lines and comments
      if (!trimmed || trimmed.startsWith('#')) {
        continue;
      }

      // Host directive
      if (trimmed.startsWith('Host ')) {
        if (currentHost) {
          hosts.push(currentHost);
        }

        const alias = trimmed.substring(5).trim();
        currentHost = {
          alias,
          config: {},
          lineNumber
        };
      }
      // Configuration options
      else if (currentHost) {
        const match = trimmed.match(/^(\S+)\s+(.+)$/);
        if (match) {
          const [, key, value] = match;
          currentHost.config[key] = value;
        }
      }
    }

    // Add last host
    if (currentHost) {
      hosts.push(currentHost);
    }

    return hosts;
  }

  /**
   * Add SSH host with validation and backup
   */
  async addSSHHost({ alias, hostname, port = 22, username, identityFile }) {
    try {
      // Validate inputs
      const aliasValidation = validateAlias(alias);
      if (!aliasValidation.valid) {
        return { success: false, error: aliasValidation.error };
      }

      const hostnameValidation = validateHostname(hostname);
      if (!hostnameValidation.valid) {
        return { success: false, error: hostnameValidation.error };
      }

      const portValidation = validatePort(port);
      if (!portValidation.valid) {
        return { success: false, error: portValidation.error };
      }

      if (!username || typeof username !== 'string') {
        return { success: false, error: 'Username is required' };
      }

      // Check if alias already exists
      const existingConfig = await this.getSSHConfig();
      if (existingConfig.success) {
        const exists = existingConfig.hosts.some(h => h.alias === alias);
        if (exists) {
          return { success: false, error: 'SSH host alias already exists: ' + alias };
        }
      }

      // Build config lines
      const configLines = [
        '',
        '# Pi Emulator - Added by Control Center on ' + new Date().toISOString(),
        'Host ' + alias,
        '    HostName ' + hostname,
        '    Port ' + portValidation.port,
        '    User ' + username
      ];

      if (identityFile) {
        // Expand ~ in identity file path
        const expandedPath = identityFile.startsWith('~')
          ? path.join(os.homedir(), identityFile.substring(1))
          : identityFile;

        // Verify identity file exists
        if (!fsSync.existsSync(expandedPath)) {
          Logger.warn('Identity file does not exist', { identityFile, expandedPath });
        }

        configLines.push('    IdentityFile ' + identityFile);
        configLines.push('    PreferredAuthentications publickey');
      }

      configLines.push('    StrictHostKeyChecking no');
      configLines.push('    UserKnownHostsFile /dev/null');

      const config = configLines.join('\n') + '\n';

      // Create backup before modifying
      await this.createBackup();

      // Ensure .ssh directory exists
      const sshDir = path.dirname(this.sshConfigPath);
      if (!fsSync.existsSync(sshDir)) {
        await fs.mkdir(sshDir, { recursive: true, mode: 0o700 });
      }

      // Append new host
      await fs.appendFile(this.sshConfigPath, config);

      // Set proper permissions (600)
      await fs.chmod(this.sshConfigPath, 0o600);

      Logger.info('SSH host added successfully', { alias, hostname, port: portValidation.port, username });

      return {
        success: true,
        message: 'SSH host "' + alias + '" added successfully',
        alias,
        hostname,
        port: portValidation.port,
        username
      };
    } catch (error) {
      Logger.error('Error adding SSH host', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Remove SSH host by alias
   */
  async removeSSHHost(alias) {
    try {
      // Validate alias
      const aliasValidation = validateAlias(alias);
      if (!aliasValidation.valid) {
        return { success: false, error: aliasValidation.error };
      }

      if (!fsSync.existsSync(this.sshConfigPath)) {
        return { success: false, error: 'SSH config file not found' };
      }

      const content = await fs.readFile(this.sshConfigPath, 'utf8');
      const lines = content.split('\n');
      const newLines = [];
      let skipUntilNextHost = false;
      let foundHost = false;

      for (const line of lines) {
        const trimmed = line.trim();

        if (trimmed.startsWith('Host ')) {
          const hostAlias = trimmed.substring(5).trim();
          if (hostAlias === alias) {
            skipUntilNextHost = true;
            foundHost = true;
            continue; // Skip the Host line itself
          } else {
            skipUntilNextHost = false;
          }
        }

        if (!skipUntilNextHost) {
          newLines.push(line);
        }
      }

      if (!foundHost) {
        return { success: false, error: 'SSH host not found: ' + alias };
      }

      // Create backup
      await this.createBackup();

      // Write modified config
      await fs.writeFile(this.sshConfigPath, newLines.join('\n'));
      await fs.chmod(this.sshConfigPath, 0o600);

      Logger.info('SSH host removed successfully', { alias });

      return {
        success: true,
        message: 'SSH host "' + alias + '" removed successfully',
        alias
      };
    } catch (error) {
      Logger.error('Error removing SSH host', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Test SSH connection to host
   */
  async testSSHConnection(alias) {
    try {
      const aliasValidation = validateAlias(alias);
      if (!aliasValidation.valid) {
        return { success: false, error: aliasValidation.error };
      }

      Logger.info('Testing SSH connection', { alias });

      const cmd = 'ssh -o ConnectTimeout=' + (CONFIG.SSH.CONNECT_TIMEOUT / 1000) +
                  ' -o StrictHostKeyChecking=no -o BatchMode=yes ' +
                  alias + ' "echo Connection_OK"';

      const result = await safeExec(cmd, { timeout: CONFIG.SSH.CONNECT_TIMEOUT });

      if (result.success && result.stdout.includes('Connection_OK')) {
        Logger.info('SSH connection test successful', { alias });
        return {
          success: true,
          message: 'SSH connection to "' + alias + '" successful',
          output: result.stdout.trim()
        };
      } else {
        Logger.warn('SSH connection test failed', { alias, error: result.error });
        return {
          success: false,
          error: result.error || 'Connection test failed',
          output: result.stderr || result.stdout
        };
      }
    } catch (error) {
      Logger.error('Error testing SSH connection', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Create backup of SSH config
   */
  async createBackup() {
    try {
      if (!fsSync.existsSync(this.sshConfigPath)) {
        return;
      }

      const timestamp = Date.now();
      const backup = this.sshConfigPath + '.bak.' + timestamp;

      await fs.copyFile(this.sshConfigPath, backup);

      // Clean old backups (keep only last N)
      await this.cleanOldBackups();

      Logger.debug('SSH config backup created', { backup });
    } catch (error) {
      Logger.error('Error creating backup', error);
      // Non-fatal, continue
    }
  }

  /**
   * Clean old backup files
   */
  async cleanOldBackups() {
    try {
      const sshDir = path.dirname(this.sshConfigPath);
      const files = await fs.readdir(sshDir);

      const backups = files
        .filter(f => f.startsWith('config.bak.'))
        .map(f => ({
          name: f,
          path: path.join(sshDir, f),
          timestamp: parseInt(f.replace('config.bak.', ''))
        }))
        .sort((a, b) => b.timestamp - a.timestamp);

      // Remove old backups
      const toDelete = backups.slice(CONFIG.SSH.MAX_BACKUP_FILES);

      for (const backup of toDelete) {
        await fs.unlink(backup.path);
        Logger.debug('Old backup deleted', { backup: backup.name });
      }
    } catch (error) {
      Logger.error('Error cleaning old backups', error);
      // Non-fatal
    }
  }

  // ===========================================================================
  // Pi Emulator Management
  // ===========================================================================

  /**
   * Get emulator status with detailed info
   */
  async getEmulatorStatus() {
    try {
      const cmd = 'docker ps --filter "name=pi-emulator" --format "{{.Names}}\t{{.Status}}\t{{.Ports}}"';
      const result = await safeExec(cmd);

      if (!result.success) {
        return {
          success: false,
          running: false,
          status: 'error',
          error: result.error
        };
      }

      if (!result.stdout.trim()) {
        Logger.debug('No emulator container running');
        return {
          success: true,
          running: false,
          status: 'stopped'
        };
      }

      const parts = result.stdout.trim().split('\t');
      const name = parts[0] || '';
      const status = parts[1] || '';
      const ports = parts[2] || '';

      Logger.info('Emulator status retrieved', { name, status });

      return {
        success: true,
        running: true,
        name,
        status,
        ports,
        container: name
      };
    } catch (error) {
      Logger.error('Error getting emulator status', error);
      return {
        success: false,
        running: false,
        status: 'error',
        error: error.message
      };
    }
  }

  /**
   * Deploy emulator on remote Linux host
   */
  async deployEmulator({ targetHost, targetUser }) {
    try {
      // Validate inputs
      const hostnameValidation = validateHostname(targetHost);
      if (!hostnameValidation.valid) {
        return { success: false, error: hostnameValidation.error };
      }

      if (!targetUser || typeof targetUser !== 'string') {
        return { success: false, error: 'Target user is required' };
      }

      const scriptPath = path.join(this.emulatorPath, 'scripts/01-pi-emulator-deploy-linux.sh');

      if (!fsSync.existsSync(scriptPath)) {
        Logger.error('Deployment script not found', { scriptPath });
        return {
          success: false,
          error: 'Deployment script not found at: ' + scriptPath
        };
      }

      Logger.info('Deploying emulator', { targetHost, targetUser });

      const cmd = 'cat ' + scriptPath + ' | ssh ' + targetUser + '@' + targetHost + ' "bash -s"';

      const result = await safeExec(cmd, { timeout: CONFIG.EMULATOR.DEPLOY_TIMEOUT });

      if (result.success) {
        Logger.info('Emulator deployed successfully', { targetHost });
        return {
          success: true,
          message: 'Emulator deployed successfully on ' + targetHost,
          output: result.stdout,
          errors: result.stderr
        };
      } else {
        Logger.error('Emulator deployment failed', { targetHost, error: result.error });
        return {
          success: false,
          error: result.error,
          output: result.stdout,
          errors: result.stderr
        };
      }
    } catch (error) {
      Logger.error('Error deploying emulator', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Start emulator (local or remote)
   */
  async startEmulator({ remote = false, remoteHost }) {
    try {
      let cmd;

      if (remote && remoteHost) {
        const hostnameValidation = validateHostname(remoteHost);
        if (!hostnameValidation.valid) {
          return { success: false, error: hostnameValidation.error };
        }

        cmd = 'ssh ' + remoteHost + ' "cd ~/pi-emulator && docker compose up -d"';
        Logger.info('Starting remote emulator', { remoteHost });
      } else {
        if (!fsSync.existsSync(this.emulatorPath + '/compose')) {
          return { success: false, error: 'Emulator compose directory not found' };
        }

        cmd = 'cd ' + this.emulatorPath + '/compose && docker compose up -d';
        Logger.info('Starting local emulator');
      }

      const result = await safeExec(cmd, { timeout: CONFIG.EMULATOR.START_TIMEOUT });

      if (result.success) {
        Logger.info('Emulator started successfully', { remote });
        return {
          success: true,
          message: remote ? 'Remote emulator started' : 'Emulator started locally',
          output: result.stdout
        };
      } else {
        Logger.error('Failed to start emulator', { remote, error: result.error });
        return {
          success: false,
          error: result.error,
          output: result.stderr
        };
      }
    } catch (error) {
      Logger.error('Error starting emulator', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Stop emulator (local or remote)
   */
  async stopEmulator({ remote = false, remoteHost }) {
    try {
      let cmd;

      if (remote && remoteHost) {
        const hostnameValidation = validateHostname(remoteHost);
        if (!hostnameValidation.valid) {
          return { success: false, error: hostnameValidation.error };
        }

        cmd = 'ssh ' + remoteHost + ' "cd ~/pi-emulator && docker compose down"';
        Logger.info('Stopping remote emulator', { remoteHost });
      } else {
        cmd = 'cd ' + this.emulatorPath + '/compose && docker compose down';
        Logger.info('Stopping local emulator');
      }

      const result = await safeExec(cmd, { timeout: CONFIG.EMULATOR.STOP_TIMEOUT });

      if (result.success) {
        Logger.info('Emulator stopped successfully', { remote });
        return {
          success: true,
          message: remote ? 'Remote emulator stopped' : 'Emulator stopped locally',
          output: result.stdout
        };
      } else {
        Logger.error('Failed to stop emulator', { remote, error: result.error });
        return {
          success: false,
          error: result.error,
          output: result.stderr
        };
      }
    } catch (error) {
      Logger.error('Error stopping emulator', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Get emulator connection information
   */
  async getEmulatorInfo({ remoteHost }) {
    try {
      const scriptPath = path.join(this.emulatorPath, 'scripts/get-emulator-info.sh');

      if (!fsSync.existsSync(scriptPath)) {
        Logger.error('Info script not found', { scriptPath });
        return {
          success: false,
          error: 'Info script not found at: ' + scriptPath
        };
      }

      let cmd;
      if (remoteHost) {
        const hostnameValidation = validateHostname(remoteHost);
        if (!hostnameValidation.valid) {
          return { success: false, error: hostnameValidation.error };
        }

        cmd = 'cat ' + scriptPath + ' | ssh ' + remoteHost + ' "bash -s"';
        Logger.info('Getting remote emulator info', { remoteHost });
      } else {
        cmd = 'bash ' + scriptPath;
        Logger.info('Getting local emulator info');
      }

      const result = await safeExec(cmd);

      if (result.success) {
        return {
          success: true,
          output: result.stdout
        };
      } else {
        return {
          success: false,
          error: result.error,
          output: result.stderr
        };
      }
    } catch (error) {
      Logger.error('Error getting emulator info', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  // ===========================================================================
  // Network Utilities
  // ===========================================================================

  /**
   * Scan local network for devices
   */
  async scanNetwork() {
    try {
      Logger.info('Starting network scan');

      // Get local subnet
      const ifconfigCmd = "ifconfig en0 2>/dev/null | grep 'inet ' | awk '{print $2}'";
      const ifconfigResult = await safeExec(ifconfigCmd);

      if (!ifconfigResult.success || !ifconfigResult.stdout.trim()) {
        Logger.warn('Could not detect local IP from en0, trying en1');
        const ifconfig2Cmd = "ifconfig en1 2>/dev/null | grep 'inet ' | awk '{print $2}'";
        const ifconfig2Result = await safeExec(ifconfig2Cmd);

        if (!ifconfig2Result.success || !ifconfig2Result.stdout.trim()) {
          return { success: false, error: 'Could not detect local IP address' };
        }
      }

      const localIP = ifconfigResult.stdout.trim();
      const subnet = localIP.substring(0, localIP.lastIndexOf('.'));

      Logger.info('Detected subnet', { localIP, subnet });

      // Try nmap first
      const nmapCmd = 'nmap -sn ' + subnet + '.0/24 -oG - 2>/dev/null | grep "Up" | awk \'{print $2}\'';
      const nmapResult = await safeExec(nmapCmd, { timeout: CONFIG.NETWORK.SCAN_TIMEOUT });

      if (nmapResult.success && nmapResult.stdout.trim()) {
        const devices = nmapResult.stdout.trim().split('\n').filter(ip => ip && ip !== '');

        Logger.info('Network scan completed via nmap', { deviceCount: devices.length });

        return {
          success: true,
          devices,
          method: 'nmap',
          subnet
        };
      }

      // Fallback to arp
      Logger.info('nmap failed or unavailable, falling back to arp');

      const arpCmd = 'arp -a 2>/dev/null | grep "(' + subnet + '." | awk \'{print $2}\' | tr -d "()"';
      const arpResult = await safeExec(arpCmd);

      if (arpResult.success) {
        const devices = arpResult.stdout.trim().split('\n').filter(ip => ip && ip !== '');

        Logger.info('Network scan completed via arp', { deviceCount: devices.length });

        return {
          success: true,
          devices,
          method: 'arp',
          subnet
        };
      }

      return {
        success: false,
        error: 'Both nmap and arp scan methods failed',
        details: {
          nmap: nmapResult.error,
          arp: arpResult.error
        }
      };
    } catch (error) {
      Logger.error('Error scanning network', error);
      return {
        success: false,
        error: error.message
      };
    }
  }
}

// =============================================================================
// Export
// =============================================================================

module.exports = { SshEmulatorManager };
