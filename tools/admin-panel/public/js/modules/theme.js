// =============================================================================
// Theme Module - Dark/Light Mode Switcher
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// =============================================================================

class ThemeManager {
    constructor() {
        this.currentTheme = 'dark'; // default
        this.storageKey = 'pi5-theme';
    }

    init() {
        this.loadTheme();
        this.createToggleButton();
        console.log(`✅ Theme module initialized (${this.currentTheme} mode)`);
    }

    /**
     * Load theme from localStorage or system preference
     */
    loadTheme() {
        // Check localStorage first
        const saved = localStorage.getItem(this.storageKey);
        if (saved) {
            this.currentTheme = saved;
        } else {
            // Check system preference
            if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
                this.currentTheme = 'light';
            }
        }

        this.applyTheme(this.currentTheme);

        // Listen for system theme changes
        if (window.matchMedia) {
            window.matchMedia('(prefers-color-scheme: light)').addEventListener('change', (e) => {
                // Only auto-switch if user hasn't manually set a preference
                if (!localStorage.getItem(this.storageKey)) {
                    this.setTheme(e.matches ? 'light' : 'dark');
                }
            });
        }
    }

    /**
     * Apply theme to DOM
     * @param {string} theme - 'dark' or 'light'
     */
    applyTheme(theme) {
        if (theme === 'light') {
            document.documentElement.setAttribute('data-theme', 'light');
        } else {
            document.documentElement.removeAttribute('data-theme');
        }

        this.currentTheme = theme;
        this.updateToggleButton();
    }

    /**
     * Set and persist theme
     * @param {string} theme - 'dark' or 'light'
     */
    setTheme(theme) {
        this.applyTheme(theme);
        localStorage.setItem(this.storageKey, theme);

        // Notify toast
        if (window.toastManager) {
            const icon = theme === 'light' ? '☀️' : '🌙';
            window.toastManager.success(`${icon} ${theme === 'light' ? 'Light' : 'Dark'} Mode`, 'Theme updated successfully');
        }

        // Emit event for other modules
        window.dispatchEvent(new CustomEvent('theme:changed', { detail: { theme } }));
    }

    /**
     * Toggle between dark and light
     */
    toggle() {
        const newTheme = this.currentTheme === 'dark' ? 'light' : 'dark';
        this.setTheme(newTheme);
    }

    /**
     * Create theme toggle button in header
     */
    createToggleButton() {
        const headerStats = document.querySelector('.header-stats');
        if (!headerStats) return;

        const btn = document.createElement('button');
        btn.id = 'theme-toggle';
        btn.className = 'btn-power btn-theme';
        btn.title = 'Toggle Theme';
        btn.innerHTML = '<i data-lucide="moon" size="18"></i>';
        btn.addEventListener('click', () => this.toggle());

        // Insert before power controls
        const powerControls = headerStats.querySelector('.power-controls');
        if (powerControls) {
            headerStats.insertBefore(btn, powerControls);
        } else {
            headerStats.appendChild(btn);
        }

        // Initialize icon
        if (typeof lucide !== 'undefined') {
            lucide.createIcons();
        }

        this.updateToggleButton();
    }

    /**
     * Update toggle button icon
     */
    updateToggleButton() {
        const btn = document.getElementById('theme-toggle');
        if (!btn) return;

        const icon = btn.querySelector('[data-lucide]');
        if (!icon) return;

        // Update icon based on current theme
        if (this.currentTheme === 'light') {
            icon.setAttribute('data-lucide', 'sun');
            btn.title = 'Switch to Dark Mode';
        } else {
            icon.setAttribute('data-lucide', 'moon');
            btn.title = 'Switch to Light Mode';
        }

        // Re-initialize icons
        if (typeof lucide !== 'undefined') {
            lucide.createIcons();
        }
    }

    /**
     * Get current theme
     * @returns {string} 'dark' or 'light'
     */
    getTheme() {
        return this.currentTheme;
    }

    /**
     * Check if dark mode is active
     * @returns {boolean}
     */
    isDark() {
        return this.currentTheme === 'dark';
    }

    /**
     * Check if light mode is active
     * @returns {boolean}
     */
    isLight() {
        return this.currentTheme === 'light';
    }
}

// Export singleton
const themeManager = new ThemeManager();
export default themeManager;

// Make available globally
window.themeManager = themeManager;
