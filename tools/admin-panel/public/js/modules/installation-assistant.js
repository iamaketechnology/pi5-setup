// =============================================================================
// Installation Assistant Module
// =============================================================================
// Intelligent assistant that guides users through Pi installation
// =============================================================================

import api from '../utils/api.js';
import terminalManager from './terminal.js';

class InstallationAssistant {
    constructor() {
        this.steps = [
            { id: 'docker', name: 'Docker', emoji: '🐳', required: true },
            { id: 'network', name: 'Réseau', emoji: '📡', required: true },
            { id: 'security', name: 'Sécurité', emoji: '🔒', required: true },
            { id: 'traefik', name: 'Traefik', emoji: '🌐', required: false },
            { id: 'monitoring', name: 'Monitoring', emoji: '📊', required: false }
        ];
        this.currentStatus = {};
        this.messageCount = 0;
    }

    init() {
        console.log('✅ Installation Assistant initialized');
        this.initSidebar();
        this.initQuickActions();
    }

    initSidebar() {
        // Handle category clicks (filter services)
        document.querySelectorAll('.category-item').forEach(categoryBtn => {
            categoryBtn.addEventListener('click', () => {
                const category = categoryBtn.dataset.category;

                // Remove active from all categories
                document.querySelectorAll('.category-item').forEach(item => item.classList.remove('active'));
                categoryBtn.classList.add('active');

                // Filter services
                if (category === 'all') {
                    this.showAllServices();
                } else if (category === 'backups') {
                    this.showBackupsList();
                } else {
                    this.filterServicesByCategory(category);
                }
            });
        });

        // Handle service card clicks
        document.querySelectorAll('.service-card').forEach(card => {
            const installBtn = card.querySelector('.service-install-btn');
            const type = card.dataset.install;

            // Click on button
            installBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                this.handleQuickInstall(type, installBtn);
            });

            // Click on card (except button)
            card.addEventListener('click', (e) => {
                if (!e.target.closest('.service-install-btn')) {
                    // Highlight card and show details in assistant
                    this.showServiceDetails(type);
                }
            });
        });
    }

    showAllServices() {
        document.getElementById('category-title').textContent = 'Tous les services';
        document.getElementById('services-grid').style.display = 'grid';
        document.getElementById('backups-list').style.display = 'none';

        // Show all service cards
        document.querySelectorAll('.service-card').forEach(card => {
            card.classList.remove('hidden');
        });
    }

    filterServicesByCategory(category) {
        const categoryNames = {
            'infrastructure': 'Infrastructure',
            'webserver': 'Serveur Web',
            'security': 'Sécurité',
            'email': 'Email'
        };

        document.getElementById('category-title').textContent = categoryNames[category] || category;
        document.getElementById('services-grid').style.display = 'grid';
        document.getElementById('backups-list').style.display = 'none';

        // Show only services matching category
        document.querySelectorAll('.service-card').forEach(card => {
            if (card.dataset.category === category) {
                card.classList.remove('hidden');
            } else {
                card.classList.add('hidden');
            }
        });
    }

    showBackupsList() {
        document.getElementById('category-title').textContent = 'Gestion des backups';
        document.getElementById('services-grid').style.display = 'none';
        document.getElementById('backups-list').style.display = 'block';

        // Load backups for all services
        this.loadAllBackups();
    }

    async loadAllBackups() {
        const backupsList = document.getElementById('backups-list');
        backupsList.innerHTML = '<div class="loading"><i data-lucide="loader" size="32"></i><p>Chargement des backups...</p></div>';

        const piId = window.currentPiId || null;
        const services = ['supabase', 'pocketbase', 'vaultwarden', 'nginx', 'caddy'];

        let allBackups = [];

        for (const service of services) {
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
            lucide.createIcons();
            return;
        }

        // Display backups grouped by service
        let html = '<div class="backups-by-service">';

        allBackups.forEach(({ service, backups }) => {
            html += `
                <div class="backup-service-group">
                    <h3><i data-lucide="${this.getServiceIcon(service)}" size="18"></i> ${this.getServiceName(service)} (${backups.length})</h3>
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
        lucide.createIcons();

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

    showServiceDetails(type) {
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
                            if (installBtn) {
                                this.handleQuickInstall(type, installBtn);
                            }
                        },
                        primary: true
                    },
                    {
                        text: '🔄 Voir les backups',
                        action: () => this.listBackups(type),
                        primary: false
                    }
                ]
            }
        );
    }

    initQuickActions() {
        // Handle quick installation action buttons (legacy - for old layout)
        document.querySelectorAll('.action-btn[data-install]').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                const installType = btn.dataset.install;
                await this.handleQuickInstall(installType, btn);
            });
        });
    }

    async handleQuickInstall(type, btn) {
        const piId = window.currentPiId || null;

        // Step 1: Check if service already installed
        this.addMessage(
            `🔍 Vérification de l'état du service...`,
            'assistant'
        );

        let serviceInstalled = false;
        let serviceDetails = null;

        try {
            const serviceResponse = await fetch(`/api/setup/check-service?piId=${piId}&service=${type}`);
            const serviceData = await serviceResponse.json();

            if (serviceData.installed) {
                serviceInstalled = true;
                serviceDetails = serviceData.details;

                this.addMessage(
                    `⚠️ ${this.getServiceName(type)} est déjà installé !`,
                    'assistant'
                );

                // Show service details
                let detailsMsg = `📊 État actuel :\n`;
                if (serviceDetails.running) {
                    detailsMsg += `  • Statut : ✅ En cours d'exécution`;
                    if (serviceDetails.uptime) {
                        detailsMsg += ` (${serviceDetails.uptime})`;
                    }
                } else {
                    detailsMsg += `  • Statut : ⏸️ Arrêté`;
                }
                if (serviceDetails.size) {
                    detailsMsg += `\n  • Espace utilisé : ${serviceDetails.size}`;
                }

                this.addMessage(detailsMsg, 'assistant');

                // Ask user what to do
                this.addMessage(
                    `Que souhaitez-vous faire ?`,
                    'assistant',
                    {
                        actions: [
                            {
                                text: '✅ Ignorer (garder l\'existant)',
                                action: () => {
                                    this.addMessage('Installation annulée - Service existant conservé', 'assistant');
                                    btn.classList.remove('loading');
                                    const originalIcon = btn.querySelector('i').getAttribute('data-lucide');
                                    btn.querySelector('i').setAttribute('data-lucide', originalIcon);
                                    lucide.createIcons();
                                },
                                primary: true
                            },
                            {
                                text: '🔄 Restaurer depuis un backup',
                                action: () => this.listBackups(type),
                                primary: false
                            },
                            {
                                text: '💾 Backup puis réinstaller',
                                action: () => this.generateBackupScript(type, btn),
                                primary: false
                            },
                            {
                                text: '🗑️ Nettoyer et réinstaller (sans backup)',
                                action: () => this.proceedWithReinstall(type, btn, true),
                                primary: false
                            },
                            {
                                text: 'ℹ️ Voir les conteneurs Docker',
                                action: () => window.tabsManager?.switchTab('docker'),
                                primary: false
                            }
                        ]
                    }
                );

                // Stop here and wait for user choice
                btn.classList.remove('loading');
                const originalIcon = btn.querySelector('i').getAttribute('data-lucide');
                btn.querySelector('i').setAttribute('data-lucide', originalIcon);
                lucide.createIcons();
                return;
            }
        } catch (error) {
            console.error('Failed to check service:', error);
        }

        // Step 2: Check prerequisites
        this.addMessage(
            `🔍 Vérification des prérequis...`,
            'assistant'
        );

        let needsBaseSetup = true;
        try {
            const response = await fetch(`/api/setup/check-prerequisites?piId=${piId}`);
            const data = await response.json();

            if (data.status === 'COMPLETE') {
                needsBaseSetup = false;
                this.addMessage(
                    `✅ Prérequis déjà installés ! (Docker, UFW, Fail2ban, Page size 4KB)`,
                    'assistant'
                );
                this.addMessage(
                    `📊 Détails : ${data.passed}/${data.total} vérifications réussies`,
                    'assistant'
                );
            } else {
                this.addMessage(
                    `⚠️ Prérequis manquants (${data.passed || 0}/${data.total || 6} vérifications)`,
                    'assistant'
                );
            }
        } catch (error) {
            console.error('Failed to check prerequisites:', error);
            this.addMessage(
                `⚠️ Impossible de vérifier les prérequis - Installation complète recommandée`,
                'assistant'
            );
        }

        // Proceed with installation
        this.proceedWithInstall(type, btn, needsBaseSetup);
    }

    getServiceName(type) {
        const names = {
            'supabase': 'Supabase',
            'pocketbase': 'PocketBase',
            'vaultwarden': 'Vaultwarden',
            'nginx': 'Nginx',
            'pihole': 'Pi-hole'
        };
        return names[type] || type;
    }

    async proceedWithReinstall(type, btn, cleanFirst) {
        this.addMessage(
            `🗑️ Préparation de la réinstallation...`,
            'assistant'
        );

        if (cleanFirst) {
            this.addMessage(
                `⚠️ Avant de réinstaller, vous devez nettoyer l'installation existante.`,
                'assistant'
            );
            this.addMessage(
                `Étapes recommandées :`,
                'assistant',
                {
                    description: '1. Sauvegarder vos données si nécessaire\n2. Arrêter et supprimer les conteneurs\n3. Supprimer les volumes (optionnel)\n4. Relancer l\'installation',
                    actions: [{
                        text: '🗑️ Générer script de nettoyage',
                        action: () => this.generateCleanupScript(type),
                        primary: true
                    }]
                }
            );
        }
    }

    generateCleanupScript(type) {
        const cleanupScripts = {
            'supabase': `# Nettoyage Supabase
docker compose -f ~/stacks/supabase/docker-compose.yml down --volumes
rm -rf ~/stacks/supabase
# Relancez ensuite le script d'installation`,
            'pocketbase': `# Nettoyage PocketBase
systemctl stop pocketbase
systemctl disable pocketbase
rm -rf ~/apps/pocketbase
rm /etc/systemd/system/pocketbase.service
systemctl daemon-reload`,
            'vaultwarden': `# Nettoyage Vaultwarden
docker compose -f ~/stacks/vaultwarden/docker-compose.yml down --volumes
rm -rf ~/stacks/vaultwarden`
        };

        const script = cleanupScripts[type] || `# Pas de script de nettoyage disponible pour ${type}`;

        this.addMessage(
            `📋 Script de nettoyage pour ${this.getServiceName(type)} :`,
            'assistant'
        );
        this.addMessage(
            `\`\`\`bash\n${script}\n\`\`\``,
            'assistant',
            {
                description: '⚠️ Attention : Cette opération supprimera toutes les données du service !',
                actions: [{
                    text: '💾 Copier dans le terminal',
                    action: () => {
                        if (window.terminalManager) {
                            window.terminalManager.pasteCommand(script);
                        }
                    },
                    primary: true
                }]
            }
        );
    }

    generateBackupScript(type, btn) {
        const timestamp = '$(date +%Y%m%d_%H%M%S)';

        const backupScripts = {
            'supabase': `#!/bin/bash
# =============================================================================
# Backup Supabase - Sauvegarde complète avant réinstallation
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-20
# =============================================================================

set -euo pipefail

BACKUP_DIR=~/backups/supabase_${timestamp}
mkdir -p $BACKUP_DIR

echo "📦 Démarrage backup Supabase..."
echo "📁 Destination: $BACKUP_DIR"

# 1. Backup PostgreSQL database
echo ""
echo "1️⃣ Backup de la base de données PostgreSQL..."
docker exec supabase-db pg_dumpall -U postgres > $BACKUP_DIR/database.sql
if [ -f "$BACKUP_DIR/database.sql" ]; then
    echo "   ✅ Database SQL dump créé ($(du -sh $BACKUP_DIR/database.sql | cut -f1))"
else
    echo "   ❌ Échec backup database"
    exit 1
fi

# 2. Backup volumes Docker
echo ""
echo "2️⃣ Backup des volumes Docker..."

# DB data volume
docker run --rm \\
    -v supabase_db_data:/data \\
    -v $BACKUP_DIR:/backup \\
    alpine tar czf /backup/db_data.tar.gz /data
echo "   ✅ db_data.tar.gz créé ($(du -sh $BACKUP_DIR/db_data.tar.gz | cut -f1))"

# Storage volume (if exists)
if docker volume inspect supabase_storage_data &>/dev/null; then
    docker run --rm \\
        -v supabase_storage_data:/data \\
        -v $BACKUP_DIR:/backup \\
        alpine tar czf /backup/storage_data.tar.gz /data
    echo "   ✅ storage_data.tar.gz créé ($(du -sh $BACKUP_DIR/storage_data.tar.gz | cut -f1))"
fi

# 3. Backup configuration files
echo ""
echo "3️⃣ Backup des fichiers de configuration..."
if [ -d ~/stacks/supabase ]; then
    cp -r ~/stacks/supabase $BACKUP_DIR/config
    echo "   ✅ Configuration copiée"
fi

# 4. Backup .env file (si existant)
if [ -f ~/stacks/supabase/.env ]; then
    cp ~/stacks/supabase/.env $BACKUP_DIR/.env.backup
    echo "   ✅ Fichier .env sauvegardé"
fi

# 5. Résumé
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ BACKUP SUPABASE TERMINÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Emplacement : $BACKUP_DIR"
echo ""
echo "Contenu du backup :"
ls -lh $BACKUP_DIR
echo ""
echo "Espace utilisé :"
du -sh $BACKUP_DIR
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Prochaines étapes :"
echo "   1. Vérifiez le contenu du backup ci-dessus"
echo "   2. Lancez le nettoyage : docker compose down --volumes"
echo "   3. Réinstallez Supabase"
echo "   4. Restaurez si besoin avec les fichiers .tar.gz"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"`,

            'pocketbase': `#!/bin/bash
# =============================================================================
# Backup PocketBase - Sauvegarde complète avant réinstallation
# =============================================================================

set -euo pipefail

BACKUP_DIR=~/backups/pocketbase_${timestamp}
mkdir -p $BACKUP_DIR

echo "📦 Démarrage backup PocketBase..."
echo "📁 Destination: $BACKUP_DIR"

# 1. Stop service
echo ""
echo "1️⃣ Arrêt du service PocketBase..."
systemctl stop pocketbase
echo "   ✅ Service arrêté"

# 2. Backup database
echo ""
echo "2️⃣ Backup de la base de données..."
if [ -f ~/apps/pocketbase/pb_data/data.db ]; then
    cp ~/apps/pocketbase/pb_data/data.db $BACKUP_DIR/data.db
    echo "   ✅ data.db sauvegardé ($(du -sh $BACKUP_DIR/data.db | cut -f1))"
fi

# 3. Backup storage
echo ""
echo "3️⃣ Backup du storage (fichiers uploadés)..."
if [ -d ~/apps/pocketbase/pb_data/storage ]; then
    tar czf $BACKUP_DIR/storage.tar.gz -C ~/apps/pocketbase/pb_data storage
    echo "   ✅ storage.tar.gz créé ($(du -sh $BACKUP_DIR/storage.tar.gz | cut -f1))"
fi

# 4. Backup logs
echo ""
echo "4️⃣ Backup des logs..."
if [ -d ~/apps/pocketbase/pb_data/logs ]; then
    tar czf $BACKUP_DIR/logs.tar.gz -C ~/apps/pocketbase/pb_data logs
    echo "   ✅ logs.tar.gz créé"
fi

# 5. Backup configuration
echo ""
echo "5️⃣ Backup de la configuration..."
if [ -d ~/apps/pocketbase ]; then
    cp -r ~/apps/pocketbase $BACKUP_DIR/config
    echo "   ✅ Configuration copiée"
fi

# 6. Restart service
echo ""
echo "6️⃣ Redémarrage du service..."
systemctl start pocketbase
echo "   ✅ Service redémarré"

# Résumé
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ BACKUP POCKETBASE TERMINÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Emplacement : $BACKUP_DIR"
echo ""
ls -lh $BACKUP_DIR
echo ""
du -sh $BACKUP_DIR
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"`,

            'vaultwarden': `#!/bin/bash
# =============================================================================
# Backup Vaultwarden - Sauvegarde complète avant réinstallation
# =============================================================================

set -euo pipefail

BACKUP_DIR=~/backups/vaultwarden_${timestamp}
mkdir -p $BACKUP_DIR

echo "📦 Démarrage backup Vaultwarden..."
echo "📁 Destination: $BACKUP_DIR"

# 1. Backup SQLite database
echo ""
echo "1️⃣ Backup de la base de données SQLite..."
docker exec vaultwarden sqlite3 /data/db.sqlite3 ".backup '/data/backup.sqlite3'"
docker cp vaultwarden:/data/backup.sqlite3 $BACKUP_DIR/db.sqlite3
echo "   ✅ db.sqlite3 sauvegardé ($(du -sh $BACKUP_DIR/db.sqlite3 | cut -f1))"

# 2. Backup attachments
echo ""
echo "2️⃣ Backup des pièces jointes..."
docker run --rm \\
    -v vaultwarden_data:/data \\
    -v $BACKUP_DIR:/backup \\
    alpine tar czf /backup/attachments.tar.gz /data/attachments 2>/dev/null || echo "   ⚠️ Pas de pièces jointes"

# 3. Backup configuration
echo ""
echo "3️⃣ Backup de la configuration..."
if [ -d ~/stacks/vaultwarden ]; then
    cp -r ~/stacks/vaultwarden $BACKUP_DIR/config
    echo "   ✅ Configuration copiée"
fi

# 4. Backup .env
if [ -f ~/stacks/vaultwarden/.env ]; then
    cp ~/stacks/vaultwarden/.env $BACKUP_DIR/.env.backup
    echo "   ✅ .env sauvegardé"
fi

# 5. Backup entire data volume
echo ""
echo "4️⃣ Backup du volume complet..."
docker run --rm \\
    -v vaultwarden_data:/data \\
    -v $BACKUP_DIR:/backup \\
    alpine tar czf /backup/vaultwarden_data_full.tar.gz /data
echo "   ✅ vaultwarden_data_full.tar.gz créé ($(du -sh $BACKUP_DIR/vaultwarden_data_full.tar.gz | cut -f1))"

# Résumé
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ BACKUP VAULTWARDEN TERMINÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Emplacement : $BACKUP_DIR"
echo ""
ls -lh $BACKUP_DIR
echo ""
du -sh $BACKUP_DIR
echo ""
echo "⚠️ IMPORTANT : Conservez ce backup dans un endroit sûr !"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"`,

            'nginx': `#!/bin/bash
# =============================================================================
# Backup Nginx - Sauvegarde complète avant réinstallation
# =============================================================================

set -euo pipefail

BACKUP_DIR=~/backups/nginx_${timestamp}
mkdir -p $BACKUP_DIR

echo "📦 Démarrage backup Nginx..."

# 1. Backup configuration
echo ""
echo "1️⃣ Backup de la configuration Nginx..."
if [ -d ~/stacks/nginx ]; then
    cp -r ~/stacks/nginx $BACKUP_DIR/config
    echo "   ✅ Configuration copiée"
fi

# 2. Backup SSL certificates
echo ""
echo "2️⃣ Backup des certificats SSL..."
docker run --rm \\
    -v nginx_certs:/certs \\
    -v $BACKUP_DIR:/backup \\
    alpine tar czf /backup/ssl_certs.tar.gz /certs 2>/dev/null || echo "   ⚠️ Pas de certificats"

# 3. Backup static content (if any)
if docker volume inspect nginx_html &>/dev/null; then
    echo ""
    echo "3️⃣ Backup du contenu statique..."
    docker run --rm \\
        -v nginx_html:/html \\
        -v $BACKUP_DIR:/backup \\
        alpine tar czf /backup/html.tar.gz /html
    echo "   ✅ html.tar.gz créé"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ BACKUP NGINX TERMINÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Emplacement : $BACKUP_DIR"
ls -lh $BACKUP_DIR
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"`
        };

        const script = backupScripts[type];

        if (!script) {
            this.addMessage(
                `❌ Pas de script de backup disponible pour ${this.getServiceName(type)}`,
                'assistant'
            );
            return;
        }

        this.addMessage(
            `📋 Script de backup pour ${this.getServiceName(type)} :`,
            'assistant'
        );

        this.addMessage(
            `\`\`\`bash\n${script}\n\`\`\``,
            'assistant',
            {
                description: '💾 Ce script va créer une sauvegarde complète dans ~/backups/',
                actions: [
                    {
                        text: '▶️ Exécuter le backup',
                        action: () => {
                            if (window.terminalManager) {
                                window.terminalManager.pasteCommand(script);
                            }
                        },
                        primary: true
                    },
                    {
                        text: '📋 Copier le script',
                        action: () => {
                            navigator.clipboard.writeText(script).then(() => {
                                this.addMessage('✅ Script copié dans le presse-papier', 'assistant');
                            });
                        },
                        primary: false
                    },
                    {
                        text: '🔄 Backup terminé, continuer la réinstallation',
                        action: () => {
                            this.proceedWithReinstall(type, btn, true);
                        },
                        primary: false
                    }
                ]
            }
        );
    }

    async listBackups(type) {
        const piId = window.currentPiId || null;

        this.addMessage(
            `🔍 Recherche des backups pour ${this.getServiceName(type)}...`,
            'assistant'
        );

        try {
            const response = await fetch(`/api/setup/list-backups?piId=${piId}&service=${type}`);
            const data = await response.json();

            if (!data.success) {
                this.addMessage(`❌ Erreur: ${data.error}`, 'assistant');
                return;
            }

            if (data.backups.length === 0) {
                this.addMessage(
                    `📁 Aucun backup trouvé pour ${this.getServiceName(type)} dans ~/backups/`,
                    'assistant'
                );
                this.addMessage(
                    `💡 Créez un backup avant de réinstaller pour sauvegarder vos données.`,
                    'assistant'
                );
                return;
            }

            // Display backups list
            this.addMessage(
                `📦 ${data.backups.length} backup(s) trouvé(s) pour ${this.getServiceName(type)} :`,
                'assistant'
            );

            let backupsList = '\n';
            data.backups.forEach((backup, index) => {
                backupsList += `${index + 1}. 📁 ${backup.name}\n`;
                backupsList += `   📅 Date: ${backup.date}\n`;
                backupsList += `   💾 Taille: ${backup.size}\n`;
                backupsList += `   📂 Contenu: ${backup.files.join(', ')}\n\n`;
            });

            this.addMessage(
                `\`\`\`${backupsList}\`\`\``,
                'assistant'
            );

            // Add restore options
            this.addMessage(
                `Que souhaitez-vous faire ?`,
                'assistant',
                {
                    actions: data.backups.map((backup, index) => ({
                        text: `🔄 Restaurer "${backup.name}"`,
                        action: () => this.generateRestoreScript(type, backup),
                        primary: index === 0 // Most recent is primary
                    })).concat([
                        {
                            text: '❌ Annuler',
                            action: () => {
                                this.addMessage('✅ Opération annulée', 'assistant');
                            },
                            primary: false
                        }
                    ])
                }
            );

        } catch (error) {
            this.addMessage(`❌ Erreur lors de la récupération des backups: ${error.message}`, 'assistant');
        }
    }

    generateRestoreScript(type, backup) {
        const backupPath = backup.path;

        const restoreScripts = {
            'supabase': `#!/bin/bash
# =============================================================================
# Restore Supabase - Restauration depuis backup
# =============================================================================
# Backup: ${backup.name}
# Date: ${backup.date}
# =============================================================================

set -euo pipefail

BACKUP_DIR="${backupPath}"

echo "🔄 Restauration de Supabase depuis backup..."
echo "📁 Source: $BACKUP_DIR"
echo ""

# 1. Vérifier que le backup existe
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Erreur: Backup introuvable à $BACKUP_DIR"
    exit 1
fi

# 2. Arrêter Supabase
echo "1️⃣ Arrêt de Supabase..."
cd ~/stacks/supabase
docker compose down
echo "   ✅ Supabase arrêté"

# 3. Restaurer les volumes Docker
echo ""
echo "2️⃣ Restauration des volumes Docker..."

# Restaurer db_data
if [ -f "$BACKUP_DIR/db_data.tar.gz" ]; then
    docker volume rm supabase_db_data 2>/dev/null || true
    docker volume create supabase_db_data
    docker run --rm \\
        -v supabase_db_data:/data \\
        -v $BACKUP_DIR:/backup \\
        alpine sh -c "cd / && tar xzf /backup/db_data.tar.gz"
    echo "   ✅ db_data restauré"
else
    echo "   ⚠️ db_data.tar.gz introuvable"
fi

# Restaurer storage_data
if [ -f "$BACKUP_DIR/storage_data.tar.gz" ]; then
    docker volume rm supabase_storage_data 2>/dev/null || true
    docker volume create supabase_storage_data
    docker run --rm \\
        -v supabase_storage_data:/data \\
        -v $BACKUP_DIR:/backup \\
        alpine sh -c "cd / && tar xzf /backup/storage_data.tar.gz"
    echo "   ✅ storage_data restauré"
fi

# 4. Restaurer la configuration
echo ""
echo "3️⃣ Restauration de la configuration..."
if [ -d "$BACKUP_DIR/config" ]; then
    cp -r $BACKUP_DIR/config/* ~/stacks/supabase/
    echo "   ✅ Configuration restaurée"
fi

# 5. Restaurer .env
if [ -f "$BACKUP_DIR/.env.backup" ]; then
    cp $BACKUP_DIR/.env.backup ~/stacks/supabase/.env
    echo "   ✅ .env restauré"
fi

# 6. Redémarrer Supabase
echo ""
echo "4️⃣ Redémarrage de Supabase..."
cd ~/stacks/supabase
docker compose up -d
echo "   ✅ Supabase redémarré"

# 7. Restaurer la base de données (si dump SQL disponible)
echo ""
echo "5️⃣ Restauration de la base de données..."
if [ -f "$BACKUP_DIR/database.sql" ]; then
    echo "   ⏳ Attente démarrage PostgreSQL (30s)..."
    sleep 30

    docker exec -i supabase-db psql -U postgres < $BACKUP_DIR/database.sql
    echo "   ✅ Base de données restaurée"
else
    echo "   ⚠️ database.sql introuvable"
fi

# Résumé
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ RESTAURATION SUPABASE TERMINÉE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Vérifiez l'état des services :"
echo "   docker ps | grep supabase"
echo ""
echo "🌐 Accès :"
echo "   http://localhost:8001 (Kong API)"
echo "   http://localhost:54321 (Edge Functions)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"`,

            'pocketbase': `#!/bin/bash
# =============================================================================
# Restore PocketBase - Restauration depuis backup
# =============================================================================
# Backup: ${backup.name}
# Date: ${backup.date}
# =============================================================================

set -euo pipefail

BACKUP_DIR="${backupPath}"

echo "🔄 Restauration de PocketBase depuis backup..."
echo "📁 Source: $BACKUP_DIR"
echo ""

# 1. Vérifier backup
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Backup introuvable: $BACKUP_DIR"
    exit 1
fi

# 2. Arrêter PocketBase
echo "1️⃣ Arrêt de PocketBase..."
systemctl stop pocketbase
echo "   ✅ Service arrêté"

# 3. Restaurer database
echo ""
echo "2️⃣ Restauration de la base de données..."
if [ -f "$BACKUP_DIR/data.db" ]; then
    cp $BACKUP_DIR/data.db ~/apps/pocketbase/pb_data/data.db
    echo "   ✅ data.db restauré ($(du -sh ~/apps/pocketbase/pb_data/data.db | cut -f1))"
else
    echo "   ❌ data.db introuvable dans le backup"
    exit 1
fi

# 4. Restaurer storage
echo ""
echo "3️⃣ Restauration du storage..."
if [ -f "$BACKUP_DIR/storage.tar.gz" ]; then
    rm -rf ~/apps/pocketbase/pb_data/storage
    tar xzf $BACKUP_DIR/storage.tar.gz -C ~/apps/pocketbase/pb_data
    echo "   ✅ Storage restauré"
fi

# 5. Restaurer logs
if [ -f "$BACKUP_DIR/logs.tar.gz" ]; then
    tar xzf $BACKUP_DIR/logs.tar.gz -C ~/apps/pocketbase/pb_data
    echo "   ✅ Logs restaurés"
fi

# 6. Restaurer configuration
echo ""
echo "4️⃣ Restauration de la configuration..."
if [ -d "$BACKUP_DIR/config" ]; then
    cp -r $BACKUP_DIR/config/* ~/apps/pocketbase/ 2>/dev/null || true
    echo "   ✅ Configuration restaurée"
fi

# 7. Redémarrer
echo ""
echo "5️⃣ Redémarrage de PocketBase..."
systemctl start pocketbase
sleep 3

if systemctl is-active --quiet pocketbase; then
    echo "   ✅ PocketBase redémarré avec succès"
else
    echo "   ❌ Échec redémarrage - Vérifiez les logs: journalctl -u pocketbase -n 50"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ RESTAURATION POCKETBASE TERMINÉE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Admin UI: http://localhost:8090/_/"
echo "📊 Status: systemctl status pocketbase"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"`,

            'vaultwarden': `#!/bin/bash
# =============================================================================
# Restore Vaultwarden - Restauration depuis backup
# =============================================================================
# Backup: ${backup.name}
# Date: ${backup.date}
# =============================================================================

set -euo pipefail

BACKUP_DIR="${backupPath}"

echo "🔄 Restauration de Vaultwarden depuis backup..."
echo "📁 Source: $BACKUP_DIR"
echo ""

# 1. Vérifier backup
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Backup introuvable: $BACKUP_DIR"
    exit 1
fi

# 2. Arrêter Vaultwarden
echo "1️⃣ Arrêt de Vaultwarden..."
cd ~/stacks/vaultwarden
docker compose down
echo "   ✅ Vaultwarden arrêté"

# 3. Restaurer le volume complet
echo ""
echo "2️⃣ Restauration du volume de données..."
if [ -f "$BACKUP_DIR/vaultwarden_data_full.tar.gz" ]; then
    docker volume rm vaultwarden_data 2>/dev/null || true
    docker volume create vaultwarden_data
    docker run --rm \\
        -v vaultwarden_data:/data \\
        -v $BACKUP_DIR:/backup \\
        alpine sh -c "cd / && tar xzf /backup/vaultwarden_data_full.tar.gz"
    echo "   ✅ Volume complet restauré"
fi

# 4. Restaurer configuration
echo ""
echo "3️⃣ Restauration de la configuration..."
if [ -d "$BACKUP_DIR/config" ]; then
    cp -r $BACKUP_DIR/config/* ~/stacks/vaultwarden/
    echo "   ✅ Configuration restaurée"
fi

# 5. Restaurer .env
if [ -f "$BACKUP_DIR/.env.backup" ]; then
    cp $BACKUP_DIR/.env.backup ~/stacks/vaultwarden/.env
    echo "   ✅ .env restauré"
fi

# 6. Redémarrer
echo ""
echo "4️⃣ Redémarrage de Vaultwarden..."
cd ~/stacks/vaultwarden
docker compose up -d
echo "   ✅ Vaultwarden redémarré"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ RESTAURATION VAULTWARDEN TERMINÉE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️ IMPORTANT: Testez la connexion avec vos identifiants"
echo "🌐 URL: http://localhost:8080"
echo "📊 Logs: docker logs vaultwarden --tail 50"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"`,

            'nginx': `#!/bin/bash
# =============================================================================
# Restore Nginx - Restauration depuis backup
# =============================================================================
# Backup: ${backup.name}
# Date: ${backup.date}
# =============================================================================

set -euo pipefail

BACKUP_DIR="${backupPath}"

echo "🔄 Restauration de Nginx depuis backup..."
echo "📁 Source: $BACKUP_DIR"
echo ""

# 1. Vérifier backup
if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Backup introuvable: $BACKUP_DIR"
    exit 1
fi

# 2. Arrêter Nginx
echo "1️⃣ Arrêt de Nginx..."
cd ~/stacks/nginx
docker compose down
echo "   ✅ Nginx arrêté"

# 3. Restaurer certificats SSL
echo ""
echo "2️⃣ Restauration des certificats SSL..."
if [ -f "$BACKUP_DIR/ssl_certs.tar.gz" ]; then
    docker volume rm nginx_certs 2>/dev/null || true
    docker volume create nginx_certs
    docker run --rm \\
        -v nginx_certs:/certs \\
        -v $BACKUP_DIR:/backup \\
        alpine sh -c "cd / && tar xzf /backup/ssl_certs.tar.gz"
    echo "   ✅ Certificats SSL restaurés"
fi

# 4. Restaurer contenu statique
if [ -f "$BACKUP_DIR/html.tar.gz" ]; then
    echo ""
    echo "3️⃣ Restauration du contenu statique..."
    docker volume rm nginx_html 2>/dev/null || true
    docker volume create nginx_html
    docker run --rm \\
        -v nginx_html:/html \\
        -v $BACKUP_DIR:/backup \\
        alpine sh -c "cd / && tar xzf /backup/html.tar.gz"
    echo "   ✅ Contenu HTML restauré"
fi

# 5. Restaurer configuration
echo ""
echo "4️⃣ Restauration de la configuration..."
if [ -d "$BACKUP_DIR/config" ]; then
    cp -r $BACKUP_DIR/config/* ~/stacks/nginx/
    echo "   ✅ Configuration restaurée"
fi

# 6. Redémarrer
echo ""
echo "5️⃣ Redémarrage de Nginx..."
cd ~/stacks/nginx
docker compose up -d
echo "   ✅ Nginx redémarré"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ RESTAURATION NGINX TERMINÉE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Testez vos sites web"
echo "📊 Logs: docker logs nginx --tail 50"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"`
        };

        const script = restoreScripts[type];

        if (!script) {
            this.addMessage(
                `❌ Pas de script de restauration disponible pour ${this.getServiceName(type)}`,
                'assistant'
            );
            return;
        }

        this.addMessage(
            `📋 Script de restauration pour ${this.getServiceName(type)} :`,
            'assistant'
        );

        this.addMessage(
            `\`\`\`bash\n${script}\n\`\`\``,
            'assistant',
            {
                description: `🔄 Ce script va restaurer ${this.getServiceName(type)} depuis le backup "${backup.name}"`,
                actions: [
                    {
                        text: '▶️ Exécuter la restauration',
                        action: () => {
                            if (window.terminalManager) {
                                window.terminalManager.pasteCommand(script);
                            }
                        },
                        primary: true
                    },
                    {
                        text: '📋 Copier le script',
                        action: () => {
                            navigator.clipboard.writeText(script).then(() => {
                                this.addMessage('✅ Script copié dans le presse-papier', 'assistant');
                            });
                        },
                        primary: false
                    },
                    {
                        text: '🔍 Voir d\'autres backups',
                        action: () => this.listBackups(type),
                        primary: false
                    }
                ]
            }
        );
    }

    proceedWithInstall(type, btn, needsBaseSetup) {

        const installConfigs = {
            'supabase': {
                name: 'Supabase',
                emoji: '🗄️',
                baseSetupRequired: true,
                steps: [
                    {
                        name: 'Pi5 Base Setup (Prerequisites)',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/01-pi5-base-setup.sh | sudo bash',
                        description: 'Installation Docker, UFW, Fail2ban, optimisations Pi 5 (requis pour tous les services)',
                        required: needsBaseSetup,
                        skipMessage: '✅ Prérequis déjà installés - Étape ignorée'
                    },
                    {
                        name: 'Supabase Deployment',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash',
                        description: 'Déploiement PostgreSQL, Auth, Storage, Edge Functions (ouvre automatiquement les ports 8001, 54321)',
                        required: true
                    }
                ]
            },
            'pocketbase': {
                name: 'PocketBase',
                emoji: '📦',
                baseSetupRequired: true,
                steps: [
                    {
                        name: 'Pi5 Base Setup (Prerequisites)',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/01-pi5-base-setup.sh | sudo bash',
                        description: 'Installation Docker, UFW, Fail2ban (requis)',
                        required: needsBaseSetup,
                        skipMessage: '✅ Prérequis déjà installés'
                    },
                    {
                        name: 'PocketBase Deployment',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/pocketbase/scripts/01-pocketbase-deploy.sh | sudo bash',
                        description: 'Backend-as-a-Service léger avec base de données intégrée',
                        required: true
                    }
                ]
            },
            'appwrite': {
                name: 'Appwrite',
                emoji: '☁️',
                baseSetupRequired: true,
                steps: [
                    {
                        name: 'Pi5 Base Setup (Prerequisites)',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/01-pi5-base-setup.sh | sudo bash',
                        description: 'Installation Docker (requis)',
                        required: needsBaseSetup,
                        skipMessage: '✅ Prérequis déjà installés'
                    },
                    {
                        name: 'Appwrite Deployment',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/appwrite/scripts/01-appwrite-deploy.sh | sudo bash',
                        description: 'Backend complet avec APIs, Auth, Database, Storage',
                        required: true
                    }
                ]
            },
            'nginx': {
                name: 'Nginx',
                emoji: '🌐',
                baseSetupRequired: true,
                steps: [
                    {
                        name: 'Pi5 Base Setup (Prerequisites)',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/01-pi5-base-setup.sh | sudo bash',
                        description: 'Installation Docker (requis)',
                        required: needsBaseSetup,
                        skipMessage: '✅ Prérequis déjà installés'
                    },
                    {
                        name: 'Nginx Deployment',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/webserver/scripts/01-nginx-deploy.sh | sudo bash',
                        description: 'Reverse proxy haute performance',
                        required: true
                    }
                ]
            },
            'caddy': {
                name: 'Caddy',
                emoji: '🔒',
                baseSetupRequired: true,
                steps: [
                    {
                        name: 'Pi5 Base Setup (Prerequisites)',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/01-pi5-base-setup.sh | sudo bash',
                        description: 'Installation Docker (requis)',
                        required: needsBaseSetup,
                        skipMessage: '✅ Prérequis déjà installés'
                    },
                    {
                        name: 'Caddy Deployment',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/webserver/scripts/01-caddy-deploy.sh | sudo bash',
                        description: 'Serveur web avec HTTPS automatique',
                        required: true
                    }
                ]
            },
            'vaultwarden': {
                name: 'Vaultwarden',
                emoji: '🔑',
                baseSetupRequired: true,
                steps: [
                    {
                        name: 'Pi5 Base Setup (Prerequisites)',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/01-pi5-base-setup.sh | sudo bash',
                        description: 'Installation Docker (requis)',
                        required: needsBaseSetup,
                        skipMessage: '✅ Prérequis déjà installés'
                    },
                    {
                        name: 'Vaultwarden Deployment',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vaultwarden/scripts/01-vaultwarden-deploy.sh | sudo bash',
                        description: 'Gestionnaire de mots de passe auto-hébergé',
                        required: true
                    }
                ]
            },
            'tailscale': {
                name: 'Tailscale',
                emoji: '🛡️',
                baseSetupRequired: false, // Tailscale ne nécessite pas Docker
                steps: [{
                    name: 'Tailscale Setup',
                    command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vpn-wireguard/scripts/01-tailscale-setup.sh | sudo bash',
                    description: 'VPN zero-config mesh network',
                    required: true
                }]
            },
            'pihole': {
                name: 'Pi-hole',
                emoji: '🛡️',
                baseSetupRequired: true,
                steps: [
                    {
                        name: 'Pi5 Base Setup (Prerequisites)',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/01-pi5-base-setup.sh | sudo bash',
                        description: 'Installation Docker (requis)',
                        required: needsBaseSetup,
                        skipMessage: '✅ Prérequis déjà installés'
                    },
                    {
                        name: 'Pi-hole Deployment',
                        command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/pihole/scripts/01-pihole-deploy.sh | sudo bash',
                        description: 'Bloqueur de publicités au niveau réseau',
                        required: true
                    }
                ]
            },
            'email-smtp': {
                name: 'SMTP Email',
                emoji: '📧',
                baseSetupRequired: false, // SMTP setup ne nécessite pas Docker
                steps: [{
                    name: 'Email Provider Setup',
                    command: 'curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/01-email-provider-setup.sh | sudo bash',
                    description: 'Configuration SMTP (Resend, SendGrid, SMTP externe)',
                    required: true
                }]
            }
        };

        const config = installConfigs[type];
        if (!config) {
            console.error('Unknown installation type:', type);
            return;
        }

        // Update button state
        btn.classList.add('loading');
        const originalIcon = btn.querySelector('i').getAttribute('data-lucide');
        btn.querySelector('i').setAttribute('data-lucide', 'loader');
        lucide.createIcons();

        // Filter required steps
        const requiredSteps = config.steps.filter(step => step.required !== false);
        const skippedSteps = config.steps.filter(step => step.required === false);

        // Add welcome message
        this.addMessage(
            `Installation de ${config.emoji} ${config.name}`,
            'user'
        );

        if (skippedSteps.length > 0) {
            this.addMessage(
                `✅ ${skippedSteps.length} étape${skippedSteps.length > 1 ? 's' : ''} ignorée${skippedSteps.length > 1 ? 's' : ''} (déjà installée${skippedSteps.length > 1 ? 's' : ''})`,
                'assistant'
            );
            skippedSteps.forEach(step => {
                this.addMessage(
                    `⏭️ ${step.name} : ${step.skipMessage || 'Déjà installé'}`,
                    'assistant'
                );
            });
        }

        if (requiredSteps.length === 0) {
            this.addMessage(
                `✅ ${config.name} semble déjà complètement installé ! Vérifiez l'onglet Docker ou Services.`,
                'assistant'
            );
            btn.classList.remove('loading');
            btn.querySelector('i').setAttribute('data-lucide', originalIcon);
            lucide.createIcons();
            return;
        }

        this.addMessage(
            `Parfait ! Je vais installer ${config.name} en ${requiredSteps.length} étape${requiredSteps.length > 1 ? 's' : ''}.`,
            'assistant'
        );

        // Execute required steps only
        for (let i = 0; i < requiredSteps.length; i++) {
            const step = requiredSteps[i];

            this.addMessage(
                `📌 Étape ${i + 1}/${requiredSteps.length} : ${step.name}`,
                'assistant',
                {
                    description: step.description,
                    actions: [{
                        text: '▶️ Lancer',
                        command: step.command,
                        primary: true
                    }]
                }
            );
        }

        // Add final message
        this.addMessage(
            `💡 Clique sur les boutons "▶️ Lancer" ci-dessus pour exécuter chaque étape. Le terminal s'ouvrira automatiquement pour suivre l'installation.`,
            'assistant'
        );

        // Reset button state
        btn.classList.remove('loading');
        btn.querySelector('i').setAttribute('data-lucide', originalIcon);
        lucide.createIcons();
    }

    async load() {
        try {
            // Get setup status
            const data = await api.get('/setup-status');
            this.currentStatus = data.status || {};

            // Render progress
            this.renderProgress();

            // Analyze and suggest next step
            this.analyzeSituation();
        } catch (error) {
            console.error('Failed to load installation status:', error);
            this.addMessage('❌ Impossible de vérifier l\'état du Pi. Vérifie ta connexion SSH.', 'error');
        }
    }

    renderProgress() {
        const stepsContainer = document.getElementById('install-progress-steps');
        if (!stepsContainer) return;

        const completedSteps = this.steps.filter(step => this.isStepCompleted(step.id));
        const progress = Math.round((completedSteps.length / this.steps.length) * 100);

        // Update progress bar
        const progressFill = document.getElementById('install-progress-fill');
        const progressPercent = document.getElementById('install-progress-percent');
        if (progressFill) progressFill.style.width = `${progress}%`;
        if (progressPercent) progressPercent.textContent = `${progress}%`;

        // Render steps
        stepsContainer.innerHTML = this.steps.map(step => {
            const completed = this.isStepCompleted(step.id);
            const current = this.isCurrentStep(step.id);

            let statusClass = 'pending';
            let statusIcon = '⏸️';

            if (completed) {
                statusClass = 'completed';
                statusIcon = '✅';
            } else if (current) {
                statusClass = 'active';
                statusIcon = '🔧';
            }

            return `
                <div class="step ${statusClass}">
                    <span class="step-icon">${statusIcon}</span>
                    <span class="step-name">${step.emoji} ${step.name}</span>
                </div>
            `;
        }).join('');
    }

    isStepCompleted(stepId) {
        switch (stepId) {
            case 'docker':
                return this.currentStatus.docker === true;
            case 'network':
                return this.currentStatus.network?.configured === true;
            case 'security':
                return this.currentStatus.security?.configured === true;
            case 'traefik':
                return this.currentStatus.traefik?.running === true;
            case 'monitoring':
                return this.currentStatus.monitoring?.running === true;
            default:
                return false;
        }
    }

    isCurrentStep(stepId) {
        // Find first incomplete step
        for (const step of this.steps) {
            if (!this.isStepCompleted(step.id)) {
                return step.id === stepId;
            }
        }
        return false;
    }

    analyzeSituation() {
        const completedAll = this.steps.every(step => this.isStepCompleted(step.id));

        if (completedAll) {
            this.showCompletionMessage();
            return;
        }

        // Find next step
        const nextStep = this.steps.find(step => !this.isStepCompleted(step.id));
        if (nextStep) {
            this.suggestNextStep(nextStep);
        }
    }

    suggestNextStep(step) {
        const suggestions = {
            docker: {
                message: 'Docker n\'est pas encore installé. C\'est la base de tout ! 🐳',
                description: 'Docker te permettra de déployer tous les services facilement.',
                command: 'sudo bash common-scripts/02-docker-install-verify.sh',
                buttonText: '🐳 Installer Docker'
            },
            network: {
                message: 'Super ! Docker est prêt. Maintenant, configurons ton réseau. 📡',
                description: 'IP statique, hostname personnalisé, DNS...',
                command: 'sudo bash common-scripts/set-static-ip.sh',
                buttonText: '📡 Configurer réseau'
            },
            security: {
                message: 'Réseau configuré ✅ Passons à la sécurité ! 🔒',
                description: 'UFW (firewall), Fail2ban (protection brute force), SSH hardening',
                command: 'sudo bash common-scripts/01-system-hardening.sh',
                buttonText: '🔒 Sécuriser le Pi'
            },
            traefik: {
                message: 'Ton Pi est bien sécurisé ! Installons Traefik (reverse proxy). 🌐',
                description: 'Traefik va gérer le routage et les certificats SSL automatiquement.',
                command: 'sudo bash common-scripts/03-traefik-setup.sh',
                buttonText: '🌐 Installer Traefik'
            },
            monitoring: {
                message: 'Presque fini ! Ajoutons du monitoring pour surveiller ton Pi. 📊',
                description: 'Prometheus + Grafana + Node Exporter pour des métriques en temps réel.',
                command: 'sudo bash 03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh',
                buttonText: '📊 Installer Monitoring'
            }
        };

        const config = suggestions[step.id];
        if (config) {
            this.addMessage(config.message, 'assistant', {
                actions: [
                    { text: config.buttonText, command: config.command, primary: true },
                    { text: '⏭️ Passer cette étape', action: () => this.skipStep(step.id), primary: false },
                    { text: 'ℹ️ En savoir plus', action: () => this.showStepInfo(step.id), primary: false }
                ],
                description: config.description
            });
        }
    }

    addMessage(text, type = 'assistant', options = {}) {
        const messagesContainer = document.getElementById('assistant-messages');
        if (!messagesContainer) return;

        this.messageCount++;
        const messageId = `msg-${this.messageCount}`;

        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${type}-message`;
        messageDiv.id = messageId;

        const now = new Date();
        const timeStr = now.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });

        let html = '';

        if (type === 'assistant') {
            html += '<div class="message-avatar">🤖</div>';
        }

        html += '<div class="message-content">';
        html += `<div class="message-text">${text}</div>`;

        if (options.description) {
            html += `<div class="message-description">${options.description}</div>`;
        }

        if (options.actions && options.actions.length > 0) {
            html += '<div class="message-actions">';
            options.actions.forEach((action, index) => {
                const btnClass = action.primary ? 'action-btn primary' : 'action-btn secondary';
                const dataAttr = action.command ? `data-command="${action.command}"` : '';
                html += `<button class="${btnClass}" data-msg-id="${messageId}" data-action-idx="${index}" ${dataAttr}>${action.text}</button>`;
            });
            html += '</div>';
        }

        html += '</div>';
        html += `<div class="message-time">${timeStr}</div>`;

        messageDiv.innerHTML = html;
        messagesContainer.appendChild(messageDiv);

        // Scroll to bottom
        messagesContainer.scrollTop = messagesContainer.scrollHeight;

        // Add event listeners to action buttons
        if (options.actions) {
            messageDiv.querySelectorAll('.action-btn').forEach((btn, index) => {
                btn.addEventListener('click', (e) => {
                    const command = btn.dataset.command;
                    const action = options.actions[index].action;

                    if (command) {
                        this.executeCommand(command, text);
                    } else if (action) {
                        action();
                    }

                    // Disable all buttons in this message after click
                    messageDiv.querySelectorAll('.action-btn').forEach(b => {
                        b.disabled = true;
                        b.style.opacity = '0.5';
                    });
                });
            });
        }
    }

    executeCommand(command, context) {
        // Add user message
        this.addMessage(`Lancement : ${command}`, 'user');

        // Execute in terminal
        terminalManager.executeCommand(command);

        // Add feedback message
        this.addMessage('⏳ Exécution en cours... Surveille le terminal à droite.', 'assistant');

        // Listen to execution end
        const checkInterval = setInterval(() => {
            if (!terminalManager.currentExecutionId) {
                clearInterval(checkInterval);
                setTimeout(() => {
                    this.load(); // Reload status after command
                }, 2000);
            }
        }, 1000);
    }

    skipStep(stepId) {
        this.addMessage(`Étape "${stepId}" passée. On continue !`, 'user');
        // Find next step
        const currentIndex = this.steps.findIndex(s => s.id === stepId);
        if (currentIndex >= 0 && currentIndex < this.steps.length - 1) {
            const nextStep = this.steps[currentIndex + 1];
            this.suggestNextStep(nextStep);
        } else {
            this.showCompletionMessage();
        }
    }

    showStepInfo(stepId) {
        const info = {
            docker: 'Docker est un système de conteneurisation qui permet de déployer des applications de manière isolée et reproductible.',
            network: 'Une IP statique garantit que ton Pi aura toujours la même adresse réseau, facilitant l\'accès distant.',
            security: 'UFW (Uncomplicated Firewall) protège ton Pi en bloquant les connexions non autorisées. Fail2ban bannit les IP qui tentent trop de connexions échouées.',
            traefik: 'Traefik est un reverse proxy moderne qui route le trafic vers tes services et gère les certificats SSL automatiquement.',
            monitoring: 'Prometheus collecte les métriques système, Grafana les visualise dans des dashboards interactifs.'
        };

        this.addMessage(info[stepId] || 'Pas d\'info disponible.', 'assistant');
    }

    showCompletionMessage() {
        this.addMessage('🎉 Félicitations ! Ton Pi est complètement configuré !', 'assistant');
        this.addMessage(
            'Tu peux maintenant déployer des services via l\'onglet "Scripts" ou consulter l\'état de tes conteneurs dans "Docker".',
            'assistant',
            {
                actions: [
                    { text: '📜 Voir les Scripts', action: () => window.tabsManager?.switchTab('scripts'), primary: true },
                    { text: '🐳 Voir Docker', action: () => window.tabsManager?.switchTab('docker'), primary: false }
                ]
            }
        );
    }
}

// Export singleton
const installationAssistant = new InstallationAssistant();
export default installationAssistant;
