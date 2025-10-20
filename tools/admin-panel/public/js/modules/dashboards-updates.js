// =============================================================================
// Dashboards Updates Module
// =============================================================================
// Manages Dashboard n8n and Admin Panel updates
// Version: 1.0.0
// =============================================================================

import api from '../utils/api.js';

class DashboardsUpdatesManager {
    constructor() {
        this.dashboards = [
            {
                id: 'dashboard-n8n',
                name: 'Dashboard n8n',
                description: 'Notifications temps réel & Quick Actions',
                currentVersion: '1.2.0',
                latestVersion: '1.2.0',
                status: 'up-to-date', // 'up-to-date', 'update-available', 'unknown'
                icon: 'layout-dashboard',
                color: '#3b82f6',
                features: [
                    'Trigger workflows n8n (1-click)',
                    'Stats 24h & health checks',
                    'Real-time WebSocket notifications'
                ],
                location: 'pi5.local:3000',
                repository: 'pi5-setup/01-infrastructure/dashboard'
            },
            {
                id: 'admin-panel',
                name: 'PI5 Control Center',
                description: 'Interface de gestion complète',
                currentVersion: '3.4.0',
                latestVersion: '3.4.0',
                status: 'up-to-date',
                icon: 'rocket',
                color: '#10b981',
                features: [
                    'SSH Tunnels management',
                    'Docker containers control',
                    'Scripts execution',
                    'System monitoring'
                ],
                location: 'localhost:4000',
                repository: 'pi5-setup/tools/admin-panel'
            }
        ];
    }

    /**
     * Initialize
     */
    init() {
        this.setupCategoryListener();
        console.log('✅ Dashboards Updates module initialized');
    }

    /**
     * Setup category listener
     */
    setupCategoryListener() {
        // Listen for category changes
        document.addEventListener('click', (e) => {
            const categoryBtn = e.target.closest('[data-category="updates-dashboards"]');
            if (categoryBtn) {
                this.render();
            }
        });
    }

    /**
     * Render dashboards list
     */
    render() {
        const container = document.getElementById('updates-panel-center');
        if (!container) {
            console.warn('[Dashboards Updates] Container not found');
            return;
        }

        // Update title
        const titleElement = document.getElementById('category-title');
        if (titleElement) {
            titleElement.innerHTML = '<i data-lucide="layout-dashboard" size="18"></i> Mises à jour - Dashboards';
        }

        container.innerHTML = `
            <div class="dashboards-updates-container">
                <div class="section-header">
                    <h2>
                        <i data-lucide="layout-dashboard" size="20"></i>
                        <span>Dashboards</span>
                    </h2>
                    <p class="section-description">
                        Gérer les mises à jour de vos interfaces de gestion
                    </p>
                </div>

                <div class="dashboards-grid">
                    ${this.dashboards.map(dashboard => this.renderDashboardCard(dashboard)).join('')}
                </div>
            </div>
        `;

        // Initialize icons
        if (window.lucide) window.lucide.createIcons();

        // Setup event listeners
        this.setupEventListeners();
    }

    /**
     * Render dashboard card
     */
    renderDashboardCard(dashboard) {
        const statusBadge = this.getStatusBadge(dashboard.status);
        const versionInfo = this.getVersionInfo(dashboard);

        return `
            <div class="dashboard-card" data-dashboard-id="${dashboard.id}">
                <div class="dashboard-header">
                    <div class="dashboard-icon" style="color: ${dashboard.color}">
                        <i data-lucide="${dashboard.icon}" size="32"></i>
                    </div>
                    <div class="dashboard-info">
                        <h3>${dashboard.name}</h3>
                        <p class="dashboard-description">${dashboard.description}</p>
                    </div>
                    ${statusBadge}
                </div>

                <div class="dashboard-body">
                    <!-- Version Info -->
                    <div class="version-section">
                        <div class="version-current">
                            <span class="version-label">Version actuelle</span>
                            <span class="version-value">${dashboard.currentVersion}</span>
                        </div>
                        ${versionInfo}
                    </div>

                    <!-- Features -->
                    <div class="features-section">
                        <h4>Fonctionnalités</h4>
                        <ul class="features-list-compact">
                            ${dashboard.features.slice(0, 3).map(f => `
                                <li><i data-lucide="check" size="14"></i>${f}</li>
                            `).join('')}
                        </ul>
                    </div>

                    <!-- Location -->
                    <div class="location-section">
                        <i data-lucide="map-pin" size="14"></i>
                        <span>${dashboard.location}</span>
                    </div>

                    <!-- Actions -->
                    <div class="dashboard-actions">
                        ${this.renderActions(dashboard)}
                    </div>
                </div>
            </div>
        `;
    }

    /**
     * Get status badge HTML
     */
    getStatusBadge(status) {
        const badges = {
            'up-to-date': '<span class="status-badge status-success">✓ À jour</span>',
            'update-available': '<span class="status-badge status-warning">↑ Mise à jour disponible</span>',
            'unknown': '<span class="status-badge status-secondary">? Inconnu</span>'
        };
        return badges[status] || badges['unknown'];
    }

