// =============================================================================
// Deployment Module - Deploy Dashboard Updates to Pi
// =============================================================================

import api from '../utils/api.js';

class DeploymentManager {
    constructor() {
        this.isDeploying = false;
    }

    /**
     * Deploy dashboard to Pi
     */
    async deployDashboard() {
        if (this.isDeploying) {
            if (window.toastManager) {
                window.toastManager.warning('Déploiement déjà en cours...');
            }
            return;
        }

        if (!confirm('Déployer la mise à jour du Dashboard n8n sur le Pi ?\n\nCela va :\n- Copier les fichiers\n- Installer les dépendances\n- Redémarrer le container')) {
            return;
        }

        this.isDeploying = true;

        try {
            if (window.toastManager) {
                window.toastManager.info('🚀 Déploiement en cours...');
            }

            const response = await api.post('/deploy/dashboard');

            if (response.success) {
                if (window.toastManager) {
                    window.toastManager.success(`✅ Dashboard déployé sur ${response.piHost}`);
                }

                // Show deployment output in modal
                this.showDeploymentOutput(response.output, response.piHost);
            } else {
                throw new Error(response.error || 'Deployment failed');
            }
        } catch (error) {
            console.error('Deployment failed:', error);

            if (window.toastManager) {
                window.toastManager.error(`❌ Erreur: ${error.message}`);
            }

            // Show error details in modal
            this.showDeploymentOutput(
                error.output || error.message,
                'Error',
                error.stderr
            );
        } finally {
            this.isDeploying = false;
        }
    }

    /**
     * Check deployment status
     */
    async checkStatus() {
        try {
            const response = await api.get('/deploy/status');

            if (response.success) {
                const status = response.running ? '🟢 Running' : '🔴 Stopped';
                const message = `Dashboard: ${status}\nHost: ${response.piHost || 'N/A'}`;

                if (window.toastManager) {
                    window.toastManager.info(message);
                }

                return response;
            }
        } catch (error) {
            console.error('Status check failed:', error);
            if (window.toastManager) {
                window.toastManager.error('Erreur vérification status');
            }
        }
    }

    /**
     * Restart dashboard container
     */
    async restartDashboard() {
        if (!confirm('Redémarrer le Dashboard n8n ?')) {
            return;
        }

        try {
            if (window.toastManager) {
                window.toastManager.info('🔄 Redémarrage...');
            }

            const response = await api.post('/deploy/restart');

            if (response.success) {
                if (window.toastManager) {
                    window.toastManager.success('✅ Dashboard redémarré');
                }
            } else {
                throw new Error(response.error || 'Restart failed');
            }
        } catch (error) {
            console.error('Restart failed:', error);
            if (window.toastManager) {
                window.toastManager.error(`❌ Erreur: ${error.message}`);
            }
        }
    }

    /**
     * View dashboard logs
     */
    async viewLogs() {
        try {
            const response = await api.get('/deploy/logs?lines=100');

            if (response.success) {
                this.showLogsModal(response.logs);
            } else {
                throw new Error(response.error || 'Failed to fetch logs');
            }
        } catch (error) {
            console.error('Logs fetch failed:', error);
            if (window.toastManager) {
                window.toastManager.error('Erreur récupération logs');
            }
        }
    }

    /**
     * Show deployment output modal
     */
    showDeploymentOutput(output, title = 'Déploiement', stderr = '') {
        const modal = document.createElement('div');
        modal.className = 'deployment-modal';
        modal.innerHTML = `
            <div class="modal-overlay" onclick="this.parentElement.remove()"></div>
            <div class="modal-content large">
                <div class="modal-header">
                    <h3>📦 ${title}</h3>
                    <button class="btn-close" onclick="this.closest('.deployment-modal').remove()">✕</button>
                </div>
                <div class="modal-body">
                    <pre class="deployment-output">${this.escapeHtml(output)}</pre>
                    ${stderr ? `<pre class="deployment-error">${this.escapeHtml(stderr)}</pre>` : ''}
                </div>
                <div class="modal-footer">
                    <button class="btn btn-secondary" onclick="this.closest('.deployment-modal').remove()">
                        Fermer
                    </button>
                </div>
            </div>
        `;
        document.body.appendChild(modal);
    }

