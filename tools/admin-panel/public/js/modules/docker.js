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

        // Filter listeners
        this.setupFilterListeners();
    }

    /**
     * Setup filter listeners for smart filtering
     */
    setupFilterListeners() {
        // Will be dynamically created after render
        document.addEventListener('click', (e) => {
            if (e.target.matches('.docker-filter-btn')) {
                const filterType = e.target.dataset.filter;
                const filterValue = e.target.dataset.value;
                this.applyFilter(filterType, filterValue);

                // Toggle active state
                document.querySelectorAll('.docker-filter-btn').forEach(btn => {
                    if (btn.dataset.filter === filterType) {
                        btn.classList.toggle('active', btn.dataset.value === filterValue);
                    }
                });
            }
        });

        // Search input
        document.addEventListener('input', (e) => {
            if (e.target.matches('#docker-search')) {
                this.searchContainers(e.target.value);
            }
        });
    }

    /**
     * Apply filter (state, stack, health)
     */
    applyFilter(type, value) {
        const cards = document.querySelectorAll('.docker-card');

        cards.forEach(card => {
            let shouldShow = true;

            if (type === 'state' && value !== 'all') {
                const state = card.querySelector('.docker-state').textContent.toLowerCase();
                shouldShow = state === value;
            } else if (type === 'stack' && value !== 'all') {
                const name = card.querySelector('.docker-name').textContent.toLowerCase();
                shouldShow = name.startsWith(value + '-');
            } else if (type === 'health' && value !== 'all') {
                const healthBadge = card.querySelector('.health-badge');
                if (value === 'healthy') {
                    shouldShow = healthBadge && healthBadge.classList.contains('healthy');
                } else if (value === 'unhealthy') {
                    shouldShow = healthBadge && healthBadge.classList.contains('unhealthy');
                } else if (value === 'starting') {
                    shouldShow = healthBadge && healthBadge.classList.contains('starting');
                }
            }

            card.style.display = shouldShow ? '' : 'none';
        });
    }

    /**
     * Search containers by name
     */
    searchContainers(query) {
        const cards = document.querySelectorAll('.docker-card');
        const lowerQuery = query.toLowerCase();

        cards.forEach(card => {
            const name = card.querySelector('.docker-name').textContent.toLowerCase();
            card.style.display = name.includes(lowerQuery) ? '' : 'none';
        });
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

        // Group containers by stack
        const stacks = this.groupContainersByStack();

        // Render stack controls + individual containers
        container.innerHTML = `
            ${this.renderStackControls(stacks)}
            ${this.containers.map(c => this.renderContainer(c)).join('')}
        `;

        if (typeof lucide !== 'undefined') {
            lucide.createIcons({ root: container });
        }
    }

    /**
     * Group containers by stack (automatic detection via prefix)
     * Detects: prefix-* patterns (supabase-*, n8n-*, etc.)
     */
    groupContainersByStack() {
        const stacks = {};

        this.containers.forEach(c => {
            const name = c.Names.toLowerCase();

            // Extract prefix before first dash (e.g., "supabase-db" → "supabase")
            const match = name.match(/^([a-z0-9]+)-/);

            if (match) {
                const stackName = match[1];

                // Ignore standalone containers (no multi-container stacks)
                if (!stacks[stackName]) stacks[stackName] = [];
                stacks[stackName].push(c.Names);
            }
        });

        // Only keep stacks with 2+ containers
        Object.keys(stacks).forEach(stackName => {
            if (stacks[stackName].length < 2) {
                delete stacks[stackName];
            }
        });

        return stacks;
    }

    /**
     * Render stack controls + filters
     */
    renderStackControls(stacks) {
        const stackNames = Object.keys(stacks);

        return `
            <!-- Search & Filters -->
            <div class="docker-filters">
                <div class="docker-search-box">
                    <i data-lucide="search" size="16"></i>
                    <input
                        type="text"
                        id="docker-search"
                        placeholder="Rechercher un conteneur..."
                        class="docker-search-input"
                    />
                </div>

                <div class="docker-filter-group">
                    <span class="filter-label">État:</span>
                    <button class="docker-filter-btn active" data-filter="state" data-value="all">Tous</button>
                    <button class="docker-filter-btn" data-filter="state" data-value="running">Running</button>
                    <button class="docker-filter-btn" data-filter="state" data-value="exited">Stopped</button>
                </div>

                ${stackNames.length > 0 ? `
                    <div class="docker-filter-group">
                        <span class="filter-label">Stack:</span>
                        <button class="docker-filter-btn active" data-filter="stack" data-value="all">Tous</button>
                        ${stackNames.map(stack => `
                            <button class="docker-filter-btn" data-filter="stack" data-value="${stack}">
                                ${stack.toUpperCase()}
                            </button>
                        `).join('')}
                    </div>
                ` : ''}
            </div>

            <!-- Stack Controls -->
            ${stackNames.length > 0 ? `
                <div class="docker-stacks">
                    <h4 style="margin: 0 0 12px 0; font-size: 14px; font-weight: 600; color: #374151;">
                        <i data-lucide="layers" size="16"></i> Stacks Docker
                    </h4>
                    <div class="stack-controls">
                        ${Object.entries(stacks).map(([stackName, containers]) => `
                            <div class="stack-card">
                                <div class="stack-header">
                                    <span class="stack-name">${stackName.toUpperCase()}</span>
                                    <span class="stack-count">${containers.length} conteneur${containers.length > 1 ? 's' : ''}</span>
                                </div>
                                <div class="stack-actions">
                                    <button
                                        class="stack-btn restart"
                                        onclick="window.dockerManager.restartStack('${stackName}', ${JSON.stringify(containers)})"
                                        title="Redémarrer tous les conteneurs ${stackName}">
                                        <i data-lucide="rotate-cw" size="14"></i>
                                        <span>Restart All</span>
                                    </button>
                                    <button
                                        class="stack-btn stop"
                                        onclick="window.dockerManager.stopStack('${stackName}', ${JSON.stringify(containers)})"
                                        title="Arrêter tous les conteneurs ${stackName}">
                                        <i data-lucide="square" size="14"></i>
                                        <span>Stop All</span>
                                    </button>
                                </div>
                            </div>
                        `).join('')}
                    </div>
                </div>
            ` : ''}
        `;
    }

    /**
     * Render single container card
     * @param {Object} container - Container data
     * @returns {string} HTML string
     */
    renderContainer(container) {
        const isRunning = container.State === 'running';
        const stateClass = isRunning ? 'running' : 'exited';

        // Extract health status from Status field
        const healthMatch = container.Status.match(/\(([^)]+)\)/);
        const healthStatus = healthMatch ? healthMatch[1] : null;
        const isHealthy = healthStatus && healthStatus.toLowerCase().includes('healthy');
        const isUnhealthy = healthStatus && healthStatus.toLowerCase().includes('unhealthy');
        const isStarting = healthStatus && healthStatus.toLowerCase().includes('starting');

        const actions = [
            {
                id: 'start',
                icon: 'play',
                label: 'Démarrer',
                disabled: isRunning
            },
            {
                id: 'stop',
                icon: 'square',
                label: 'Arrêter',
                disabled: !isRunning
            },
            {
                id: 'restart',
                icon: 'refresh-cw',
                label: 'Redémarrer'
            },
            {
                id: 'logs',
                icon: 'scroll-text',
                label: 'Logs'
            }
        ];

        const healthBadges = [
            isHealthy ? '<span class="health-badge healthy"><i data-lucide="heart" size="14"></i> Sain</span>' : '',
            isUnhealthy ? '<span class="health-badge unhealthy"><i data-lucide="alert-octagon" size="14"></i> En erreur</span>' : '',
            isStarting ? '<span class="health-badge starting"><i data-lucide="loader-2" size="14" class="animate-spin"></i> Démarrage</span>' : ''
        ].join('');

        return `
            <div class="docker-card">
                <div class="docker-card-header">
                    <div class="docker-name">${container.Names}</div>
                    <div class="docker-state ${stateClass}">${container.State}</div>
                </div>
                <div class="docker-status">
                    ${container.Status}
                    ${healthBadges}
                </div>
                <div class="docker-actions">
                    ${actions.map(action => `
                        <button
                            class="docker-btn"
                            data-action="${action.id}"
                            data-container="${container.Names}"
                            ${action.disabled ? 'disabled' : ''}
                        >
                            <i data-lucide="${action.icon}" size="16"></i>
                            <span>${action.label}</span>
                        </button>
                    `).join('')}
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

    /**
     * Restart entire stack (all containers with same prefix)
     * @param {string} stackName - Stack name (supabase, n8n, etc.)
     * @param {Array} containers - Array of container names
     */
    async restartStack(stackName, containers) {
        if (!containers || containers.length === 0) return;

        const confirmMsg = `Redémarrer ${containers.length} conteneur${containers.length > 1 ? 's' : ''} du stack ${stackName.toUpperCase()} ?\n\n${containers.join('\n')}`;

        if (!confirm(confirmMsg)) return;

        try {
            if (window.terminalManager) {
                window.terminalManager.addLine(
                    `🔄 Restarting ${stackName} stack (${containers.length} containers)...`,
                    'info'
                );
            }

            // Restart all containers in parallel
            const promises = containers.map(container =>
                this.executeAction('restart', container).catch(err => {
                    console.error(`Failed to restart ${container}:`, err);
                    return { success: false, container, error: err.message };
                })
            );

            const results = await Promise.all(promises);

            const failures = results.filter(r => r && r.success === false);

            if (failures.length > 0) {
                if (window.terminalManager) {
                    window.terminalManager.addLine(
                        `⚠️ ${failures.length} container(s) failed to restart`,
                        'warning'
                    );
                }
            } else {
                if (window.terminalManager) {
                    window.terminalManager.addLine(
                        `✅ ${stackName} stack restarted successfully`,
                        'success'
                    );
                }
            }

            // Reload after 3s
            setTimeout(() => this.load(), 3000);

        } catch (error) {
            if (window.terminalManager) {
                window.terminalManager.addLine(
                    `❌ Error restarting ${stackName} stack: ${error.message}`,
                    'error'
                );
            }
        }
    }

    /**
     * Stop entire stack (all containers with same prefix)
     * @param {string} stackName - Stack name
     * @param {Array} containers - Array of container names
     */
    async stopStack(stackName, containers) {
        if (!containers || containers.length === 0) return;

        const confirmMsg = `Arrêter ${containers.length} conteneur${containers.length > 1 ? 's' : ''} du stack ${stackName.toUpperCase()} ?\n\n${containers.join('\n')}`;

        if (!confirm(confirmMsg)) return;

        try {
            if (window.terminalManager) {
                window.terminalManager.addLine(
                    `⏹️ Stopping ${stackName} stack (${containers.length} containers)...`,
                    'info'
                );
            }

            // Stop all containers in parallel
            const promises = containers.map(container =>
                this.executeAction('stop', container).catch(err => {
                    console.error(`Failed to stop ${container}:`, err);
                    return { success: false, container, error: err.message };
                })
            );

            const results = await Promise.all(promises);

            const failures = results.filter(r => r && r.success === false);

            if (failures.length > 0) {
                if (window.terminalManager) {
                    window.terminalManager.addLine(
                        `⚠️ ${failures.length} container(s) failed to stop`,
                        'warning'
                    );
                }
            } else {
                if (window.terminalManager) {
                    window.terminalManager.addLine(
                        `✅ ${stackName} stack stopped successfully`,
                        'success'
                    );
                }
            }

            // Reload after 2s
            setTimeout(() => this.load(), 2000);

        } catch (error) {
            if (window.terminalManager) {
                window.terminalManager.addLine(
                    `❌ Error stopping ${stackName} stack: ${error.message}`,
                    'error'
                );
            }
        }
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
