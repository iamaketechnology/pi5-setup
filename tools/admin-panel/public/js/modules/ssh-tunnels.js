// =============================================================================
// SSH Tunnels Manager Module
// =============================================================================
// Version: 2.0.0 - Refactored to use TunnelService
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

import api from '../utils/api.js';
import tunnelService from '../utils/tunnel-service.js';

/**
 * SSHTunnelsManager - Manages SSH tunnels to Pi services
 */
class SSHTunnelsManager {
    constructor() {
        this.tunnels = [];
        this.refreshInterval = null;
        this.tunnelService = tunnelService;
    }

    /**
     * Initialize SSH tunnels module
     */
    init() {
        this.setupEventListeners();
        this.load();
        this.startAutoRefresh();
        console.log('✅ SSH Tunnels module initialized');
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Form submit
        const form = document.getElementById('create-tunnel-form');
        if (form) {
            form.addEventListener('submit', async (e) => {
                e.preventDefault();
                const formData = new FormData(form);
                try {
                    await this.create(formData);
                } catch (error) {
                    console.error('Failed to create tunnel:', error);
                }
            });
        }
    }

    /**
     * Load active tunnels
     */
    async load() {
        try {
            this.tunnels = await this.tunnelService.getTunnels(true); // Force refresh

            // Render in all available containers
            this.render(); // Default container (ssh-tunnels-list)

            // Also render in Network tab container if it exists
            if (document.getElementById('ssh-tunnels-list-network')) {
                this.render('ssh-tunnels-list-network');
            }
        } catch (error) {
            console.error('Failed to load SSH tunnels:', error);
            if (window.toastManager) {
                window.toastManager.error('Erreur chargement tunnels SSH');
            }
        }
    }

