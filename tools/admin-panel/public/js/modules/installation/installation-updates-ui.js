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

        // Get template for section (simplified - using existing HTML rendering from old code)
        // For now, delegate to updatesManager which has the templates
        panel.innerHTML = '<div class="loading">Chargement...</div>';

        // Reinitialize Lucide icons
        if (window.lucide) window.lucide.createIcons();

        // Re-attach event listeners and load data
        await this.loadSectionData(section);
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
            await window.updatesManager.loadUpdates();
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
