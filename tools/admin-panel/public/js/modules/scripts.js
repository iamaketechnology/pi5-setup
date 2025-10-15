// =============================================================================
// Scripts Manager Module
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

import api from '../utils/api.js';
import { debounce } from '../utils/debounce.js';

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

            // Render all scripts in single view
            this.renderGroup('all-scripts', this.scripts);

            // Setup search and filters
            this.setupSearch('search-scripts', 'all-scripts');
            this.setupTypeFilter();

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

        // Group scripts by category
        const byCategory = scripts.reduce((acc, script) => {
            const cat = script.category || 'other';
            if (!acc[cat]) acc[cat] = [];
            acc[cat].push(script);
            return acc;
        }, {});

        // Sort categories
        const sortedCategories = Object.keys(byCategory).sort();

        // Generate HTML with collapsible categories
        container.innerHTML = sortedCategories.map(category => {
            const categoryScripts = byCategory[category];
            const categoryLabel = this.getCategoryLabel(category);
            const categoryIcon = this.getCategoryIcon(category);

            return `
                <div class="script-category-section" data-category="${category}">
                    <div class="category-header">
                        <span class="category-icon">${categoryIcon}</span>
                        <h3 class="category-title">${categoryLabel}</h3>
                        <span class="category-count">${categoryScripts.length}</span>
                        <button class="category-toggle">▼</button>
                    </div>
                    <div class="category-scripts active">
                        ${categoryScripts.map(script => `
                            <div class="script-card" data-script-id="${script.id}" data-script-path="${script.path}">
                                <div class="script-header">
                                    <div class="script-icon">${script.icon}</div>
                                    <div class="script-info">
                                        <div class="script-name">${script.name}</div>
                                        <div class="script-service">${script.service}</div>
                                    </div>
                                </div>
                                <span class="script-type ${script.type}">${script.typeLabel}</span>
                            </div>
                        `).join('')}
                    </div>
                </div>
            `;
        }).join('');

        // Add click handlers for scripts
        container.querySelectorAll('.script-card').forEach(card => {
            card.addEventListener('click', () => {
                const scriptPath = card.dataset.scriptPath;
                const scriptName = card.querySelector('.script-name').textContent;
                this.confirmExecution(scriptPath, scriptName);
            });
        });

        // Add toggle handlers for categories
        container.querySelectorAll('.category-header').forEach(header => {
            header.addEventListener('click', () => {
                const section = header.parentElement;
                const scriptsDiv = section.querySelector('.category-scripts');
                const toggleBtn = header.querySelector('.category-toggle');

                scriptsDiv.classList.toggle('active');
                toggleBtn.textContent = scriptsDiv.classList.contains('active') ? '▼' : '▶';
            });
        });
    }

    /**
     * Get category label from category ID
     */
    getCategoryLabel(category) {
        const labels = {
            'common-scripts': '📦 Scripts Communs',
            '01-infrastructure': '🏗️ Infrastructure',
            '02-securite': '🔒 Sécurité',
            '03-monitoring': '📊 Monitoring',
            '04-developpement': '💻 Développement',
            '05-stockage': '💾 Stockage',
            '06-media': '🎬 Média',
            '07-domotique': '🏠 Domotique',
            '08-interface': '🖥️ Interface',
            '10-productivity': '📋 Productivité',
            '11-intelligence-artificielle': '🤖 IA'
        };
        return labels[category] || category;
    }

    /**
     * Get category icon
     */
    getCategoryIcon(category) {
        const icons = {
            'common-scripts': '📦',
            '01-infrastructure': '🏗️',
            '02-securite': '🔒',
            '03-monitoring': '📊',
            '04-developpement': '💻',
            '05-stockage': '💾',
            '06-media': '🎬',
            '07-domotique': '🏠',
            '08-interface': '🖥️',
            '10-productivity': '📋',
            '11-intelligence-artificielle': '🤖'
        };
        return icons[category] || '📁';
    }

    /**
     * Setup search filter for a container
     * @param {string} inputId - Search input ID
     * @param {string} containerId - Container ID
     */
    setupSearch(inputId, containerId) {
        const input = document.getElementById(inputId);
        if (!input) return;

        // Debounced search function
        const performSearch = debounce((query) => {
            const container = document.getElementById(containerId);
            const sections = container.querySelectorAll('.script-category-section');

            sections.forEach(section => {
                const cards = section.querySelectorAll('.script-card');
                let hasVisibleCard = false;

                cards.forEach(card => {
                    const name = card.querySelector('.script-name').textContent.toLowerCase();
                    const service = card.querySelector('.script-service')?.textContent.toLowerCase() || '';

                    if (name.includes(query) || service.includes(query)) {
                        card.style.display = 'block';
                        hasVisibleCard = true;
                    } else {
                        card.style.display = 'none';
                    }
                });

                // Show/hide entire category section
                if (query === '') {
                    section.style.display = 'block';
                } else {
                    section.style.display = hasVisibleCard ? 'block' : 'none';
                }

                // Auto-expand categories when searching
                const scriptsDiv = section.querySelector('.category-scripts');
                const toggleBtn = section.querySelector('.category-toggle');
                if (query !== '' && hasVisibleCard) {
                    scriptsDiv.classList.add('active');
                    toggleBtn.textContent = '▼';
                }
            });
        }, 300); // 300ms debounce

        input.addEventListener('input', (e) => {
            const query = e.target.value.toLowerCase();
            performSearch(query);
        });
    }

    /**
     * Setup type filter
     */
    setupTypeFilter() {
        const filter = document.getElementById('filter-script-type');
        if (!filter) return;

        filter.addEventListener('change', (e) => {
            const selectedType = e.target.value;
            const container = document.getElementById('all-scripts');
            const sections = container.querySelectorAll('.script-category-section');

            sections.forEach(section => {
                const cards = section.querySelectorAll('.script-card');
                let hasVisibleCard = false;

                cards.forEach(card => {
                    const typeSpan = card.querySelector('.script-type');
                    const cardType = typeSpan?.className.match(/script-type\s+(\w+)/)?.[1];

                    if (!selectedType || cardType === selectedType) {
                        card.style.display = 'block';
                        hasVisibleCard = true;
                    } else {
                        card.style.display = 'none';
                    }
                });

                // Show/hide category section
                section.style.display = hasVisibleCard ? 'block' : 'none';
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
