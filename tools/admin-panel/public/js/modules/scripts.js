// =============================================================================
// Scripts Manager Module
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

import api from '../utils/api.js';
import { debounce } from '../utils/debounce.js';
import ScriptStorage from '../utils/script-storage.js';

/**
 * ScriptsManager - Manages script discovery, display, and execution
 */
class ScriptsManager {
    constructor() {
        this.scripts = [];
        this.pendingExecution = null;
        this.executionStartTime = null;
    }

    /**
     * Initialize scripts module
     */
    init() {
        this.setupConfirmationModal();
        this.setupRefreshButton();
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
                await this.execute(this.pendingExecution.path, this.pendingExecution.name, this.pendingExecution.id);
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
     * Setup refresh button
     */
    setupRefreshButton() {
        const refreshBtn = document.getElementById('refresh-scripts');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => this.load());
        }
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

            // Render favorites and recent
            this.renderFavorites();
            this.renderRecent();

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

        // Render Quick Actions (if main view)
        if (containerId === 'all-scripts') {
            this.renderQuickActions(container, scripts);
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
        const categoriesHTML = sortedCategories.map(category => {
            const categoryScripts = byCategory[category];
            const categoryLabel = this.getCategoryLabel(category);

            return `
                <div class="script-category-section" data-category="${category}">
                    <div class="category-header">
                        <h3 class="category-title">${categoryLabel}</h3>
                        <span class="category-count">${categoryScripts.length}</span>
                        <button class="category-toggle">▼</button>
                    </div>
                    <div class="category-scripts active">
                        ${categoryScripts.map(script => this.renderScriptCard(script)).join('')}
                    </div>
                </div>
            `;
        }).join('');

        // Append (or replace) categories HTML
        if (containerId === 'all-scripts') {
            // Remove existing script sections first
            container.querySelectorAll('.script-category-section').forEach(section => section.remove());

            // Append after Quick Actions
            const existingQuickActions = container.querySelector('.quick-actions-zone');
            if (existingQuickActions) {
                existingQuickActions.insertAdjacentHTML('afterend', categoriesHTML);
            } else {
                container.innerHTML = categoriesHTML;
            }
        } else {
            container.innerHTML = categoriesHTML;
        }

        // Add click handlers for scripts (delegated to avoid conflicts with buttons)
        if (!container.dataset.clickBound) {
            container.addEventListener('click', (e) => {
                const card = e.target.closest('.script-card');
                if (!card) return;

                // Ignore clicks on buttons
                if (e.target.closest('button')) return;

                const scriptPath = card.dataset.scriptPath;
                const scriptId = card.dataset.scriptId;
                const scriptName = card.querySelector('.script-name').textContent;
                this.confirmExecution(scriptPath, scriptName, scriptId);
            });
            container.dataset.clickBound = 'true';
        }

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

        // Setup favorite buttons
        this.setupFavoriteButtons(container);
    }

    /**
     * Render a single script card - SIMPLE ROW
     */
    renderScriptCard(script) {
        const isFavorite = ScriptStorage.isFavorite(script.id);
        const recentExec = ScriptStorage.getRecent().find(r => r.scriptId === script.id);
        const description = this.getScriptDescription(script);

        return `
            <div class="script-card" data-script-id="${script.id}" data-script-path="${script.path}">
                <!-- Favorite Button -->
                <button class="script-favorite ${isFavorite ? 'active' : ''}"
                        data-script-id="${script.id}"
                        title="${isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris'}">
                    <i data-lucide="star" size="14"></i>
                </button>

                <!-- Icon + Name + Path + Description -->
                <div class="script-card-header">
                    <div class="script-icon">${script.icon}</div>
                    <div class="script-info">
                        <div class="script-name">${script.name}</div>
                        <div class="script-path">${script.path}</div>
                        ${description ? `<div class="script-description">${description}</div>` : ''}
                    </div>
                </div>

                <!-- Badge on right -->
                <span class="script-type ${script.type}">${script.typeLabel}</span>

                <!-- Favorite star (inline) -->
                <button class="script-favorite ${isFavorite ? 'active' : ''}"
                        data-script-id="${script.id}"
                        title="${isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris'}">
                    <i data-lucide="star" size="14"></i>
                </button>
            </div>
        `;
    }

