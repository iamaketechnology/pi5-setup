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
        this.setupConfirmationModal();
        this.load();
        console.log('✅ Scripts module initialized');
    }

    /**
     * Setup confirmation modal event listeners
     */
    setupConfirmationModal() {
        const yesBtn = document.getElementById('confirm-yes');
        const noBtn = document.getElementById('confirm-no');
        const modal = document.getElementById('confirm-modal');

        if (!yesBtn || !noBtn || !modal) return;

        // Handle confirmation
        yesBtn.addEventListener('click', async () => {
            if (this.pendingExecution) {
                modal.classList.add('hidden');
                await this.execute(this.pendingExecution.path);
                this.pendingExecution = null;
            }
        });

        // Handle cancellation
        noBtn.addEventListener('click', () => {
            modal.classList.add('hidden');
            this.pendingExecution = null;
        });

        // Close on backdrop click
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.classList.add('hidden');
                this.pendingExecution = null;
            }
        });
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
            this.setupCategorySidebar();

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
     * Setup category sidebar navigation
     */
    setupCategorySidebar() {
        const categoryButtons = document.querySelectorAll('.category-item');
        const categoryTitle = document.getElementById('scripts-category-title');

        // Map script categories to sidebar categories
        const categoryMapping = {
            'all': null, // Show all
            'infrastructure': '01-infrastructure',
            'security': '02-securite',
            'monitoring': '03-monitoring',
            'development': '04-developpement',
            'maintenance': null, // Will match based on type
            'utils': null,
            'common': 'common-scripts'
        };

        // Update category counts
        this.updateCategoryCounts();

        // Add click handlers
        categoryButtons.forEach(button => {
            button.addEventListener('click', () => {
                const selectedCategory = button.dataset.category;

                // Update active state
                categoryButtons.forEach(btn => btn.classList.remove('active'));
                button.classList.add('active');

                // Update title
                const categoryName = button.querySelector('.category-name').textContent;
                categoryTitle.textContent = categoryName;

                // Filter scripts
                this.filterByCategory(selectedCategory, categoryMapping);
            });
        });

        console.log('✅ Category sidebar initialized');
    }

    /**
     * Filter scripts by category
     */
    filterByCategory(selectedCategory, categoryMapping) {
        const container = document.getElementById('all-scripts');
        const sections = container.querySelectorAll('.script-category-section');

        if (selectedCategory === 'all') {
            // Show all sections
            sections.forEach(section => {
                section.style.display = 'block';
                const cards = section.querySelectorAll('.script-card');
                cards.forEach(card => card.style.display = 'block');
            });
            return;
        }

        sections.forEach(section => {
            const sectionCategory = section.dataset.category;
            const cards = section.querySelectorAll('.script-card');
            let hasVisibleCard = false;

            cards.forEach(card => {
                let shouldShow = false;

                // Check category mapping
                if (selectedCategory === 'infrastructure' && sectionCategory === '01-infrastructure') {
                    shouldShow = true;
                } else if (selectedCategory === 'security' && sectionCategory === '02-securite') {
                    shouldShow = true;
                } else if (selectedCategory === 'monitoring' && sectionCategory === '03-monitoring') {
                    shouldShow = true;
                } else if (selectedCategory === 'development' && sectionCategory === '04-developpement') {
                    shouldShow = true;
                } else if (selectedCategory === 'common' && sectionCategory === 'common-scripts') {
                    shouldShow = true;
                } else if (selectedCategory === 'maintenance' || selectedCategory === 'utils') {
                    // Match by script type
                    const typeSpan = card.querySelector('.script-type');
                    const scriptType = typeSpan?.className.match(/script-type\s+(\w+)/)?.[1];
                    shouldShow = scriptType === selectedCategory;
                }

                card.style.display = shouldShow ? 'block' : 'none';
                if (shouldShow) hasVisibleCard = true;
            });

            section.style.display = hasVisibleCard ? 'block' : 'none';
        });
    }

    /**
     * Update category counts
     */
    updateCategoryCounts() {
        const categoryCounts = {
            all: this.scripts.length,
            infrastructure: 0,
            security: 0,
            monitoring: 0,
            development: 0,
            maintenance: 0,
            utils: 0,
            common: 0
        };

        this.scripts.forEach(script => {
            const category = script.category || '';
            const type = script.type || '';

            if (category.includes('01-infrastructure')) categoryCounts.infrastructure++;
            if (category.includes('02-securite')) categoryCounts.security++;
            if (category.includes('03-monitoring')) categoryCounts.monitoring++;
            if (category.includes('04-developpement')) categoryCounts.development++;
            if (category.includes('common-scripts')) categoryCounts.common++;
            if (type === 'maintenance') categoryCounts.maintenance++;
            if (type === 'utils') categoryCounts.utils++;
        });

        // Update UI
        Object.keys(categoryCounts).forEach(key => {
            const countEl = document.getElementById(`count-${key}`);
            if (countEl) {
                countEl.textContent = categoryCounts[key];
            }
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

            const runPromise = (async () => {
                const response = await api.post('/execute', body);
                if (!response.success) {
                    throw new Error(response.error || 'Execution failed');
                }
                return response;
            })();

            const messages = {
                loading: `Exécution de ${scriptPath}...`,
                success: 'Script déclenché, surveillez le terminal',
                error: `Échec du lancement de ${scriptPath}`
            };

            const result = window.toastManager
                ? await window.toastManager.promise(runPromise, messages)
                : await runPromise;

            if (window.terminalManager) {
                window.terminalManager.addLine(`✅ Script ${scriptPath} lancé`, 'success');
            }

            window.historyManager?.load();

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
