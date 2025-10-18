// =============================================================================
// Quick Launch Module
// =============================================================================
// Quickly launch services with automatic SSH tunnel + browser open
// Version: 2.0.0 - Refactored to use TunnelService
// =============================================================================

import api from '../utils/api.js';
import tunnelService from '../utils/tunnel-service.js';

/**
 * Quick Launch Manager
 */
class QuickLaunchManager {
    constructor() {
        this.services = [];
        this.tunnelStates = new Map(); // Service ID -> tunnel state
        this.tunnelService = tunnelService;
    }

    /**
     * Initialize Quick Launch module
     */
    init() {
        this.setupEventListeners();
        this.loadServices();
        this.startAutoRefresh();
        console.log('✅ Quick Launch module initialized');
    }

    /**
     * Start auto-refresh for container states
     */
    startAutoRefresh() {
        // Initial refresh after 2s
        setTimeout(() => this.refreshContainerStates(), 2000);

        // Then refresh every 30s
        this.refreshInterval = setInterval(() => {
            this.refreshContainerStates();
        }, 30000);
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
     * Refresh container states automatically
     */
    async refreshContainerStates() {
        try {
            // Get all running containers
            const response = await api.get('/docker/containers');

            if (!response.containers) return;

            // Map container names to service IDs
            this.services.forEach(service => {
                if (!service.container) return;

                const container = response.containers.find(c =>
                    c.Names.includes(service.container)
                );

                if (container && container.State === 'running') {
                    // Container is running, update state
                    const currentState = this.tunnelStates.get(service.id);

                    // Don't override 'launching' state
                    if (currentState !== 'launching') {
                        // Check if we have an active tunnel
                        this.checkTunnelForService(service.id);
                    }
                }
            });
        } catch (error) {
            console.error('Failed to refresh container states:', error);
        }
    }

    /**
     * Check if service has active tunnel
     */
    async checkTunnelForService(serviceId) {
        try {
            const service = this.services.find(s => s.id === serviceId);
            if (!service) return;

            const tunnels = await this.tunnelService.getTunnels();
            const tunnel = tunnels.find(t =>
                t.service === serviceId ||
                (t.localPort === service.localPort && t.remotePort === service.remotePort)
            );

            if (tunnel && tunnel.status === 'active') {
                this.tunnelStates.set(serviceId, 'active');
            } else {
                this.tunnelStates.set(serviceId, 'inactive');
            }

            this.render();
        } catch (error) {
            // Silently fail, don't spam console
        }
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        const refreshBtn = document.getElementById('refresh-services');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => this.loadServices());
        }
    }

    /**
     * Load available services
     */
    async loadServices() {
        try {
            // Get list of running Docker containers + known services
            const data = await api.get('/quick-launch/services');
            this.services = data.services || [];

            // If no services from API, use default list
            if (this.services.length === 0) {
                this.services = this.getDefaultServices();
            }

            this.render();
        } catch (error) {
            console.error('Failed to load services:', error);
            // Fallback to default services
            this.services = this.getDefaultServices();
            this.render();
        }
    }

    /**
     * Get default services list
     * Note: Ports based on actual Pi5 deployment
     */
    getDefaultServices() {
        return [
            {
                id: 'vaultwarden',
                name: 'Vaultwarden',
                description: 'Password Manager',
                icon: 'lock',
                localPort: 8000,
                remotePort: 8000,
                color: '#10b981',
                essential: false
            },
            {
                id: 'portainer',
                name: 'Portainer',
                description: 'Docker Management',
                icon: 'container',
                localPort: 9000,
                remotePort: 9000, // 127.0.0.1:8080->9000/tcp (tunnel needed)
                color: '#3b82f6'
            },
            {
                id: 'homepage',
                name: 'Homepage',
                description: 'Services Dashboard',
                icon: 'layout-dashboard',
                localPort: 3001,
                remotePort: 3001,
                color: '#06b6d4',
                url: 'http://pi5.local:3001' // Direct access (no tunnel needed)
            },
            {
                id: 'supabase-kong',
                name: 'Supabase API',
                description: 'REST API & Auth',
                icon: 'database',
                localPort: 8001,
                remotePort: 8001,
                color: '#8b5cf6',
                url: 'http://pi5.local:8001' // Direct access (no tunnel needed)
            },
            {
                id: 'supabase-studio',
                name: 'Supabase Studio',
                description: 'Database UI (localhost only)',
                icon: 'database',
                localPort: 3000,
                remotePort: 3000, // 127.0.0.1:3000 on Pi
                color: '#8b5cf6'
            },
            {
                id: 'grafana',
                name: 'Grafana',
                description: 'Monitoring Dashboards',
                icon: 'bar-chart-2',
                localPort: 3005, // Local port for tunnel
                remotePort: 3000, // 3000/tcp on Pi (tunnel needed)
                color: '#ef4444'
            },
            {
                id: 'pi5-dashboard',
                name: 'Pi5 Dashboard',
                description: 'Status & Metrics',
                icon: 'gauge',
                localPort: 3100,
                remotePort: 3100,
                color: '#10b981',
                url: 'http://pi5.local:3100' // Direct access
            },
            {
                id: 'n8n',
                name: 'N8N',
                description: 'Workflow Automation',
                icon: 'workflow',
                localPort: 5678,
                remotePort: 5678,
                color: '#ea5a0c',
                url: 'http://pi5.local:5678' // Direct access
            },
            {
                id: 'ollama',
                name: 'Ollama',
                description: 'AI Models API',
                icon: 'brain',
                localPort: 11434,
                remotePort: 11434,
                color: '#000000',
                url: 'http://pi5.local:11434' // Direct access
            },
            {
                id: 'open-webui',
                name: 'Open WebUI',
                description: 'AI Chat Interface',
                icon: 'message-square',
                localPort: 3002,
                remotePort: 3002,
                color: '#8b5cf6',
                url: 'http://pi5.local:3002' // Direct access (port 3002->8080)
            },
            {
                id: 'certidoc-frontend',
                name: 'CertiDoc',
                description: 'Document Verification',
                icon: 'file-check',
                localPort: 9000,
                remotePort: 9000,
                color: '#0ea5e9',
                url: 'http://pi5.local:9000' // Direct access
            }
        ];
    }

    /**
     * Render services grid
     */
    render() {
        const container = document.getElementById('quick-launch-grid');
        if (!container) return;

        if (this.services.length === 0) {
            container.innerHTML = `
                <div class="quick-launch-empty">
                    <i data-lucide="inbox" size="32"></i>
                    <p>Aucun service détecté</p>
                    <button class="btn btn-sm btn-primary" onclick="window.quickLaunchManager.loadServices()">
                        <i data-lucide="refresh-cw" size="14"></i>
                        <span>Réessayer</span>
                    </button>
                </div>
            `;
            if (window.lucide) window.lucide.createIcons();
            return;
        }

        container.innerHTML = this.services.map(service => {
            const tunnelState = this.tunnelStates.get(service.id) || 'inactive';
            const statusClass = tunnelState;
            const statusText = {
                'active': 'Actif',
                'launching': 'Lancement...',
                'error': 'Erreur',
                'inactive': 'Inactif'
            }[tunnelState] || 'Inactif';

            // Quick actions removed - now in Docker tab
            const quickActions = '';

            return `
                <div class="service-card ${service.essential ? 'essential' : ''}" data-service-id="${service.id}">
                    <button
                        class="service-launch-btn ${statusClass}"
                        onclick="window.quickLaunchManager.launchService('${service.id}')">

                        <div class="service-status ${statusClass}">
                            <span class="status-dot"></span>
                            <span>${statusText}</span>
                        </div>

                        <div class="service-icon" style="${service.color ? `color: ${service.color}` : ''}">
                            <i data-lucide="${service.icon}" size="32"></i>
                        </div>

                        <div class="service-info">
                            <div class="service-name">
                                ${service.name}
                                ${service.essential ? '<span class="essential-badge">⚡</span>' : ''}
                            </div>
                            <div class="service-description">${service.description}</div>
                            <div class="service-port">
                                <i data-lucide="arrow-right" size="10"></i>
                                <span>localhost:${service.localPort}</span>
                            </div>
                        </div>
                    </button>
                    ${quickActions}
                </div>
            `;
        }).join('');

        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Launch service (create tunnel + open browser)
     * Now using TunnelService - much simpler!
     */
    async launchService(serviceId) {
        const service = this.services.find(s => s.id === serviceId);
        if (!service) {
            console.error('Service not found:', serviceId);
            return;
        }

        // Update UI state
        this.tunnelStates.set(serviceId, 'launching');
        this.render();

        try {
            // Use TunnelService to handle everything
            await this.tunnelService.launchService({
                id: serviceId,
                name: service.name,
                localPort: service.localPort,
                remotePort: service.remotePort,
                url: service.url,
                service: serviceId
            });

            // Update state
            this.tunnelStates.set(serviceId, 'active');
            this.render();

        } catch (error) {
            console.error('Failed to launch service:', error);
            this.tunnelStates.set(serviceId, 'error');
            this.render();
        }
    }

    /**
     * Stop service tunnel
     */
    async stopService(serviceId) {
        const service = this.services.find(s => s.id === serviceId);
        if (!service) return;

        try {
            // Find tunnel using TunnelService
            const tunnel = await this.tunnelService.findTunnel({
                service: serviceId,
                localPort: service.localPort,
                remotePort: service.remotePort
            });

            if (!tunnel) {
                console.warn('No tunnel found for service:', serviceId);
                return;
            }

            // Stop tunnel using TunnelService
            if (tunnel.status === 'active') {
                await this.tunnelService.stopTunnel(tunnel.id);
            }

            // Update state
            this.tunnelStates.set(serviceId, 'inactive');
            this.render();

        } catch (error) {
            console.error('Failed to stop service:', error);
        }
    }

    /**
     * Refresh tunnel states from server
     */
    async refreshStates() {
        try {
            const tunnels = await this.tunnelService.getTunnels();

            // Update states based on active tunnels
            this.services.forEach(service => {
                const tunnel = tunnels.find(t =>
                    t.service === service.id ||
                    (t.localPort === service.localPort && t.remotePort === service.remotePort)
                );

                if (tunnel && tunnel.status === 'active') {
                    this.tunnelStates.set(service.id, 'active');
                } else {
                    this.tunnelStates.set(service.id, 'inactive');
                }
            });

            this.render();
        } catch (error) {
            console.error('Failed to refresh tunnel states:', error);
        }
    }

    /**
     * Restart Docker container
     */
    async restartContainer(containerName) {
        if (!containerName) return;

        try {
            console.log(`🔄 Restarting container: ${containerName}`);

            const response = await api.post('/docker/restart', {
                container: containerName
            });

            if (response.success) {
                this.showNotification(`✅ ${containerName} redémarré avec succès`, 'success');

                // Wait 2s then refresh states
                setTimeout(() => this.refreshStates(), 2000);
            } else {
                throw new Error(response.error || 'Restart failed');
            }
        } catch (error) {
            console.error('Failed to restart container:', error);
            this.showNotification(`❌ Erreur: ${error.message}`, 'error');
        }
    }

    /**
     * Show container logs
     */
    async showLogs(containerName) {
        if (!containerName) return;

        try {
            const response = await api.get(`/docker/logs/${containerName}?lines=50`);

            if (response.success) {
                // Open modal with logs
                this.openLogsModal(containerName, response.logs);
            } else {
                throw new Error(response.error || 'Failed to fetch logs');
            }
        } catch (error) {
            console.error('Failed to fetch logs:', error);
            this.showNotification(`❌ Erreur: ${error.message}`, 'error');
        }
    }

    /**
     * Check container status
     */
    async checkStatus(containerName) {
        if (!containerName) return;

        try {
            const response = await api.get(`/docker/status/${containerName}`);

            if (response.success) {
                const status = response.status;
                const emoji = status.state === 'running' ? '✅' : '❌';
                const health = status.health || 'N/A';

                this.showNotification(
                    `${emoji} ${containerName}\n` +
                    `État: ${status.state}\n` +
                    `Santé: ${health}\n` +
                    `Uptime: ${status.uptime || 'N/A'}`,
                    status.state === 'running' ? 'success' : 'warning'
                );
            } else {
                throw new Error(response.error || 'Status check failed');
            }
        } catch (error) {
            console.error('Failed to check status:', error);
            this.showNotification(`❌ Erreur: ${error.message}`, 'error');
        }
    }

    /**
     * Show notification (toast)
     */
    showNotification(message, type = 'info') {
        // Simple toast notification
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.textContent = message;
        toast.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: ${type === 'success' ? '#10b981' : type === 'error' ? '#ef4444' : '#3b82f6'};
            color: white;
            padding: 12px 20px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            z-index: 10000;
            animation: slideIn 0.3s ease;
            white-space: pre-line;
        `;
        document.body.appendChild(toast);

        setTimeout(() => {
            toast.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }

    /**
     * Open logs modal
     */
    openLogsModal(containerName, logs) {
        const modal = document.createElement('div');
        modal.className = 'logs-modal';
        modal.innerHTML = `
            <div class="logs-modal-overlay" onclick="this.parentElement.remove()"></div>
            <div class="logs-modal-content">
                <div class="logs-modal-header">
                    <h3>
                        <i data-lucide="file-text" size="20"></i>
                        Logs: ${containerName}
                    </h3>
                    <button class="btn-close" onclick="this.closest('.logs-modal').remove()">
                        <i data-lucide="x" size="20"></i>
                    </button>
                </div>
                <pre class="logs-content">${logs}</pre>
            </div>
        `;
        document.body.appendChild(modal);

        if (window.lucide) window.lucide.createIcons();
    }
}

// Create singleton
const quickLaunchManager = new QuickLaunchManager();

// Export
export default quickLaunchManager;

// Global access
window.quickLaunchManager = quickLaunchManager;
