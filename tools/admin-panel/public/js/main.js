// =============================================================================
// Main Entry Point - ES6 Modules Architecture
// =============================================================================
// Version: 3.4.0
// Architecture: Modular (Native ES6 Modules - No build step!)
// =============================================================================

// Import modules
import { loadServerConfig } from './config.js';
import tabsManager from './modules/tabs.js';
import piSelectorManager from './modules/pi-selector.js';
import terminalManager from './modules/terminal.js';
import networkManager from './modules/network.js';
import dockerManager from './modules/docker.js';
import systemStatsManager from './modules/system-stats.js';
import scriptsManager from './modules/scripts.js';
import historyManager from './modules/history.js';
import schedulerManager from './modules/scheduler.js';
import servicesManager from './modules/services.js';

// Global state (minimal - most state in modules)
window.currentPiId = null;

// =============================================================================
// Initialization
// =============================================================================

document.addEventListener('DOMContentLoaded', async () => {
    console.log('🚀 PI5 Control Center v3.3 - Modular Architecture');

    // 1. Load server configuration first
    await loadServerConfig();

    // 2. Initialize modules
    initModules();

    // 3. Setup callbacks
    setupCallbacks();
});

function initModules() {
    console.log('📦 Initializing modules...');

    // Core modules
    tabsManager.init();
    piSelectorManager.init();
    terminalManager.init();

    // System monitoring
    systemStatsManager.init(); // Auto-refresh every 5s
    dockerManager.init();

    // Scripts and execution
    scriptsManager.init();
    historyManager.init();
    schedulerManager.init();

    // Services
    servicesManager.init();

    console.log('✅ All modules initialized');
}

function setupCallbacks() {
    // Tab load callbacks
    tabsManager.onTabLoad('network', () => {
        console.log('📡 Loading network tab...');
        networkManager.init();
        networkManager.load();
    });

    tabsManager.onTabLoad('history', () => {
        console.log('📜 Loading history tab...');
        historyManager.load();
    });

    tabsManager.onTabLoad('scheduler', () => {
        console.log('⏰ Loading scheduler tab...');
        schedulerManager.load();
    });

    tabsManager.onTabLoad('info', () => {
        console.log('ℹ️ Loading services tab...');
        servicesManager.load();
    });

    // Pi switch callbacks - reload modules that depend on Pi
    piSelectorManager.onPiSwitch((piId, pi) => {
        console.log(`🔄 Pi switched to: ${pi.name}`);

        // Update currentPiId globally (for backward compat)
        window.currentPiId = piId;

        // Reload active tab data
        const currentTab = tabsManager.getActiveTab();

        if (currentTab === 'network') {
            networkManager.load();
        } else if (currentTab === 'history') {
            historyManager.load();
        } else if (currentTab === 'scheduler') {
            schedulerManager.load();
        } else if (currentTab === 'info') {
            servicesManager.load();
        }

        // Always reload system stats and Docker
        systemStatsManager.load();
        dockerManager.load();
    });
}

console.log('✅ Main.js loaded - Modular architecture active');