    /**
     * Get script description based on path and name
     */
    getScriptDescription(script) {
        const path = script.path?.toLowerCase() || '';
        const name = script.name?.toLowerCase() || '';

        // Deploy scripts
        if (path.includes('supabase') && path.includes('deploy')) {
            return 'Déploie Supabase (PostgreSQL + Auth + Storage + Realtime)';
        }
        if (path.includes('traefik') && path.includes('deploy')) {
            return 'Déploie Traefik (Reverse Proxy + SSL automatique)';
        }
        if (path.includes('monitoring') && path.includes('deploy')) {
            return 'Déploie Prometheus + Grafana (monitoring complet)';
        }
        if (path.includes('vaultwarden') && path.includes('deploy')) {
            return 'Déploie Vaultwarden (gestionnaire de mots de passe)';
        }
        if (path.includes('homepage') && path.includes('deploy')) {
            return 'Déploie Homepage (dashboard de services)';
        }
        if (path.includes('portainer') && path.includes('deploy')) {
            return 'Déploie Portainer (gestion Docker via interface)';
        }

        // Maintenance scripts
        if (name.includes('backup')) {
            return 'Sauvegarde les données importantes';
        }
        if (name.includes('update')) {
            return 'Met à jour le système et les services';
        }
        if (name.includes('restart')) {
            return 'Redémarre les services Docker';
        }

        // Cleanup scripts
        if (name.includes('clean') || name.includes('purge')) {
            return 'Nettoie les fichiers temporaires et libère de l\'espace';
        }

        // Credentials scripts
        if (name.includes('credential') || name.includes('password')) {
            return 'Affiche ou regénère les identifiants';
        }

        // Reset scripts
        if (name.includes('reset')) {
            return 'Réinitialise la configuration par défaut';
        }

        // Health/Test scripts
        if (name.includes('health') || name.includes('check')) {
            return 'Vérifie l\'état de santé du système';
        }
        if (name.includes('diagnose')) {
            return 'Diagnostic complet du système';
        }

        // Security scripts
        if (path.includes('hardening')) {
            return 'Renforce la sécurité du système';
        }
        if (path.includes('authelia')) {
            return 'Configure l\'authentification 2FA';
        }

        // Storage scripts
        if (path.includes('nextcloud')) {
            return 'Déploie Nextcloud (cloud personnel)';
        }
        if (path.includes('syncthing')) {
            return 'Synchronisation de fichiers peer-to-peer';
        }

        // Media scripts
        if (path.includes('jellyfin')) {
            return 'Serveur multimédia (films, séries, musique)';
        }
        if (path.includes('navidrome')) {
            return 'Serveur de streaming audio personnel';
        }

        // Generic by type
        if (script.type === 'deploy') {
            return 'Script de déploiement';
        }
        if (script.type === 'maintenance') {
            return 'Script de maintenance';
        }
        if (script.type === 'test') {
            return 'Script de test';
        }
        if (script.type === 'utils') {
            return 'Script utilitaire';
        }

        return ''; // No description
    }

    /**
     * Create a script card (alias for renderScriptCard for backward compatibility)
     */
    createScriptCard(script) {
        return this.renderScriptCard(script);
    }

    /**
     * Attach card listeners to a container
     */
    attachCardListeners(container) {
        // Add click handlers for scripts
        container.querySelectorAll('.script-card').forEach(card => {
            card.addEventListener('click', (e) => {
                // Ignore clicks on buttons
                if (e.target.closest('button')) return;

                const scriptPath = card.dataset.scriptPath;
                const scriptId = card.dataset.scriptId;
                const scriptName = card.querySelector('.script-name').textContent;
                this.confirmExecution(scriptPath, scriptName, scriptId);
            });
        });

        // Setup favorite buttons
        this.setupFavoriteButtons(container);
    }

