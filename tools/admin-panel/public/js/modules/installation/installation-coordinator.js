/**
 * Installation Coordinator
 * Main entry point - coordinates all installation sub-modules
 *
 * This is a REFACTORED version that delegates to specialized modules.
 * Eventually, all logic from installation-assistant.js will be moved here.
 */

import { InstallationTerminal } from './installation-terminal.js';
import { InstallationWidgets } from './installation-widgets.js';
import { InstallationSidebar } from './installation-sidebar.js';
import { InstallationUpdatesUI } from './installation-updates-ui.js';
import legacyAssistant from '../installation-assistant-legacy.js';

export class InstallationCoordinator {
    constructor() {
        // Core modules
        this.diagnostics = new SystemDiagnostics();

        // Sub-modules
        this.terminalModule = new InstallationTerminal();
        this.widgetsModule = new InstallationWidgets(this.diagnostics, this.terminalModule);
        this.updatesUIModule = new InstallationUpdatesUI(this.widgetsModule);
        this.sidebarModule = new InstallationSidebar(
            legacyAssistant, // backupsModule - uses legacy for now
            this.updatesUIModule,
            legacyAssistant  // servicesModule - uses legacy for now
        );

        // Legacy compatibility
        this.messageCount = 0;
        this.currentStatus = {};
        this.steps = [
            { id: 'docker', name: 'Docker', emoji: '🐳', required: true },
            { id: 'network', name: 'Réseau', emoji: '📡', required: true },
            { id: 'security', name: 'Sécurité', emoji: '🔒', required: true },
            { id: 'traefik', name: 'Traefik', emoji: '🌐', required: false },
            { id: 'monitoring', name: 'Monitoring', emoji: '📊', required: false }
        ];
    }

    /**
     * Initialize all modules
     */
    async init() {
        console.log('✅ Installation Coordinator initialized');

        // Initialize sub-modules
        this.terminalModule.init();
        this.sidebarModule.init();

        // Load widgets and show default section
        await this.widgetsModule.load();
        this.updatesUIModule.showSection('overview');

        // Initialize quick actions (legacy)
        this.initQuickActions();
    }

    /**
     * Legacy addMessage stub - redirects to terminal
     */
    addMessage(text, type = 'info', options = {}) {
        this.terminalModule.write(text, type === 'assistant' ? 'info' : type);
    }

    /**
     * Legacy loadWidgets - delegates to widgets module
     */
    async loadWidgets() {
        return this.widgetsModule.load();
    }

    /**
     * Legacy showUpdatesSection - delegates to updates UI module
     */
    showUpdatesSection(section) {
        return this.updatesUIModule.showSection(section);
    }

    /**
     * Initialize quick actions
     * TODO: Move to InstallationServices module
     */
    initQuickActions() {
        document.querySelectorAll('.quick-action-btn').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                e.preventDefault();
                const type = btn.dataset.install;
                if (type) {
                    // Legacy - to be refactored
                    console.warn('TODO: Move handleQuickInstall to InstallationServices module');
                }
            });
        });
    }

    /**
     * Get terminal module (for external access)
     */
    getTerminal() {
        return this.terminalModule;
    }

    /**
     * Get widgets module (for external access)
     */
    getWidgets() {
        return this.widgetsModule;
    }
}

// Export singleton for backward compatibility
const installationCoordinator = new InstallationCoordinator();
export default installationCoordinator;
