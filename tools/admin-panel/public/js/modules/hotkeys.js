// =============================================================================
// Hotkeys Module - Global Keyboard Shortcuts
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// =============================================================================

class HotkeysManager {
    constructor() {
        this.shortcuts = new Map();
        this.enabled = true;
    }

    init() {
        this.registerDefaultShortcuts();
        this.setupGlobalListener();
        console.log('✅ Hotkeys module initialized');
    }

    registerDefaultShortcuts() {
        // Tab navigation (1-8)
        this.register('1', () => window.tabsManager?.switchTab('dashboard'), 'Go to Dashboard');
        this.register('2', () => window.tabsManager?.switchTab('installation'), 'Go to Installation');
        this.register('3', () => window.tabsManager?.switchTab('scripts'), 'Go to Scripts');
        this.register('4', () => window.tabsManager?.switchTab('network'), 'Go to Network');
        this.register('5', () => window.tabsManager?.switchTab('docker'), 'Go to Docker');
        this.register('6', () => window.tabsManager?.switchTab('info'), 'Go to Services Info');
        this.register('7', () => window.tabsManager?.switchTab('history'), 'Go to History');
        this.register('8', () => window.tabsManager?.switchTab('scheduler'), 'Go to Scheduler');

        // Terminal toggle (Ctrl+`)
        this.register('Ctrl+`', () => window.terminalSidebarManager?.toggle(), 'Toggle Terminal');

        // Refresh (Ctrl+R or Cmd+R) - Override browser refresh for custom refresh
        this.register('Ctrl+Shift+R', () => {
            window.systemStatsManager?.load();
            window.dockerManager?.load();
            window.toast?.success('Refreshed', 'All data reloaded');
        }, 'Refresh All Data');

        // Help (?)
        this.register('?', () => {
            this.showHelp();
        }, 'Show Keyboard Shortcuts');
    }

    /**
     * Register a keyboard shortcut
     * @param {string} key - Key combination (e.g., 'Ctrl+K', 'Shift+A', '1')
     * @param {Function} callback - Function to execute
     * @param {string} description - Human-readable description
     */
    register(key, callback, description = '') {
        const normalized = this.normalizeKey(key);
        this.shortcuts.set(normalized, { callback, description, key });
    }

    /**
     * Normalize key combination for consistent matching
     * @param {string} key - Raw key combination
     * @returns {string} - Normalized key
     */
    normalizeKey(key) {
        return key.toLowerCase().replace(/\s+/g, '');
    }

    setupGlobalListener() {
        document.addEventListener('keydown', (e) => {
            // Don't trigger if user is typing in input/textarea
            const target = e.target;
            if (
                target.tagName === 'INPUT' ||
                target.tagName === 'TEXTAREA' ||
                target.isContentEditable ||
                target.classList.contains('terminal-input') ||
                target.classList.contains('command-palette-input')
            ) {
                // Exception: Allow Ctrl+` even in inputs
                if (e.key === '`' && (e.ctrlKey || e.metaKey)) {
                    e.preventDefault();
                    const shortcut = this.shortcuts.get('ctrl+`');
                    if (shortcut) shortcut.callback();
                }
                return;
            }

            if (!this.enabled) return;

            const keyCombo = this.buildKeyCombo(e);
            const shortcut = this.shortcuts.get(keyCombo);

            if (shortcut) {
                e.preventDefault();
                shortcut.callback();
            }
        });
    }

    /**
     * Build key combination string from event
     * @param {KeyboardEvent} e - Keyboard event
     * @returns {string} - Key combination
     */
    buildKeyCombo(e) {
        const parts = [];

        if (e.ctrlKey) parts.push('ctrl');
        if (e.metaKey) parts.push('meta');
        if (e.altKey) parts.push('alt');
        if (e.shiftKey) parts.push('shift');

        // Add the actual key
        const key = e.key.toLowerCase();
        if (key !== 'control' && key !== 'meta' && key !== 'alt' && key !== 'shift') {
            parts.push(key);
        }

        return parts.join('+');
    }

    /**
     * Show help modal with all shortcuts
     */
    showHelp() {
        const shortcuts = Array.from(this.shortcuts.values());

        // Group shortcuts by category
        const grouped = {
            'Navigation': shortcuts.filter(s => s.description.includes('Go to')),
            'Actions': shortcuts.filter(s => !s.description.includes('Go to') && s.key !== '?'),
            'Help': shortcuts.filter(s => s.key === '?')
        };

        let html = `
            <div class="hotkeys-help-modal">
                <div class="hotkeys-help-content">
                    <h2>⌨️ Keyboard Shortcuts</h2>
        `;

        Object.keys(grouped).forEach(category => {
            if (grouped[category].length === 0) return;

            html += `<div class="hotkeys-category">`;
            html += `<h3>${category}</h3>`;
            html += `<div class="hotkeys-list">`;

            grouped[category].forEach(shortcut => {
                html += `
                    <div class="hotkey-item">
                        <div class="hotkey-keys">${this.formatKey(shortcut.key)}</div>
                        <div class="hotkey-desc">${shortcut.description}</div>
                    </div>
                `;
            });

            html += `</div></div>`;
        });

        html += `
                    <button class="btn btn-primary" onclick="window.hotkeysManager.closeHelp()">Close</button>
                </div>
            </div>
        `;

        const modal = document.createElement('div');
        modal.id = 'hotkeys-help-overlay';
        modal.className = 'modal active';
        modal.innerHTML = html;
        modal.addEventListener('click', (e) => {
            if (e.target === modal) this.closeHelp();
        });

        document.body.appendChild(modal);
    }

    formatKey(key) {
        const parts = key.split('+');
        return parts.map(part => {
            const formatted = part.charAt(0).toUpperCase() + part.slice(1);
            return `<kbd class="hotkey-kbd">${formatted}</kbd>`;
        }).join(' + ');
    }

    closeHelp() {
        const modal = document.getElementById('hotkeys-help-overlay');
        if (modal) {
            modal.remove();
        }
    }

    /**
     * Enable/disable hotkeys
     */
    enable() {
        this.enabled = true;
    }

    disable() {
        this.enabled = false;
    }

    /**
     * Get all registered shortcuts
     */
    getAllShortcuts() {
        return Array.from(this.shortcuts.entries()).map(([key, data]) => ({
            key,
            ...data
        }));
    }
}

// Export singleton
const hotkeysManager = new HotkeysManager();
export default hotkeysManager;

// Make available globally
window.hotkeysManager = hotkeysManager;
