// =============================================================================
// SSH Emulator Manager - Backend Service
// =============================================================================
// Manages SSH configurations and Pi emulators
// Version: 1.0.0
// =============================================================================

const { exec } = require('child_process');
const { promisify } = require('util');
const path = require('path');
const fs = require('fs');
const os = require('os');

const execAsync = promisify(exec);

class SshEmulatorManager {
  constructor() {
    this.projectRoot = path.resolve(__dirname, '../..');
    this.emulatorPath = path.join(this.projectRoot, 'tools/pi-emulator');
    this.sshConfigPath = path.join(os.homedir(), '.ssh/config');
  }

  // ===========================================================================
  // SSH Configuration Management
  // ===========================================================================

  /**
   * Get current SSH configuration
   */
  async getSSHConfig() {
    try {
      if (!fs.existsSync(this.sshConfigPath)) {
        return { hosts: [], raw: '' };
      }

      const content = fs.readFileSync(this.sshConfigPath, 'utf8');
      const hosts = this.parseSSHConfig(content);

      return {
        hosts,
        raw: content,
        path: this.sshConfigPath
      };
    } catch (error) {
      console.error('Error reading SSH config:', error);
      return { hosts: [], raw: '', error: error.message };
    }
  }

  /**
   * Parse SSH config file into structured data
   */
  parseSSHConfig(content) {
    const hosts = [];
    const lines = content.split('\n');
    let currentHost = null;

    for (const line of lines) {
      const trimmed = line.trim();

      // Host directive
      if (trimmed.startsWith('Host ')) {
        if (currentHost) {
          hosts.push(currentHost);
        }
        currentHost = {
          alias: trimmed.substring(5).trim(),
          config: {}
        };
      }
      // Configuration options
      else if (currentHost && trimmed && !trimmed.startsWith('#')) {
        const match = trimmed.match(/^(\S+)\s+(.+)$/);
        if (match) {
          const [, key, value] = match;
          currentHost.config[key] = value;
        }
      }
    }

    if (currentHost) {
      hosts.push(currentHost);
    }

    return hosts;
  }

