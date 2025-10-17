// =============================================================================
// Quick Launch Module
// =============================================================================
// Quickly launch services with automatic SSH tunnel + browser open
// Version: 1.0.0
// =============================================================================

import api from '../utils/api.js';

/**
 * Quick Launch Manager
 */
class QuickLaunchManager {
    constructor() {
        this.services = [];
        this.tunnelStates = new Map(); // Service ID -> tunnel state
    }

    /**
     * Initialize Quick Launch module
     */
    init() {
        this.setupEventListeners();
        this.loadServices();
        console.log('✅ Quick Launch module initialized');
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
                color: '#10b981'
            },
            {
                id: 'portainer',
                name: 'Portainer',
                description: 'Docker Management',
                icon: 'container',
                localPort: 9000,
                remotePort: 9000,
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
                localPort: 3002, // Avoid conflict with Studio
                remotePort: 3000, // Internal Grafana port
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

            return `
                <button
                    class="service-launch-btn ${statusClass}"
                    data-service-id="${service.id}"
                    onclick="window.quickLaunchManager.launchService('${service.id}')">

                    <div class="service-status ${statusClass}">
                        <span class="status-dot"></span>
                        <span>${statusText}</span>
                    </div>

                    <div class="service-icon" style="${service.color ? `color: ${service.color}` : ''}">
                        <i data-lucide="${service.icon}" size="32"></i>
                    </div>

                    <div class="service-info">
                        <div class="service-name">${service.name}</div>
                        <div class="service-description">${service.description}</div>
                        <div class="service-port">
                            <i data-lucide="arrow-right" size="10"></i>
                            <span>localhost:${service.localPort}</span>
                        </div>
                    </div>
                </button>
            `;
        }).join('');

        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Launch service (create tunnel + open browser)
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
            // 1. Check if tunnel already exists
            const tunnelsData = await api.get('/ssh-tunnels');
            let tunnel = tunnelsData.tunnels.find(t =>
                t.service === serviceId ||
                (t.localPort === service.localPort && t.remotePort === service.remotePort)
            );

            // 2. Create tunnel if it doesn't exist
            if (!tunnel) {
                const createData = await api.post('/ssh-tunnels', {
                    name: service.name,
                    service: serviceId,
                    localPort: service.localPort,
                    remotePort: service.remotePort,
                    autoStart: false
                });
                tunnel = createData.tunnel;

                if (window.toastManager) {
                    window.toastManager.success(`Tunnel ${service.name} créé`);
                }
            }

            // 3. Start tunnel if not active
            if (tunnel.status !== 'active') {
                await api.post(`/ssh-tunnels/${tunnel.id}/start`);

                if (window.toastManager) {
                    window.toastManager.success(`Tunnel ${service.name} démarré`);
                }
            }

            // 4. Update state
            this.tunnelStates.set(serviceId, 'active');
            this.render();

            // 5. Wait a bit for tunnel to be ready
            await new Promise(resolve => setTimeout(resolve, 1000));

            // 6. Open service in new tab
            const url = `http://localhost:${service.localPort}`;
            window.open(url, '_blank');

            if (window.toastManager) {
                window.toastManager.success(`${service.name} ouvert dans un nouvel onglet`);
            }

        } catch (error) {
            console.error('Failed to launch service:', error);
            this.tunnelStates.set(serviceId, 'error');
            this.render();

            if (window.toastManager) {
                window.toastManager.error(`Erreur lancement ${service.name}: ${error.message}`);
            }
        }
    }

    /**
     * Stop service tunnel
     */
    async stopService(serviceId) {
        const service = this.services.find(s => s.id === serviceId);
        if (!service) return;

        try {
            // Find tunnel
            const tunnelsData = await api.get('/ssh-tunnels');
            const tunnel = tunnelsData.tunnels.find(t =>
                t.service === serviceId ||
                (t.localPort === service.localPort && t.remotePort === service.remotePort)
            );

            if (!tunnel) {
                console.warn('No tunnel found for service:', serviceId);
                return;
            }

            // Stop tunnel
            if (tunnel.status === 'active') {
                await api.post(`/ssh-tunnels/${tunnel.id}/stop`);

                if (window.toastManager) {
                    window.toastManager.info(`Tunnel ${service.name} arrêté`);
                }
            }

            // Update state
            this.tunnelStates.set(serviceId, 'inactive');
            this.render();

        } catch (error) {
            console.error('Failed to stop service:', error);
            if (window.toastManager) {
                window.toastManager.error(`Erreur arrêt ${service.name}`);
            }
        }
    }

    /**
     * Refresh tunnel states from server
     */
    async refreshStates() {
        try {
            const data = await api.get('/ssh-tunnels');
            const tunnels = data.tunnels || [];

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
}

// Create singleton
const quickLaunchManager = new QuickLaunchManager();

// Export
export default quickLaunchManager;

// Global access
window.quickLaunchManager = quickLaunchManager;
