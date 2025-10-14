// =============================================================================
// Docker Manager Module
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

import api from '../utils/api.js';

/**
 * DockerManager - Manages Docker containers
 */
class DockerManager {
    constructor() {
        this.containers = [];
        this.refreshInterval = null;
        this.autoRefreshEnabled = false;
    }

    /**
     * Initialize Docker module
     */
    init() {
        this.setupEventListeners();
        console.log('✅ Docker module initialized');
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Refresh button
        const refreshBtn = document.getElementById('refresh-docker');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => this.load());
        }

        // Dashboard refresh button
        const refreshDashBtn = document.getElementById('refresh-docker-dash');
        if (refreshDashBtn) {
            refreshDashBtn.addEventListener('click', () => this.load());
        }
    }

    /**
     * Load Docker containers
     */
    async load() {
        try {
            const piId = window.currentPiId;
            const params = piId ? `?piId=${piId}` : '';

            const data = await api.get(`/docker/containers${params}`);
            this.containers = data.containers || [];
            this.render();

            return this.containers;
        } catch (error) {
            console.error('Failed to load Docker containers:', error);
            this.renderError('Failed to load containers');
            throw error;
        }
    }

    /**
     * Render Docker containers
     */
    render() {
        const container = document.getElementById('docker-container');
        if (!container) return;

        if (!this.containers || this.containers.length === 0) {
            container.innerHTML = '<div class="loading">Aucun conteneur Docker</div>';
            return;
        }

        container.innerHTML = this.containers.map(c => this.renderContainer(c)).join('');
    }

    /**
     * Render single container card
     * @param {Object} container - Container data
     * @returns {string} HTML string
     */
    renderContainer(container) {
        const isRunning = container.State === 'running';
        const stateClass = isRunning ? 'running' : 'exited';

        return `
            <div class="docker-card">
                <div class="docker-card-header">
                    <div class="docker-name">${container.Names}</div>
                    <div class="docker-state ${stateClass}">${container.State}</div>
                </div>
                <div class="docker-status">${container.Status}</div>
                <div class="docker-actions">
                    <button
                        class="docker-btn"
                        data-action="start"
                        data-container="${container.Names}"
                        ${isRunning ? 'disabled' : ''}
                    >
                        ▶️ Start
                    </button>
                    <button
                        class="docker-btn"
                        data-action="stop"
                        data-container="${container.Names}"
                        ${!isRunning ? 'disabled' : ''}
                    >
                        ⏸️ Stop
                    </button>
                    <button
                        class="docker-btn"
                        data-action="restart"
                        data-container="${container.Names}"
                    >
                        🔄 Restart
                    </button>
                    <button
                        class="docker-btn"
                        data-action="logs"
                        data-container="${container.Names}"
                    >
                        📋 Logs
                    </button>
                </div>
            </div>
        `;
    }

    /**
     * Render error message
     * @param {string} message - Error message
     */
    renderError(message) {
        const container = document.getElementById('docker-container');
        if (!container) return;

        container.innerHTML = `<div class="error">${message}</div>`;
    }

    /**
     * Execute Docker action (start/stop/restart)
     * @param {string} action - Action to perform
     * @param {string} containerName - Container name
     */
    async executeAction(action, containerName) {
        try {
            // Notify via terminal if available
            if (window.terminalManager) {
                window.terminalManager.addLine(
                    `Executing docker ${action} ${containerName}...`,
                    'info'
                );
            }

            const piId = window.currentPiId;
            const params = piId ? `?piId=${piId}` : '';

            const result = await api.post(`/docker/${action}/${containerName}${params}`);

            if (result.success) {
                if (window.terminalManager) {
                    window.terminalManager.addLine(
                        `✅ Docker ${action} completed for ${containerName}`,
                        'success'
                    );
                }

                // Reload containers after 1 second
                setTimeout(() => this.load(), 1000);

                return result;
            } else {
                throw new Error(result.error || 'Unknown error');
            }
        } catch (error) {
            const errorMsg = `❌ Docker ${action} failed: ${error.message}`;

            if (window.terminalManager) {
                window.terminalManager.addLine(errorMsg, 'error');
            }

            console.error(errorMsg);
            throw error;
        }
    }

    /**
     * Show Docker logs
     * @param {string} containerName - Container name
     * @param {number} lines - Number of lines to fetch
     */
    async showLogs(containerName, lines = 50) {
        try {
            if (window.terminalManager) {
                window.terminalManager.addLine(
                    `Fetching logs for ${containerName}...`,
                    'info'
                );
            }

            const piId = window.currentPiId;
            const params = piId ? `&piId=${piId}` : '';

            const result = await api.get(`/docker/logs/${containerName}?lines=${lines}${params}`);

            if (window.terminalManager) {
                window.terminalManager.addLine(
                    `\n=== Logs: ${containerName} ===\n${result.logs}\n=== End Logs ===\n`,
                    'info'
                );
            }

            return result.logs;
        } catch (error) {
            const errorMsg = `❌ Error fetching logs: ${error.message}`;

            if (window.terminalManager) {
                window.terminalManager.addLine(errorMsg, 'error');
            }

            console.error(errorMsg);
            throw error;
        }
    }

    /**
     * Start auto-refresh
     * @param {number} interval - Refresh interval in milliseconds
     */
    startAutoRefresh(interval = 10000) {
        this.stopAutoRefresh();
        this.autoRefreshEnabled = true;
        this.refreshInterval = setInterval(() => this.load(), interval);
        console.log(`🔄 Docker auto-refresh started (${interval}ms)`);
    }

    /**
     * Stop auto-refresh
     */
    stopAutoRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }
        this.autoRefreshEnabled = false;
        console.log('⏸️ Docker auto-refresh stopped');
    }

    /**
     * Get container by name
     * @param {string} name - Container name
     * @returns {Object|null} Container object or null
     */
    getContainer(name) {
        return this.containers.find(c => c.Names === name) || null;
    }

    /**
     * Get all running containers
     * @returns {Array} Array of running containers
     */
    getRunningContainers() {
        return this.containers.filter(c => c.State === 'running');
    }
}

// Create singleton instance
const dockerManager = new DockerManager();

// Export
export default dockerManager;

// Global access for backward compatibility
window.dockerManager = dockerManager;

// Global functions for onclick handlers (backward compat)
window.dockerAction = (action, containerName) => dockerManager.executeAction(action, containerName);
window.showDockerLogs = (containerName) => dockerManager.showLogs(containerName);
