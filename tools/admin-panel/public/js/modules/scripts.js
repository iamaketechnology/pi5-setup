// =============================================================================
// Scripts Manager Module
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

import api from '../utils/api.js';

/**
 * ScriptsManager - Manages script discovery, display, and execution
 */
class ScriptsManager {
    constructor() {
        this.scripts = [];
        this.pendingExecution = null;
    }

    /**
     * Initialize scripts module
     */
    init() {
        this.load();
        console.log('✅ Scripts module initialized');
    }

    /**
     * Load all scripts from API
     */
    async load() {
        try {
            const data = await api.get('/scripts');
            this.scripts = data.scripts || [];

            // Group scripts by type
            const groups = {
                deploy: this.scripts.filter(s => s.type === 'deploy'),
                maintenance: this.scripts.filter(s => s.type === 'maintenance'),
                test: this.scripts.filter(s => s.type === 'test'),
                config: this.scripts.filter(s => s.type === 'utils' || s.type === 'common')
            };

            // Render each category
            this.renderGroup('deploy-scripts', groups.deploy);
            this.renderGroup('maintenance-scripts', groups.maintenance);
            this.renderGroup('test-scripts', groups.test);
            this.renderGroup('config-scripts', groups.config);

            // Setup search filters
            this.setupSearch('search-deploy', 'deploy-scripts');
            this.setupSearch('search-maintenance', 'maintenance-scripts');
            this.setupSearch('search-tests', 'test-scripts');
            this.setupSearch('search-config', 'config-scripts');

            return this.scripts;
        } catch (error) {
            console.error('Failed to load scripts:', error);
            throw error;
        }
    }

    /**
     * Render scripts group
     * @param {string} containerId - Container element ID
     * @param {Array} scripts - Scripts array
     */
    renderGroup(containerId, scripts) {
        const container = document.getElementById(containerId);
        if (!container) return;

        if (scripts.length === 0) {
            container.innerHTML = '<div class="loading">Aucun script disponible</div>';
            return;
        }

        container.innerHTML = scripts.map(script => `
            <div class="script-card" data-script-id="${script.id}" data-script-path="${script.path}">
                <div class="script-header">
                    <div class="script-icon">${script.icon}</div>
                    <div class="script-info">
                        <div class="script-name">${script.name}</div>
                        <div class="script-category">${script.service} / ${script.category}</div>
                    </div>
                </div>
                <span class="script-type ${script.type}">${script.typeLabel}</span>
            </div>
        `).join('');

        // Add click handlers
        container.querySelectorAll('.script-card').forEach(card => {
            card.addEventListener('click', () => {
                const scriptPath = card.dataset.scriptPath;
                const scriptName = card.querySelector('.script-name').textContent;
                this.confirmExecution(scriptPath, scriptName);
            });
        });
    }

    /**
     * Setup search filter for a container
     * @param {string} inputId - Search input ID
     * @param {string} containerId - Container ID
     */
    setupSearch(inputId, containerId) {
        const input = document.getElementById(inputId);
        if (!input) return;

        input.addEventListener('input', (e) => {
            const query = e.target.value.toLowerCase();
            const container = document.getElementById(containerId);
            const cards = container.querySelectorAll('.script-card');

            cards.forEach(card => {
                const name = card.querySelector('.script-name').textContent.toLowerCase();
                const category = card.querySelector('.script-category').textContent.toLowerCase();

                if (name.includes(query) || category.includes(query)) {
                    card.style.display = 'block';
                } else {
                    card.style.display = 'none';
                }
            });
        });
    }

    /**
     * Show confirmation modal for script execution
     * @param {string} scriptPath - Script path
     * @param {string} scriptName - Script name
     */
    confirmExecution(scriptPath, scriptName) {
        this.pendingExecution = { path: scriptPath, name: scriptName };

        const modal = document.getElementById('confirm-modal');
        const message = document.getElementById('confirm-message');

        if (!modal || !message) return;

        message.textContent = `Voulez-vous vraiment exécuter "${scriptName}" ?`;
        modal.classList.remove('hidden');

        // Switch to dashboard to show terminal (if tabs manager available)
        if (window.tabsManager) {
            window.tabsManager.switchTab('dashboard');
        }
    }

    /**
     * Execute a script
     * @param {string} scriptPath - Script path
     */
    async execute(scriptPath) {
        try {
            // Notify via terminal if available
            if (window.terminalManager) {
                window.terminalManager.addLine(`\n🚀 Executing: ${scriptPath}`, 'info');
            }

            const body = { scriptPath };
            if (window.currentPiId) {
                body.piId = window.currentPiId;
            }

            const result = await api.post('/execute', body);

            if (!result.success) {
                const errorMsg = `❌ Failed to start execution: ${result.error}`;
                if (window.terminalManager) {
                    window.terminalManager.addLine(errorMsg, 'error');
                }
                throw new Error(result.error);
            }

            return result;
        } catch (error) {
            const errorMsg = `❌ Error: ${error.message}`;
            if (window.terminalManager) {
                window.terminalManager.addLine(errorMsg, 'error');
            }
            console.error(errorMsg);
            throw error;
        }
    }

    /**
     * Get all scripts
     * @returns {Array} Scripts array
     */
    getScripts() {
        return this.scripts;
    }

    /**
     * Get script by path
     * @param {string} path - Script path
     * @returns {Object|null} Script object or null
     */
    getScript(path) {
        return this.scripts.find(s => s.path === path) || null;
    }

    /**
     * Get pending execution
     * @returns {Object|null} Pending execution or null
     */
    getPendingExecution() {
        return this.pendingExecution;
    }
}

// Create singleton instance
const scriptsManager = new ScriptsManager();

// Export
export default scriptsManager;

// Global access for backward compatibility
window.scriptsManager = scriptsManager;
window.confirmExecution = (path, name) => scriptsManager.confirmExecution(path, name);
window.executeScript = (path) => scriptsManager.execute(path);
