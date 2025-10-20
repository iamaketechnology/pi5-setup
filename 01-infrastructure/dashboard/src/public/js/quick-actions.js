// =============================================================================
// Quick Actions Module
// =============================================================================
// Version: 1.0.0
// Description: Quick actions for n8n workflows, stats, and health checks
// =============================================================================

/**
 * Quick Actions Manager
 */
class QuickActionsManager {
    constructor() {
        this.workflows = [];
        this.stats = null;
        this.refreshInterval = null;
    }

    /**
     * Initialize Quick Actions
     */
    async init() {
        console.log('[Quick Actions] Initializing...');

        await this.loadWorkflows();
        await this.loadStats();

        this.render();
        this.setupEventListeners();
        this.startAutoRefresh();

        console.log('[Quick Actions] Initialized');
    }

    /**
     * Load n8n workflows
     */
    async loadWorkflows() {
        try {
            const response = await fetch('/api/n8n/workflows');
            const data = await response.json();

            if (data.success) {
                this.workflows = data.workflows;
                console.log(`[Quick Actions] Loaded ${this.workflows.length} workflows`);
            } else {
                console.warn('[Quick Actions] Failed to load workflows:', data.error);
            }
        } catch (error) {
            console.error('[Quick Actions] Error loading workflows:', error);
        }
    }

    /**
     * Load dashboard stats
     */
    async loadStats() {
        try {
            const response = await fetch('/api/stats');
            this.stats = await response.json();
            console.log('[Quick Actions] Stats loaded');
        } catch (error) {
            console.error('[Quick Actions] Error loading stats:', error);
        }
    }

