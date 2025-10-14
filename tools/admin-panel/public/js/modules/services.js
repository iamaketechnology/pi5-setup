// =============================================================================
// Services Manager Module
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

import api from '../utils/api.js';

/**
 * ServicesManager - Manages service discovery and details
 */
class ServicesManager {
    constructor() {
        this.services = [];
        this.currentService = null;
    }

    /**
     * Initialize services module
     */
    init() {
        this.setupEventListeners();
        console.log('✅ Services module initialized');
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Refresh button
        const refreshBtn = document.getElementById('refresh-services');
        if (refreshBtn) {
            refreshBtn.addEventListener('click', () => this.load(true));
        }

        // Service selector
        const selector = document.getElementById('service-selector');
        if (selector) {
            selector.addEventListener('change', (e) => {
                const serviceName = e.target.value;
                if (serviceName) {
                    const service = this.services.find(s => s.app === serviceName);
                    if (service) {
                        this.showDetails(service);
                    }
                } else {
                    this.hideDetails();
                }
            });
        }

        // Category filter
        const categoryFilter = document.getElementById('category-filter');
        if (categoryFilter) {
            categoryFilter.addEventListener('change', () => this.filterByCategory());
        }

        // Service tabs navigation
        document.querySelectorAll('.service-tab').forEach(tab => {
            tab.addEventListener('click', () => {
                const targetTab = tab.dataset.serviceTab;
                this.switchServiceTab(targetTab);
            });
        });
    }

    /**
     * Load services from API
     * @param {boolean} forceRefresh - Force refresh
     */
    async load(forceRefresh = false) {
        try {
            const piId = window.currentPiId;
            const params = piId ? `?piId=${piId}` : '';

            const data = await api.get(`/api/services/discover${params}`);
            this.services = data.services || [];

            this.populateSelector();

            // Notify via terminal
            if (window.terminalManager) {
                if (this.services.length === 0) {
                    window.terminalManager.addLine('ℹ️ Aucun service Docker détecté', 'info');
                } else {
                    window.terminalManager.addLine(
                        `✅ ${this.services.length} service(s) détecté(s)`,
                        'success'
                    );
                }
            }

            return this.services;
        } catch (error) {
            console.error('Failed to load services:', error);
            if (window.terminalManager) {
                window.terminalManager.addLine(
                    `❌ Erreur découverte services: ${error.message}`,
                    'error'
                );
            }
            throw error;
        }
    }

    /**
     * Populate service selector
     */
    populateSelector() {
        const selector = document.getElementById('service-selector');
        if (!selector) return;

        // Reset selector
        selector.innerHTML = '<option value="">Sélectionner un service...</option>';

        // Group by category
        const byCategory = {};
        this.services.forEach(service => {
            const cat = service.category || 'Other';
            if (!byCategory[cat]) byCategory[cat] = [];
            byCategory[cat].push(service);
        });

        // Add options by category
        Object.keys(byCategory).sort().forEach(category => {
            const optgroup = document.createElement('optgroup');
            optgroup.label = category;

            byCategory[category].forEach(service => {
                const option = document.createElement('option');
                option.value = service.app;
                option.textContent = `${service.icon} ${service.app}`;
                optgroup.appendChild(option);
            });

            selector.appendChild(optgroup);
        });
    }

    /**
     * Filter services by category
     */
    filterByCategory() {
        const categoryFilter = document.getElementById('category-filter')?.value;
        const selector = document.getElementById('service-selector');
        if (!selector) return;

        // Reset and populate with filtered services
        selector.innerHTML = '<option value="">Sélectionner un service...</option>';

        const filtered = categoryFilter
            ? this.services.filter(s => s.category === categoryFilter)
            : this.services;

        filtered.forEach(service => {
            const option = document.createElement('option');
            option.value = service.app;
            option.textContent = `${service.icon} ${service.app}`;
            selector.appendChild(option);
        });
    }

    /**
     * Show service details
     * @param {Object} service - Service data
     */
    showDetails(service) {
        this.currentService = service;

        // Hide empty state, show detail view
        const emptyState = document.getElementById('service-empty-state');
        const detailView = document.getElementById('service-detail-view');

        if (emptyState) emptyState.style.display = 'none';
        if (detailView) detailView.style.display = 'flex';

        // Populate header
        this.setElementText('detail-icon', service.icon);
        this.setElementText('detail-name', service.app);
        this.setElementText('detail-description', service.description);

        const categoryEl = document.getElementById('detail-category');
        if (categoryEl) {
            categoryEl.textContent = service.category || 'Other';
            categoryEl.className = `badge ${(service.category || 'other').toLowerCase()}`;
        }

        // Populate containers
        this.renderContainers(service.containers);

        // Populate URLs
        this.renderURLs(service.urls);

        // Populate ports
        this.renderPorts(service.ports);

        // Reset credentials section
        const credsContainer = document.getElementById('detail-credentials');
        if (credsContainer) {
            credsContainer.innerHTML = '<button id="load-creds-btn" class="btn btn-sm" onclick="loadCurrentServiceCredentials()">🔓 Charger les credentials</button>';
        }

        // Populate commands
        this.renderCommands(service);
    }

