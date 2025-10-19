/**
 * Installation Backups Module
 * Manages backup/restore operations for all services
 */

import api from '../../utils/api.js';

export class InstallationBackups {
    constructor() {
        this.services = ['supabase', 'pocketbase', 'vaultwarden', 'nginx', 'caddy'];
    }

    /**
     * Get service display name
     */
    getServiceName(service) {
        const names = {
            'supabase': 'Supabase',
            'pocketbase': 'PocketBase',
            'vaultwarden': 'Vaultwarden',
            'nginx': 'Nginx',
            'caddy': 'Caddy',
            'appwrite': 'Appwrite',
            'tailscale': 'Tailscale',
            'pihole': 'Pi-hole',
            'email-smtp': 'Email SMTP'
        };
        return names[service] || service;
    }

    /**
     * Get service icon
     */
    getServiceIcon(service) {
        const icons = {
            'supabase': 'database',
            'pocketbase': 'package',
            'vaultwarden': 'key',
            'nginx': 'server',
            'caddy': 'shield',
            'appwrite': 'cloud',
            'tailscale': 'shield',
            'pihole': 'filter',
            'email-smtp': 'send'
        };
        return icons[service] || 'box';
    }

    /**
     * Show backups list view
     */
    showBackupsList() {
        document.getElementById('category-title').textContent = 'Gestion des backups';
        document.getElementById('services-grid').style.display = 'none';
        document.getElementById('backups-list').style.display = 'block';

        // Hide updates panel
        const updatesPanel = document.getElementById('updates-panel-center');
        if (updatesPanel) updatesPanel.style.display = 'none';

        // Load backups for all services
        this.loadAllBackups();
    }

    /**
     * Load all backups from all services
     */
    async loadAllBackups() {
        const backupsList = document.getElementById('backups-list');
        backupsList.innerHTML = '<div class="loading"><i data-lucide="loader" size="32"></i><p>Chargement des backups...</p></div>';

        const piId = window.currentPiId || null;
        let allBackups = [];

        for (const service of this.services) {
            try {
                const response = await fetch(`/api/setup/list-backups?piId=${piId}&service=${service}`);
                const data = await response.json();

                if (data.success && data.backups.length > 0) {
                    allBackups.push({ service, backups: data.backups });
                }
            } catch (error) {
                console.error(`Error loading backups for ${service}:`, error);
            }
        }

        if (allBackups.length === 0) {
            backupsList.innerHTML = `
                <p class="empty-state">
                    <i data-lucide="archive" size="48"></i>
                    <span>Aucun backup trouvé sur le Pi</span>
                    <small style="opacity: 0.7; margin-top: 8px;">Les backups apparaîtront ici après leur création</small>
                </p>
            `;
            if (window.lucide) window.lucide.createIcons();
            return;
        }

        // Display backups grouped by service
        let html = '<div class="backups-by-service">';

        allBackups.forEach(({ service, backups }) => {
            html += `
                <div class="backup-service-group">
                    <div class="backup-service-header">
                        <h3><i data-lucide="${this.getServiceIcon(service)}" size="18"></i> ${this.getServiceName(service)} (${backups.length})</h3>
                        <button class="btn btn-sm btn-success create-backup-btn" data-service="${service}">
                            <i data-lucide="archive" size="14"></i>
                            <span>Créer backup</span>
                        </button>
                    </div>
                    <div class="backup-items">
            `;

            backups.forEach(backup => {
                html += `
                    <div class="backup-item" data-service="${service}" data-backup="${backup.name}">
                        <div class="backup-info">
                            <div class="backup-name">${backup.name}</div>
                            <div class="backup-meta">
                                <span><i data-lucide="calendar" size="12"></i> ${backup.date}</span>
                                <span><i data-lucide="hard-drive" size="12"></i> ${backup.size}</span>
                                <span><i data-lucide="file" size="12"></i> ${backup.files.length} fichier(s)</span>
                            </div>
                        </div>
                        <button class="btn btn-sm btn-primary restore-backup-btn">
                            <i data-lucide="rotate-ccw" size="14"></i>
                            <span>Restaurer</span>
                        </button>
                    </div>
                `;
            });

            html += `
                    </div>
                </div>
            `;
        });

        html += '</div>';
        backupsList.innerHTML = html;
        if (window.lucide) window.lucide.createIcons();

        // Attach create backup handlers
        document.querySelectorAll('.create-backup-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const service = btn.dataset.service;
                this.generateBackupScript(service, btn);
            });
        });

        // Attach restore handlers
        document.querySelectorAll('.restore-backup-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const backupItem = e.target.closest('.backup-item');
                const service = backupItem.dataset.service;
                const backupName = backupItem.dataset.backup;

                // Find backup object
                const serviceBackups = allBackups.find(sb => sb.service === service);
                if (serviceBackups) {
                    const backup = serviceBackups.backups.find(b => b.name === backupName);
                    if (backup) {
                        this.generateRestoreScript(service, backup);
                    }
                }
            });
        });
    }

    /**
     * Generate backup script for a service
     */
    async generateBackupScript(service, btn) {
        const originalText = btn.innerHTML;
        btn.innerHTML = '<i data-lucide="loader" size="14" class="spin"></i> Génération...';
        btn.disabled = true;

        try {
            const piId = window.currentPiId || null;
            const response = await fetch('/api/setup/generate-backup-script', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ piId, service })
            });

            const data = await response.json();

            if (data.success) {
                if (window.terminalManager) {
                    window.terminalManager.write(`🎯 Création du backup ${this.getServiceName(service)}...`, 'info');
                    window.terminalManager.write(data.command, 'command');
                }

                // Execute backup
                const execResponse = await fetch('/api/setup/create-backup', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ piId, service })
                });

                const execData = await execResponse.json();

                if (execData.success) {
                    if (window.terminalManager) {
                        window.terminalManager.write(`✅ Backup créé avec succès !`, 'success');
                        window.terminalManager.write(`📦 ${execData.backupName}`, 'info');
                    }
                    // Reload backups list
                    this.loadAllBackups();
                } else {
                    throw new Error(execData.error || 'Échec de la création du backup');
                }
            } else {
                throw new Error(data.error || 'Échec de la génération du script');
            }
        } catch (error) {
            console.error('Backup creation error:', error);
            if (window.terminalManager) {
                window.terminalManager.write(`❌ Erreur: ${error.message}`, 'error');
            }
        } finally {
            btn.innerHTML = originalText;
            btn.disabled = false;
            if (window.lucide) window.lucide.createIcons();
        }
    }

    /**
     * Generate restore script for a backup
     */
    async generateRestoreScript(service, backup) {
        if (!confirm(`⚠️ Restaurer le backup "${backup.name}" ?\n\nCela va écraser les données actuelles de ${this.getServiceName(service)}.`)) {
            return;
        }

        try {
            const piId = window.currentPiId || null;

            if (window.terminalManager) {
                window.terminalManager.write(`🔄 Restauration du backup ${backup.name}...`, 'info');
            }

            const response = await fetch('/api/setup/restore-backup', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ piId, service, backupName: backup.name })
            });

            const data = await response.json();

            if (data.success) {
                if (window.terminalManager) {
                    window.terminalManager.write(`✅ Backup restauré avec succès !`, 'success');
                }
            } else {
                throw new Error(data.error || 'Échec de la restauration');
            }
        } catch (error) {
            console.error('Restore error:', error);
            if (window.terminalManager) {
                window.terminalManager.write(`❌ Erreur: ${error.message}`, 'error');
            }
        }
    }
}

// Create singleton
const installationBackups = new InstallationBackups();

// Export
export default installationBackups;