  /**
   * Add SSH host configuration
   */
  async addSSHHost({ alias, hostname, port = 22, username, identityFile, password }) {
    try {
      const config = \`
# Pi Emulator - Added by Control Center
Host ${alias}
    HostName ${hostname}
    Port ${port}
    User ${username}`;

      const configWithKey = identityFile
        ? `${config}
    IdentityFile ${identityFile}
    PreferredAuthentications publickey`
        : config;

      // Backup existing config
      if (fs.existsSync(this.sshConfigPath)) {
        const backup = `${this.sshConfigPath}.bak.${Date.now()}`;
        fs.copyFileSync(this.sshConfigPath, backup);
      }

      // Append new host
      fs.appendFileSync(this.sshConfigPath, `\n${configWithKey}\n`);

      return {
        success: true,
        message: `SSH host '${alias}' added successfully`,
        alias
      };
    } catch (error) {
      console.error('Error adding SSH host:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Remove SSH host configuration
   */
  async removeSSHHost(alias) {
    try {
      if (!fs.existsSync(this.sshConfigPath)) {
        return { success: false, error: 'SSH config file not found' };
      }

      const content = fs.readFileSync(this.sshConfigPath, 'utf8');
      const lines = content.split('\n');
      const newLines = [];
      let skipUntilNextHost = false;

      for (const line of lines) {
        if (line.trim().startsWith('Host ')) {
          const hostAlias = line.trim().substring(5).trim();
          skipUntilNextHost = (hostAlias === alias);
        }

        if (!skipUntilNextHost) {
          newLines.push(line);
        }
      }

      // Backup and write
      const backup = `${this.sshConfigPath}.bak.${Date.now()}`;
      fs.copyFileSync(this.sshConfigPath, backup);
      fs.writeFileSync(this.sshConfigPath, newLines.join('\n'));

      return {
        success: true,
        message: `SSH host '${alias}' removed successfully`
      };
    } catch (error) {
      console.error('Error removing SSH host:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Test SSH connection
   */
  async testSSHConnection(alias) {
    try {
      const { stdout, stderr } = await execAsync(`ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${alias} "echo 'Connection OK'"`);

      return {
        success: true,
        message: 'SSH connection successful',
        output: stdout.trim()
      };
    } catch (error) {
      return {
        success: false,
        error: error.message,
        output: error.stderr || error.stdout
      };
    }
  }

  // ===========================================================================
  // Pi Emulator Management
  // ===========================================================================

  /**
   * Get emulator status
   */
  async getEmulatorStatus() {
    try {
      const { stdout } = await execAsync('docker ps --filter "name=pi-emulator" --format "{{.Names}}\t{{.Status}}\t{{.Ports}}"');

      if (!stdout.trim()) {
        return {
          running: false,
          status: 'stopped'
        };
      }

      const [name, status, ports] = stdout.trim().split('\t');

      return {
        running: true,
        name,
        status,
        ports,
        container: name
      };
    } catch (error) {
      return {
        running: false,
        status: 'error',
        error: error.message
      };
    }
  }

  /**
   * Deploy emulator on remote Linux host
   */
  async deployEmulator({ targetHost, targetUser, targetPassword }) {
    try {
      const scriptPath = path.join(this.emulatorPath, 'scripts/01-pi-emulator-deploy-linux.sh');

      if (!fs.existsSync(scriptPath)) {
        return {
          success: false,
          error: 'Deployment script not found'
        };
      }

      // Execute deployment script via SSH
      const command = `cat ${scriptPath} | ssh ${targetUser}@${targetHost} "bash -s"`;

      const { stdout, stderr } = await execAsync(command, { timeout: 120000 }); // 2 min timeout

      return {
        success: true,
        message: 'Emulator deployed successfully',
        output: stdout,
        errors: stderr
      };
    } catch (error) {
      return {
        success: false,
        error: error.message,
        output: error.stdout,
        errors: error.stderr
      };
    }
  }

  /**
   * Start emulator (local or remote)
   */
  async startEmulator({ remote = false, remoteHost }) {
    try {
      if (remote && remoteHost) {
        const command = `ssh ${remoteHost} "cd ~/pi-emulator && docker compose up -d"`;
        const { stdout } = await execAsync(command);
        return {
          success: true,
          message: 'Remote emulator started',
          output: stdout
        };
      } else {
        const command = `cd ${this.emulatorPath}/compose && docker compose up -d`;
        const { stdout } = await execAsync(command);
        return {
          success: true,
          message: 'Emulator started locally',
          output: stdout
        };
      }
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Stop emulator
   */
  async stopEmulator({ remote = false, remoteHost }) {
    try {
      if (remote && remoteHost) {
        const command = `ssh ${remoteHost} "cd ~/pi-emulator && docker compose down"`;
        const { stdout } = await execAsync(command);
        return {
          success: true,
          message: 'Remote emulator stopped',
          output: stdout
        };
      } else {
        const command = `cd ${this.emulatorPath}/compose && docker compose down`;
        const { stdout } = await execAsync(command);
        return {
          success: true,
          message: 'Emulator stopped locally',
          output: stdout
        };
      }
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Get emulator connection info
   */
  async getEmulatorInfo({ remoteHost }) {
    try {
      const scriptPath = path.join(this.emulatorPath, 'scripts/get-emulator-info.sh');

      if (!fs.existsSync(scriptPath)) {
        return {
          success: false,
          error: 'Info script not found'
        };
      }

      const command = remoteHost
        ? `cat ${scriptPath} | ssh ${remoteHost} "bash -s"`
        : `bash ${scriptPath}`;

      const { stdout } = await execAsync(command);

      return {
        success: true,
        output: stdout
      };
    } catch (error) {
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
      // Get local subnet
      const { stdout: ifconfigOut } = await execAsync('ifconfig en0 | grep "inet " | awk '{print $2}'');
      const localIP = ifconfigOut.trim();

      if (!localIP) {
        return { success: false, error: 'Could not detect local IP' };
      }

      const subnet = localIP.substring(0, localIP.lastIndexOf('.'));

      // Try nmap first
      try {
        const { stdout } = await execAsync(`nmap -sn ${subnet}.0/24 -oG - | grep "Up" | awk '{print $2}'`, { timeout: 30000 });
        const devices = stdout.trim().split('\n').filter(ip => ip);

        return {
          success: true,
          devices,
          method: 'nmap'
        };
      } catch {
        // Fallback to arp-scan or simple ping
        const { stdout } = await execAsync(`arp -a | grep "${subnet}" | awk '{print $2}' | tr -d '()'`);
        const devices = stdout.trim().split('\n').filter(ip => ip);

        return {
          success: true,
          devices,
          method: 'arp'
        };
      }
    } catch (error) {
      return {
        success: false,
        error: error.message
      };
    }
  }
}

module.exports = { SshEmulatorManager };
