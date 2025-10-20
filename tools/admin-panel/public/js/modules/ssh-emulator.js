// =============================================================================
// SSH & Emulator Manager Module
// =============================================================================
// Manages SSH configurations and Pi emulators from the UI
// Version: 1.0.0
// =============================================================================

class SshEmulatorModule {
  constructor() {
    this.currentView = 'ssh-config';
  }

  async init() {
    this.setupEventListeners();
    await this.loadSSHConfig();
    await this.loadEmulatorStatus();
    await this.updateBootstrapCommand();
  }

  setupEventListeners() {
    // View switcher
    document.querySelectorAll('[data-ssh-view]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const view = e.currentTarget.dataset.sshView;
        this.switchView(view);
      });
    });

    // SSH Config actions
    document.getElementById('btn-add-ssh-host')?.addEventListener('click', () => this.showAddSSHHostModal());
    document.getElementById('btn-scan-network')?.addEventListener('click', () => this.scanNetwork());
    document.getElementById('form-add-ssh-host')?.addEventListener('submit', (e) => this.handleAddSSHHost(e));

    // Emulator actions
    document.getElementById('btn-deploy-emulator')?.addEventListener('click', () => this.showDeployEmulatorModal());
    document.getElementById('btn-start-emulator')?.addEventListener('click', () => this.startEmulator());
    document.getElementById('btn-stop-emulator')?.addEventListener('click', () => this.stopEmulator());
    document.getElementById('btn-get-emulator-info')?.addEventListener('click', () => this.getEmulatorInfo());
    document.getElementById('form-deploy-emulator')?.addEventListener('submit', (e) => this.handleDeployEmulator(e));

    // Bootstrap actions
    document.getElementById('btn-copy-bootstrap')?.addEventListener('click', () => this.copyBootstrapCommand());
    document.getElementById('btn-generate-qr')?.addEventListener('click', () => this.generateBootstrapQR());
  }

  switchView(view) {
    this.currentView = view;

    // Update buttons
    document.querySelectorAll('[data-ssh-view]').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.sshView === view);
    });

    // Update content
    document.querySelectorAll('[data-ssh-content]').forEach(content => {
      content.classList.toggle('hidden', content.dataset.sshContent !== view);
    });
  }

  // ===========================================================================
  // SSH Configuration
  // ===========================================================================

  async loadSSHConfig() {
    try {
      const response = await fetch('/api/ssh/config');
      const data = await response.json();

      if (data.success) {
        this.renderSSHHosts(data.hosts);
      } else {
        this.showError('Failed to load SSH config');
      }
    } catch (error) {
      console.error('Error loading SSH config:', error);
      this.showError('Error loading SSH config');
    }
  }

  renderSSHHosts(hosts) {
    const container = document.getElementById('ssh-hosts-list');
    if (!container) return;

    if (hosts.length === 0) {
      container.innerHTML = '<div class="empty-state">No SSH hosts configured</div>';
      return;
    }

    container.innerHTML = hosts.map(host => `
      <div class="ssh-host-card">
        <div class="ssh-host-header">
          <h4>${host.alias}</h4>
          <div class="ssh-host-actions">
            <button class="btn-icon" onclick="sshEmulatorModule.testSSHConnection('${host.alias}')" title="Test">
              <i data-lucide="check-circle" size="16"></i>
            </button>
            <button class="btn-icon" onclick="sshEmulatorModule.removeSSHHost('${host.alias}')" title="Remove">
              <i data-lucide="trash-2" size="16"></i>
            </button>
          </div>
        </div>
        <div class="ssh-host-info">
          <div><strong>Host:</strong> ${host.config.HostName || 'N/A'}</div>
          <div><strong>Port:</strong> ${host.config.Port || '22'}</div>
          <div><strong>User:</strong> ${host.config.User || 'N/A'}</div>
          <div><strong>Auth:</strong> ${host.config.IdentityFile ? 'Key' : 'Password'}</div>
        </div>
      </div>
    `).join('');

    // Re-render lucide icons
    if (window.lucide) lucide.createIcons();
  }

  showAddSSHHostModal() {
    const modal = document.getElementById('modal-add-ssh-host');
    if (modal) modal.classList.remove('hidden');
  }

  async handleAddSSHHost(e) {
    e.preventDefault();
    const formData = new FormData(e.target);

    try {
      const response = await fetch('/api/ssh/hosts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          alias: formData.get('alias'),
          hostname: formData.get('hostname'),
          port: formData.get('port') || 22,
          username: formData.get('username'),
          identityFile: formData.get('identityFile') || null
        })
      });

      const data = await response.json();

      if (data.success) {
        this.showSuccess('SSH host added successfully');
        document.getElementById('modal-add-ssh-host')?.classList.add('hidden');
        e.target.reset();
        await this.loadSSHConfig();
      } else {
        this.showError(data.error || 'Failed to add SSH host');
      }
    } catch (error) {
      console.error('Error adding SSH host:', error);
      this.showError('Error adding SSH host');
    }
  }

  async removeSSHHost(alias) {
    if (!confirm(`Remove SSH host '${alias}'?`)) return;

    try {
      const response = await fetch(`/api/ssh/hosts/${alias}`, { method: 'DELETE' });
      const data = await response.json();

      if (data.success) {
        this.showSuccess('SSH host removed');
        await this.loadSSHConfig();
      } else {
        this.showError(data.error || 'Failed to remove SSH host');
      }
    } catch (error) {
      console.error('Error removing SSH host:', error);
      this.showError('Error removing SSH host');
    }
  }

  async testSSHConnection(alias) {
    try {
      const response = await fetch(`/api/ssh/test/${alias}`, { method: 'POST' });
      const data = await response.json();

      if (data.success) {
        this.showSuccess(`SSH connection to '${alias}' successful!`);
      } else {
        this.showError(`SSH connection failed: ${data.error}`);
      }
    } catch (error) {
      console.error('Error testing SSH connection:', error);
      this.showError('Error testing SSH connection');
    }
  }

  async scanNetwork() {
    const btn = document.getElementById('btn-scan-network');
    if (btn) btn.disabled = true;

    try {
      const response = await fetch('/api/network/scan');
      const data = await response.json();

      if (data.success) {
        this.showNetworkScanResults(data.devices);
      } else {
        this.showError(data.error || 'Network scan failed');
      }
    } catch (error) {
      console.error('Error scanning network:', error);
      this.showError('Error scanning network');
    } finally {
      if (btn) btn.disabled = false;
    }
  }

  showNetworkScanResults(devices) {
    const resultsDiv = document.getElementById('network-scan-results');
    if (!resultsDiv) return;

    if (devices.length === 0) {
      resultsDiv.innerHTML = `
        <div class="scan-results-empty">
          <p>Aucun appareil trouvé sur le réseau</p>
        </div>
      `;
      return;
    }

    resultsDiv.innerHTML = `
      <div class="scan-results-header">
        <h4>Appareils détectés (${devices.length})</h4>
        <p class="scan-hint">Cliquez sur une IP pour ajouter un host SSH</p>
      </div>
      <div class="network-devices-grid">
        ${devices.map(ip => `
          <div class="network-device-card" onclick="sshEmulatorModule.quickAddHost('${ip}')">
            <div class="device-icon">🖥️</div>
            <div class="device-ip">${ip}</div>
            <div class="device-action">
              <i data-lucide="plus-circle" size="16"></i>
              <span>Ajouter</span>
            </div>
          </div>
        `).join('')}
      </div>
    `;

    // Refresh lucide icons
    if (window.lucide) window.lucide.createIcons();
  }

  /**
   * Quick add host from network scan with auto-credential detection
   */
  async quickAddHost(ip) {
    const suggestedAlias = 'pi-' + ip.split('.').pop();

    // Show loading notification
    this.showInfo('Tentative de connexion automatique à ' + ip + '...');

    // Try to add with default SSH key first
    try {
      const response = await fetch('/api/ssh/hosts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          alias: suggestedAlias,
          hostname: ip,
          port: 22,
          username: 'pi',
          identityFile: '~/.ssh/id_rsa'  // Try default SSH key
        })
      });

      const data = await response.json();

      if (data.success) {
        // Test the connection
        const testResponse = await fetch(`/api/ssh/test/${suggestedAlias}`, { method: 'POST' });
        const testData = await testResponse.json();

        if (testData.success) {
          // Auto-connection successful!
          this.showSuccess(`Pi ajouté automatiquement : ${suggestedAlias} (${ip})`);
          await this.loadSSHConfig();
          return;
        } else {
          // Connection failed, remove the failed host and ask for credentials
          await fetch(`/api/ssh/hosts/${suggestedAlias}`, { method: 'DELETE' });
          this.showWarning('Connexion SSH échouée, veuillez renseigner les credentials');
        }
      }
    } catch (error) {
      console.log('Auto-connection failed, asking for credentials:', error);
    }

    // If we get here, auto-connection failed - show modal with credentials form
    this.showManualCredentialsForm(ip, suggestedAlias);
  }

  /**
   * Show manual credentials form when auto-connection fails
   */
  showManualCredentialsForm(ip, suggestedAlias) {
    const modal = document.getElementById('modal-add-ssh-host');
    if (!modal) return;

    // Pre-fill hostname field
    const hostnameInput = document.getElementById('ssh-hostname');
    if (hostnameInput) hostnameInput.value = ip;

    // Pre-fill alias
    const aliasInput = document.getElementById('ssh-alias');
    if (aliasInput) aliasInput.value = suggestedAlias;

    // Pre-fill default username
    const usernameInput = document.getElementById('ssh-username');
    if (usernameInput) usernameInput.value = 'pi';

    // Pre-fill default port
    const portInput = document.getElementById('ssh-port');
    if (portInput) portInput.value = '22';

    // Clear identity file (since auto-connect failed)
    const identityFileInput = document.getElementById('ssh-identity-file');
    if (identityFileInput) identityFileInput.value = '';

    // Show modal
    modal.classList.remove('hidden');

    // Focus on identity file field
    setTimeout(() => {
      if (identityFileInput) identityFileInput.focus();
    }, 100);
  }

  // ===========================================================================
  // Pi Emulator Management
  // ===========================================================================

  async loadEmulatorStatus() {
    try {
      const response = await fetch('/api/emulator/status');
      const data = await response.json();

      if (data.success) {
        this.renderEmulatorStatus(data);
      }
    } catch (error) {
      console.error('Error loading emulator status:', error);
    }
  }

  renderEmulatorStatus(status) {
    const statusBadge = document.getElementById('emulator-status-badge');
    const statusText = document.getElementById('emulator-status-text');

    if (statusBadge) {
      statusBadge.className = `status-badge ${status.running ? 'status-success' : 'status-inactive'}`;
      statusBadge.textContent = status.running ? 'Running' : 'Stopped';
    }

    if (statusText) {
      statusText.textContent = status.running ? `Container: ${status.name}` : 'No emulator running';
    }
  }

  showDeployEmulatorModal() {
    const modal = document.getElementById('modal-deploy-emulator');
    if (modal) modal.classList.remove('hidden');
  }

  async handleDeployEmulator(e) {
    e.preventDefault();
    const formData = new FormData(e.target);

    try {
      const response = await fetch('/api/emulator/deploy', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          targetHost: formData.get('targetHost'),
          targetUser: formData.get('targetUser'),
          targetPassword: formData.get('targetPassword')
        })
      });

      const data = await response.json();

      if (data.success) {
        this.showSuccess('Emulator deployed successfully');
        document.getElementById('modal-deploy-emulator')?.classList.add('hidden');
        e.target.reset();
        await this.loadEmulatorStatus();
      } else {
        this.showError(data.error || 'Failed to deploy emulator');
      }
    } catch (error) {
      console.error('Error deploying emulator:', error);
      this.showError('Error deploying emulator');
    }
  }

  async startEmulator() {
    try {
      const response = await fetch('/api/emulator/start', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ remote: false })
      });

      const data = await response.json();

      if (data.success) {
        this.showSuccess('Emulator started');
        await this.loadEmulatorStatus();
      } else {
        this.showError(data.error || 'Failed to start emulator');
      }
    } catch (error) {
      console.error('Error starting emulator:', error);
      this.showError('Error starting emulator');
    }
  }

  async stopEmulator() {
    if (!confirm('Stop the emulator?')) return;

    try {
      const response = await fetch('/api/emulator/stop', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ remote: false })
      });

      const data = await response.json();

      if (data.success) {
        this.showSuccess('Emulator stopped');
        await this.loadEmulatorStatus();
      } else {
        this.showError(data.error || 'Failed to stop emulator');
      }
    } catch (error) {
      console.error('Error stopping emulator:', error);
      this.showError('Error stopping emulator');
    }
  }

  async getEmulatorInfo() {
    try {
      const response = await fetch('/api/emulator/info');
      const data = await response.json();

      if (data.success) {
        this.showEmulatorInfo(data.output);
      } else {
        this.showError(data.error || 'Failed to get emulator info');
      }
    } catch (error) {
      console.error('Error getting emulator info:', error);
      this.showError('Error getting emulator info');
    }
  }

  showEmulatorInfo(output) {
    const infoDiv = document.getElementById('emulator-info-display');
    if (!infoDiv) return;

    infoDiv.innerHTML = `<pre>${output}</pre>`;
  }

  // ===========================================================================
  // Bootstrap Commands
  // ===========================================================================

  /**
   * Update bootstrap command with real IP address
   */
  async updateBootstrapCommand() {
    try {
      // Get local IP from server
      const response = await fetch('/api/network/local-ip');
      const data = await response.json();

      const ip = data.success && data.ip ? data.ip : window.location.hostname;
      const port = window.location.port || '4000';
      const protocol = window.location.protocol;

      const bootstrapUrl = `${protocol}//${ip}:${port}/bootstrap`;
      const command = `curl -fsSL ${bootstrapUrl} | sudo bash`;

      const commandElement = document.getElementById('bootstrap-command-text');
      if (commandElement) {
        commandElement.textContent = command;
      }

      console.log('Bootstrap command updated:', command);
    } catch (error) {
      console.error('Error updating bootstrap command:', error);
      // Fallback to localhost
      const command = `curl -fsSL http://localhost:4000/bootstrap | sudo bash`;
      const commandElement = document.getElementById('bootstrap-command-text');
      if (commandElement) {
        commandElement.textContent = command;
      }
    }
  }

  async copyBootstrapCommand() {
    const command = document.getElementById('bootstrap-command-text')?.textContent;
    if (!command) return;

    try {
      await navigator.clipboard.writeText(command);
      this.showSuccess('Bootstrap command copied to clipboard');
    } catch (error) {
      console.error('Error copying to clipboard:', error);
      this.showError('Failed to copy to clipboard');
    }
  }

  async generateBootstrapQR() {
    this.showInfo('QR code generation not yet implemented');
  }

  // ===========================================================================
  // UI Helpers
  // ===========================================================================

  showSuccess(message) {
    this.showNotification(message, 'success');
  }

  showError(message) {
    this.showNotification(message, 'error');
  }

  showInfo(message) {
    this.showNotification(message, 'info');
  }

  showWarning(message) {
    this.showNotification(message, 'warning');
  }

  showNotification(message, type = 'info') {
    // Use existing notification system if available
    if (window.showNotification) {
      window.showNotification(message, type);
    } else {
      console.log(`[${type.toUpperCase()}] ${message}`);
    }
  }
}

// Export global instance
window.sshEmulatorModule = new SshEmulatorModule();

export default SshEmulatorModule;
