// =============================================================================
// Tunnel Service - Shared service for SSH tunnel management
// =============================================================================
// Centralizes all tunnel operations to avoid code duplication
// Used by both SSH Tunnels module and Quick Launch module
// Version: 1.0.0
// =============================================================================

import api from './api.js';

/**
 * TunnelService - Unified SSH tunnel operations
 */
class TunnelService {
    constructor() {
        this.tunnelsCache = [];
        this.lastCacheUpdate = 0;
        this.cacheTTL = 5000; // 5 seconds
    }

    /**
     * Get all tunnels (with cache)
     */
    async getTunnels(forceRefresh = false) {
        const now = Date.now();
        if (!forceRefresh && this.tunnelsCache.length > 0 && (now - this.lastCacheUpdate) < this.cacheTTL) {
            return this.tunnelsCache;
        }

        try {
            const data = await api.get('/ssh-tunnels');
            this.tunnelsCache = data.tunnels || [];
            this.lastCacheUpdate = now;
            return this.tunnelsCache;
        } catch (error) {
            console.error('Failed to fetch tunnels:', error);
            throw error;
        }
    }

    /**
     * Find tunnel by service ID or port
     */
    async findTunnel(criteria) {
        const tunnels = await this.getTunnels();

        return tunnels.find(t => {
            if (criteria.id) return t.id === criteria.id;
            if (criteria.service) return t.service === criteria.service;
            if (criteria.localPort && criteria.remotePort) {
                return t.localPort === criteria.localPort && t.remotePort === criteria.remotePort;
            }
            return false;
        });
    }

    /**
     * Create new tunnel
     */
    async createTunnel(config) {
        try {
            const data = await api.post('/ssh-tunnels', {
                name: config.name,
                service: config.service || config.id,
                localPort: config.localPort,
                remotePort: config.remotePort,
                host: config.host || 'pi5.local',
                username: config.username || 'pi',
                autoStart: config.autoStart || false,
                favorite: config.favorite || false
            });

            // Invalidate cache
            this.lastCacheUpdate = 0;

            if (window.toastManager) {
                window.toastManager.success(`Tunnel "${config.name}" créé`);
            }

            return data.tunnel;
        } catch (error) {
            console.error('Failed to create tunnel:', error);
            if (window.toastManager) {
                window.toastManager.error(`Erreur création tunnel: ${error.message}`);
            }
            throw error;
        }
    }

    /**
     * Start tunnel
     */
    async startTunnel(tunnelId) {
        try {
            const result = await api.post(`/ssh-tunnels/${tunnelId}/start`);

            // Invalidate cache
            this.lastCacheUpdate = 0;

            if (window.toastManager) {
                const tunnel = await this.findTunnel({ id: tunnelId });
                window.toastManager.success(`Tunnel "${tunnel?.name}" démarré`);
            }

            return result;
        } catch (error) {
            console.error('Failed to start tunnel:', error);
            if (window.toastManager) {
                window.toastManager.error(`Erreur démarrage tunnel: ${error.message}`);
            }
            throw error;
        }
    }

    /**
     * Stop tunnel
     */
    async stopTunnel(tunnelId) {
        try {
            const result = await api.post(`/ssh-tunnels/${tunnelId}/stop`);

            // Invalidate cache
            this.lastCacheUpdate = 0;

            if (window.toastManager) {
                const tunnel = await this.findTunnel({ id: tunnelId });
                window.toastManager.success(`Tunnel "${tunnel?.name}" arrêté`);
            }

            return result;
        } catch (error) {
            console.error('Failed to stop tunnel:', error);
            if (window.toastManager) {
                window.toastManager.error(`Erreur arrêt tunnel: ${error.message}`);
            }
            throw error;
        }
    }

    /**
     * Delete tunnel
     */
    async deleteTunnel(tunnelId) {
        try {
            await api.delete(`/ssh-tunnels/${tunnelId}`);

            // Invalidate cache
            this.lastCacheUpdate = 0;

            if (window.toastManager) {
                window.toastManager.success('Tunnel supprimé');
            }
        } catch (error) {
            console.error('Failed to delete tunnel:', error);
            if (window.toastManager) {
                window.toastManager.error(`Erreur suppression tunnel: ${error.message}`);
            }
            throw error;
        }
    }

