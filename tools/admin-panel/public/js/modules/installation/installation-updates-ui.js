/**
 * Installation Updates UI Module
 * Renders the Updates sections (Overview, Docker, System, Settings)
 */

export class InstallationUpdatesUI {
    constructor(widgetsModule) {
        this.widgetsModule = widgetsModule;
    }

    /**
     * Show updates section
     */
    showSection(section) {
        // Hide other panels
        const servicesGrid = document.getElementById('services-grid');
        const backupsList = document.getElementById('backups-list');
        const updatesPanel = document.getElementById('updates-panel-center');

        if (servicesGrid) servicesGrid.style.display = 'none';
        if (backupsList) backupsList.style.display = 'none';
        if (updatesPanel) updatesPanel.style.display = 'block';

        // Render section content
        this.renderSectionContent(section);
    }

    /**
     * Render section content
     */
    async renderSectionContent(section) {
        const panel = document.getElementById('updates-panel-center');
        if (!panel) return;

        const titles = {
            'overview': 'Vue d\'ensemble',
            'docker': 'Services Docker',
            'system': 'Système (APT)',
            'settings': 'Paramètres'
        };

        // Update category title
        const categoryTitle = document.getElementById('category-title');
        if (categoryTitle) {
            categoryTitle.textContent = `Mises à jour - ${titles[section] || section}`;
        }

        // Render HTML based on section
        let content = '';

        if (section === 'overview') {
            content = this.getOverviewHTML();
        } else if (section === 'docker') {
            content = this.getDockerHTML();
        } else if (section === 'system') {
            content = this.getSystemHTML();
        } else if (section === 'settings') {
            content = this.getSettingsHTML();
        }

        panel.innerHTML = content;

        // Reinitialize Lucide icons
        if (window.lucide) window.lucide.createIcons();

        // Re-attach event listeners and load data
        await this.loadSectionData(section);
    }

