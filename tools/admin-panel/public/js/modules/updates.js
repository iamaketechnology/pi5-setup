// =============================================================================
// Updates Manager Module
// =============================================================================
// Intelligent update detection for Docker images, system packages, and more
// Version: 1.0.0
// Author: PI5-SETUP Project
// =============================================================================

import api from '../utils/api.js';

/**
 * Updates Manager - Detects and manages updates
 */
class UpdatesManager {
    constructor() {
        this.services = [];
        this.updateCheckInterval = null;
        this.showBetaVersions = false; // Toggle state
        this.checkMode = 'fast'; // 'fast' or 'accurate'
        this.dockerFilter = 'all'; // 'all', 'up-to-date', 'updates-available'
    }

    /**
     * Initialize Updates module
     */
    init() {
        this.setupUI();
        this.setupEventListeners();
        this.loadUpdates();
        console.log('✅ Updates module initialized');
    }

    /**
     * Setup UI (create HTML structure dynamically)
     */
    setupUI() {
        const container = document.getElementById('updates-content');
        if (!container) return;

        container.innerHTML = `
            <div class="sidebar-layout updates-layout-sidebar">
                <!-- Sidebar -->
                <aside class="sidebar updates-sidebar">
                    <div class="sidebar-header">
                        <h3>
                            <i data-lucide="refresh-cw" size="18"></i>
                            <span>Mises à jour</span>
                        </h3>
                        <p class="sidebar-description">Navigation par sections</p>
                    </div>

                    <div class="sidebar-categories">
                        <button class="category-item updates-category-item active" data-category="overview">
                            <i data-lucide="layout-dashboard" size="16"></i>
                            <span class="category-name">Vue d'ensemble</span>
                        </button>
                        <button class="category-item updates-category-item" data-category="docker">
                            <i data-lucide="layers" size="16"></i>
                            <span class="category-name">Services Docker</span>
                            <span class="category-count" id="docker-count">0</span>
                        </button>
                        <button class="category-item updates-category-item" data-category="system">
                            <i data-lucide="server" size="16"></i>
                            <span class="category-name">Système (APT)</span>
                            <span class="category-count" id="system-count">0</span>
                        </button>
                        <button class="category-item updates-category-item" data-category="settings">
                            <i data-lucide="settings" size="16"></i>
                            <span class="category-name">Paramètres</span>
                        </button>
                    </div>
                </aside>

                <!-- Main Content -->
                <div class="main-content updates-main">
                    <!-- Overview Section -->
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
                    </div>

                    <!-- Docker Updates Section -->
                    <div class="content-section updates-section" data-section="docker">
                        <div class="section-header updates-section-header">
                            <h2>
                                <i data-lucide="layers" size="20"></i>
                                <span>Services Docker</span>
                            </h2>
                            <div class="section-actions">
                                <div class="btn-group" id="docker-filter-group">
                                    <button class="btn btn-sm active" data-filter="all">
                                        <i data-lucide="layers" size="14"></i>
                                        <span>Tous</span>
                                    </button>
                                    <button class="btn btn-sm" data-filter="up-to-date">
                                        <i data-lucide="check-circle" size="14"></i>
                                        <span>À jour</span>
                                    </button>
                                    <button class="btn btn-sm" data-filter="updates-available">
                                        <i data-lucide="arrow-up-circle" size="14"></i>
                                        <span>À mettre à jour</span>
                                    </button>
                                </div>
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

                    <!-- System Updates Section -->
                    <div class="content-section updates-section" data-section="system">
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

                    <!-- Settings Section -->
                    <div class="content-section updates-section" data-section="settings">
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
                </div>
            </div>
        `;

        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Sidebar navigation
        document.querySelectorAll('.updates-category-item').forEach(button => {
            button.addEventListener('click', (e) => {
                this.navigateToSection(button.dataset.category);
            });
        });

        // Widget click navigation
        this.setupWidgetNavigation();

        // Mode toggle (Fast/Accurate)
        document.getElementById('mode-checkbox')?.addEventListener('change', (e) => {
            this.checkMode = e.target.checked ? 'accurate' : 'fast';
            const toggle = document.querySelector('.mode-toggle');

            if (this.checkMode === 'accurate') {
                toggle.classList.add('accurate-mode');
                if (window.toastManager) {
                    window.toastManager.warning(
                        '🎯 Mode Précis activé',
                        'Vérification complète avec docker pull - peut prendre plusieurs minutes'
                    );
                }
            } else {
                toggle.classList.remove('accurate-mode');
            }

            // Auto-reload updates with new mode
            this.loadUpdates();
        });

        // Beta toggle
        document.getElementById('beta-checkbox')?.addEventListener('change', (e) => {
            this.showBetaVersions = e.target.checked;
            const toggle = document.querySelector('.version-toggle:not(.mode-toggle)');

            // Animation ludique
            if (this.showBetaVersions) {
                toggle.classList.add('beta-mode');
                this.showBetaNotification();
            } else {
                toggle.classList.remove('beta-mode');
            }

            // Reload updates with new filter
            this.renderDockerUpdates();
        });

        // Check updates button
        document.getElementById('check-updates-btn')?.addEventListener('click', () => {
            this.loadUpdates();
        });

        // Update all button
        document.getElementById('update-all-btn')?.addEventListener('click', () => {
            this.updateAll();
        });

        // Refresh APT
        document.getElementById('refresh-apt-btn')?.addEventListener('click', () => {
            this.checkSystemUpdates();
        });

        // Docker filter buttons
        document.querySelectorAll('#docker-filter-group button').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const filter = btn.dataset.filter;
                this.dockerFilter = filter;

                // Update active state
                document.querySelectorAll('#docker-filter-group button').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');

                // Re-render Docker list with filter
                this.renderDockerUpdates();
            });
        });

        // Refresh Docker updates
        document.getElementById('check-updates-btn-docker')?.addEventListener('click', () => {
            this.checkDockerUpdates();
        });
    }

    /**
     * Navigate to a specific section
     */
    navigateToSection(category) {
        // Update active states in sidebar
        document.querySelectorAll('.updates-category-item').forEach(btn =>
            btn.classList.remove('active')
        );
        const categoryBtn = document.querySelector(`.updates-category-item[data-category="${category}"]`);
        if (categoryBtn) {
            categoryBtn.classList.add('active');
        }

        // Show corresponding section - ONLY within updates layout
        const updatesContainer = document.querySelector('.updates-layout-sidebar');
        if (!updatesContainer) return;

        updatesContainer.querySelectorAll('.updates-section').forEach(section => {
            section.classList.remove('active');
        });

        const targetSection = updatesContainer.querySelector(`.updates-section[data-section="${category}"]`);
        if (targetSection) {
            targetSection.classList.add('active');
        }
    }

    /**
     * Setup widget navigation
     */
    setupWidgetNavigation() {
        // Click on "Mises à jour disponibles" widget -> navigate to Docker section
        const availableWidget = document.querySelector('[data-type="available"]');
        if (availableWidget) {
            availableWidget.addEventListener('click', () => {
                const count = parseInt(document.getElementById('updates-available')?.textContent || '0');
                if (count > 0) {
                    this.navigateToSection('docker');
                }
            });
        }

        // Click on "Services totaux" widget -> navigate to Docker section
        const totalWidget = document.querySelector('[data-type="total"]');
        if (totalWidget) {
            totalWidget.addEventListener('click', () => {
                this.navigateToSection('docker');
            });
        }

        // Click on "À jour" widget -> navigate to Docker section
        const upToDateWidget = document.querySelector('[data-type="up-to-date"]');
        if (upToDateWidget) {
            upToDateWidget.addEventListener('click', () => {
                this.navigateToSection('docker');
            });
        }
    }

    /**
     * Show playful notification when enabling beta mode
     */
    showBetaNotification() {
        if (window.toastManager) {
            window.toastManager.info(
                '🚀 Mode Beta activé',
                'Vous verrez maintenant les versions instables et en développement'
            );
        }
    }

    /**
     * Load all updates (Docker + System)
     */
    async loadUpdates() {
        await Promise.all([
            this.checkDockerUpdates(),
            this.checkSystemUpdates()
        ]);

        this.updateLastCheckTime();
    }

    /**
     * Check Docker image updates
     */
    async checkDockerUpdates() {
        try {
            const container = document.getElementById('docker-updates-list');
            if (!container) return;

            const loadingMsg = this.checkMode === 'accurate'
                ? '🎯 Vérification précise en cours (docker pull) - peut prendre plusieurs minutes...'
                : '⚡ Vérification rapide des images Docker...';

            container.innerHTML = `<div class="loading"><i data-lucide="loader" size="24" class="spin"></i> ${loadingMsg}</div>`;
            if (window.lucide) window.lucide.createIcons();

            const data = await api.get(`/updates/docker?mode=${this.checkMode}`);
            this.services = data.services || [];

            this.renderDockerUpdates();
            this.updateSummary();

            // Update Docker updates badge in sidebar
            const dockerCount = this.services.filter(s => s.updateAvailable).length;
            const dockerCountEl = document.getElementById('docker-count');
            if (dockerCountEl) dockerCountEl.textContent = dockerCount;

        } catch (error) {
            console.error('Failed to check Docker updates:', error);
            const container = document.getElementById('docker-updates-list');
            if (container) {
                container.innerHTML = `<div class="error">❌ Erreur: ${error.message}</div>`;
            }
        }
    }

    /**
     * Check if version is stable (not beta/alpha/rc)
     */
    isStableVersion(version) {
        if (!version) return true;
        const lowerVersion = version.toLowerCase();
        return !lowerVersion.includes('beta') &&
               !lowerVersion.includes('alpha') &&
               !lowerVersion.includes('rc') &&
               !lowerVersion.includes('dev') &&
               !lowerVersion.includes('nightly') &&
               !lowerVersion.includes('canary');
    }

    /**
     * Render Docker updates list
     */
    renderDockerUpdates() {
        const container = document.getElementById('docker-updates-list');
        if (!container) return;

        if (this.services.length === 0) {
            container.innerHTML = '<p class="no-data">Aucun service Docker détecté</p>';
            return;
        }

        // Filter services based on beta toggle
        let filteredServices = this.services;
        if (!this.showBetaVersions) {
            filteredServices = this.services.filter(service => {
                // Only show if update is stable OR no update available
                return !service.updateAvailable || this.isStableVersion(service.latestVersion);
            });
        }

        // Apply Docker filter (all, up-to-date, updates-available)
        if (this.dockerFilter === 'up-to-date') {
            filteredServices = filteredServices.filter(s => !s.updateAvailable);
        } else if (this.dockerFilter === 'updates-available') {
            filteredServices = filteredServices.filter(s => s.updateAvailable);
        }
        // 'all' = no additional filtering

        // Sort: updates available first, then up-to-date
        filteredServices.sort((a, b) => {
            // updateAvailable = true should come first (return -1)
            if (a.updateAvailable && !b.updateAvailable) return -1;
            if (!a.updateAvailable && b.updateAvailable) return 1;
            // If both same status, sort alphabetically by name
            return a.name.localeCompare(b.name);
        });

        if (filteredServices.length === 0) {
            let message = '';
            if (this.dockerFilter === 'up-to-date') {
                message = '✅ Aucun service à jour pour le moment';
            } else if (this.dockerFilter === 'updates-available') {
                message = '🎉 Tous vos services sont déjà à jour !';
            } else if (this.showBetaVersions) {
                message = 'Aucune version beta disponible';
            } else {
                message = 'Aucune mise à jour stable disponible. Activez le mode Beta pour voir plus de versions.';
            }

            container.innerHTML = `<p class="no-data">${message}</p>`;
            return;
        }

        container.innerHTML = filteredServices.map(service => {
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

        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Check system (APT) updates
     */
    async checkSystemUpdates() {
        try {
            const container = document.getElementById('system-updates-list');
            if (!container) return;

            container.innerHTML = '<div class="loading"><i data-lucide="loader" size="24" class="spin"></i> Vérification des packages système...</div>';
            if (window.lucide) window.lucide.createIcons();

            const data = await api.get('/updates/system');
            const systemCount = (data.updates && data.updates.length) || 0;

            if (systemCount > 0) {
                container.innerHTML = `
                    <div class="system-updates">
                        <p><strong>${systemCount} package(s)</strong> peuvent être mis à jour.</p>
                        <button class="btn btn-primary" onclick="window.updatesManager.updateSystem()">
                            <i data-lucide="download" size="16"></i>
                            <span>Mettre à jour le système</span>
                        </button>
                        <details style="margin-top: 16px;">
                            <summary style="cursor: pointer; font-weight: 600;">Voir la liste des packages</summary>
                            <pre style="margin-top: 12px; padding: 12px; background: var(--bg-secondary); border-radius: 6px; font-size: 11px; max-height: 300px; overflow-y: auto;">${data.updates.join('\n')}</pre>
                        </details>
                    </div>
                `;
            } else {
                container.innerHTML = '<p class="no-data">✅ Système à jour</p>';
            }

            // Update System updates badge in sidebar
            const systemCountEl = document.getElementById('system-count');
            if (systemCountEl) systemCountEl.textContent = systemCount;

            if (window.lucide) window.lucide.createIcons();

        } catch (error) {
            console.error('Failed to check system updates:', error);
            const container = document.getElementById('system-updates-list');
            if (container) {
                container.innerHTML = `<div class="error">❌ Erreur: ${error.message}</div>`;
            }
        }
    }

    /**
     * Update summary cards
     */
    updateSummary() {
        const total = this.services.length;
        const available = this.services.filter(s => s.updateAvailable).length;
        const upToDate = total - available;

        document.getElementById('total-services').textContent = total;
        document.getElementById('updates-available').textContent = available;
        document.getElementById('up-to-date-count').textContent = upToDate;

        // Update sidebar badges
        const updatesCountEl = document.getElementById('updates-count');
        const updatesCountMainEl = document.getElementById('updates-count-main');
        if (updatesCountEl) updatesCountEl.textContent = available;
        if (updatesCountMainEl) updatesCountMainEl.textContent = available;

        // Show/hide "Update All" button
        const updateAllBtn = document.getElementById('update-all-btn');
        if (updateAllBtn) {
            updateAllBtn.style.display = available > 0 ? 'flex' : 'none';
        }

        // Update notification badge on Updates tab
        this.updateNotificationBadge(available);
    }

    /**
     * Update notification badge on Updates tab
     */
    updateNotificationBadge(count) {
        const updatesTab = document.querySelector('[data-tab="updates"]');
        if (!updatesTab) return;

        if (count > 0) {
            updatesTab.setAttribute('data-notification', count > 99 ? '99+' : count);
        } else {
            updatesTab.removeAttribute('data-notification');
        }
    }

    /**
     * Update last check time
     */
    updateLastCheckTime() {
        const now = new Date();
        const timeStr = now.toLocaleTimeString('fr-FR', {
            hour: '2-digit',
            minute: '2-digit'
        });
        const dateStr = now.toLocaleDateString('fr-FR', {
            day: 'numeric',
            month: 'short'
        });

        document.getElementById('last-check-time').textContent = timeStr;
        document.getElementById('last-check-date').textContent = dateStr;
    }

    /**
     * Update a single service
     */
    async updateService(containerName, newImage) {
        if (!confirm(`Mettre à jour ${containerName} vers ${newImage} ?\n\nCela va arrêter et redémarrer le conteneur.`)) {
            return;
        }

        try {
            if (window.terminalManager) {
                window.terminalManager.addLine(`🔄 Updating ${containerName}...`, 'info');
            }

            const response = await api.post('/updates/docker/update', {
                container: containerName,
                image: newImage
            });

            if (response.success) {
                if (window.terminalManager) {
                    window.terminalManager.addLine(`✅ ${containerName} updated successfully`, 'success');
                }
                alert(`✅ ${containerName} mis à jour avec succès !`);
                this.loadUpdates();
            } else {
                throw new Error(response.error || 'Update failed');
            }

        } catch (error) {
            console.error('Update failed:', error);
            if (window.terminalManager) {
                window.terminalManager.addLine(`❌ Update failed: ${error.message}`, 'error');
            }
            alert(`❌ Échec de la mise à jour: ${error.message}`);
        }
    }

    /**
     * Update all services with available updates
     */
    async updateAll() {
        const servicesToUpdate = this.services.filter(s => s.updateAvailable);

        if (servicesToUpdate.length === 0) return;

        if (!confirm(`Mettre à jour ${servicesToUpdate.length} service(s) ?\n\n${servicesToUpdate.map(s => `• ${s.name}`).join('\n')}`)) {
            return;
        }

        for (const service of servicesToUpdate) {
            await this.updateService(service.container, `${service.image}:${service.latestVersion}`);
        }
    }

    /**
     * Update system packages
     */
    async updateSystem() {
        if (!confirm('Mettre à jour tous les packages système ?\n\nCela peut prendre plusieurs minutes.')) {
            return;
        }

        try {
            if (window.terminalManager) {
                window.terminalManager.addLine('🔄 Updating system packages...', 'info');
            }

            const response = await api.post('/updates/system/upgrade');

            if (response.success) {
                if (window.terminalManager) {
                    window.terminalManager.addLine('✅ System updated successfully', 'success');
                }
                alert('✅ Système mis à jour avec succès !');
                this.checkSystemUpdates();
            }

        } catch (error) {
            console.error('System update failed:', error);
            if (window.terminalManager) {
                window.terminalManager.addLine(`❌ Update failed: ${error.message}`, 'error');
            }
            alert(`❌ Échec: ${error.message}`);
        }
    }

    /**
     * Show changelog for a service
     */
    showChangelog(serviceName, currentVersion, latestVersion) {
        alert(`Changelog pour ${serviceName}\n\nVersion actuelle: ${currentVersion}\nNouvelle version: ${latestVersion}\n\n(Fonctionnalité en développement)`);
    }
}

// Create singleton
const updatesManager = new UpdatesManager();

// Export
export default updatesManager;

// Global access
window.updatesManager = updatesManager;
