// =============================================================================
// Scheduler Manager Module
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

import api from '../utils/api.js';

/**
 * SchedulerManager - Manages scheduled tasks
 */
class SchedulerManager {
    constructor() {
        this.tasks = [];
        this.filterStorageKey = 'pi5-scheduler-filters';
    }

    /**
     * Initialize scheduler module
     */
    init() {
        this.setupEventListeners();
        this.setupFilters();
        console.log('✅ Scheduler module initialized');
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Add task button
        const addBtn = document.getElementById('add-task');
        if (addBtn) {
            addBtn.addEventListener('click', () => this.showAddTaskModal());
        }

        // Add task form
        const form = document.getElementById('add-task-form');
        if (form) {
            form.addEventListener('submit', (e) => this.handleAddTask(e));
        }
    }

    setupFilters() {
        this.restoreFilters();
        this.populatePiFilter();

        const piFilter = document.getElementById('filter-task-pi');
        if (piFilter) {
            piFilter.addEventListener('change', () => {
                this.persistFilters();
                this.render();
            });
        }

        const statusFilter = document.getElementById('filter-task-status');
        if (statusFilter) {
            statusFilter.addEventListener('change', () => {
                this.persistFilters();
                this.render();
            });
        }

        const shareBtn = document.getElementById('scheduler-share');
        if (shareBtn) {
            shareBtn.addEventListener('click', () => this.copyShareLink());
        }

        window.addEventListener('pi:switched', () => {
            this.populatePiFilter();
            this.persistFilters();
            this.render();
        });

        window.addEventListener('pi:list-updated', () => {
            this.populatePiFilter();
        });
    }

    /**
     * Load scheduled tasks
     */
    async load() {
        try {
            const data = await api.get('/scheduler/tasks');
            this.tasks = data.tasks || [];
            this.render();
            this.updateSummary();
            return this.tasks;
        } catch (error) {
            console.error('Failed to load scheduled tasks:', error);
            throw error;
        }
    }

    /**
     * Render tasks
     */
    render() {
        const container = document.getElementById('scheduler-tasks');
        if (!container) return;

        const tasks = this.getFilteredTasks();

        if (!tasks || tasks.length === 0) {
            container.innerHTML = '<div class="loading">Aucune tâche planifiée</div>';
            return;
        }

        container.innerHTML = tasks.map(task => this.renderTask(task)).join('');

        if (typeof lucide !== 'undefined') {
            lucide.createIcons({ root: container });
        }
    }

    getFilteredTasks() {
        const filters = this.getFilterState();

        return (this.tasks || []).filter(task => {
            const matchPi = !filters.pi || task.pi_id === filters.pi;
            const matchStatus = !filters.status
                || (filters.status === 'enabled' && task.enabled)
                || (filters.status === 'disabled' && !task.enabled);
            return matchPi && matchStatus;
        });
    }

    getFilterState() {
        return {
            pi: document.getElementById('filter-task-pi')?.value || '',
            status: document.getElementById('filter-task-status')?.value || ''
        };
    }

    persistFilters() {
        try {
            localStorage.setItem(this.filterStorageKey, JSON.stringify(this.getFilterState()));
        } catch (error) {
            console.warn('Impossible de sauvegarder les filtres du planificateur:', error);
        }
    }

    restoreFilters() {
        try {
            const params = new URLSearchParams(window.location.search);
            const stored = localStorage.getItem(this.filterStorageKey);
            const defaults = stored ? JSON.parse(stored) : {};

            const pi = params.get('schedulerPi') ?? defaults.pi ?? '';
            const status = params.get('schedulerStatus') ?? defaults.status ?? '';

            const piSelect = document.getElementById('filter-task-pi');
            const statusSelect = document.getElementById('filter-task-status');

            if (piSelect) piSelect.value = pi;
            if (statusSelect) statusSelect.value = status;

            this.restoredFilters = { pi, status };

            if (params.has('schedulerPi') || params.has('schedulerStatus')) {
                this.persistFilters();
            }
        } catch (error) {
            console.warn('Impossible de restaurer les filtres du planificateur:', error);
        }
    }

