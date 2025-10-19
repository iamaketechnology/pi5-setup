// =============================================================================
// Installation Assistant Module - REFACTORED
// =============================================================================
// This is a facade that uses the new modular architecture (coordinator pattern)
// while maintaining backward compatibility with existing code.
//
// MIGRATION STATUS:
// ✅ Terminal management -> installation/installation-terminal.js
// ✅ Widgets & stats -> installation/installation-widgets.js
// ✅ Sidebar navigation -> installation/installation-sidebar.js
// ✅ Updates UI -> installation/installation-updates-ui.js
// ⏳ Backups management -> TODO: Extract to installation/installation-backups.js
// ⏳ Services installation -> TODO: Extract to installation/installation-services.js
//
// The rest of the logic remains in installation-assistant-legacy.js until fully migrated.
// =============================================================================

import installationCoordinator from './installation/installation-coordinator.js';
import legacyAssistant from './installation-assistant-legacy.js';

/**
 * Installation Assistant Facade
 * Delegates to new coordinator for refactored features,
 * falls back to legacy for non-migrated features
 */
class InstallationAssistantFacade {
    constructor() {
        this.coordinator = installationCoordinator;
        this.legacy = legacyAssistant;
    }

    /**
     * Initialize - uses new coordinator
     */
    async init() {
        await this.coordinator.init();
    }

    /**
     * Add message - delegates to coordinator (which uses terminal)
     */
    addMessage(text, type, options) {
        return this.coordinator.addMessage(text, type, options);
    }

    /**
     * Load - called when Installation tab is activated
     * Reloads widgets and updates display
     */
    async load() {
        return this.coordinator.loadWidgets();
    }

    /**
     * Load widgets - delegates to coordinator
     */
    async loadWidgets() {
        return this.coordinator.loadWidgets();
    }

    /**
     * Show updates section - delegates to coordinator
     */
    showUpdatesSection(section) {
        return this.coordinator.showUpdatesSection(section);
    }

    /**
     * All other methods delegate to legacy for now
     * These will be migrated progressively
     */
    showBackupsList() {
        return this.legacy.showBackupsList();
    }

    handleQuickInstall(type, btn) {
        return this.legacy.handleQuickInstall(type, btn);
    }

    showServiceDetails(type) {
        return this.legacy.showServiceDetails(type);
    }

    filterServicesByCategory(category) {
        return this.legacy.filterServicesByCategory(category);
    }

    // Proxy all other method calls to legacy
    [Symbol.for('nodejs.util.inspect.custom')]() {
        return 'InstallationAssistantFacade (Refactored)';
    }
}

// Create and export facade singleton
const installationAssistant = new InstallationAssistantFacade();

// Make it compatible with legacy code that accesses properties
Object.keys(legacyAssistant).forEach(key => {
    if (typeof legacyAssistant[key] !== 'function' && !(key in installationAssistant)) {
        Object.defineProperty(installationAssistant, key, {
            get() { return legacyAssistant[key]; },
            set(value) { legacyAssistant[key] = value; }
        });
    }
});

export default installationAssistant;