    /**
     * Setup favorite button handlers
     */
    setupFavoriteButtons(container) {
        container.querySelectorAll('.script-favorite').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                const scriptId = btn.dataset.scriptId;
                const isNowFavorite = ScriptStorage.toggleFavorite(scriptId);

                // Update button state
                btn.classList.toggle('active', isNowFavorite);
                btn.title = isNowFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris';

                // Re-render favorites section
                this.renderFavorites();

                // Toast notification
                if (window.toastManager) {
                    window.toastManager.show(
                        isNowFavorite ? 'Ajouté aux favoris ⭐' : 'Retiré des favoris',
                        isNowFavorite ? 'success' : 'info'
                    );
                }
            });
        });
    }


    /**
     * Get category label from category ID (SIMPLIFIED)
     */
    getCategoryLabel(category) {
        const labels = {
            'common-scripts': '📦 Communs',
            '01-infrastructure': '🏗️ Infrastructure',
            '02-securite': '🔒 Sécurité',
            '03-monitoring': '📊 Monitoring',
            '04-developpement': '💻 Développement',
            '05-stockage': '💾 Stockage',
            '06-media': '🎬 Média',
            '07-domotique': '🏠 Domotique',
            '08-interface': '🖥️ Interface',
            '10-productivity': '📋 Productivité',
            '11-intelligence-artificielle': '🤖 IA',
            // Fallback for dynamic categories
            'infrastructure': '🏗️ Infrastructure',
            'security': '🔒 Sécurité',
            'monitoring': '📊 Monitoring',
            'development': '💻 Développement',
            'maintenance': '🔧 Maintenance',
            'utils': '⚙️ Utilitaires',
            'cleanup': '🧹 Nettoyage',
            'credentials': '🔑 Identifiants',
            'reset': '🔄 Réinitialisation',
            // Per-app categories
            'supabase': '🐘 Supabase',
            'traefik': '🌐 Traefik',
            'monitoring': '📊 Monitoring',
            'docker': '🐳 Docker',
            'vaultwarden': '🔐 Vaultwarden',
            'n8n': '⚡ N8N',
            'homepage': '🏠 Homepage',
            'portainer': '🐳 Portainer'
        };
        return labels[category] || `📁 ${category}`;
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
            '11-intelligence-artificielle': '🤖',
            'cleanup': '🧹',
            'credentials': '🔑',
            'reset': '🔄',
            // Per-app icons
            'supabase': '🐘',
            'traefik': '🌐',
            'monitoring': '📊',
            'docker': '🐳',
            'vaultwarden': '🔐',
            'n8n': '⚡',
            'homepage': '🏠',
            'portainer': '🐳'
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
        const stackButtons = document.querySelectorAll('.stack-item');
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
            'common': 'common-scripts',
            'storage': '05-stockage',
            'media': '06-media',
            'home-automation': '07-domotique',
            'interface': '08-interface',
            'productivity': '10-productivity',
            'ai': '11-intelligence-artificielle',
            'backups': '09-backups',
            'favorites': 'favorites',
            'recent': 'recent',
            // Action type categories
            'type-deploy': 'deploy',
            'type-maintenance': 'maintenance',
            'type-cleanup': 'cleanup',
            'type-credentials': 'credentials',
            'type-reset': 'reset',
            'type-utils': 'utils',
            'type-test': 'test'
        };

        // Stack mapping (stack name -> folder name)
        const stackMapping = {
            'supabase': 'supabase',
            'traefik': 'traefik',
            'email': 'email',
            'appwrite': 'appwrite',
            'pocketbase': 'pocketbase',
            'vaultwarden': 'vaultwarden',
            'dashboard': 'dashboard',
            'webserver': 'webserver',
            'pihole': 'pihole',
            'vpn-wireguard': 'vpn-wireguard',
            'external-access': 'external-access',
            'apps': 'apps',
            'authelia': 'authelia',
            'passwords': 'passwords',
            'hardening': 'hardening',
            'prometheus-grafana': 'prometheus-grafana',
            'uptime-kuma': 'uptime-kuma',
            'gitea': 'gitea',
            'filebrowser-nextcloud': 'filebrowser-nextcloud',
            'syncthing': 'syncthing',
            'jellyfin-arr': 'jellyfin-arr',
            'navidrome': 'navidrome',
            'calibre-web': 'calibre-web',
            'qbittorrent': 'qbittorrent',
            'homeassistant': 'homeassistant',
            'homepage': 'homepage',
            'portainer': 'portainer',
            'paperless-ngx': 'paperless-ngx',
            'immich': 'immich',
            'joplin': 'joplin',
            'n8n': 'n8n',
            'ollama': 'ollama',
            'restic-offsite': 'restic-offsite'
        };

        // Update category counts
        this.updateCategoryCounts();

        // Setup accordion behavior for parent categories
        document.querySelectorAll('.category-parent').forEach(parent => {
            parent.addEventListener('click', (e) => {
                const category = parent.dataset.category;
                const stacksContainer = document.querySelector(`.category-stacks[data-parent="${category}"]`);

                if (!stacksContainer) return;

                // Toggle expanded state
                const isExpanded = parent.classList.contains('expanded');

                if (isExpanded) {
                    parent.classList.remove('expanded');
                    stacksContainer.classList.remove('expanded');
                } else {
                    parent.classList.add('expanded');
                    stacksContainer.classList.add('expanded');
                }
            });
        });

        // Add click handlers for category buttons (non-parent)
        categoryButtons.forEach(button => {
            if (button.classList.contains('category-parent')) return; // Skip parents

            button.addEventListener('click', () => {
                const selectedCategory = button.dataset.category;

                // Update active state
                categoryButtons.forEach(btn => btn.classList.remove('active'));
                stackButtons.forEach(btn => btn.classList.remove('active'));
                button.classList.add('active');

                // Update title
                const categoryName = button.querySelector('.category-name').textContent;
                categoryTitle.textContent = categoryName;

                // Filter scripts
                this.filterByCategory(selectedCategory, categoryMapping);
            });
        });

        // Add click handlers for stack buttons
        stackButtons.forEach(button => {
            button.addEventListener('click', () => {
                const selectedStack = button.dataset.stack;
                const category = button.dataset.category;

                // Update active state
                categoryButtons.forEach(btn => btn.classList.remove('active'));
                stackButtons.forEach(btn => btn.classList.remove('active'));
                button.classList.add('active');

                // Update title
                const stackName = button.textContent.trim();
                categoryTitle.textContent = stackName;

                // Filter scripts by stack
                this.filterByStack(selectedStack, stackMapping[selectedStack], categoryMapping[category]);
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

        // Handle special categories
        if (selectedCategory === 'favorites') {
            this.showFavoritesInMain();
            return;
        }

        if (selectedCategory === 'recent') {
            this.showRecentInMain();
            return;
        }

        if (selectedCategory === 'all') {
            // Show all sections and quick actions
            const quickActions = container.querySelector('.quick-actions-zone');
            if (quickActions) quickActions.style.display = 'grid';

            sections.forEach(section => {
                section.style.display = 'block';
                const cards = section.querySelectorAll('.script-card');
                cards.forEach(card => card.style.display = 'block');
            });
            return;
        }

        // Hide quick actions for filtered categories
        const quickActions = container.querySelector('.quick-actions-zone');
        if (quickActions) quickActions.style.display = 'none';

        sections.forEach(section => {
            const sectionCategory = section.dataset.category;
            const cards = section.querySelectorAll('.script-card');
            let hasVisibleCard = false;

            cards.forEach(card => {
                let shouldShow = false;
                const scriptPath = card.dataset.scriptPath || '';
                const scriptName = card.querySelector('.script-name')?.textContent.toLowerCase() || '';

                // Check category mapping
                const mappedCategory = categoryMapping[selectedCategory];

                if (mappedCategory && sectionCategory === mappedCategory) {
                    shouldShow = true;
                } else if (selectedCategory === 'maintenance' || selectedCategory === 'utils') {
                    // Match by script type
                    const typeSpan = card.querySelector('.script-type');
                    const scriptType = typeSpan?.className.match(/script-type\s+(\w+)/)?.[1];
                    shouldShow = scriptType === selectedCategory;
                } else if (selectedCategory.startsWith('type-')) {
                    // Handle action type categories (type-deploy, type-cleanup, etc.)
                    const actionType = mappedCategory; // 'deploy', 'cleanup', etc.
                    const typeSpan = card.querySelector('.script-type');
                    const scriptType = typeSpan?.className.match(/script-type\s+(\w+)/)?.[1];

                    // Match by type or path/name patterns
                    if (actionType === 'deploy') {
                        shouldShow = scriptType === 'deploy' || scriptPath.includes('deploy') || scriptName.includes('deploy');
                    } else if (actionType === 'maintenance') {
                        shouldShow = scriptType === 'maintenance' || scriptPath.includes('maintenance') || scriptName.includes('backup') || scriptName.includes('update');
                    } else if (actionType === 'cleanup') {
                        shouldShow = scriptPath.includes('cleanup') || scriptName.includes('clean') || scriptName.includes('nettoyage') || scriptName.includes('purge');
                    } else if (actionType === 'credentials') {
                        shouldShow = scriptPath.includes('credentials') || scriptName.includes('credential') || scriptName.includes('identifiant') || scriptName.includes('password');
                    } else if (actionType === 'reset') {
                        shouldShow = scriptPath.includes('reset') || scriptName.includes('reset') || scriptName.includes('réinitialise') || scriptName.includes('restore');
                    } else if (actionType === 'utils') {
                        shouldShow = scriptType === 'utils' || scriptPath.includes('utils') || scriptName.includes('util') || scriptName.includes('helper');
                    } else if (actionType === 'test') {
                        shouldShow = scriptType === 'test' || scriptPath.includes('test') || scriptName.includes('test') || scriptName.includes('health') || scriptName.includes('check');
                    }
                }

                card.style.display = shouldShow ? 'block' : 'none';
                if (shouldShow) hasVisibleCard = true;
            });

            section.style.display = hasVisibleCard ? 'block' : 'none';
        });
    }

    /**
     * Filter scripts by stack
     */
    filterByStack(stackId, stackFolder, categoryPath) {
        const container = document.getElementById('all-scripts');
        const sections = container.querySelectorAll('.script-category-section');
        const quickActions = container.querySelector('.quick-actions-zone');

        // Hide quick actions
        if (quickActions) quickActions.style.display = 'none';

        sections.forEach(section => {
            const sectionCategory = section.dataset.category;
            const cards = section.querySelectorAll('.script-card');
            let hasVisibleCard = false;

            cards.forEach(card => {
                let shouldShow = false;
                const scriptPath = card.dataset.scriptPath || '';

                // Check if script path contains the stack folder
                if (scriptPath.includes(`/${stackFolder}/`)) {
                    shouldShow = true;
                }

                card.style.display = shouldShow ? 'block' : 'none';
                if (shouldShow) hasVisibleCard = true;
            });

            section.style.display = hasVisibleCard ? 'block' : 'none';
        });
    }

    /**
     * Show favorites in main area
     */
    showFavoritesInMain() {
        const container = document.getElementById('all-scripts');
        const favorites = ScriptStorage.getFavorites();
        const favoriteScripts = this.scripts.filter(s => favorites.includes(s.id));

        // Hide all sections and quick actions
        container.querySelectorAll('.script-category-section').forEach(s => s.style.display = 'none');
        const quickActions = container.querySelector('.quick-actions-zone');
        if (quickActions) quickActions.style.display = 'none';

        // Create or update favorites section
        let favSection = container.querySelector('[data-category="favorites-view"]');
        if (!favSection) {
            favSection = document.createElement('div');
            favSection.className = 'script-category-section';
            favSection.dataset.category = 'favorites-view';
            container.insertBefore(favSection, container.firstChild);
        }

        if (favoriteScripts.length === 0) {
            favSection.innerHTML = `
                <div class="category-header">
                    <span class="category-icon">⭐</span>
                    <h3 class="category-title">Scripts Favoris</h3>
                    <span class="category-count">0</span>
                </div>
                <div class="scripts-empty">
                    <i data-lucide="star-off" size="48"></i>
                    <p>Aucun script favori pour le moment.<br>Cliquez sur ⭐ pour ajouter un script.</p>
                </div>
            `;
        } else {
            const cardsHtml = favoriteScripts.map(script => this.createScriptCard(script)).join('');
            favSection.innerHTML = `
                <div class="category-header">
                    <span class="category-icon">⭐</span>
                    <h3 class="category-title">Scripts Favoris</h3>
                    <span class="category-count">${favoriteScripts.length}</span>
                </div>
                <div class="category-scripts active">${cardsHtml}</div>
            `;
            this.attachCardListeners(favSection);
        }

        favSection.style.display = 'block';
        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Show recent scripts in main area
     */
    showRecentInMain() {
        const container = document.getElementById('all-scripts');
        const recent = ScriptStorage.getRecent();
        const recentScripts = recent.map(r => this.scripts.find(s => s.id === r.scriptId)).filter(Boolean);

        // Hide all sections and quick actions
        container.querySelectorAll('.script-category-section').forEach(s => s.style.display = 'none');
        const quickActions = container.querySelector('.quick-actions-zone');
        if (quickActions) quickActions.style.display = 'none';

        // Create or update recent section
        let recentSection = container.querySelector('[data-category="recent-view"]');
        if (!recentSection) {
            recentSection = document.createElement('div');
            recentSection.className = 'script-category-section';
            recentSection.dataset.category = 'recent-view';
            container.insertBefore(recentSection, container.firstChild);
        }

        if (recentScripts.length === 0) {
            recentSection.innerHTML = `
                <div class="category-header">
                    <span class="category-icon">🕐</span>
                    <h3 class="category-title">Récemment Exécutés</h3>
                    <span class="category-count">0</span>
                </div>
                <div class="scripts-empty">
                    <i data-lucide="clock" size="48"></i>
                    <p>Aucune exécution récente.</p>
                </div>
            `;
        } else {
            const cardsHtml = recentScripts.map(script => this.createScriptCard(script)).join('');
            recentSection.innerHTML = `
                <div class="category-header">
                    <span class="category-icon">🕐</span>
                    <h3 class="category-title">Récemment Exécutés</h3>
                    <span class="category-count">${recentScripts.length}</span>
                </div>
                <div class="category-scripts active">${cardsHtml}</div>
            `;
            this.attachCardListeners(recentSection);
        }

        recentSection.style.display = 'block';
        if (window.lucide) window.lucide.createIcons();
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
            common: 0,
            storage: 0,
            media: 0,
            'home-automation': 0,
            interface: 0,
            productivity: 0,
            ai: 0,
            backups: 0,
            favorites: ScriptStorage.getFavorites().length,
            recent: ScriptStorage.getRecent().length,
            // Action type counts
            'type-deploy': 0,
            'type-maintenance': 0,
            'type-cleanup': 0,
            'type-credentials': 0,
            'type-reset': 0,
            'type-utils': 0,
            'type-test': 0
        };

        this.scripts.forEach(script => {
            const category = script.category || '';
            const type = script.type || '';
            const path = script.path || '';
            const name = script.name?.toLowerCase() || '';

            // Category-based counts
            if (category.includes('01-infrastructure')) categoryCounts.infrastructure++;
            if (category.includes('02-securite')) categoryCounts.security++;
            if (category.includes('03-monitoring')) categoryCounts.monitoring++;
            if (category.includes('04-developpement')) categoryCounts.development++;
            if (category.includes('05-stockage')) categoryCounts.storage++;
            if (category.includes('06-media')) categoryCounts.media++;
            if (category.includes('07-domotique')) categoryCounts['home-automation']++;
            if (category.includes('08-interface')) categoryCounts.interface++;
            if (category.includes('09-backups')) categoryCounts.backups++;
            if (category.includes('10-productivity')) categoryCounts.productivity++;
            if (category.includes('11-intelligence-artificielle')) categoryCounts.ai++;
            if (category.includes('common-scripts')) categoryCounts.common++;
            if (type === 'maintenance') categoryCounts.maintenance++;
            if (type === 'utils') categoryCounts.utils++;

            // Action type counts (based on script path and name patterns)
            if (type === 'deploy' || path.includes('deploy') || name.includes('deploy')) {
                categoryCounts['type-deploy']++;
            }
            if (type === 'maintenance' || path.includes('maintenance') || name.includes('backup') || name.includes('update')) {
                categoryCounts['type-maintenance']++;
            }
            if (path.includes('cleanup') || name.includes('clean') || name.includes('nettoyage') || name.includes('purge')) {
                categoryCounts['type-cleanup']++;
            }
            if (path.includes('credentials') || name.includes('credential') || name.includes('identifiant') || name.includes('password')) {
                categoryCounts['type-credentials']++;
            }
            if (path.includes('reset') || name.includes('reset') || name.includes('reinitialise') || name.includes('restore')) {
                categoryCounts['type-reset']++;
            }
            if (type === 'utils' || path.includes('utils') || name.includes('util') || name.includes('helper')) {
                categoryCounts['type-utils']++;
            }
            if (type === 'test' || path.includes('test') || name.includes('test') || name.includes('health') || name.includes('check')) {
                categoryCounts['type-test']++;
            }
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
     * @param {string} scriptId - Script ID
     */
    confirmExecution(scriptPath, scriptName, scriptId) {
        this.pendingExecution = { path: scriptPath, name: scriptName, id: scriptId };

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
     * @param {string} scriptName - Script name
     * @param {string} scriptId - Script ID
     */
    async execute(scriptPath, scriptName, scriptId) {
        this.executionStartTime = Date.now();

        // Add to recent (status: pending)
        if (scriptId && scriptName) {
            ScriptStorage.addRecent({
                scriptId,
                scriptName,
                status: 'pending'
            });
            this.renderRecent();
        }

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

            // Update recent status (success)
            if (scriptId) {
                const duration = Date.now() - this.executionStartTime;
                ScriptStorage.updateRecentStatus(scriptId, 'success', duration);
                this.renderRecent();

                // Re-render script cards to show last run badge
                this.renderGroup('all-scripts', this.scripts);
                this.setupCategorySidebar();
            }

            window.historyManager?.load();

            return result;
        } catch (error) {
            const errorMsg = `❌ Error: ${error.message}`;
            if (window.terminalManager) {
                window.terminalManager.addLine(errorMsg, 'error');
            }

            // Update recent status (failed)
            if (scriptId) {
                const duration = Date.now() - this.executionStartTime;
                ScriptStorage.updateRecentStatus(scriptId, 'failed', duration);
                this.renderRecent();

                // Re-render script cards to show last run badge
                this.renderGroup('all-scripts', this.scripts);
                this.setupCategorySidebar();
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

    /**
     * Render favorites section
     */
    renderFavorites() {
        const section = document.getElementById('favorites-section');
        const container = document.getElementById('favorites-grid');
        const countEl = document.getElementById('favorites-count');

        if (!section || !container) return;

        const favoriteIds = ScriptStorage.getFavorites();
        const favoriteScripts = this.scripts.filter(s => favoriteIds.includes(s.id));

        section.classList.toggle('is-empty', favoriteScripts.length === 0);
        countEl.textContent = favoriteScripts.length;

        if (favoriteScripts.length === 0) {
            container.innerHTML = `
                <div class="favorites-empty">
                    <i data-lucide="star-off" size="18"></i>
                    <p>Aucun favori pour le moment</p>
                </div>
            `;
        } else {
            container.innerHTML = `
                <div class="favorites-list">
                    ${favoriteScripts.map(script => `
                        <div class="favorite-item" data-script-id="${script.id}" data-script-path="${script.path}">
                            <span class="favorite-icon">${script.icon}</span>
                            <div class="favorite-info">
                                <span class="favorite-name">${script.name}</span>
                                <span class="favorite-path">${script.path}</span>
                            </div>
                            <button class="script-favorite active"
                                    data-script-id="${script.id}"
                                    title="Retirer des favoris">
                                <i data-lucide="star" size="14"></i>
                            </button>
                        </div>
                    `).join('')}
                </div>
            `;
        }

        // Allow running scripts from sidebar favorites
        container.querySelectorAll('.favorite-item').forEach(item => {
            item.addEventListener('click', (event) => {
                if (event.target.closest('button')) return;
                const scriptPath = item.dataset.scriptPath;
                const scriptId = item.dataset.scriptId;
                const scriptName = item.querySelector('.favorite-name')?.textContent || scriptPath;
                this.confirmExecution(scriptPath, scriptName, scriptId);
            });
        });

        // Setup favorite toggle buttons inside sidebar
        this.setupFavoriteButtons(container);

        if (window.lucide) {
            window.lucide.createIcons();
        }
    }

    /**
     * Render recent executions section
     */
    renderRecent() {
        const section = document.getElementById('recent-scripts-section');
        const list = document.getElementById('recent-list');

        if (!section || !list) return;

        const recent = ScriptStorage.getRecent();

        if (recent.length === 0) {
            section.style.display = 'block';
            section.classList.add('is-empty');
            list.innerHTML = `
                <div class="recent-empty favorites-empty">
                    <i data-lucide="clock" size="18"></i>
                    <p>Aucune exécution récente</p>
                </div>
            `;
            if (window.lucide) {
                window.lucide.createIcons();
            }
            return;
        }

        section.classList.remove('is-empty');
        section.style.display = 'block';

        list.innerHTML = recent.map(item => {
            const script = this.scripts.find(s => s.id === item.scriptId);
            if (!script) return '';

            return `
                <div class="recent-item" data-script-id="${item.scriptId}">
                    <div class="recent-item-left">
                        <span class="recent-item-status ${item.status}"></span>
                        <div class="recent-info">
                            <span class="recent-item-name">${item.scriptName}</span>
                            <span class="recent-item-time">${ScriptStorage.formatRelativeTime(item.timestamp)}</span>
                        </div>
                    </div>
                    <button class="recent-item-rerun"
                            data-script-path="${script.path}"
                            data-script-name="${item.scriptName}"
                            data-script-id="${item.scriptId}">
                        <i data-lucide="play" size="10"></i>
                        Re-run
                    </button>
                </div>
            `;
        }).join('');

        // Setup re-run buttons
        list.querySelectorAll('.recent-item-rerun').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                const scriptPath = btn.dataset.scriptPath;
                const scriptName = btn.dataset.scriptName;
                const scriptId = btn.dataset.scriptId;
                this.confirmExecution(scriptPath, scriptName, scriptId);
            });
        });

        // Reinitialize lucide icons
        if (window.lucide) {
            window.lucide.createIcons();
        }
    }

    /**
     * Show script info modal
     * @param {string} scriptPath - Script path
     */
    showScriptInfo(scriptPath) {
        const script = this.scripts.find(s => s.path === scriptPath);
        if (!script) return;

        if (window.toastManager) {
            window.toastManager.show(
                `📄 ${script.name}\n📂 ${script.path}\n🏷️ ${script.typeLabel}`,
                'info'
            );
        }
    }

    /**
     * Render Quick Actions zone (NEW)
     * @param {HTMLElement} container - Container element
     * @param {Array} scripts - All scripts
     */
    renderQuickActions(container, scripts) {
        // Remove existing Quick Actions if any
        const existing = container.querySelector('.quick-actions-zone');
        if (existing) {
            existing.remove();
        }

        // Find most important scripts
        const deployScripts = scripts.filter(s => s.type === 'deploy');
        const maintenanceScripts = scripts.filter(s => s.type === 'maintenance' || s.name.includes('backup'));
        const testScripts = scripts.filter(s => s.type === 'test' || s.name.includes('health'));

        // Select top 4 scripts
        const quickActions = [
            deployScripts.find(s => s.name.includes('supabase') || s.name.includes('infrastructure')) || deployScripts[0],
            maintenanceScripts.find(s => s.name.includes('backup') || s.name.includes('all')) || maintenanceScripts[0],
            testScripts.find(s => s.name.includes('health') || s.name.includes('diagnose')) || testScripts[0],
            scripts.find(s => s.name.includes('security') || s.name.includes('hardening'))
        ].filter(Boolean).slice(0, 4);

        // If less than 4, fill with recent
        while (quickActions.length < 4 && scripts.length > quickActions.length) {
            const recent = ScriptStorage.getRecent();
            const recentScript = recent.map(r => scripts.find(s => s.id === r.scriptId)).filter(Boolean)[quickActions.length];
            if (recentScript && !quickActions.includes(recentScript)) {
                quickActions.push(recentScript);
            } else {
                break;
            }
        }

        if (quickActions.length === 0) return;

        const quickActionsHTML = `
            <div class="quick-actions-zone">
                ${quickActions.map(script => `
                    <div class="quick-action-card" data-script-path="${script.path}" data-script-id="${script.id}">
                        <div class="quick-action-icon">${script.icon}</div>
                        <div class="quick-action-name">${script.name}</div>
                        <div class="quick-action-desc">${script.typeLabel} • ${script.category || 'Script'}</div>
                    </div>
                `).join('')}
            </div>
        `;

        container.insertAdjacentHTML('afterbegin', quickActionsHTML);

        // Add click handlers
        container.querySelectorAll('.quick-action-card').forEach(card => {
            card.addEventListener('click', () => {
                const scriptPath = card.dataset.scriptPath;
                const scriptId = card.dataset.scriptId;
                const scriptName = card.querySelector('.quick-action-name').textContent;
                this.confirmExecution(scriptPath, scriptName, scriptId);
            });
        });
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