    populatePiFilter() {
        const piSelect = document.getElementById('filter-task-pi');
        if (!piSelect) return;

        const currentValue = piSelect.value;
        const desiredValue = this.restoredFilters?.pi || currentValue;
        piSelect.innerHTML = '<option value="">Tous les Pi</option>' +
            (window.allPis || []).map(pi => `<option value="${pi.id}">${pi.name}</option>`).join('');

        if (desiredValue && Array.from(piSelect.options).some(opt => opt.value === desiredValue)) {
            piSelect.value = desiredValue;
        }
    }

    copyShareLink() {
        try {
            const filters = this.getFilterState();
            const params = new URLSearchParams();

            if (filters.pi) params.set('schedulerPi', filters.pi);
            if (filters.status) params.set('schedulerStatus', filters.status);
            if (window.currentPiId) params.set('piId', window.currentPiId);

            const baseUrl = `${window.location.origin}${window.location.pathname}`;
            const url = params.toString() ? `${baseUrl}?${params.toString()}` : baseUrl;

            if (navigator.clipboard?.writeText) {
                navigator.clipboard.writeText(url).then(() => {
                    window.toastManager?.success('Lien copié', 'Partagez cette vue du planificateur');
                }).catch(() => window.toastManager?.info('Lien du planificateur', url));
            } else {
                window.toastManager?.info('Lien du planificateur', url);
            }
        } catch (error) {
            console.error('Erreur lors du partage du planificateur:', error);
            window.toastManager?.error('Partage impossible', error.message);
        }
    }

    /**
     * Render single task
     * @param {Object} task - Task data
     * @returns {string} HTML string
     */
    renderTask(task) {
        const piName = window.allPis?.find(p => p.id === task.pi_id)?.name || task.pi_id;
        const statusClass = task.enabled ? 'enabled' : 'disabled';
        const toggleClass = task.enabled ? 'active' : '';

        const lastRun = task.last_run
            ? `<div><strong>Dernière exéc.:</strong> ${new Date(task.last_run).toLocaleString('fr-FR')}</div>`
            : '';

        const nextRun = task.next_run
            ? `<div><strong>Prochaine exéc.:</strong> ${new Date(task.next_run).toLocaleString('fr-FR')}</div>`
            : '';

        return `
            <div class="task-card ${statusClass}">
                <div class="task-header">
                    <div>
                        <div class="task-name">${task.name}</div>
                        <div class="task-cron">⏰ ${task.cron_expression}</div>
                    </div>
                    <div
                        class="toggle-switch ${toggleClass}"
                        onclick="toggleTask(${task.id}, ${!task.enabled})"
                    ></div>
                </div>
                <div class="task-details">
                    <div><strong>Script:</strong> ${task.script_path}</div>
                    <div><strong>Pi:</strong> ${piName}</div>
                    ${lastRun}
                    ${nextRun}
                </div>
                <div class="task-actions">
                    <button
                        class="btn btn-sm btn-danger"
                        onclick="deleteTask(${task.id})"
                    >
                        <i data-lucide="trash-2" size="14"></i>
                        <span>Supprimer</span>
                    </button>
                </div>
            </div>
        `;
    }

    /**
     * Show add task modal
     */
    showAddTaskModal() {
        // Populate Pi selector
        const piSelect = document.getElementById('task-pi');
        if (piSelect && window.allPis) {
            piSelect.innerHTML = '<option value="">Sélectionner un Pi...</option>' +
                window.allPis.map(pi => `<option value="${pi.id}">${pi.name}</option>`).join('');
        }

        // Populate script selector
        const scriptSelect = document.getElementById('task-script');
        if (scriptSelect && window.scriptsManager) {
            const scripts = window.scriptsManager.getScripts();
            scriptSelect.innerHTML = '<option value="">Sélectionner un script...</option>' +
                scripts.map(script =>
                    `<option value="${script.path}">${script.name} (${script.service})</option>`
                ).join('');
        }

        const modal = document.getElementById('add-task-modal');
        if (modal) {
            modal.classList.remove('hidden');
        }
    }