    /**
     * Update tunnel
     */
    async updateTunnel(tunnelId, updates) {
        try {
            const data = await api.put(`/ssh-tunnels/${tunnelId}`, updates);

            // Invalidate cache
            this.lastCacheUpdate = 0;

            if (window.toastManager) {
                window.toastManager.success('Tunnel mis à jour');
            }

            return data.tunnel;
        } catch (error) {
            console.error('Failed to update tunnel:', error);
            if (window.toastManager) {
                window.toastManager.error(`Erreur mise à jour tunnel: ${error.message}`);
            }
            throw error;
        }
    }

    /**
     * Ensure tunnel exists and is active (create + start if needed)
     * Returns tunnel info
     */
    async ensureTunnelActive(config) {
        try {
            // 1. Find existing tunnel
            let tunnel = await this.findTunnel({
                service: config.service || config.id,
                localPort: config.localPort,
                remotePort: config.remotePort
            });

            // 2. Create if doesn't exist
            if (!tunnel) {
                tunnel = await this.createTunnel(config);
            }

            // 3. Start if not active
            if (tunnel.status !== 'active') {
                await this.startTunnel(tunnel.id);
                // Refresh tunnel data after starting
                tunnel = await this.findTunnel({ id: tunnel.id });
            }

            return tunnel;
        } catch (error) {
            console.error('Failed to ensure tunnel active:', error);
            throw error;
        }
    }

    /**
     * Launch service: ensure tunnel + open browser
     * Main entry point for Quick Launch functionality
     */
    async launchService(config) {
        try {
            // 1. Ensure tunnel is active
            const tunnel = await this.ensureTunnelActive(config);

            // 2. Wait a bit for tunnel to be ready
            await new Promise(resolve => setTimeout(resolve, 1000));

            // 3. Open service in new tab
            const url = config.url || `http://localhost:${config.localPort}`;
            window.open(url, '_blank');

            if (window.toastManager) {
                window.toastManager.success(`${config.name} ouvert dans un nouvel onglet`);
            }

            return { tunnel, url };
        } catch (error) {
            console.error('Failed to launch service:', error);
            if (window.toastManager) {
                window.toastManager.error(`Erreur lancement ${config.name}: ${error.message}`);
            }
            throw error;
        }
    }

    /**
     * Open tunnel URL in browser
     */
    openTunnelUrl(tunnel) {
        if (!tunnel) return;

        const url = `http://localhost:${tunnel.localPort}`;
        window.open(url, '_blank');
        console.log(`🌐 Opening tunnel URL: ${url}`);

        if (window.toastManager) {
            window.toastManager.info(`Ouverture de ${tunnel.name}`);
        }
    }

    /**
     * Discover Docker services on Pi
     */
    async discoverServices() {
        try {
            const data = await api.post('/ssh-tunnels/discover', {});

            if (window.toastManager && data.success) {
                window.toastManager.success(`${data.count} service(s) découvert(s)`);
            }

            return data.services || [];
        } catch (error) {
            console.error('Failed to discover services:', error);
            if (window.toastManager) {
                window.toastManager.error('Erreur découverte des services');
            }
            throw error;
        }
    }

    /**
     * Toggle favorite status
     */
    async toggleFavorite(tunnelId) {
        try {
            const tunnel = await this.findTunnel({ id: tunnelId });
            if (!tunnel) throw new Error('Tunnel not found');

            const updated = await this.updateTunnel(tunnelId, {
                favorite: !tunnel.favorite
            });

            return updated;
        } catch (error) {
            console.error('Failed to toggle favorite:', error);
            throw error;
        }
    }

    /**
     * Get favorite tunnels only
     */
    async getFavoriteTunnels() {
        const tunnels = await this.getTunnels();
        return tunnels.filter(t => t.favorite);
    }

    /**
     * Clear cache (force refresh on next call)
     */
    clearCache() {
        this.lastCacheUpdate = 0;
        this.tunnelsCache = [];
    }
}

// Create singleton instance
const tunnelService = new TunnelService();

// Export
export default tunnelService;

// Global access for debugging
if (typeof window !== 'undefined') {
    window.tunnelService = tunnelService;
}