    /**
     * Trigger workflow
     */
    async triggerWorkflow(workflowId, workflowName) {
        if (!confirm(`Déclencher le workflow "${workflowName}" ?`)) {
            return;
        }

        try {
            const response = await fetch(`/api/n8n/workflows/${workflowId}/trigger`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ source: 'dashboard' })
            });

            const result = await response.json();

            if (result.success) {
                this.showToast(`✅ Workflow "${workflowName}" déclenché`, 'success');
            } else {
                this.showToast(`❌ Erreur: ${result.error}`, 'error');
            }
        } catch (error) {
            console.error('[Quick Actions] Trigger error:', error);
            this.showToast('❌ Erreur de connexion', 'error');
        }
    }

    /**
     * Check services health
     */
    async checkHealth() {
        try {
            const response = await fetch('/api/health/services');
            const health = await response.json();

            this.showHealthModal(health);
        } catch (error) {
            console.error('[Quick Actions] Health check error:', error);
            this.showToast('❌ Erreur health check', 'error');
        }
    }

    /**
     * Render quick actions UI
     */
    render() {
        const container = document.getElementById('quick-actions-container');
        if (!container) {
            console.warn('[Quick Actions] Container not found, creating...');
            this.createContainer();
            return;
        }

        container.innerHTML = `
            <div class="quick-actions-panel">
                ${this.renderStatsWidget()}
                ${this.renderWorkflowsWidget()}
                ${this.renderHealthWidget()}
            </div>
        `;
    }

    /**
     * Create container if not exists
     */
    createContainer() {
        const header = document.querySelector('.dashboard-header');
        if (!header) return;

        const container = document.createElement('div');
        container.id = 'quick-actions-container';
        container.className = 'quick-actions-wrapper';

        header.parentNode.insertBefore(container, header.nextSibling);

        this.render();
    }

    /**
     * Render stats widget
     */
    renderStatsWidget() {
        if (!this.stats) {
            return '<div class="stats-widget">Chargement stats...</div>';
        }

        const { last24h } = this.stats;

        return `
            <div class="stats-widget">
                <h3>📊 Statistiques 24h</h3>
                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-value">${last24h.total}</div>
                        <div class="stat-label">Total</div>
                    </div>
                    <div class="stat-card success">
                        <div class="stat-value">${last24h.success}</div>
                        <div class="stat-label">Succès</div>
                    </div>
                    <div class="stat-card error">
                        <div class="stat-value">${last24h.error}</div>
                        <div class="stat-label">Erreurs</div>
                    </div>
                    <div class="stat-card rate">
                        <div class="stat-value">${last24h.successRate}</div>
                        <div class="stat-label">Taux de succès</div>
                    </div>
                </div>
            </div>
        `;
    }

    /**
     * Render workflows widget
     */
    renderWorkflowsWidget() {
        if (this.workflows.length === 0) {
            return `
                <div class="workflows-widget">
                    <h3>⚡ Workflows n8n</h3>
                    <p class="empty-state">Aucun workflow disponible</p>
                </div>
            `;
        }

        const activeWorkflows = this.workflows.filter(w => w.active);

        return `
            <div class="workflows-widget">
                <h3>⚡ Workflows n8n (${activeWorkflows.length} actifs)</h3>
                <div class="workflows-list">
                    ${activeWorkflows.slice(0, 5).map(w => `
                        <div class="workflow-item">
                            <div class="workflow-info">
                                <span class="workflow-name">${w.name}</span>
                                <span class="workflow-badge ${w.active ? 'active' : 'inactive'}">
                                    ${w.active ? '✓ Actif' : '○ Inactif'}
                                </span>
                            </div>
                            <button
                                class="btn-trigger"
                                onclick="quickActions.triggerWorkflow('${w.id}', '${w.name}')"
                                title="Déclencher ce workflow">
                                ▶
                            </button>
                        </div>
                    `).join('')}
                </div>
                ${activeWorkflows.length > 5 ? `<div class="workflows-more">+${activeWorkflows.length - 5} workflows</div>` : ''}
            </div>
        `;
    }

    /**
     * Render health widget
     */
    renderHealthWidget() {
        return `
            <div class="health-widget">
                <h3>🏥 Services</h3>
                <button class="btn btn-secondary" onclick="quickActions.checkHealth()">
                    Vérifier l'état
                </button>
            </div>
        `;
    }

    /**
     * Show health modal
     */
    showHealthModal(health) {
        const modal = document.createElement('div');
        modal.className = 'health-modal';
        modal.innerHTML = `
            <div class="modal-overlay" onclick="this.parentElement.remove()"></div>
            <div class="modal-content">
                <div class="modal-header">
                    <h3>🏥 État des Services</h3>
                    <button class="btn-close" onclick="this.closest('.health-modal').remove()">✕</button>
                </div>
                <div class="modal-body">
                    ${this.renderHealthServices(health.services)}
                </div>
                <div class="modal-footer">
                    <small>Dernière vérification: ${new Date(health.timestamp).toLocaleString('fr-FR')}</small>
                </div>
            </div>
        `;
        document.body.appendChild(modal);
    }

    /**
     * Render health services list
     */
    renderHealthServices(services) {
        return Object.entries(services).map(([key, service]) => {
            const statusClass = service.status === 'healthy' ? 'healthy' : 'unhealthy';
            const statusIcon = service.status === 'healthy' ? '✅' : '❌';

            return `
                <div class="service-health ${statusClass}">
                    <div class="service-name">
                        ${statusIcon} ${service.name || key}
                    </div>
                    <div class="service-status">
                        ${service.status}
                        ${service.statusCode ? `(${service.statusCode})` : ''}
                    </div>
                    ${service.url ? `<div class="service-url">${service.url}</div>` : ''}
                    ${service.error ? `<div class="service-error">${service.error}</div>` : ''}
                </div>
            `;
        }).join('');
    }

    /**
     * Show toast notification
     */
    showToast(message, type = 'info') {
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
        `;
        document.body.appendChild(toast);

        setTimeout(() => {
            toast.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey && e.key === 'h') {
                e.preventDefault();
                this.checkHealth();
            }
            if (e.ctrlKey && e.key === 'r') {
                e.preventDefault();
                this.refresh();
            }
        });
    }

    /**
     * Start auto-refresh
     */
    startAutoRefresh() {
        // Refresh stats every 30s
        this.refreshInterval = setInterval(() => {
            this.loadStats().then(() => {
                const statsWidget = document.querySelector('.stats-widget');
                if (statsWidget) {
                    statsWidget.outerHTML = this.renderStatsWidget();
                }
            });
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
     * Manual refresh
     */
    async refresh() {
        await Promise.all([
            this.loadWorkflows(),
            this.loadStats()
        ]);
        this.render();
        this.showToast('✅ Données rafraîchies', 'success');
    }

    /**
     * Cleanup
     */
    destroy() {
        this.stopAutoRefresh();
    }
}

// Create singleton instance
const quickActions = new QuickActionsManager();

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => quickActions.init());
} else {
    quickActions.init();
}

// Export for global access
window.quickActions = quickActions;
