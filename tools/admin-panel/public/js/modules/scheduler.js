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
    }

    /**
     * Initialize scheduler module
     */
    init() {
        this.setupEventListeners();
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

    /**
     * Load scheduled tasks
     */
    async load() {
        try {
            const data = await api.get('/scheduler/tasks');
            this.tasks = data.tasks || [];
            this.render();
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

        if (!this.tasks || this.tasks.length === 0) {
            container.innerHTML = '<div class="loading">Aucune tâche planifiée</div>';
            return;
        }

        container.innerHTML = this.tasks.map(task => this.renderTask(task)).join('');
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
                        🗑️ Supprimer
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
