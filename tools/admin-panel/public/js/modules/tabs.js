// =============================================================================
// Tabs Navigation Module
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

class TabsManager {
    constructor() {
        this.activeTab = 'dashboard';
        this.tabLoadCallbacks = new Map();
    }

    init() {
        this.setupEventListeners();
        console.log('✅ Tabs module initialized');
    }

    setupEventListeners() {
        const tabs = document.querySelectorAll('.tab');
        tabs.forEach(tab => {
            tab.addEventListener('click', () => {
                const targetTab = tab.dataset.tab;
                this.switchTab(targetTab);
            });
        });
    }

    /**
     * Register a callback to be called when a tab is activated
     * @param {string} tabName - Name of the tab
     * @param {Function} callback - Function to call when tab is loaded
     */
    onTabLoad(tabName, callback) {
        if (!this.tabLoadCallbacks.has(tabName)) {
            this.tabLoadCallbacks.set(tabName, []);
        }
        this.tabLoadCallbacks.get(tabName).push(callback);
    }

    switchTab(tabName) {
        // Update active tab
        this.activeTab = tabName;

        // Update tab buttons
        document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
        const activeTabButton = document.querySelector(`[data-tab="${tabName}"]`);
        if (activeTabButton) {
            activeTabButton.classList.add('active');
        }

        // Update tab content
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        const activeTabContent = document.getElementById(`${tabName}-content`);
        if (activeTabContent) {
            activeTabContent.classList.add('active');
        }

        // Call registered callbacks for this tab
        if (this.tabLoadCallbacks.has(tabName)) {
            const callbacks = this.tabLoadCallbacks.get(tabName);
            callbacks.forEach(callback => {
                try {
                    callback();
                } catch (error) {
                    console.error(`Error loading tab ${tabName}:`, error);
                }
            });
        }

        // Emit custom event
        window.dispatchEvent(new CustomEvent('tab:switched', {
            detail: { tabName }
        }));
    }

    getActiveTab() {
        return this.activeTab;
    }

    isTabActive(tabName) {
        return this.activeTab === tabName;
    }
}

// Export singleton
const tabsManager = new TabsManager();
export default tabsManager;

// Make available globally for backward compatibility
window.tabsManager = tabsManager;
window.switchTab = (tabName) => tabsManager.switchTab(tabName);
