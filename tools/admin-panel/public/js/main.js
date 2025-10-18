// =============================================================================
// Main Entry Point - ES6 Modules Architecture
// =============================================================================
// Version: 3.4.0
// Architecture: Modular (Native ES6 Modules - No build step!)
// =============================================================================

// Import modules
import { APP_CONFIG, loadServerConfig } from './config.js';
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
import footerManager from './modules/footer.js';
import databaseManager from './modules/database.js';
import sshTunnelsManager from './modules/ssh-tunnels.js';
import quickLaunchManager from './modules/quick-launch.js';
import updatesManager from './modules/updates.js';
import { AddPiModal } from './modules/add-pi.js';
import { initIcons } from './utils/icons.js';
import './utils/export.js'; // Load export utilities

// Global state (minimal - most state in modules)
window.currentPiId = null;
window.footerManager = null; // Will be set during init
window.uiStatus = (() => {
    const header = {
        set(id, { state = 'loading', value = '--', tooltip = '' } = {}) {
            const badge = document.getElementById(`health-${id}`);
            if (!badge) return;
            badge.dataset.state = state;

            const valueEl = document.getElementById(`health-${id}-value`) ||
                (id === 'ssh' ? document.getElementById('ssh-status') : null);

            if (valueEl) {
                valueEl.textContent = value;
                if (tooltip) {
                    valueEl.setAttribute('title', tooltip);
                }
            }
        }
    };

    const summary = {
        alerts: new Map(),
        setPi(text, meta = '') {
            const valueEl = document.getElementById('summary-pi-value');
            const metaEl = document.getElementById('summary-pi-meta');
            if (valueEl) valueEl.textContent = text;
            if (metaEl) metaEl.textContent = meta;
        },
        setNextTask(text, meta = '') {
            const valueEl = document.getElementById('summary-task-value');
            const metaEl = document.getElementById('summary-task-meta');
            if (valueEl) valueEl.textContent = text;
            if (metaEl) metaEl.textContent = meta;
        },
        setAlerts(id, alertData) {
            if (!alertData) {
                this.alerts.delete(id);
            } else {
                this.alerts.set(id, alertData);
            }
            this.refreshAlerts();
        },
        refreshAlerts() {
            const alertsValue = document.getElementById('summary-alerts-value');
            const alertsMeta = document.getElementById('summary-alerts-meta');
            if (!alertsValue || !alertsMeta) return;

            const sorted = Array.from(this.alerts.values())
                .sort((a, b) => (b.priority || 0) - (a.priority || 0));

            const total = sorted.length;
            alertsValue.textContent = total.toString();

            if (total === 0) {
                alertsMeta.textContent = 'Aucune alerte détectée';
            } else {
                const top = sorted[0];
                alertsMeta.textContent = top?.message || 'Vérifications requises';
            }
        }
    };

    return { header, summary };
})();

// =============================================================================
// Initialization
// =============================================================================

document.addEventListener('DOMContentLoaded', async () => {
    console.log('🚀 PI5 Control Center initialisation…');

    // 1. Register Service Worker (PWA)
    registerServiceWorker();

    // 2. Load server configuration
    await loadServerConfig();
    const versionLabel = APP_CONFIG.version ? `v${APP_CONFIG.version}` : 'version inconnue';
    console.log(`🚀 PI5 Control Center ${versionLabel} - Modular Architecture + PWA`);
    updateAppVersion(APP_CONFIG.version);

    // 3. Initialize modules
    initSummaryPlaceholders();
    initModules();

    // 4. Setup callbacks
    setupCallbacks();

    // 5. UI Enhancements
    initFocusModeToggle();
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
                                window.toastManager.info('Mise à jour disponible', 'Rafraîchissez pour obtenir la dernière version');
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
    footerManager.init(); // Initialize footer
    window.footerManager = footerManager; // Make globally accessible
    tabsManager.init();
    piSelectorManager.init();
    window.piSelectorManager = piSelectorManager; // Make globally accessible for Add Pi modal
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

    // Database
    databaseManager.init();

    // SSH Tunnels
    sshTunnelsManager.init();

    // Quick Launch
    quickLaunchManager.init();

    // Updates
    updatesManager.init();

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
        console.log('📡 Chargement de l’onglet réseau...');
        networkManager.init();
        networkManager.load();
    });

    tabsManager.onTabLoad('docker', () => {
        console.log('🐳 Chargement de l’onglet Docker...');
        dockerManager.load();
    });

    tabsManager.onTabLoad('history', () => {
        console.log('📜 Chargement de l’historique...');
        historyManager.load();
    });

    tabsManager.onTabLoad('scheduler', () => {
        console.log('⏰ Chargement du planificateur...');
        schedulerManager.load();
    });

    tabsManager.onTabLoad('info', () => {
        console.log('ℹ️ Chargement des services...');
        servicesManager.load();
    });

    tabsManager.onTabLoad('installation', () => {
        console.log('Installation assistant loading...');
        installationAssistant.load();
    });

    tabsManager.onTabLoad('database', () => {
        console.log('Database configuration loading...');
        databaseManager.load();
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

function initFocusModeToggle() {
    const toggleBtn = document.getElementById('toggle-focus-mode');
    if (!toggleBtn) return;

    const storageKey = 'pi5-focus-mode';
    const stored = localStorage.getItem(storageKey);
    if (stored === 'on') {
        document.body.classList.add('focus-mode');
        toggleBtn.setAttribute('aria-pressed', 'true');
        toggleBtn.querySelector('span').textContent = 'Mode focus (actif)';
    }

    toggleBtn.addEventListener('click', () => {
        const isActive = document.body.classList.toggle('focus-mode');
        toggleBtn.setAttribute('aria-pressed', isActive ? 'true' : 'false');
        toggleBtn.querySelector('span').textContent = isActive ? 'Mode focus (actif)' : 'Mode focus';
        localStorage.setItem(storageKey, isActive ? 'on' : 'off');

        if (window.toastManager) {
            const message = isActive
                ? 'Affichage concentré sur les sections principales'
                : 'Tous les panneaux sont de nouveau disponibles';
            window.toastManager.info('Mode focus', message);
        }
    });
}

function initSummaryPlaceholders() {
    if (!window.uiStatus) return;

    window.uiStatus.summary.setPi('Chargement...', 'Détection en cours');
    window.uiStatus.summary.setNextTask('Chargement...', 'Synchronisation des tâches');

    const alertsValue = document.getElementById('summary-alerts-value');
    const alertsMeta = document.getElementById('summary-alerts-meta');
    if (alertsValue) alertsValue.textContent = '—';
    if (alertsMeta) alertsMeta.textContent = 'Analyse des alertes en cours';

    window.uiStatus.header.set('ssh', { state: 'loading', value: '...' });
    window.uiStatus.header.set('system', { state: 'loading', value: '--' });
    window.uiStatus.header.set('docker', { state: 'loading', value: '--' });
}

function updateAppVersion(version) {
    const versionEl = document.getElementById('app-version');
    if (!versionEl) return;

    // Update footer version too
    if (window.footerManager) {
        window.footerManager.updateVersion(version ? `v${version}` : '--');
    }

    versionEl.textContent = version ? `v${version}` : '--';
}

console.log('✅ Main.js loaded - Modular architecture active');