    /**
     * Show logs modal
     */
    showLogsModal(logs) {
        const modal = document.createElement('div');
        modal.className = 'deployment-modal';
        modal.innerHTML = `
            <div class="modal-overlay" onclick="this.parentElement.remove()"></div>
            <div class="modal-content large">
                <div class="modal-header">
                    <h3>📝 Dashboard Logs</h3>
                    <button class="btn-close" onclick="this.closest('.deployment-modal').remove()">✕</button>
                </div>
                <div class="modal-body">
                    <pre class="logs-output">${this.escapeHtml(logs)}</pre>
                </div>
                <div class="modal-footer">
                    <button class="btn btn-primary" onclick="window.deploymentManager.viewLogs()">
                        Rafraîchir
                    </button>
                    <button class="btn btn-secondary" onclick="this.closest('.deployment-modal').remove()">
                        Fermer
                    </button>
                </div>
            </div>
        `;
        document.body.appendChild(modal);
    }

    /**
     * Escape HTML
     */
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    /**
     * Add deployment section to Installation > Updates
     */
    addDeployButton() {
        const updatesPanel = document.getElementById('updates-panel-center');
        if (!updatesPanel) {
            console.warn('[Deployment] updates-panel-center not found');
            return;
        }

        // Check if already added
        if (document.getElementById('dashboard-deploy-section')) return;

        // Create deployment card
        const deploySection = document.createElement('div');
        deploySection.id = 'dashboard-deploy-section';
        deploySection.className = 'deployment-card';
        deploySection.innerHTML = `
            <div class="card-header">
                <div class="header-left">
                    <i data-lucide="layout-dashboard" size="24"></i>
                    <div>
                        <h3>Dashboard n8n</h3>
                        <p class="card-subtitle">Notifications temps réel & Quick Actions</p>
                    </div>
                </div>
                <span class="version-badge">v1.2.0</span>
            </div>
            <div class="card-body">
                <div class="features-list">
                    <div class="feature-item">
                        <i data-lucide="check-circle" size="16"></i>
                        <span>Trigger workflows n8n (1-click)</span>
                    </div>
                    <div class="feature-item">
                        <i data-lucide="check-circle" size="16"></i>
                        <span>Stats 24h & health checks</span>
                    </div>
                    <div class="feature-item">
                        <i data-lucide="check-circle" size="16"></i>
                        <span>Real-time WebSocket notifications</span>
                    </div>
                </div>
                <div class="deploy-actions">
                    <button id="deploy-dashboard-btn" class="btn btn-primary btn-large">
                        <i data-lucide="upload-cloud" size="18"></i>
                        <span>Déployer sur Pi</span>
                    </button>
                    <div class="secondary-actions">
                        <button id="dashboard-logs-btn" class="btn btn-secondary" title="Voir logs">
                            <i data-lucide="file-text" size="16"></i>
                            <span>Logs</span>
                        </button>
                        <button id="dashboard-restart-btn" class="btn btn-secondary" title="Redémarrer">
                            <i data-lucide="rotate-cw" size="16"></i>
                            <span>Restart</span>
                        </button>
                        <button id="dashboard-status-btn" class="btn btn-secondary" title="Vérifier status">
                            <i data-lucide="activity" size="16"></i>
                            <span>Status</span>
                        </button>
                    </div>
                </div>
            </div>
        `;

        // Insert at the top of updates panel
        updatesPanel.insertBefore(deploySection, updatesPanel.firstChild);

        // Initialize icons
        if (window.lucide) window.lucide.createIcons();

        // Event listeners
        document.getElementById('deploy-dashboard-btn')?.addEventListener('click', () => {
            this.deployDashboard();
        });

        document.getElementById('dashboard-logs-btn')?.addEventListener('click', () => {
            this.viewLogs();
        });

        document.getElementById('dashboard-restart-btn')?.addEventListener('click', () => {
            this.restartDashboard();
        });

        document.getElementById('dashboard-status-btn')?.addEventListener('click', () => {
            this.checkStatus();
        });

        console.log('✅ Dashboard deployment section added to Updates');
    }
}

// Create singleton
const deploymentManager = new DeploymentManager();

// Export
export default deploymentManager;

// Global access
window.deploymentManager = deploymentManager;