    /**
     * Get version info HTML
     */
    getVersionInfo(dashboard) {
        if (dashboard.status === 'update-available') {
            return `
                <div class="version-latest">
                    <span class="version-label">Dernière version</span>
                    <span class="version-value highlight">${dashboard.latestVersion}</span>
                </div>
            `;
        }
        return '';
    }

    /**
     * Render actions based on dashboard
     */
    renderActions(dashboard) {
        if (dashboard.id === 'dashboard-n8n') {
            return `
                <button class="btn btn-primary btn-block" data-action="deploy" data-dashboard="dashboard-n8n">
                    <i data-lucide="upload-cloud" size="16"></i>
                    <span>Déployer sur Pi</span>
                </button>
                <div class="action-buttons">
                    <button class="btn btn-secondary btn-sm" data-action="logs" data-dashboard="dashboard-n8n">
                        <i data-lucide="file-text" size="14"></i>
                        <span>Logs</span>
                    </button>
                    <button class="btn btn-secondary btn-sm" data-action="restart" data-dashboard="dashboard-n8n">
                        <i data-lucide="rotate-cw" size="14"></i>
                        <span>Restart</span>
                    </button>
                    <button class="btn btn-secondary btn-sm" data-action="status" data-dashboard="dashboard-n8n">
                        <i data-lucide="activity" size="14"></i>
                        <span>Status</span>
                    </button>
                </div>
            `;
        }

        if (dashboard.id === 'admin-panel') {
            return `
                <button class="btn btn-secondary btn-block" data-action="open" data-dashboard="admin-panel">
                    <i data-lucide="external-link" size="16"></i>
                    <span>Ouvrir dans un nouvel onglet</span>
                </button>
                <div class="action-buttons">
                    <button class="btn btn-secondary btn-sm" data-action="check-updates" data-dashboard="admin-panel">
                        <i data-lucide="refresh-cw" size="14"></i>
                        <span>Vérifier mises à jour</span>
                    </button>
                </div>
            `;
        }

        return '';
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Deploy button
        document.querySelectorAll('[data-action="deploy"]').forEach(btn => {
            btn.addEventListener('click', () => {
                const dashboardId = btn.dataset.dashboard;
                this.handleDeploy(dashboardId);
            });
        });

        // Logs button
        document.querySelectorAll('[data-action="logs"]').forEach(btn => {
            btn.addEventListener('click', () => {
                const dashboardId = btn.dataset.dashboard;
                this.handleLogs(dashboardId);
            });
        });

        // Restart button
        document.querySelectorAll('[data-action="restart"]').forEach(btn => {
            btn.addEventListener('click', () => {
                const dashboardId = btn.dataset.dashboard;
                this.handleRestart(dashboardId);
            });
        });

        // Status button
        document.querySelectorAll('[data-action="status"]').forEach(btn => {
            btn.addEventListener('click', () => {
                const dashboardId = btn.dataset.dashboard;
                this.handleStatus(dashboardId);
            });
        });

        // Open button
        document.querySelectorAll('[data-action="open"]').forEach(btn => {
            btn.addEventListener('click', () => {
                const dashboardId = btn.dataset.dashboard;
                this.handleOpen(dashboardId);
            });
        });
    }

    /**
     * Handle deploy
     */
    async handleDeploy(dashboardId) {
        if (dashboardId === 'dashboard-n8n') {
            if (window.deploymentManager) {
                await window.deploymentManager.deployDashboard();
            }
        }
    }

    /**
     * Handle logs
     */
    async handleLogs(dashboardId) {
        if (dashboardId === 'dashboard-n8n') {
            if (window.deploymentManager) {
                await window.deploymentManager.viewLogs();
            }
        }
    }

    /**
     * Handle restart
     */
    async handleRestart(dashboardId) {
        if (dashboardId === 'dashboard-n8n') {
            if (window.deploymentManager) {
                await window.deploymentManager.restartDashboard();
            }
        }
    }

    /**
     * Handle status
     */
    async handleStatus(dashboardId) {
        if (dashboardId === 'dashboard-n8n') {
            if (window.deploymentManager) {
                await window.deploymentManager.checkStatus();
            }
        }
    }

    /**
     * Handle open
     */
    handleOpen(dashboardId) {
        const dashboard = this.dashboards.find(d => d.id === dashboardId);
        if (dashboard) {
            window.open(`http://${dashboard.location}`, '_blank');
        }
    }

    /**
     * Check for updates
     */
    async checkForUpdates() {
        // TODO: Implement version checking via GitHub API or package.json
        console.log('Checking for updates...');
    }
}

// Create singleton
const dashboardsUpdatesManager = new DashboardsUpdatesManager();

// Export
export default dashboardsUpdatesManager;

// Global access
window.dashboardsUpdatesManager = dashboardsUpdatesManager;
