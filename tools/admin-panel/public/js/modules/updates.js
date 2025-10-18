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
            <div class="updates-container">
                <div class="updates-header">
                    <h2>
                        <i data-lucide="refresh-cw" size="20"></i>
                        <span>Mises à jour</span>
                    </h2>
                    <div class="updates-actions">
                        <!-- Ludique Beta Toggle -->
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
                        <button id="check-updates-btn" class="btn btn-primary">
                            <i data-lucide="search" size="16"></i>
                            <span>Vérifier les mises à jour</span>
                        </button>
                        <button id="update-all-btn" class="btn btn-success" style="display: none;">
                            <i data-lucide="download" size="16"></i>
                            <span>Tout mettre à jour</span>
                        </button>
                    </div>
                </div>

                <p class="updates-description">
                    Détection intelligente des mises à jour disponibles pour vos services Docker, packages système et dépendances.
                </p>

                <!-- Summary Cards -->
                <div class="updates-summary">
                    <div class="update-summary-card" data-type="total">
                        <div class="summary-icon">📦</div>
                        <div class="summary-content">
                            <h4>Services totaux</h4>
                            <p id="total-services">—</p>
                        </div>
                    </div>
                    <div class="update-summary-card" data-type="available">
                        <div class="summary-icon">🆕</div>
                        <div class="summary-content">
                            <h4>Mises à jour disponibles</h4>
                            <p id="updates-available">—</p>
                        </div>
                    </div>
                    <div class="update-summary-card" data-type="up-to-date">
                        <div class="summary-icon">✅</div>
                        <div class="summary-content">
                            <h4>À jour</h4>
                            <p id="up-to-date-count">—</p>
                        </div>
                    </div>
                    <div class="update-summary-card" data-type="last-check">
                        <div class="summary-icon">🕒</div>
                        <div class="summary-content">
                            <h4>Dernière vérification</h4>
                            <p id="last-check-time">Jamais</p>
                        </div>
                    </div>
                </div>

                <!-- Services List -->
                <section class="panel">
                    <div class="panel-header">
                        <h3><i data-lucide="layers" size="18"></i> Services Docker</h3>
                    </div>
                    <div id="docker-updates-list" class="updates-list">
                        <div class="loading">Chargement...</div>
                    </div>
                </section>

                <!-- System Updates -->
                <section class="panel">
                    <div class="panel-header">
                        <h3><i data-lucide="server" size="18"></i> Système (APT)</h3>
                        <button id="refresh-apt-btn" class="btn btn-sm">
                            <i data-lucide="refresh-cw" size="14"></i>
                            <span>Rafraîchir</span>
                        </button>
                    </div>
                    <div id="system-updates-list" class="updates-list">
                        <div class="loading">Vérification...</div>
                    </div>
                </section>
            </div>
        `;

        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Beta toggle
        document.getElementById('beta-checkbox')?.addEventListener('change', (e) => {
            this.showBetaVersions = e.target.checked;
            const toggle = document.querySelector('.version-toggle');

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

            container.innerHTML = '<div class="loading"><i data-lucide="loader" size="24" class="spin"></i> Vérification des images Docker...</div>';
            if (window.lucide) window.lucide.createIcons();

            const data = await api.get('/updates/docker');
            this.services = data.services || [];

            this.renderDockerUpdates();
            this.updateSummary();

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

        if (filteredServices.length === 0) {
            container.innerHTML = `
                <p class="no-data">
                    ${this.showBetaVersions
                        ? 'Aucune version beta disponible'
                        : 'Aucune mise à jour stable disponible. Activez le mode Beta pour voir plus de versions.'}
                </p>
            `;
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

            if (data.updates && data.updates.length > 0) {
                container.innerHTML = `
                    <div class="system-updates">
                        <p><strong>${data.updates.length} package(s)</strong> peuvent être mis à jour.</p>
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

        // Show/hide "Update All" button
        const updateAllBtn = document.getElementById('update-all-btn');
        if (updateAllBtn) {
            updateAllBtn.style.display = available > 0 ? 'flex' : 'none';
        }
    }

    /**
     * Update last check time
     */
    updateLastCheckTime() {
        const now = new Date();
        const timeStr = now.toLocaleTimeString('fr-FR');
        document.getElementById('last-check-time').textContent = timeStr;
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