    /**
     * Hide service details
     */
    hideDetails() {
        this.currentService = null;

        const emptyState = document.getElementById('service-empty-state');
        const detailView = document.getElementById('service-detail-view');

        if (emptyState) emptyState.style.display = 'flex';
        if (detailView) detailView.style.display = 'none';
    }

    /**
     * Render containers
     * @param {Array} containers - Containers array
     */
    renderContainers(containers) {
        const container = document.getElementById('detail-containers');
        if (!container) return;

        if (!containers || containers.length === 0) {
            container.innerHTML = '<span class="no-data">Aucun container</span>';
            return;
        }

        container.innerHTML = containers.map(c => `
            <div class="container-info">
                <span class="container-name">${c.name}</span>
                <span class="container-state ${c.state}">
                    ${c.state === 'running' ? '🟢' : '🔴'} ${c.state}
                </span>
            </div>
        `).join('');
    }

    /**
     * Render URLs
     * @param {Array} urls - URLs array
     */
    renderURLs(urls) {
        const container = document.getElementById('detail-urls');
        if (!container) return;

        if (!urls || urls.length === 0) {
            container.innerHTML = '<span class="no-data">Aucune URL Traefik détectée</span>';
            return;
        }

        container.innerHTML = urls.map(url =>
            `<a href="${url}" target="_blank" class="service-url">${url}</a>`
        ).join('');
    }

    /**
     * Render ports
     * @param {Array} ports - Ports array
     */
    renderPorts(ports) {
        const container = document.getElementById('detail-ports');
        if (!container) return;

        if (!ports || ports.length === 0) {
            container.innerHTML = '<span class="no-data">Aucun port exposé</span>';
            return;
        }

        container.innerHTML = `
            <table class="ports-table">
                <thead>
                    <tr>
                        <th>Externe</th>
                        <th>Interne</th>
                        <th>Protocol</th>
                    </tr>
                </thead>
                <tbody>
                    ${ports.map(p => `
                        <tr>
                            <td>${p.external || '-'}</td>
                            <td>${p.internal}</td>
                            <td>${p.protocol.toUpperCase()}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
    }

    /**
     * Render commands
     * @param {Object} service - Service data
     */
    renderCommands(service) {
        const container = document.getElementById('detail-commands');
        if (!container || !service.containers || service.containers.length === 0) {
            if (container) {
                container.innerHTML = '<span class="no-data">Aucune commande disponible</span>';
            }
            return;
        }

        const containerName = service.containers[0].name;

        const commands = [
            { label: 'View Logs (last 100)', command: `docker logs ${containerName} --tail 100`, icon: '📜' },
            { label: 'View Logs (follow)', command: `docker logs ${containerName} -f`, icon: '📜' },
            { label: 'Restart Container', command: `docker restart ${containerName}`, icon: '🔄' },
            { label: 'Container Stats', command: `docker stats ${containerName} --no-stream`, icon: '📊' }
        ];

        // Service-specific commands
        if (containerName.includes('postgres') || containerName.includes('db')) {
            commands.push({
                label: 'Connect to PostgreSQL',
                command: `docker exec -it ${containerName} psql -U postgres`,
                icon: '🐘'
            });
        }

        container.innerHTML = commands.map(cmd => `
            <div class="command-item">
                <div class="command-info">
                    <span class="command-icon">${cmd.icon}</span>
                    <span class="command-label">${cmd.label}</span>
                </div>
                <div class="command-actions">
                    <button
                        class="btn btn-sm"
                        onclick="copyToClipboard(\`${cmd.command.replace(/`/g, '\\`')}\`)"
                    >
                        📋 Copy
                    </button>
                    <button
                        class="btn btn-sm btn-primary"
                        onclick="executeServiceCommand(\`${cmd.command.replace(/`/g, '\\`')}\`, '${cmd.label}')"
                    >
                        ▶️ Run
                    </button>
                </div>
            </div>
        `).join('');
    }

    /**
     * Switch service tab
     * @param {string} tabName - Tab name
     */
    switchServiceTab(tabName) {
        // Update tab buttons
        document.querySelectorAll('.service-tab').forEach(t => t.classList.remove('active'));
        const activeTab = document.querySelector(`[data-service-tab="${tabName}"]`);
        if (activeTab) activeTab.classList.add('active');

        // Update tab content
        document.querySelectorAll('.service-tab-content').forEach(c => c.classList.remove('active'));
        const activeContent = document.getElementById(`service-${tabName}`);
        if (activeContent) activeContent.classList.add('active');

        // Load data for specific tabs
        if (this.currentService) {
            if (tabName === 'maintenance') {
                this.loadServiceMaintenance(this.currentService);
            } else if (tabName === 'backup') {
                this.loadServiceBackup(this.currentService);
            }
        }
    }

    /**
     * Helper: Set element text content
     * @param {string} id - Element ID
     * @param {string} text - Text content
     */
    setElementText(id, text) {
        const el = document.getElementById(id);
        if (el) el.textContent = text;
    }

    /**
     * Get all services
     * @returns {Array} Services array
     */
    getServices() {
        return this.services;
    }

    /**
     * Get current service
     * @returns {Object|null} Current service or null
     */
    getCurrentService() {
        return this.currentService;
    }
}

// Create singleton instance
const servicesManager = new ServicesManager();

// Export
export default servicesManager;

// Global access for backward compatibility
window.servicesManager = servicesManager;
