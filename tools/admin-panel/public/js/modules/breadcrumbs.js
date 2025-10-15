// =============================================================================
// Breadcrumbs Module - Dynamic Navigation Context
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// =============================================================================

class BreadcrumbsManager {
    constructor() {
        this.breadcrumbsContainer = null;
        this.currentPath = ['Dashboard'];
        this.tabNames = {
            'dashboard': 'Dashboard',
            'installation': 'Installation',
            'scripts': 'Scripts',
            'network': 'Network',
            'docker': 'Docker',
            'info': 'Services Info',
            'history': 'History',
            'scheduler': 'Scheduler'
        };
    }

    init() {
        this.createBreadcrumbsDOM();
        this.setupListeners();
        this.render();
        console.log('✅ Breadcrumbs module initialized');
    }

    createBreadcrumbsDOM() {
        // Insert breadcrumbs between header and tabs
        const header = document.querySelector('.header');
        if (!header) return;

        const breadcrumbsDiv = document.createElement('div');
        breadcrumbsDiv.className = 'breadcrumbs-container';
        breadcrumbsDiv.id = 'breadcrumbs-container';
        breadcrumbsDiv.innerHTML = `
            <nav class="breadcrumbs" id="breadcrumbs">
                <!-- Breadcrumbs will be rendered here -->
            </nav>
        `;

        // Insert after header
        header.parentNode.insertBefore(breadcrumbsDiv, header.nextSibling);
        this.breadcrumbsContainer = breadcrumbsDiv;
    }

    setupListeners() {
        // Listen for tab changes
        window.addEventListener('tab:switched', (e) => {
            const tabName = this.tabNames[e.detail.tabName] || e.detail.tabName;
            this.setPath([tabName]);
        });

        // Listen for Pi changes
        if (window.piSelectorManager) {
            const originalOnPiSwitch = window.piSelectorManager.onPiSwitch;
            // Can't easily hook into existing callback, will update on tab switch
        }
    }

    /**
     * Set breadcrumb path
     * @param {Array} path - Array of breadcrumb items
     */
    setPath(path) {
        this.currentPath = path;
        this.render();
    }

    /**
     * Add item to breadcrumb path
     * @param {string} item - Breadcrumb item
     */
    addItem(item) {
        this.currentPath.push(item);
        this.render();
    }

    /**
     * Go back to a specific breadcrumb level
     * @param {number} index - Index to go back to
     */
    goTo(index) {
        this.currentPath = this.currentPath.slice(0, index + 1);
        this.render();

        // If going back to a tab, switch to it
        if (index === 0) {
            const tabKey = Object.keys(this.tabNames).find(
                key => this.tabNames[key] === this.currentPath[0]
            );
            if (tabKey && window.tabsManager) {
                window.tabsManager.switchTab(tabKey);
            }
        }
    }

    /**
     * Render breadcrumbs
     */
    render() {
        const breadcrumbsNav = document.getElementById('breadcrumbs');
        if (!breadcrumbsNav) return;

        let html = `
            <div class="breadcrumb-item">
                <a href="#" onclick="window.breadcrumbsManager.goTo(0); return false;">
                    <i data-lucide="home" size="14"></i>
                    <span>Home</span>
                </a>
            </div>
        `;

        this.currentPath.forEach((item, index) => {
            const isLast = index === this.currentPath.length - 1;

            html += `
                <div class="breadcrumb-separator">
                    <i data-lucide="chevron-right" size="12"></i>
                </div>
                <div class="breadcrumb-item ${isLast ? 'active' : ''}">
                    ${isLast ?
                        `<span>${item}</span>` :
                        `<a href="#" onclick="window.breadcrumbsManager.goTo(${index + 1}); return false;">
                            ${item}
                        </a>`
                    }
                </div>
            `;
        });

        // Add context info (current Pi)
        const currentPi = window.currentPiId;
        if (currentPi && window.piSelectorManager) {
            const piConfig = window.piSelectorManager.piConfigs?.[currentPi];
            if (piConfig) {
                html += `
                    <div class="breadcrumb-context">
                        <div class="breadcrumb-context-item">
                            <i data-lucide="monitor" size="14"></i>
                            <span>${piConfig.name}</span>
                        </div>
                    </div>
                `;
            }
        }

        breadcrumbsNav.innerHTML = html;

        // Re-initialize Lucide icons
        if (typeof lucide !== 'undefined') {
            lucide.createIcons();
        }
    }

    /**
     * Show breadcrumbs
     */
    show() {
        if (this.breadcrumbsContainer) {
            this.breadcrumbsContainer.style.display = 'block';
        }
    }

    /**
     * Hide breadcrumbs
     */
    hide() {
        if (this.breadcrumbsContainer) {
            this.breadcrumbsContainer.style.display = 'none';
        }
    }
}

// Export singleton
const breadcrumbsManager = new BreadcrumbsManager();
export default breadcrumbsManager;

// Make available globally
window.breadcrumbsManager = breadcrumbsManager;