    /**
     * Render tunnels list
     * @param {string} containerId - Optional container ID (defaults to 'ssh-tunnels-list')
     */
    render(containerId = 'ssh-tunnels-list') {
        const container = document.getElementById(containerId);
        if (!container) return;

        if (this.tunnels.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <i data-lucide="network" size="48"></i>
                    <h3>Aucun tunnel SSH actif</h3>
                    <p>Créez un tunnel pour accéder à vos services de manière sécurisée</p>
                    <button class="btn btn-primary" onclick="window.sshTunnelsManager.showCreateModal()">
                        <i data-lucide="plus" size="16"></i>
                        <span>Créer un tunnel</span>
                    </button>
                </div>
            `;
            if (window.lucide) window.lucide.createIcons();
            return;
        }

        container.innerHTML = this.tunnels.map(tunnel => `
            <div class="tunnel-card ${tunnel.status}" data-tunnel-id="${tunnel.id}">
                <div class="tunnel-header">
                    <div class="tunnel-icon">
                        <i data-lucide="${this.getServiceIcon(tunnel.service)}" size="20"></i>
                    </div>
                    <div class="tunnel-info">
                        <div class="tunnel-name">${tunnel.name}</div>
                        <div class="tunnel-service">${tunnel.service}</div>
                    </div>
                    <div class="tunnel-status">
                        <span class="status-badge ${tunnel.status}">
                            ${tunnel.status === 'active' ? '🟢 Actif' : '🔴 Inactif'}
                        </span>
                    </div>
                </div>

                <div class="tunnel-details">
                    <div class="detail-row">
                        <span class="detail-label">Local Port:</span>
                        <code>${tunnel.localPort}</code>
                    </div>
                    <div class="detail-row">
                        <span class="detail-label">Remote Port:</span>
                        <code>${tunnel.remotePort}</code>
                    </div>
                    <div class="detail-row">
                        <span class="detail-label">URL Locale:</span>
                        <a href="http://localhost:${tunnel.localPort}" target="_blank" class="tunnel-link">
                            http://localhost:${tunnel.localPort}
                            <i data-lucide="external-link" size="14"></i>
                        </a>
                    </div>
                    ${tunnel.pid ? `
                        <div class="detail-row">
                            <span class="detail-label">PID:</span>
                            <code>${tunnel.pid}</code>
                        </div>
                    ` : ''}
                    ${tunnel.uptime ? `
                        <div class="detail-row">
                            <span class="detail-label">Uptime:</span>
                            <span>${this.formatUptime(tunnel.uptime)}</span>
                        </div>
                    ` : ''}
                </div>

                <div class="tunnel-actions">
                    ${tunnel.status === 'active' ? `
                        <button class="btn btn-sm btn-danger" onclick="window.sshTunnelsManager.stop('${tunnel.id}')">
                            <i data-lucide="x" size="14"></i>
                            <span>Arrêter</span>
                        </button>
                    ` : `
                        <button class="btn btn-sm btn-success" onclick="window.sshTunnelsManager.start('${tunnel.id}')">
                            <i data-lucide="play" size="14"></i>
                            <span>Démarrer</span>
                        </button>
                    `}
                    <button class="btn btn-sm btn-secondary" onclick="window.sshTunnelsManager.showInfo('${tunnel.id}')">
                        <i data-lucide="info" size="14"></i>
                        <span>Info</span>
                    </button>
                    <button class="btn btn-sm btn-danger" onclick="window.sshTunnelsManager.delete('${tunnel.id}')">
                        <i data-lucide="trash-2" size="14"></i>
                    </button>
                </div>
            </div>
        `).join('');

        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Show create tunnel modal
     */
    showCreateModal() {
        const modal = document.getElementById('create-tunnel-modal');
        if (!modal) return;

        // Reset form
        const form = document.getElementById('create-tunnel-form');
        if (form) form.reset();

        // Populate service templates
        this.populateServiceTemplates();

        modal.classList.remove('hidden');
    }

    /**
     * Populate service templates dropdown
     */
    populateServiceTemplates() {
        const templates = [
            { name: 'Vaultwarden', service: 'vaultwarden', localPort: 8000, remotePort: 8000, icon: 'lock' },
            { name: 'Portainer', service: 'portainer', localPort: 9000, remotePort: 9000, icon: 'container' },
            { name: 'Supabase Studio', service: 'supabase-studio', localPort: 3001, remotePort: 3001, icon: 'database' },
            { name: 'Traefik Dashboard', service: 'traefik', localPort: 8080, remotePort: 8080, icon: 'route' },
            { name: 'Custom', service: 'custom', localPort: '', remotePort: '', icon: 'settings' }
        ];

        const select = document.getElementById('tunnel-template');
        if (!select) return;

        select.innerHTML = templates.map(t =>
            `<option value="${t.service}" data-local="${t.localPort}" data-remote="${t.remotePort}">${t.name}</option>`
        ).join('');

        // Auto-fill on selection
        select.addEventListener('change', (e) => {
            const option = e.target.selectedOptions[0];
            const localPort = document.getElementById('tunnel-local-port');
            const remotePort = document.getElementById('tunnel-remote-port');
            const name = document.getElementById('tunnel-name');

            if (localPort) localPort.value = option.dataset.local || '';
            if (remotePort) remotePort.value = option.dataset.remote || '';
            if (name && option.value !== 'custom') {
                name.value = templates.find(t => t.service === option.value)?.name || '';
            }
        });

        // Trigger initial fill
        select.dispatchEvent(new Event('change'));
    }

    /**
     * Create new tunnel
     */
    async create(formData) {
        try {
            const tunnel = {
                name: formData.get('name'),
                service: formData.get('template'),
                localPort: parseInt(formData.get('localPort')),
                remotePort: parseInt(formData.get('remotePort')),
                autoStart: formData.get('autoStart') === 'on'
            };

            const createPromise = api.post('/ssh-tunnels', tunnel);

            const messages = {
                loading: 'Création du tunnel...',
                success: `Tunnel ${tunnel.name} créé avec succès!`,
                error: 'Erreur création tunnel'
            };

            const result = window.toastManager
                ? await window.toastManager.promise(createPromise, messages)
                : await createPromise;

            // Close modal
            const modal = document.getElementById('create-tunnel-modal');
            if (modal) modal.classList.add('hidden');

            // Reload list
            await this.load();

            return result;
        } catch (error) {
            console.error('Failed to create tunnel:', error);
            throw error;
        }
    }

    /**
     * Start tunnel
     */
    async start(tunnelId) {
        try {
            await this.tunnelService.startTunnel(tunnelId);
            await this.load();

            // Auto-open URL in new tab
            const tunnel = this.tunnels.find(t => t.id === tunnelId);
            if (tunnel) {
                this.tunnelService.openTunnelUrl(tunnel);
            }
        } catch (error) {
            console.error('Failed to start tunnel:', error);
            throw error;
        }
    }

    /**
     * Stop tunnel
     */
    async stop(tunnelId) {
        try {
            await this.tunnelService.stopTunnel(tunnelId);
            await this.load();
        } catch (error) {
            console.error('Failed to stop tunnel:', error);
            throw error;
        }
    }

    /**
     * Delete tunnel
     */
    async delete(tunnelId) {
        const tunnel = this.tunnels.find(t => t.id === tunnelId);
        if (!confirm(`Supprimer le tunnel "${tunnel?.name}" ?`)) {
            return;
        }

        try {
            await this.tunnelService.deleteTunnel(tunnelId);
            await this.load();
        } catch (error) {
            console.error('Failed to delete tunnel:', error);
            throw error;
        }
    }

    /**
     * Show tunnel info
     */
    showInfo(tunnelId) {
        const tunnel = this.tunnels.find(t => t.id === tunnelId);
        if (!tunnel) return;

        const info = `
Tunnel SSH: ${tunnel.name}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Service: ${tunnel.service}
Status: ${tunnel.status}

Ports:
  Local:  ${tunnel.localPort}
  Remote: ${tunnel.remotePort}

URL: http://localhost:${tunnel.localPort}

Commande équivalente:
ssh -L ${tunnel.localPort}:localhost:${tunnel.remotePort} pi@${tunnel.host || 'pi5.local'} -N

${tunnel.pid ? `PID: ${tunnel.pid}` : ''}
${tunnel.uptime ? `Uptime: ${this.formatUptime(tunnel.uptime)}` : ''}
        `.trim();

        alert(info);
    }

    /**
     * Get service icon
     */
    getServiceIcon(service) {
        const icons = {
            'vaultwarden': 'lock',
            'portainer': 'container',
            'supabase': 'database',
            'supabase-kong': 'database',
            'supabase-studio': 'database',
            'traefik': 'route',
            'grafana': 'bar-chart-2',
            'homepage': 'layout-dashboard',
            'pi5-dashboard': 'gauge',
            'n8n': 'workflow',
            'ollama': 'brain',
            'open-webui': 'message-square',
            'certidoc-frontend': 'file-check',
            'custom': 'settings'
        };
        return icons[service] || 'network';
    }

    /**
     * Format uptime
     */
    formatUptime(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;

        if (hours > 0) {
            return `${hours}h ${minutes}m`;
        } else if (minutes > 0) {
            return `${minutes}m ${secs}s`;
        } else {
            return `${secs}s`;
        }
    }

    /**
     * Start auto-refresh
     */
    startAutoRefresh() {
        this.stopAutoRefresh();
        this.refreshInterval = setInterval(() => this.load(), 10000); // Every 10s
    }

    /**
     * Stop auto-refresh
     */
    stopAutoRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }
    }

    /**
     * Get tunnels
     */
    getTunnels() {
        return this.tunnels;
    }

    /**
     * Discover Docker services on Pi for auto-tunnel creation
     */
    async discoverServices() {
        const btn = document.getElementById('discover-services-btn');
        if (btn) {
            btn.disabled = true;
            btn.innerHTML = '<i data-lucide="loader" class="spin"></i> Découverte...';
            if (window.lucide) window.lucide.createIcons();
        }

        try {
            const services = await this.tunnelService.discoverServices();

            if (services.length > 0) {
                this.showDiscoveryModal(services);
            } else {
                if (window.toastManager) {
                    window.toastManager.info('Aucun service Docker exposé trouvé');
                }
            }
        } catch (error) {
            console.error('Failed to discover services:', error);
        } finally {
            if (btn) {
                btn.disabled = false;
                btn.innerHTML = '<i data-lucide="search"></i> Découvrir Services';
                if (window.lucide) window.lucide.createIcons();
            }
        }
    }

    /**
     * Show discovery modal with found services
     */
    showDiscoveryModal(services) {
        const modalHTML = `
            <div class="modal" id="discovery-modal">
                <div class="modal-content">
                    <div class="modal-header">
                        <h2>Services Docker Découverts</h2>
                        <button class="modal-close" onclick="document.getElementById('discovery-modal').remove()">
                            <i data-lucide="x"></i>
                        </button>
                    </div>
                    <div class="modal-body">
                        <p><strong>${services.length} service(s)</strong> avec ports exposés détectés sur le Pi:</p>
                        <div class="services-list" style="max-height: 400px; overflow-y: auto;">
                            ${services.map(svc => `
                                <div class="service-card" style="border: 1px solid var(--border); padding: 1rem; margin: 0.5rem 0; border-radius: 8px;">
                                    <div style="display: flex; justify-content: space-between; align-items: center;">
                                        <div>
                                            <h4 style="margin: 0 0 0.5rem 0;">${svc.serviceName}</h4>
                                            <div style="font-size: 0.875rem; color: var(--text-secondary);">
                                                <div>Container: <code>${svc.containerName}</code></div>
                                                <div>Port: ${svc.hostPort} ${svc.isLocalhost ? '(localhost only)' : '(public)'}</div>
                                            </div>
                                        </div>
                                        <button class="btn btn-sm btn-primary" onclick="window.sshTunnelsManager.createFromDiscovered(${JSON.stringify(svc.tunnel).replace(/"/g, '&quot;')})">
                                            <i data-lucide="plus"></i> Créer Tunnel
                                        </button>
                                    </div>
                                </div>
                            `).join('')}
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button class="btn btn-secondary" onclick="document.getElementById('discovery-modal').remove()">
                            Fermer
                        </button>
                    </div>
                </div>
            </div>
        `;

        document.body.insertAdjacentHTML('beforeend', modalHTML);
        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Create tunnel from discovered service
     */
    async createFromDiscovered(tunnelConfig) {
        try {
            await this.tunnelService.createTunnel(tunnelConfig);

            // Close modal and reload
            document.getElementById('discovery-modal')?.remove();
            await this.load();
        } catch (error) {
            console.error('Failed to create tunnel:', error);
        }
    }

    /**
     * Cleanup on destroy
     */
    destroy() {
        this.stopAutoRefresh();
    }
}

// Create singleton instance
const sshTunnelsManager = new SSHTunnelsManager();

// Export
export default sshTunnelsManager;

// Global access for backward compatibility
window.sshTunnelsManager = sshTunnelsManager;
