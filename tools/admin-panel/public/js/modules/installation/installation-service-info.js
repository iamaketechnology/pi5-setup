/**
 * Installation Service Info Module
 * Shows service details and info in terminal
 */

export class InstallationServiceInfo {
    constructor() {
        this.serviceNames = {
            'supabase': 'Supabase',
            'pocketbase': 'PocketBase',
            'vaultwarden': 'Vaultwarden',
            'nginx': 'Nginx',
            'caddy': 'Caddy',
            'pihole': 'Pi-hole',
            'appwrite': 'Appwrite',
            'tailscale': 'Tailscale',
            'email-smtp': 'Email SMTP'
        };
    }

    /**
     * Get service display name
     */
    getServiceName(type) {
        return this.serviceNames[type] || type;
    }

    /**
     * Add message to terminal
     */
    addMessage(text, type = 'info', options = {}) {
        if (window.terminalManager) {
            window.terminalManager.write(text, type);
        }
    }

    /**
     * Show service details in terminal with action buttons
     */
    showServiceDetails(type, installerModule, backupsModule) {
        this.addMessage(
            `📦 ${this.getServiceName(type)}`,
            'user'
        );

        this.addMessage(
            `Pour installer ${this.getServiceName(type)}, clique sur le bouton "Installer" sur la carte du service, ou utilise l'une des options ci-dessous.`,
            'assistant',
            {
                actions: [
                    {
                        text: '▶️ Installer maintenant',
                        action: () => {
                            const card = document.querySelector(`.service-card[data-install="${type}"]`);
                            const installBtn = card?.querySelector('.service-install-btn');
                            if (installBtn && installerModule) {
                                installerModule.handleQuickInstall(type, installBtn);
                            }
                        },
                        primary: true
                    },
                    {
                        text: '🔄 Voir les backups',
                        action: () => {
                            if (backupsModule) {
                                backupsModule.showBackupsList();
                            }
                        },
                        primary: false
                    }
                ]
            }
        );
    }
}

// Create singleton
const installationServiceInfo = new InstallationServiceInfo();

// Export
export default installationServiceInfo;
