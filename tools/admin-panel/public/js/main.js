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
import { initPowerControls } from './modules/power.js';
import piCredentialsManager from './modules/pi-credentials.js';
import setupWizardManager from './modules/setup-wizard.js';
import installationAssistant from './modules/installation-assistant.js';
import terminalSidebarManager from './modules/terminal-sidebar.js';
import toastManager from './modules/toast.js';
import commandPalette from './modules/command-palette.js';
import hotkeysManager from './modules/hotkeys.js';
import themeManager from './modules/theme.js';
import errorHandler from './utils/error-handler.js';
import chartsManager from './modules/charts.js';
import breadcrumbsManager from './modules/breadcrumbs.js';
import bulkActionsManager from './modules/bulk-actions.js';
import { initIcons } from './utils/icons.js';
import './utils/export.js'; // Load export utilities

// Global state (minimal - most state in modules)
window.currentPiId = null;

// =============================================================================
// Initialization
// =============================================================================

document.addEventListener('DOMContentLoaded', async () => {
    console.log('🚀 PI5 Control Center v3.9 - Modular Architecture + PWA');

    // 1. Register Service Worker (PWA)
    registerServiceWorker();

    // 2. Load server configuration
    await loadServerConfig();

    // 3. Initialize modules
    initModules();

    // 4. Setup callbacks
    setupCallbacks();
});

// =============================================================================
// Service Worker Registration
// =============================================================================

function registerServiceWorker() {
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.register('/sw.js')
            .then((registration) => {
                console.log('✅ Service Worker registered:', registration.scope);

                // Check for updates
                registration.addEventListener('updatefound', () => {
                    const newWorker = registration.installing;
                    newWorker.addEventListener('statechange', () => {
                        if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                            if (window.toastManager) {
                                window.toastManager.info('Update available', 'Refresh to get the latest version');
                            }
                        }
                    });
                });
            })
            .catch((error) => {
                console.warn('⚠️ Service Worker registration failed:', error);
            });
    }
}

function initModules() {
    console.log('📦 Initializing modules...');

    // Error handling first
    errorHandler.init();

    // UI Core
    themeManager.init(); // Load theme first
    toastManager.init();
    commandPalette.init();
    hotkeysManager.init();
    breadcrumbsManager.init();
    bulkActionsManager.init();
    tabsManager.init();
    piSelectorManager.init();
    terminalManager.init();
    initPowerControls();

    // System monitoring
    chartsManager.init(); // Initialize charts first
    systemStatsManager.init(); // Auto-refresh every 5s
    dockerManager.init();

    // Scripts and execution
    scriptsManager.init();
    historyManager.init();
    schedulerManager.init();

    // Services
    servicesManager.init();

    // Pi Credentials
    piCredentialsManager.init();

    // Setup Wizard
    setupWizardManager.init();

    // Installation Assistant
    installationAssistant.init();

    // Terminal Sidebar
    terminalSidebarManager.init();
    terminalSidebarManager.restoreState();

    // Initialize Lucide icons
    initIcons();

    console.log('✅ All modules initialized');
}

function setupCallbacks() {
    // Tab load callbacks
    tabsManager.onTabLoad('network', () => {
        console.log('📡 Loading network tab...');
        networkManager.init();
        networkManager.load();
    });

    tabsManager.onTabLoad('docker', () => {
        console.log('🐳 Loading docker tab...');
        dockerManager.load();
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

    tabsManager.onTabLoad('installation', () => {
        console.log('🎬 Loading installation tab...');
        installationAssistant.load();
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
