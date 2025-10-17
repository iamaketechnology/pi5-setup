// =============================================================================
// History Manager Module
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

import api from '../utils/api.js';

/**
 * HistoryManager - Manages execution history
 */
class HistoryManager {
    constructor() {
        this.executions = [];
        this.stats = null;
        this.storageKey = 'pi5-history-filters';
    }

    /**
     * Initialize history module
     */
    init() {
        this.setupEventListeners();
        this.restoreFilters();
        console.log('✅ History module initialized');
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Refresh button
        const refreshBtn = document.getElementById('refresh-history');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => this.load());
        }

        // Filter change handlers
        const statusFilter = document.getElementById('filter-status');
        if (statusFilter) {
            statusFilter.addEventListener('change', () => {
                this.persistFilters();
                this.load();
            });
        }

        const typeFilter = document.getElementById('filter-type');
        if (typeFilter) {
            typeFilter.addEventListener('change', () => {
                this.persistFilters();
                this.load();
            });
        }

        // Search input
        const searchInput = document.getElementById('search-history');
        if (searchInput) {
            searchInput.addEventListener('input', this.debounce(() => {
                this.persistFilters();
                this.load();
            }, 500));
        }

        const shareBtn = document.getElementById('history-share');
        if (shareBtn) {
            shareBtn.addEventListener('click', () => this.copyShareLink());
        }
    }

    /**
     * Load history from API
     */
    async load() {
        try {
            this.persistFilters();
            const status = document.getElementById('filter-status')?.value || '';
            const type = document.getElementById('filter-type')?.value || '';
            const search = document.getElementById('search-history')?.value || '';
            const piId = window.currentPiId || '';

            const params = new URLSearchParams();
            if (status) params.append('status', status);
            if (type) params.append('type', type);
            if (search) params.append('search', search);
            if (piId) params.append('piId', piId);

            const data = await api.get(`/history?${params.toString()}`);

            this.stats = data.stats;
            this.executions = data.executions || [];

            this.renderStats();
            this.renderTable();

            return data;
        } catch (error) {
            console.error('Failed to load history:', error);
            throw error;
        }
    }

    getFilterState() {
        return {
            status: document.getElementById('filter-status')?.value || '',
            type: document.getElementById('filter-type')?.value || '',
            search: document.getElementById('search-history')?.value || ''
        };
    }

    persistFilters() {
        try {
            const filters = this.getFilterState();
            localStorage.setItem(this.storageKey, JSON.stringify(filters));
        } catch (error) {
            console.warn('Impossible de sauvegarder les filtres de l\'historique:', error);
        }
    }

    restoreFilters() {
        try {
            const params = new URLSearchParams(window.location.search);
            const stored = localStorage.getItem(this.storageKey);
            const defaults = stored ? JSON.parse(stored) : {};

            const status = params.get('historyStatus') ?? defaults.status ?? '';
            const type = params.get('historyType') ?? defaults.type ?? '';
            const search = params.get('historySearch') ?? defaults.search ?? '';

            const statusSelect = document.getElementById('filter-status');
            const typeSelect = document.getElementById('filter-type');
            const searchInput = document.getElementById('search-history');

            if (statusSelect) statusSelect.value = status;
            if (typeSelect) typeSelect.value = type;
            if (searchInput) searchInput.value = search;

            if (params.has('historyStatus') || params.has('historyType') || params.has('historySearch')) {
                this.persistFilters();
            }
        } catch (error) {
            console.warn('Impossible de restaurer les filtres de l\'historique:', error);
        }
    }

    copyShareLink() {
        try {
            const state = this.getFilterState();
            const params = new URLSearchParams();

            if (state.status) params.set('historyStatus', state.status);
            if (state.type) params.set('historyType', state.type);
            if (state.search) params.set('historySearch', state.search);
            if (window.currentPiId) params.set('piId', window.currentPiId);

            const baseUrl = `${window.location.origin}${window.location.pathname}`;
            const url = params.toString() ? `${baseUrl}?${params.toString()}` : baseUrl;

            if (navigator.clipboard?.writeText) {
                navigator.clipboard.writeText(url).then(() => {
                    window.toastManager?.success('Lien copié', 'Filtres prêts à être partagés');
                }).catch(() => {
                    window.toastManager?.info('Lien des filtres', url);
                });
            } else {
                window.toastManager?.info('Lien des filtres', url);
            }
        } catch (error) {
            console.error('Erreur lors du partage des filtres:', error);
            window.toastManager?.error('Partage impossible', error.message);
        }
    }

    /**
     * Render stats summary
     */
    renderStats() {
        if (!this.stats) return;

        const elements = {
            'hist-total': this.stats.total || 0,
            'hist-success': this.stats.success || 0,
            'hist-failed': this.stats.failed || 0,
            'hist-avg-duration': this.stats.avgDuration || '-'
        };

        Object.entries(elements).forEach(([id, value]) => {
            const el = document.getElementById(id);
            if (el) el.textContent = value;
        });
    }

    /**
     * Render history table
     */
    renderTable() {
        const tbody = document.getElementById('history-table-body');
        if (!tbody) return;

        if (!this.executions || this.executions.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7" class="loading">Aucune exécution</td></tr>';
            return;
        }

        tbody.innerHTML = this.executions.map(exec => this.renderRow(exec)).join('');

        if (typeof lucide !== 'undefined') {
            lucide.createIcons({ root: tbody });
        }
    }

    /**
     * Render single history row
     * @param {Object} exec - Execution data
     * @returns {string} HTML string
     */
    renderRow(exec) {
        const statusIcons = {
            'success': '<i data-lucide="check-circle" size="14"></i>',
            'failed': '<i data-lucide="x-circle" size="14"></i>',
            'running': '<i data-lucide="loader-2" size="14" class="animate-spin"></i>'
        };
        const statusIcon = statusIcons[exec.status] || '<i data-lucide="help-circle" size="14"></i>';
        const statusLabels = {
            'success': 'Succès',
            'failed': 'Échec',
            'running': 'En cours'
        };
        const statusLabel = statusLabels[exec.status] || exec.status;

        const date = new Date(exec.started_at).toLocaleString('fr-FR', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });

        const duration = exec.duration
            ? `${Math.round(exec.duration / 1000)}s`
            : '-';

        // Get Pi name from global allPis
        const piName = window.allPis?.find(p => p.id === exec.pi_id)?.name || exec.pi_id;

        return `
            <tr>
                <td>${date}</td>
                <td>${exec.script_name}</td>
                <td>${piName}</td>
                <td><span class="badge ${exec.script_type || 'default'}">${exec.script_type || 'N/D'}</span></td>
                <td><span class="status-badge ${exec.status}">${statusIcon} ${statusLabel}</span></td>
                <td>${duration}</td>
                <td>
                    <button
                        class="icon-btn"
                        data-execution-id="${exec.id}"
                        onclick="viewExecution(${exec.id})"
                        title="Voir détails"
                    >
                        <i data-lucide="eye" size="16"></i>
                    </button>
                </td>
            </tr>
        `;
    }

    /**
     * View execution details
     * @param {number} executionId - Execution ID
     */
    async viewExecution(executionId) {
        try {
            const exec = await api.get(`/api/history/${executionId}`);
            this.showExecutionModal(exec);
            return exec;
        } catch (error) {
            console.error('Failed to load execution details:', error);
            if (window.terminalManager) {
                window.terminalManager.addLine(
                    `❌ Error loading execution details: ${error.message}`,
                    'error'
                );
            }
            throw error;
        }
    }

    /**
     * Show execution details modal
     * @param {Object} exec - Execution data
     */
    showExecutionModal(exec) {
        const modal = document.getElementById('exec-detail-modal');
        const content = document.getElementById('exec-detail-content');

        if (!modal || !content) return;

        const statusIcons = {
            'success': '✅',
            'failed': '❌',
            'running': '⏳'
        };
        const statusIcon = statusIcons[exec.status] || '❓';

        const date = new Date(exec.started_at).toLocaleString('fr-FR');
        const duration = exec.duration
            ? `${Math.round(exec.duration / 1000)}s`
            : 'En cours...';

        const piName = window.allPis?.find(p => p.id === exec.pi_id)?.name || exec.pi_id;

        content.innerHTML = `
            <div class="detail-section">
                <h4>📋 Informations Générales</h4>
                <div class="detail-grid">
                    <div><strong>Script:</strong> ${exec.script_name}</div>
                    <div><strong>Statut:</strong> <span class="status-badge ${exec.status}">${statusIcon} ${exec.status}</span></div>
                    <div><strong>Pi:</strong> ${piName}</div>
                    <div><strong>Type:</strong> ${exec.script_type || 'N/A'}</div>
                    <div><strong>Date:</strong> ${date}</div>
                    <div><strong>Durée:</strong> ${duration}</div>
                    <div><strong>Déclenché par:</strong> ${exec.triggered_by || 'manual'}</div>
                    <div><strong>Code sortie:</strong> ${exec.exit_code !== null ? exec.exit_code : 'N/A'}</div>
                </div>
            </div>

            ${exec.output ? `
                <div class="detail-section">
                    <h4>📤 Output</h4>
                    <pre class="output-box">${this.escapeHtml(exec.output)}</pre>
                </div>
            ` : ''}

            ${exec.error ? `
                <div class="detail-section">
                    <h4>❌ Erreurs</h4>
                    <pre class="output-box error">${this.escapeHtml(exec.error)}</pre>
                </div>
            ` : ''}
        `;

        modal.classList.remove('hidden');
    }

    /**
     * Hide execution details modal
     */
    hideExecutionModal() {
        const modal = document.getElementById('exec-detail-modal');
        if (modal) {
            modal.classList.add('hidden');
        }
    }

    /**
     * Escape HTML
     * @param {string} text - Text to escape
     * @returns {string} Escaped text
     */
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    /**
     * Debounce helper
     * @param {Function} func - Function to debounce
     * @param {number} wait - Wait time in ms
     * @returns {Function} Debounced function
     */
    debounce(func, wait) {
        let timeout;
        return (...args) => {
            clearTimeout(timeout);
            timeout = setTimeout(() => func.apply(this, args), wait);
        };
    }
}

// Create singleton instance
const historyManager = new HistoryManager();

// Export
export default historyManager;

// Global access for backward compatibility
window.historyManager = historyManager;
window.viewExecution = (id) => historyManager.viewExecution(id);
window.hideExecModal = () => historyManager.hideExecutionModal();
