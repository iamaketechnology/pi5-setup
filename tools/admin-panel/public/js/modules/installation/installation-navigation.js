/**
 * Installation Navigation Module
 * Manages category filtering and navigation in services grid
 */

export class InstallationNavigation {
    constructor() {
        this.categoryNames = {
            'infrastructure': 'Infrastructure',
            'webserver': 'Serveur Web',
            'security': 'Sécurité',
            'email': 'Email'
        };
    }

    /**
     * Filter services by category
     */
    filterServicesByCategory(category) {
        // Update page title
        const categoryTitle = document.getElementById('category-title');
        if (categoryTitle) {
            categoryTitle.textContent = this.categoryNames[category] || category;
        }

        // Show services grid, hide other sections
        const servicesGrid = document.getElementById('services-grid');
        const backupsList = document.getElementById('backups-list');
        const updatesPanel = document.getElementById('updates-panel-center');

        if (servicesGrid) servicesGrid.style.display = 'grid';
        if (backupsList) backupsList.style.display = 'none';
        if (updatesPanel) updatesPanel.style.display = 'none';

        // Filter service cards by category
        document.querySelectorAll('.service-card').forEach(card => {
            if (card.dataset.category === category) {
                card.classList.remove('hidden');
            } else {
                card.classList.add('hidden');
            }
        });
    }

    /**
     * Get category display name
     */
    getCategoryName(category) {
        return this.categoryNames[category] || category;
    }
}

// Create singleton
const installationNavigation = new InstallationNavigation();

// Export
export default installationNavigation;
