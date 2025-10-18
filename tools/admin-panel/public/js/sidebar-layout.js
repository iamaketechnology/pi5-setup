// =============================================================================
// Sidebar Layout - VS Code Style
// =============================================================================
// Restructure le layout pour déplacer les tabs dans une sidebar gauche

(function() {
    'use strict';

    // Attendre que le DOM soit chargé
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initSidebarLayout);
    } else {
        initSidebarLayout();
    }

    function initSidebarLayout() {
        const container = document.querySelector('.container');
        const tabsNav = document.querySelector('.tabs');
        const singleColumnLayout = document.querySelector('.single-column-layout');

        if (!container || !tabsNav || !singleColumnLayout) {
            console.warn('Sidebar layout: Required elements not found');
            return;
        }

        // Créer la nouvelle structure
        const appLayout = document.createElement('div');
        appLayout.className = 'app-layout';

        // Créer la sidebar pour les tabs
        const sidebarTabs = document.createElement('div');
        sidebarTabs.className = 'sidebar-tabs';

        // Déplacer les boutons tabs dans la sidebar
        const tabButtons = Array.from(tabsNav.querySelectorAll('.tab'));
        tabButtons.forEach(tab => {
            sidebarTabs.appendChild(tab);
        });

        // Construire la nouvelle structure
        appLayout.appendChild(sidebarTabs);
        appLayout.appendChild(singleColumnLayout);

        // Remplacer l'ancienne structure
        container.insertBefore(appLayout, tabsNav);

        // Supprimer l'ancienne nav tabs (maintenant vide)
        tabsNav.remove();

        console.log('✅ Sidebar layout initialized');
    }
})();
