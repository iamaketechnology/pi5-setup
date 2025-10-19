// =============================================================================
// Services Manager Module
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

import api from '../utils/api.js';
import toast from '../utils/toast.js';

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

        // Search bar (filter services)
        const searchInput = document.getElementById('services-search');
        if (searchInput) {
            searchInput.addEventListener('input', (e) => this.filterServices(e.target.value));
        }

        // Sidebar category navigation - "Tous les services" button
        document.querySelectorAll('.info-category-item:not(.category-parent)').forEach(button => {
            button.addEventListener('click', (e) => {
                // Update active states
                document.querySelectorAll('.info-category-item').forEach(btn =>
                    btn.classList.remove('active')
                );
                document.querySelectorAll('.stack-item').forEach(btn =>
                    btn.classList.remove('active')
                );
                button.classList.add('active');

                // Show default view (no service selected)
                this.showDefaultView();
            });
        });

        // Category parent toggle (chevron)
        document.querySelectorAll('.category-parent').forEach(parent => {
            parent.addEventListener('click', (e) => {
                e.stopPropagation();
                const chevron = parent.querySelector('.category-chevron');
                const stacksContainer = parent.parentElement.querySelector('.category-stacks');

                if (stacksContainer) {
                    const isOpen = stacksContainer.classList.contains('open');

                    if (isOpen) {
                        stacksContainer.classList.remove('open');
                        if (chevron) chevron.style.transform = 'rotate(0deg)';
                    } else {
                        stacksContainer.classList.add('open');
                        if (chevron) chevron.style.transform = 'rotate(90deg)';
                    }
                }
            });
        });

        // Stack item clicks (individual services)
        document.querySelectorAll('.stack-item').forEach(item => {
            item.addEventListener('click', (e) => {
                e.stopPropagation();
                const serviceName = item.dataset.service;

                // Update active states
                document.querySelectorAll('.info-category-item').forEach(btn =>
                    btn.classList.remove('active')
                );
                document.querySelectorAll('.stack-item').forEach(btn =>
                    btn.classList.remove('active')
                );
                item.classList.add('active');

                // Show service detail directly
                this.showServiceDetail(serviceName);
            });
        });
    }

    /**
     * Filter services in sidebar
     */
    filterServices(query) {
        const normalizedQuery = query.toLowerCase().trim();
        const stackItems = document.querySelectorAll('.stack-item');

        stackItems.forEach(item => {
            const serviceName = item.dataset.service?.toLowerCase() || '';
            const matches = serviceName.includes(normalizedQuery);
            item.style.display = matches ? 'flex' : 'none';
        });

        // Auto-expand categories with matching results
        if (normalizedQuery) {
            document.querySelectorAll('.category-stacks').forEach(container => {
                const hasVisibleItems = Array.from(container.querySelectorAll('.stack-item'))
                    .some(item => item.style.display !== 'none');
                if (hasVisibleItems) {
                    container.classList.add('open');
                    const chevron = container.parentElement.querySelector('.category-chevron');
                    if (chevron) chevron.style.transform = 'rotate(90deg)';
                }
            });
        }
    }

    /**
     * Load services (static infrastructure data)
     * @param {boolean} forceRefresh - Force refresh
     */
    async load(forceRefresh = false) {
        try {
            // Static infrastructure services
            this.services = [
                // Backend Services
                {
                    app: 'Supabase',
                    icon: '🗄️',
                    description: 'Base de données PostgreSQL + Auth + Storage + Edge Functions',
                    category: 'Backend',
                    status: 'running',
                    containers: [
                        { name: 'supabase-db', state: 'running' },
                        { name: 'supabase-kong', state: 'running' },
                        { name: 'supabase-auth', state: 'running' },
                        { name: 'supabase-rest', state: 'running' },
                        { name: 'supabase-storage', state: 'running' },
                        { name: 'supabase-realtime', state: 'running' },
                        { name: 'edge-functions', state: 'running' }
                    ],
                    urls: ['http://pi5.local:8000', 'http://pi5.local:8001'],
                    ports: ['5432', '8000', '8001']
                },
                {
                    app: 'Traefik',
                    icon: '🔀',
                    description: 'Reverse proxy et load balancer avec dashboard',
                    category: 'Proxy',
                    status: 'running',
                    containers: [{ name: 'traefik', state: 'running' }],
                    urls: ['http://pi5.local:8080'],
                    ports: ['80', '443', '8080']
                },
                // Monitoring Services
                {
                    app: 'Netdata',
                    icon: '📊',
                    description: 'Monitoring temps réel des ressources système',
                    category: 'Monitoring',
                    status: 'running',
                    containers: [{ name: 'netdata', state: 'running' }],
                    urls: ['http://pi5.local:19999'],
                    ports: ['19999']
                },
                {
                    app: 'Uptime Kuma',
                    icon: '⏰',
                    description: 'Monitoring de disponibilité et alertes',
                    category: 'Monitoring',
                    status: 'running',
                    containers: [{ name: 'uptime-kuma', state: 'running' }],
                    urls: ['http://pi5.local:3001'],
                    ports: ['3001']
                },
                // Automation Services
                {
                    app: 'n8n',
                    icon: '🔄',
                    description: 'Workflow automation et intégrations',
                    category: 'Automation',
                    status: 'running',
                    containers: [{ name: 'n8n', state: 'running' }],
                    urls: ['http://pi5.local:5678'],
                    ports: ['5678']
                },
                // Other Services
                {
                    app: 'Portainer',
                    icon: '🐳',
                    description: 'Interface de gestion Docker',
                    category: 'Other',
                    status: 'running',
                    containers: [{ name: 'portainer', state: 'running' }],
                    urls: ['http://pi5.local:9000'],
                    ports: ['9000']
                },
                {
                    app: 'Vaultwarden',
                    icon: '🔐',
                    description: 'Gestionnaire de mots de passe (Bitwarden compatible)',
                    category: 'Other',
                    status: 'running',
                    containers: [{ name: 'vaultwarden', state: 'running' }],
                    urls: ['http://pi5.local:8082'],
                    ports: ['8082']
                }
            ];

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
     * Populate category counts in sidebar
     */
    populateSelector() {
        // Update category counts
        const categories = ['all', 'Backend', 'Monitoring', 'Automation', 'Proxy', 'Other'];
        categories.forEach(cat => {
            const count = cat === 'all'
                ? this.services.length
                : this.services.filter(s => (s.category || 'Other') === cat).length;
            const countEl = document.getElementById(`${cat === 'all' ? 'all-services' : cat.toLowerCase()}-count`);
            if (countEl) countEl.textContent = count;
        });

        // Show default view on load
        this.showDefaultView();
    }

    /**
     * Show default view (all services as cards)
     */
    showDefaultView() {
        const defaultView = document.getElementById('service-default-view');
        const detailView = document.getElementById('service-detail-content');

        if (defaultView) {
            defaultView.style.display = 'block';
            // Render all services as cards
            this.renderServicesGrid(defaultView);
        }
        if (detailView) detailView.style.display = 'none';

        this.currentService = null;

        // Re-init lucide icons
        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Render all services as clickable cards
     */
    renderServicesGrid(container) {
        const servicesHTML = this.services.map(service => {
            const statusClass = service.status === 'running' ? 'success' : 'error';
            const statusIcon = service.status === 'running' ? 'check-circle' : 'alert-circle';

            return `
                <div class="service-card" onclick="window.servicesManager.showServiceDetail('${service.app}')">
                    <div class="service-card-icon">${service.icon || '📦'}</div>
                    <div class="service-card-content">
                        <h3 class="service-card-title">${service.app}</h3>
                        <p class="service-card-description">${service.description || 'Aucune description'}</p>
                        <div class="service-card-footer">
                            <span class="service-card-category">${service.category || 'Other'}</span>
                            <span class="service-card-status ${statusClass}">
                                <i data-lucide="${statusIcon}" size="12"></i>
                                ${service.status || 'unknown'}
                            </span>
                        </div>
                    </div>
                </div>
            `;
        }).join('');

        container.innerHTML = `
            <div class="services-grid-header">
                <h2>Tous les services</h2>
                <p class="text-secondary">${this.services.length} service(s) disponible(s)</p>
            </div>
            <div class="services-cards-grid">
                ${servicesHTML}
            </div>
        `;
    }

    /**
     * Show service detail directly in main content
     */
    showServiceDetail(serviceName) {
        // Find service data
        const service = this.services.find(s => s.app === serviceName);
        if (!service) {
            console.error(`Service not found: ${serviceName}`);
            return;
        }

        this.currentService = service;

        // Hide default view, show detail view
        const defaultView = document.getElementById('service-default-view');
        const detailView = document.getElementById('service-detail-content');

        if (defaultView) defaultView.style.display = 'none';
        if (detailView) detailView.style.display = 'block';

        // Populate service details
        this.renderServiceDetail(service);

        // Re-init lucide icons
        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Render service detail content
     */
    renderServiceDetail(service) {
        // Header
        document.getElementById('detail-icon').textContent = service.icon || '📦';
        document.getElementById('detail-service-name').textContent = service.app;
        document.getElementById('detail-service-description').textContent = service.description || 'Aucune description';

        // Status badge
        const statusBadge = document.getElementById('detail-service-status');
        const statusClass = service.status === 'running' ? 'success' : 'error';
        const statusIcon = service.status === 'running' ? 'check-circle' : 'alert-circle';
        statusBadge.className = `service-status-badge ${statusClass}`;
        statusBadge.innerHTML = `
            <i data-lucide="${statusIcon}" size="12"></i>
            <span>${service.status || 'unknown'}</span>
        `;

        // Containers
        const containersHTML = this.renderContainersHTML(service.containers || []);
        document.getElementById('detail-containers').innerHTML = containersHTML;

        // URLs
        const urlsHTML = this.renderURLsHTML(service.urls || []);
        document.getElementById('detail-urls').innerHTML = urlsHTML;

        // Ports
        const portsHTML = this.renderPortsHTML(service.ports || []);
        document.getElementById('detail-ports').innerHTML = portsHTML;

        // Credentials (with load button)
        document.getElementById('detail-credentials').innerHTML = `
            <button class="btn btn-primary btn-load-credentials" data-service="${service.app}">
                <i data-lucide="key" size="14"></i>
                <span>Charger les identifiants</span>
            </button>
            <div id="credentials-content" style="display: none; margin-top: 12px;"></div>
        `;

        // Add click event for load credentials button
        const loadBtn = document.querySelector('.btn-load-credentials');
        if (loadBtn) {
            loadBtn.addEventListener('click', () => this.loadCredentials(service.app));
        }

        // Commands
        const commandsHTML = this.renderCommandsHTML(service.app);
        document.getElementById('detail-commands').innerHTML = commandsHTML;
    }

    /**
     * Load credentials for a service
     */
    async loadCredentials(serviceName) {
        const btn = document.querySelector('.btn-load-credentials');
        const content = document.getElementById('credentials-content');

        if (!btn || !content) return;

        // Show loading
        btn.disabled = true;
        btn.innerHTML = '<i data-lucide="loader" size="14" class="spin"></i><span>Chargement...</span>';

        try {
            const response = await api.get(`/services/${serviceName}/credentials`);
            const credentials = response.credentials || {};

            if (Object.keys(credentials).length === 0) {
                content.innerHTML = `
                    <div class="empty-state-small">
                        <i data-lucide="info" size="24"></i>
                        <p>Aucun identifiant trouvé</p>
                    </div>
                `;
            } else {
                content.innerHTML = this.renderCredentialsHTML(credentials);
            }

            content.style.display = 'block';
            btn.style.display = 'none';

            // Re-init lucide icons
            if (window.lucide) window.lucide.createIcons();

        } catch (error) {
            console.error('Failed to load credentials:', error);
            content.innerHTML = `
                <div class="empty-state-small error">
                    <i data-lucide="alert-circle" size="24"></i>
                    <p>Erreur lors du chargement : ${error.message}</p>
                </div>
            `;
            content.style.display = 'block';
            btn.disabled = false;
            btn.innerHTML = '<i data-lucide="key" size="14"></i><span>Réessayer</span>';

            if (window.lucide) window.lucide.createIcons();
        }
    }

    /**
     * Render credentials HTML with masked values
     */
    renderCredentialsHTML(credentials) {
        const items = Object.entries(credentials).map(([key, value]) => {
            const isSensitive = key.toLowerCase().includes('password') ||
                               key.toLowerCase().includes('secret') ||
                               key.toLowerCase().includes('key') ||
                               key.toLowerCase().includes('token');

            if (isSensitive) {
                const credId = `cred-${key.replace(/[^a-zA-Z0-9]/g, '-')}`;
                return `
                    <div class="credential-item">
                        <div class="credential-label">${key}</div>
                        <div class="credential-value-wrapper">
                            <code id="${credId}" class="credential-value masked" data-value="${value}">••••••••••••</code>
                            <button class="credential-toggle-btn" onclick="window.servicesManager.toggleCredential('${credId}')" title="Afficher/Masquer">
                                <i data-lucide="eye" size="14"></i>
                            </button>
                            <button class="credential-copy-btn" onclick="window.servicesManager.copyToClipboard('${value.replace(/'/g, "\\'")}', 'Identifiant copié')" title="Copier">
                                <i data-lucide="copy" size="14"></i>
                            </button>
                        </div>
                    </div>
                `;
            } else {
                return `
                    <div class="credential-item">
                        <div class="credential-label">${key}</div>
                        <div class="credential-value-wrapper">
                            <code class="credential-value">${value}</code>
                            <button class="credential-copy-btn" onclick="window.servicesManager.copyToClipboard('${value.replace(/'/g, "\\'")}', 'Identifiant copié')" title="Copier">
                                <i data-lucide="copy" size="14"></i>
                            </button>
                        </div>
                    </div>
                `;
            }
        }).join('');

        // Add header with bulk actions
        const header = `
            <div class="block-header-with-actions">
                <h3><i data-lucide="key"></i> Identifiants</h3>
                <div class="block-actions">
                    <button class="btn btn-secondary btn-xs" onclick="window.servicesManager.revealAllCredentials()" title="Révéler tous">
                        <i data-lucide="eye" size="12"></i>
                        Tout révéler
                    </button>
                    <button class="btn btn-secondary btn-xs" onclick="window.servicesManager.copyAllCredentials()" title="Copier tous (JSON)">
                        <i data-lucide="copy" size="12"></i>
                        Tout copier
                    </button>
                </div>
            </div>
        `;

        return `${header}<div class="credentials-list">${items}</div>`;
    }

    /**
     * Copy to clipboard with toast notification
     */
    copyToClipboard(text, message = 'Copié !') {
        navigator.clipboard.writeText(text).then(() => {
            toast.success(message);
        }).catch(err => {
            console.error('Copy failed:', err);
            toast.error('Échec de la copie');
        });
    }

    /**
     * Reveal all credentials in current view
     */
    revealAllCredentials() {
        const maskedCredentials = document.querySelectorAll('.credential-value.masked');
        maskedCredentials.forEach(el => {
            const value = el.dataset.value;
            el.textContent = value;
            el.classList.remove('masked');
            const icon = el.parentElement.querySelector('.credential-toggle-btn i');
            if (icon) icon.setAttribute('data-lucide', 'eye-off');
        });

        if (window.lucide) window.lucide.createIcons();
        toast.success('Tous les identifiants révélés');
    }

    /**
     * Copy all credentials as JSON
     */
    copyAllCredentials() {
        const credentialItems = document.querySelectorAll('.credential-item');
        const credentials = {};

        credentialItems.forEach(item => {
            const label = item.querySelector('.credential-label')?.textContent || '';
            const valueEl = item.querySelector('.credential-value');
            const value = valueEl?.dataset.value || valueEl?.textContent || '';
            if (label) credentials[label] = value;
        });

        const json = JSON.stringify(credentials, null, 2);
        navigator.clipboard.writeText(json).then(() => {
            toast.success('Tous les identifiants copiés (JSON)');
        }).catch(err => {
            console.error('Copy failed:', err);
            toast.error('Échec de la copie');
        });
    }

    /**
     * Toggle credential visibility
     */
    toggleCredential(credId) {
        const el = document.getElementById(credId);
        if (!el) return;

        const value = el.dataset.value;
        const icon = el.parentElement.querySelector('.credential-toggle-btn i');

        if (el.classList.contains('masked')) {
            el.textContent = value;
            el.classList.remove('masked');
            if (icon) icon.setAttribute('data-lucide', 'eye-off');
        } else {
            el.textContent = '••••••••••••';
            el.classList.add('masked');
            if (icon) icon.setAttribute('data-lucide', 'eye');
        }

        // Re-init lucide icons
        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Render containers HTML
     */
    renderContainersHTML(containers) {
        if (!containers || containers.length === 0) {
            return `
                <div class="empty-state-small">
                    <i data-lucide="info" size="24"></i>
                    <p>Aucun conteneur</p>
                </div>
            `;
        }

        const items = containers.map(c => `
            <div class="container-item">
                <span class="container-item-name">${c.name}</span>
                <span class="container-item-state ${c.state}">
                    <i data-lucide="${c.state === 'running' ? 'check-circle' : 'x-circle'}" size="12"></i>
                    ${c.state}
                </span>
            </div>
        `).join('');

        return `<div class="container-list">${items}</div>`;
    }

    renderURLsHTML(urls) {
        if (!urls || urls.length === 0) {
            return `
                <div class="empty-state-small">
                    <i data-lucide="info" size="24"></i>
                    <p>Aucune URL</p>
                </div>
            `;
        }

        const items = urls.map(url => `
            <div class="url-item">
                <a href="${url}" target="_blank" rel="noopener noreferrer">${url}</a>
                <button class="url-copy-btn" onclick="window.servicesManager.copyToClipboard('${url}', 'URL copiée')" title="Copier l'URL">
                    <i data-lucide="copy" size="14"></i>
                </button>
            </div>
        `).join('');

        return `<div class="url-list">${items}</div>`;
    }

    renderPortsHTML(ports) {
        if (!ports || ports.length === 0) {
            return `
                <div class="empty-state-small">
                    <i data-lucide="info" size="24"></i>
                    <p>Aucun port</p>
                </div>
            `;
        }

        const items = ports.map(port => `<span class="port-badge">${port}</span>`).join('');
        return `<div class="port-list">${items}</div>`;
    }

    renderCommandsHTML(serviceName) {
        const commands = [
            `docker logs ${serviceName}`,
            `docker restart ${serviceName}`,
            `docker exec -it ${serviceName} sh`
        ];

        const items = commands.map(cmd => `
            <div class="command-item">
                <code>${cmd}</code>
                <button class="command-copy-btn" onclick="window.servicesManager.copyToClipboard('${cmd}', 'Commande copiée')" title="Copier la commande">
                    <i data-lucide="copy" size="14"></i>
                </button>
            </div>
        `).join('');

        return `<div class="command-list">${items}</div>`;
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