    /**
     * Get Overview section HTML
     */
    getOverviewHTML() {
        return `
            <div class="content-section updates-section active" data-section="overview">
                <div class="section-header updates-section-header">
                    <h2>
                        <i data-lucide="layout-dashboard" size="20"></i>
                        <span>Vue d'ensemble</span>
                    </h2>
                    <div class="section-actions">
                        <button id="check-updates-btn" class="btn btn-primary">
                            <i data-lucide="search" size="16"></i>
                            <span>Vérifier</span>
                        </button>
                        <button id="update-all-btn" class="btn btn-success" style="display: none;">
                            <i data-lucide="download" size="16"></i>
                            <span>Tout mettre à jour</span>
                        </button>
                    </div>
                </div>

                <p class="section-description">
                    Détection intelligente des mises à jour disponibles pour vos services Docker, packages système et dépendances.
                </p>

                <!-- Quick Stats Widgets -->
                <div class="installation-widgets" id="installation-widgets" style="display: grid;">
                    <div class="install-widget" id="widget-services">
                        <div class="widget-icon">
                            <i data-lucide="package" size="20"></i>
                        </div>
                        <div class="widget-info">
                            <div class="widget-label">Services installés</div>
                            <div class="widget-value" id="widget-services-value">—</div>
                        </div>
                    </div>
                    <div class="install-widget" id="widget-updates">
                        <div class="widget-icon warning">
                            <i data-lucide="arrow-up-circle" size="20"></i>
                        </div>
                        <div class="widget-info">
                            <div class="widget-label">Mises à jour</div>
                            <div class="widget-value" id="widget-updates-value">—</div>
                        </div>
                    </div>
                    <div class="install-widget" id="widget-disk">
                        <div class="widget-icon">
                            <i data-lucide="hard-drive" size="20"></i>
                        </div>
                        <div class="widget-info">
                            <div class="widget-label">Espace disponible</div>
                            <div class="widget-value" id="widget-disk-value">—</div>
                        </div>
                    </div>
                    <div class="install-widget" id="widget-docker">
                        <div class="widget-icon">
                            <i data-lucide="box" size="20"></i>
                        </div>
                        <div class="widget-info">
                            <div class="widget-label">Conteneurs actifs</div>
                            <div class="widget-value" id="widget-docker-value">—</div>
                        </div>
                    </div>
                </div>

                <!-- Installation Progress -->
                <div class="installation-progress-section">
                    <div class="progress-header">
                        <h3>
                            <i data-lucide="trending-up" size="18"></i>
                            <span>Progression de l'installation</span>
                        </h3>
                        <span class="progress-percent" id="install-progress-percent">0%</span>
                    </div>
                    <div class="progress-bar-large">
                        <div class="progress-fill-large" id="install-progress-fill" style="width: 0%"></div>
                    </div>
                    <div class="progress-details">
                        <div class="progress-status" id="install-progress-status">Prêt à installer</div>
                        <div class="progress-steps" id="install-progress-steps">
                            <div class="step-item" data-step="docker">
                                <i data-lucide="circle" size="14"></i>
                                <span>Docker</span>
                            </div>
                            <div class="step-item" data-step="network">
                                <i data-lucide="circle" size="14"></i>
                                <span>Réseau</span>
                            </div>
                            <div class="step-item" data-step="security">
                                <i data-lucide="circle" size="14"></i>
                                <span>Sécurité</span>
                            </div>
                            <div class="step-item" data-step="services">
                                <i data-lucide="circle" size="14"></i>
                                <span>Services</span>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Summary Cards -->
                <div class="updates-summary">
                    <div class="update-summary-card" data-type="total">
                        <div class="summary-icon">📦</div>
                        <div class="summary-content">
                            <h4>Services totaux</h4>
                            <p id="total-services">—</p>
                            <span class="summary-subtitle">Conteneurs Docker surveillés</span>
                        </div>
                    </div>
                    <div class="update-summary-card" data-type="available">
                        <div class="summary-icon">🆕</div>
                        <div class="summary-content">
                            <h4>Mises à jour disponibles</h4>
                            <p id="updates-available">—</p>
                            <span class="summary-subtitle">Cliquer pour voir les détails</span>
                        </div>
                    </div>
                    <div class="update-summary-card" data-type="up-to-date">
                        <div class="summary-icon">✅</div>
                        <div class="summary-content">
                            <h4>À jour</h4>
                            <p id="up-to-date-count">—</p>
                            <span class="summary-subtitle">Aucune action requise</span>
                        </div>
                    </div>
                    <div class="update-summary-card" data-type="last-check">
                        <div class="summary-icon">🕒</div>
                        <div class="summary-content">
                            <h4>Dernière vérification</h4>
                            <p id="last-check-time" style="font-size: 16px; font-weight: 600;">Jamais</p>
                            <span class="summary-subtitle" id="last-check-date">—</span>
                        </div>
                    </div>
                </div>

                <!-- Services Docker List with Collapsible Sections -->
                <div style="margin-top: 32px;">
                    <h3 style="display: flex; align-items: center; gap: 12px; margin: 0 0 16px 0; font-size: 18px;">
                        <i data-lucide="layers" size="18"></i>
                        <span>Services Docker</span>
                    </h3>

                    <!-- Updates Available Section (Collapsible) -->
                    <div class="collapsible-section" style="margin-bottom: 16px;">
                        <div class="collapsible-header" id="overview-updates-header" style="cursor: pointer; display: flex; align-items: center; justify-content: space-between; padding: 16px; background: linear-gradient(to right, rgba(251, 191, 36, 0.08), transparent 50%); border: 1px solid rgba(251, 191, 36, 0.3); border-left: 4px solid var(--warning); border-radius: 10px;">
                            <div style="display: flex; align-items: center; gap: 12px;">
                                <i data-lucide="chevron-down" size="18" id="overview-updates-chevron"></i>
                                <i data-lucide="arrow-up-circle" size="18" style="color: var(--warning);"></i>
                                <h4 style="margin: 0; font-size: 16px; font-weight: 600;">À mettre à jour</h4>
                                <span class="category-count" id="overview-updates-count" style="background: var(--warning); color: white;">0</span>
                            </div>
                        </div>
                        <div class="collapsible-content" id="overview-updates-content" style="margin-top: 12px;">
                            <div class="updates-list" id="overview-updates-available-list">
                                <div class="loading">Chargement...</div>
                            </div>
                        </div>
                    </div>

                    <!-- Up-to-Date Section (Collapsible) -->
                    <div class="collapsible-section">
                        <div class="collapsible-header" id="overview-uptodate-header" style="cursor: pointer; display: flex; align-items: center; justify-content: space-between; padding: 16px; background: var(--bg-secondary); border: 1px solid var(--border); border-left: 4px solid var(--success); border-radius: 10px;">
                            <div style="display: flex; align-items: center; gap: 12px;">
                                <i data-lucide="chevron-down" size="18" id="overview-uptodate-chevron"></i>
                                <i data-lucide="check-circle" size="18" style="color: var(--success);"></i>
                                <h4 style="margin: 0; font-size: 16px; font-weight: 600;">À jour</h4>
                                <span class="category-count" id="overview-uptodate-count" style="background: var(--success); color: white;">0</span>
                            </div>
                        </div>
                        <div class="collapsible-content collapsed" id="overview-uptodate-content" style="margin-top: 12px; display: none;">
                            <div class="updates-list" id="overview-uptodate-list">
                                <div class="loading">Chargement...</div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }

    /**
     * Get Docker section HTML
     */
    getDockerHTML() {
        return `
            <div class="content-section updates-section active" data-section="docker">
                <div class="section-header updates-section-header">
                    <h2>
                        <i data-lucide="layers" size="20"></i>
                        <span>Services Docker</span>
                    </h2>
                    <div class="section-actions">
                        <button id="check-updates-btn-docker" class="btn btn-primary">
                            <i data-lucide="refresh-cw" size="16"></i>
                            <span>Rafraîchir</span>
                        </button>
                    </div>
                </div>
                <div id="docker-updates-list" class="updates-list">
                    <div class="loading">Chargement...</div>
                </div>
            </div>
        `;
    }

    /**
     * Get System section HTML
     */
    getSystemHTML() {
        return `
            <div class="content-section updates-section active" data-section="system">
                <div class="section-header updates-section-header">
                    <h2>
                        <i data-lucide="server" size="20"></i>
                        <span>Système (APT)</span>
                    </h2>
                    <div class="section-actions">
                        <button id="refresh-apt-btn" class="btn btn-sm">
                            <i data-lucide="refresh-cw" size="14"></i>
                            <span>Rafraîchir</span>
                        </button>
                    </div>
                </div>
                <div id="system-updates-list" class="updates-list">
                    <div class="loading">Vérification...</div>
                </div>
            </div>
        `;
    }

    /**
     * Get Settings section HTML
     */
    getSettingsHTML() {
        return `
            <div class="content-section updates-section active" data-section="settings">
                <div class="section-header updates-section-header">
                    <h2>
                        <i data-lucide="settings" size="20"></i>
                        <span>Paramètres</span>
                    </h2>
                </div>

                <div class="settings-group">
                    <h3>Mode de vérification</h3>
                    <div class="version-toggle mode-toggle">
                        <label class="toggle-label">
                            <span class="toggle-text">⚡ Rapide</span>
                            <div class="toggle-switch" id="mode-toggle">
                                <input type="checkbox" id="mode-checkbox">
                                <span class="toggle-slider">
                                    <span class="toggle-emoji fast">⚡</span>
                                    <span class="toggle-emoji accurate">🎯</span>
                                </span>
                            </div>
                            <span class="toggle-text accurate-text">🎯 Précis</span>
                        </label>
                    </div>
                </div>

                <div class="settings-group">
                    <h3>Versions</h3>
                    <div class="version-toggle">
                        <label class="toggle-label">
                            <span class="toggle-text">Stable</span>
                            <div class="toggle-switch" id="beta-toggle">
                                <input type="checkbox" id="beta-checkbox">
                                <span class="toggle-slider">
                                    <span class="toggle-emoji stable">🛡️</span>
                                    <span class="toggle-emoji beta">🚀</span>
                                </span>
                            </div>
                            <span class="toggle-text beta-text">Beta</span>
                        </label>
                    </div>
                </div>
            </div>
        `;
    }

    /**
     * Load data for section
     */
    async loadSectionData(section) {
        if (!window.updatesManager) return;

        // Setup event listeners
        window.updatesManager.setupEventListeners();

        // Load appropriate data
        if (section === 'overview') {
            // Setup collapsible sections event listeners
            this.setupOverviewCollapsibles();

            await window.updatesManager.loadUpdates();

            // Render Docker services in collapsible sections
            this.renderOverviewDockerServices();

            // Wait for data to be ready before updating widgets
            setTimeout(() => {
                if (this.widgetsModule) {
                    this.widgetsModule.load();
                }
            }, 1000);
        } else if (section === 'docker') {
            await window.updatesManager.checkDockerUpdates();
            if (this.widgetsModule) {
                this.widgetsModule.load();
            }
        } else if (section === 'system') {
            await window.updatesManager.checkSystemUpdates();
        }
    }

    /**
     * Setup collapsible sections for overview
     */
    setupOverviewCollapsibles() {
        // Updates Available section toggle
        const updatesHeader = document.getElementById('overview-updates-header');
        const updatesContent = document.getElementById('overview-updates-content');
        const updatesChevron = document.getElementById('overview-updates-chevron');

        if (updatesHeader && updatesContent && updatesChevron) {
            updatesHeader.addEventListener('click', () => {
                const isCollapsed = updatesContent.classList.contains('collapsed');

                if (isCollapsed) {
                    updatesContent.classList.remove('collapsed');
                    updatesContent.style.display = 'block';
                    updatesChevron.style.transform = 'rotate(0deg)';
                } else {
                    updatesContent.classList.add('collapsed');
                    updatesContent.style.display = 'none';
                    updatesChevron.style.transform = 'rotate(-90deg)';
                }
            });
        }

        // Up-to-Date section toggle
        const uptodateHeader = document.getElementById('overview-uptodate-header');
        const uptodateContent = document.getElementById('overview-uptodate-content');
        const uptodateChevron = document.getElementById('overview-uptodate-chevron');

        if (uptodateHeader && uptodateContent && uptodateChevron) {
            // Start collapsed
            uptodateChevron.style.transform = 'rotate(-90deg)';

            uptodateHeader.addEventListener('click', () => {
                const isCollapsed = uptodateContent.classList.contains('collapsed');

                if (isCollapsed) {
                    uptodateContent.classList.remove('collapsed');
                    uptodateContent.style.display = 'block';
                    uptodateChevron.style.transform = 'rotate(0deg)';
                } else {
                    uptodateContent.classList.add('collapsed');
                    uptodateContent.style.display = 'none';
                    uptodateChevron.style.transform = 'rotate(-90deg)';
                }
            });
        }
    }

    /**
     * Render Docker services in overview collapsible sections
     */
    renderOverviewDockerServices() {
        if (!window.updatesManager || !window.updatesManager.services) return;

        const services = window.updatesManager.services;

        // Split services by status
        const updatesAvailable = services.filter(s => s.updateAvailable).sort((a, b) => a.name.localeCompare(b.name));
        const upToDate = services.filter(s => !s.updateAvailable).sort((a, b) => a.name.localeCompare(b.name));

        // Update counts
        const updatesCountEl = document.getElementById('overview-updates-count');
        const uptodateCountEl = document.getElementById('overview-uptodate-count');
        if (updatesCountEl) updatesCountEl.textContent = updatesAvailable.length;
        if (uptodateCountEl) uptodateCountEl.textContent = upToDate.length;

        // Render updates available list
        const updatesListEl = document.getElementById('overview-updates-available-list');
        if (updatesListEl) {
            if (updatesAvailable.length === 0) {
                updatesListEl.innerHTML = '<p class="no-data">🎉 Tous vos services sont à jour !</p>';
            } else {
                updatesListEl.innerHTML = this.renderDockerServicesList(updatesAvailable);
            }
        }

        // Render up-to-date list
        const uptodateListEl = document.getElementById('overview-uptodate-list');
        if (uptodateListEl) {
            if (upToDate.length === 0) {
                uptodateListEl.innerHTML = '<p class="no-data">Aucun service à jour pour le moment</p>';
            } else {
                uptodateListEl.innerHTML = this.renderDockerServicesList(upToDate);
            }
        }

        // Reinitialize Lucide icons
        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Render Docker services list HTML
     */
    renderDockerServicesList(services) {
        return services.map(service => {
            const hasUpdate = service.updateAvailable;
            const statusClass = hasUpdate ? 'update-available' : 'up-to-date';
            const statusIcon = hasUpdate ? '🆕' : '✅';
            const statusText = hasUpdate ? 'Mise à jour disponible' : 'À jour';

            return `
                <div class="update-item ${statusClass}">
                    <div class="update-item-header">
                        <div class="update-info">
                            <h4>${service.name}</h4>
                            <div class="update-versions">
                                <span class="current-version">
                                    <strong>Installée:</strong> ${service.currentVersion || 'unknown'}
                                </span>
                                ${hasUpdate ? `
                                    <i data-lucide="arrow-right" size="14"></i>
                                    <span class="latest-version">
                                        <strong>Disponible:</strong> ${service.latestVersion}
                                    </span>
                                ` : ''}
                            </div>
                            <div class="update-image">
                                <code>${service.image}</code>
                            </div>
                        </div>
                        <div class="update-status">
                            <span class="status-badge ${statusClass}">
                                ${statusIcon} ${statusText}
                            </span>
                        </div>
                    </div>
                    ${hasUpdate ? `
                        <div class="update-item-actions">
                            <button
                                class="btn btn-sm btn-primary"
                                onclick="window.updatesManager.updateService('${service.container}', '${service.image}:${service.latestVersion}')">
                                <i data-lucide="download" size="14"></i>
                                <span>Mettre à jour</span>
                            </button>
                            <button
                                class="btn btn-sm btn-ghost"
                                onclick="window.updatesManager.showChangelog('${service.name}', '${service.currentVersion}', '${service.latestVersion}')">
                                <i data-lucide="file-text" size="14"></i>
                                <span>Changelog</span>
                            </button>
                        </div>
                    ` : ''}
                </div>
            `;
        }).join('');
    }

    /**
     * Get service icon name
     */
    getServiceIcon(service) {
        const icons = {
            'supabase': 'database',
            'pocketbase': 'package',
            'vaultwarden': 'key',
            'nginx': 'server',
            'caddy': 'shield',
            'appwrite': 'cloud',
            'tailscale': 'shield',
            'pihole': 'filter',
            'email-smtp': 'send'
        };

        return icons[service] || 'box';
    }
}
