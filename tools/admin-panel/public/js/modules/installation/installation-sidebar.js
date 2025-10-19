/**
 * Installation Sidebar Module
 * Manages sidebar navigation, category filtering, and service card interactions
 */

export class InstallationSidebar {
    constructor(backupsModule, updatesUIModule, servicesModule) {
        this.backupsModule = backupsModule;
        this.updatesUIModule = updatesUIModule;
        this.servicesModule = servicesModule;
    }

    /**
     * Initialize sidebar event handlers
     */
    init() {
        this.initCategoryHandlers();
        this.initServiceCardHandlers();
    }

    /**
     * Initialize category click handlers
     */
    initCategoryHandlers() {
        document.querySelectorAll('.installation-sidebar .category-item').forEach(categoryBtn => {
            categoryBtn.addEventListener('click', (e) => {
                const category = categoryBtn.dataset.category;

                // If it's a collapsible parent (Updates), toggle collapse
                if (categoryBtn.classList.contains('category-collapsible')) {
                    e.stopPropagation();
                    this.toggleCollapse(categoryBtn);
                    return;
                }

                // Set active category
                this.setActiveCategory(categoryBtn);

                // Route to appropriate handler
                this.handleCategoryClick(category);
            });
        });
    }

    /**
     * Initialize service card click handlers
     */
    initServiceCardHandlers() {
        document.querySelectorAll('.service-card').forEach(card => {
            const installBtn = card.querySelector('.service-install-btn');
            const type = card.dataset.install;

            if (!installBtn || !type) return;

            // Click on install button
            installBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                if (this.servicesModule) {
                    this.servicesModule.handleQuickInstall(type, installBtn);
                }
            });

            // Click on card (show details)
            card.addEventListener('click', (e) => {
                if (!e.target.closest('.service-install-btn')) {
                    if (this.servicesModule) {
                        this.servicesModule.showServiceDetails(type);
                    }
                }
            });
        });
    }

    /**
     * Handle category click routing
     */
    handleCategoryClick(category) {
        if (category === 'backups') {
            if (this.backupsModule) {
                this.backupsModule.showBackupsList();
            }
        } else if (category === 'updates-overview') {
            if (this.updatesUIModule) {
                this.updatesUIModule.showSection('overview');
            }
        } else if (category === 'updates-docker') {
            if (this.updatesUIModule) {
                this.updatesUIModule.showSection('docker');
            }
        } else if (category === 'updates-system') {
            if (this.updatesUIModule) {
                this.updatesUIModule.showSection('system');
            }
        } else if (category === 'updates-settings') {
            if (this.updatesUIModule) {
                this.updatesUIModule.showSection('settings');
            }
        } else {
            this.filterServicesByCategory(category);
        }
    }

    /**
     * Set active category
     */
    setActiveCategory(categoryBtn) {
        // Remove active from all categories
        document.querySelectorAll('.installation-sidebar .category-item, .installation-sidebar .category-parent, .installation-sidebar .category-header').forEach(item => {
            item.classList.remove('active');
        });

        // Add active to clicked category
        categoryBtn.classList.add('active');
    }

    /**
     * Toggle collapse for expandable categories
     */
    toggleCollapse(button) {
        const categoryGroup = button.closest('.category-group');
        const subcategories = categoryGroup?.querySelector('.category-subcategories');
        const chevron = button.querySelector('.collapse-icon');

        if (!subcategories) return;

        if (subcategories.style.display === 'none') {
            // Expand
            subcategories.style.display = 'block';
            button.classList.add('expanded');
            if (chevron) chevron.setAttribute('data-lucide', 'chevron-up');
        } else {
            // Collapse
            subcategories.style.display = 'none';
            button.classList.remove('expanded');
            if (chevron) chevron.setAttribute('data-lucide', 'chevron-down');
        }

        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Filter services by category
     */
    filterServicesByCategory(category) {
        const categoryNames = {
            'infrastructure': 'Infrastructure',
            'webserver': 'Serveur Web',
            'security': 'Sécurité',
            'email': 'Email'
        };

        // Update title
        const titleElement = document.getElementById('category-title');
        if (titleElement) {
            titleElement.textContent = categoryNames[category] || category;
        }

        // Show services grid, hide backups and updates panel
        const servicesGrid = document.getElementById('services-grid');
        const backupsList = document.getElementById('backups-list');
        const updatesPanel = document.getElementById('updates-panel-center');

        if (servicesGrid) servicesGrid.style.display = 'grid';
        if (backupsList) backupsList.style.display = 'none';
        if (updatesPanel) updatesPanel.style.display = 'none';

        // Show only services matching category
        document.querySelectorAll('.service-card').forEach(card => {
            if (card.dataset.category === category) {
                card.classList.remove('hidden');
            } else {
                card.classList.add('hidden');
            }
        });
    }
}
