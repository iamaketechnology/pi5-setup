// =============================================================================
// Database Setup Module
// =============================================================================

import api from '../utils/api.js';

class DatabaseManager {
    constructor() {
        this.socket = null;
        this.installing = false;
    }

    init() {
        this.setupEventListeners();
        console.log('✅ Database module initialized');
    }

    setupEventListeners() {
        // Refresh status button
        const refreshBtn = document.getElementById('refresh-db-status');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => this.loadStatus());
        }

        // Install button
        const installBtn = document.getElementById('install-db-schema');
        if (installBtn) {
            installBtn.addEventListener('click', () => this.installSchema());
        }

        // Clear logs button
        const clearBtn = document.getElementById('clear-db-logs');
        if (clearBtn) {
            clearBtn.addEventListener('click', () => this.clearLogs());
        }

        // Socket connection for real-time logs
        if (window.socket) {
            this.socket = window.socket;
            this.socket.on('db:install:log', (data) => {
                this.addLog(data.message, data.type);
            });
            this.socket.on('db:install:complete', (data) => {
                this.onInstallComplete(data);
            });
        }
    }

    async load() {
        await this.loadStatus();
    }

    async loadStatus() {
        const statusContent = document.getElementById('db-status-content');
        if (!statusContent) return;

        try {
            statusContent.innerHTML = '<div class="loading">Vérification du status...</div>';

            const status = await api.get('/database/status');

            this.renderStatus(status);
        } catch (error) {
            console.error('Failed to load database status:', error);
            statusContent.innerHTML = `
                <div class="db-status-item status-error">
                    <div class="db-status-label">Erreur</div>
                    <div class="db-status-value">Connexion échouée</div>
                    <div class="db-status-meta">${error.message}</div>
                </div>
            `;
        }
    }

    renderStatus(status) {
        const statusContent = document.getElementById('db-status-content');
        if (!statusContent) return;

        const isInstalled = status.schema_exists;
        const statusClass = isInstalled ? 'status-success' : 'status-warning';
        const statusText = isInstalled ? 'Installé' : 'Non installé';
        const statusIcon = isInstalled ? '✅' : '⚠️';

        let html = `
            <div class="db-status-grid">
                <div class="db-status-item ${statusClass}">
                    <div class="db-status-label">Schema</div>
                    <div class="db-status-value">${statusIcon} ${statusText}</div>
                    <div class="db-status-meta">control_center</div>
                </div>
        `;

        if (isInstalled) {
            html += `
                <div class="db-status-item status-success">
                    <div class="db-status-label">Tables</div>
                    <div class="db-status-value">${status.table_count || 0}</div>
                    <div class="db-status-meta">pis, installations, system_stats, scheduled_tasks</div>
                </div>
                <div class="db-status-item status-success">
                    <div class="db-status-label">Pis configurés</div>
                    <div class="db-status-value">${status.pi_count || 0}</div>
                    <div class="db-status-meta">${status.pi_names || 'Aucun'}</div>
                </div>
            `;
        }

        html += '</div>';

        if (isInstalled) {
            html += `
                <div style="margin-top: 16px; padding: 12px; background: var(--bg-success); border-left: 4px solid var(--success); border-radius: 6px;">
                    <strong style="color: var(--success);">✓ Schema installé avec succès</strong>
                    <p style="margin: 8px 0 0 0; color: var(--text-secondary); font-size: 14px;">
                        La base de données est prête. Vous pouvez maintenant utiliser le Control Center en mode multi-Pi.
                    </p>
                </div>
            `;
        } else {
            html += `
                <div style="margin-top: 16px; padding: 12px; background: var(--bg-warning); border-left: 4px solid var(--warning); border-radius: 6px;">
                    <strong style="color: var(--warning);">⚠ Schema non installé</strong>
                    <p style="margin: 8px 0 0 0; color: var(--text-secondary); font-size: 14px;">
                        Cliquez sur "Installer le Schema" ci-dessous pour configurer la base de données.
                    </p>
                </div>
            `;
        }

        statusContent.innerHTML = html;
    }

    async installSchema() {
        if (this.installing) {
            if (window.toastManager) {
                window.toastManager.warning('Installation en cours', 'Une installation est déjà en cours...');
            }
            return;
        }

        // Confirm with user
        if (!confirm('Installer le schema control_center sur Supabase ?\n\nCela va exécuter :\n• schema.sql\n• policies.sql\n• seed.sql')) {
            return;
        }

        this.installing = true;
        const installBtn = document.getElementById('install-db-schema');
        const logsPanel = document.getElementById('db-logs-panel');

        // Disable button
        if (installBtn) {
            installBtn.disabled = true;
            installBtn.innerHTML = '<i data-lucide="loader" size="18"></i><span>Installation...</span>';
            if (window.lucide) window.lucide.createIcons();
        }

        // Show logs panel
        if (logsPanel) {
            logsPanel.style.display = 'block';
        }

        // Clear previous logs
        this.clearLogs();

        try {
            this.addLog('🚀 Début de l\'installation du schema...', 'info');

            const result = await api.post('/database/install');

            if (result.success) {
                this.addLog('✅ Installation terminée avec succès!', 'success');
                this.addLog(`📊 ${result.pi_count} Pi(s) migré(s)`, 'success');

                if (window.toastManager) {
                    window.toastManager.success('Schema installé', 'Base de données configurée avec succès');
                }

                // Refresh status
                setTimeout(() => this.loadStatus(), 1000);
            } else {
                this.addLog(`❌ Erreur: ${result.error}`, 'error');

                if (window.toastManager) {
                    window.toastManager.error('Installation échouée', result.error);
                }
            }
        } catch (error) {
            console.error('Installation failed:', error);
            this.addLog(`❌ Erreur: ${error.message}`, 'error');

            if (window.toastManager) {
                window.toastManager.error('Installation échouée', error.message);
            }
        } finally {
            this.installing = false;

            // Re-enable button
            if (installBtn) {
                installBtn.disabled = false;
                installBtn.innerHTML = '<i data-lucide="database" size="18"></i><span>Installer le Schema</span>';
                if (window.lucide) window.lucide.createIcons();
            }
        }
    }

    addLog(message, type = 'info') {
        const logsContainer = document.getElementById('db-logs');
        if (!logsContainer) return;

        const timestamp = new Date().toLocaleTimeString('fr-FR');
        const logLine = document.createElement('div');
        logLine.className = `db-log-line log-${type}`;
        logLine.innerHTML = `<span class="timestamp">[${timestamp}]</span>${message}`;

        logsContainer.appendChild(logLine);

        // Auto-scroll to bottom
        logsContainer.scrollTop = logsContainer.scrollHeight;
    }

    clearLogs() {
        const logsContainer = document.getElementById('db-logs');
        if (logsContainer) {
            logsContainer.innerHTML = '';
        }
    }

    onInstallComplete(data) {
        this.installing = false;

        if (data.success) {
            this.addLog('✅ Installation terminée', 'success');
            this.loadStatus();
        } else {
            this.addLog(`❌ Installation échouée: ${data.error}`, 'error');
        }
    }
}

// Export singleton
const databaseManager = new DatabaseManager();
export default databaseManager;