    /**
     * Hide add task modal
     */
    hideAddTaskModal() {
        const modal = document.getElementById('add-task-modal');
        if (modal) {
            modal.classList.add('hidden');
        }

        const form = document.getElementById('add-task-form');
        if (form) {
            form.reset();
        }
    }

    /**
     * Handle add task form submission
     * @param {Event} e - Form submit event
     */
    async handleAddTask(e) {
        e.preventDefault();

        const taskData = {
            name: document.getElementById('task-name')?.value,
            scriptPath: document.getElementById('task-script')?.value,
            piId: document.getElementById('task-pi')?.value,
            cron: document.getElementById('task-cron')?.value,
            enabled: document.getElementById('task-enabled')?.checked
        };

        try {
            const result = await api.post('/scheduler/tasks', taskData);

            if (result.success) {
                this.hideAddTaskModal();
                this.load(); // Reload tasks
            } else {
                alert(`Erreur: ${result.error || 'Unknown error'}`);
            }
        } catch (error) {
            console.error('Failed to add task:', error);
            alert(`Erreur: ${error.message}`);
        }
    }

    /**
     * Toggle task enabled status
     * @param {number} taskId - Task ID
     * @param {boolean} enabled - Enabled status
     */
    async toggleTask(taskId, enabled) {
        try {
            const result = await api.put(`/api/scheduler/tasks/${taskId}`, { enabled });

            if (result.success) {
                this.load(); // Reload tasks
            } else {
                alert(`Erreur: ${result.error || 'Unknown error'}`);
            }
        } catch (error) {
            console.error('Failed to toggle task:', error);
            alert(`Erreur: ${error.message}`);
        }
    }

    /**
     * Delete task
     * @param {number} taskId - Task ID
     */
    async deleteTask(taskId) {
        if (!confirm('Êtes-vous sûr de vouloir supprimer cette tâche ?')) {
            return;
        }

        try {
            const result = await api.delete(`/api/scheduler/tasks/${taskId}`);

            if (result.success) {
                this.load(); // Reload tasks
            } else {
                alert(`Erreur: ${result.error || 'Unknown error'}`);
            }
        } catch (error) {
            console.error('Failed to delete task:', error);
            alert(`Erreur: ${error.message}`);
        }
    }

    /**
     * Update dashboard summary with next upcoming task
     */
    updateSummary() {
        if (!window.uiStatus) return;

        if (!this.tasks || this.tasks.length === 0) {
            window.uiStatus.summary.setNextTask('Aucune tâche', 'Planifiez votre première action');
            return;
        }

        const upcoming = this.tasks
            .filter(task => task.enabled && task.next_run)
            .sort((a, b) => new Date(a.next_run) - new Date(b.next_run))[0];

        if (!upcoming) {
            window.uiStatus.summary.setNextTask('Aucune tâche active', 'Activez ou créez une tâche planifiée');
            return;
        }

        const date = new Date(upcoming.next_run);
        const localeDate = date.toLocaleString('fr-FR', {
            weekday: 'short',
            hour: '2-digit',
            minute: '2-digit'
        });

        window.uiStatus.summary.setNextTask(upcoming.name, `Prochaine exécution ${localeDate}`);
    }
}

// Create singleton instance
const schedulerManager = new SchedulerManager();

// Export
export default schedulerManager;

// Global access for backward compatibility
window.schedulerManager = schedulerManager;
window.toggleTask = (id, enabled) => schedulerManager.toggleTask(id, enabled);
window.deleteTask = (id) => schedulerManager.deleteTask(id);
window.hideAddTaskModal = () => schedulerManager.hideAddTaskModal();
