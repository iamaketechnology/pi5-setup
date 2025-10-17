// =============================================================================
// Command Palette Module (Cmd+K / Ctrl+K)
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// =============================================================================

import { debounce } from '../utils/debounce.js';

class CommandPalette {
    constructor() {
        this.isOpen = false;
        this.commands = [];
        this.filteredCommands = [];
        this.selectedIndex = 0;
        this.onExecuteCallbacks = new Map();
        this.currentContext = 'dashboard';
    }

    init() {
        this.createDOM();
        this.registerGlobalShortcut();
        this.setupDefaultCommands();
        this.setupContextListeners();
        console.log('✅ Command Palette initialized');
    }

    createDOM() {
        const overlay = document.createElement('div');
        overlay.className = 'command-palette-overlay';
        overlay.id = 'command-palette-overlay';

        overlay.innerHTML = `
            <div class="command-palette" onclick="event.stopPropagation()">
                <div class="command-palette-search">
                    <i data-lucide="search" size="20"></i>
                    <input
                        type="text"
                        class="command-palette-input"
                        id="command-palette-input"
                        placeholder="Rechercher une commande..."
                        autocomplete="off"
                        spellcheck="false"
                    >
                    <div class="command-palette-shortcut">
                        <span class="command-palette-kbd">ESC</span>
                    </div>
                </div>
                <div class="command-palette-results" id="command-palette-results">
                    <!-- Results will be rendered here -->
                </div>
                <div class="command-palette-footer">
                    <div class="command-palette-hints">
                        <div class="command-hint">
                            <span class="command-palette-kbd">↑↓</span>
                            <span>Naviguer</span>
                        </div>
                        <div class="command-hint">
                            <span class="command-palette-kbd">Enter</span>
                            <span>Exécuter</span>
                        </div>
                        <div class="command-hint">
                            <span class="command-palette-kbd">ESC</span>
                            <span>Fermer</span>
                        </div>
                    </div>
                </div>
            </div>
        `;

        document.body.appendChild(overlay);

        // Event listeners
        overlay.addEventListener('click', () => this.close());

        const input = document.getElementById('command-palette-input');
        input.addEventListener('input', debounce((e) => {
            this.handleSearch(e.target.value);
        }, 150));

        input.addEventListener('keydown', (e) => this.handleKeyboard(e));

        // Initialize icons
        if (typeof lucide !== 'undefined') {
            lucide.createIcons();
        }
    }

    registerGlobalShortcut() {
        document.addEventListener('keydown', (e) => {
            // Cmd+K (Mac) or Ctrl+K (Windows/Linux)
            if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
                e.preventDefault();
                this.toggle();
            }

            // ESC to close
            if (e.key === 'Escape' && this.isOpen) {
                e.preventDefault();
                this.close();
            }
        });
    }

    setupContextListeners() {
        window.addEventListener('tab:switched', (event) => {
            const context = event.detail?.tabName || 'dashboard';
            this.currentContext = context;
            if (this.isOpen) {
                const input = document.getElementById('command-palette-input');
                this.handleSearch(input?.value || '');
            }
        });
    }

    setupDefaultCommands() {
        const commands = [
            // Navigation
            {
                id: 'nav-dashboard',
                title: 'Aller au dashboard',
                description: "Vue d'ensemble des ressources système",
                icon: 'layout-dashboard',
                iconColor: 'primary',
                category: 'Navigation',
                shortcut: '1',
                action: () => window.tabsManager?.switchTab('dashboard')
            },
            {
                id: 'nav-installation',
                title: "Assistant d'installation",
                description: "Accéder au guide de mise en service",
                icon: 'clapperboard',
                iconColor: 'primary',
                category: 'Navigation',
                shortcut: '2',
                action: () => window.tabsManager?.switchTab('installation')
            },
            {
                id: 'nav-scripts',
                title: 'Scripts disponibles',
                description: 'Parcourir et exécuter les scripts PI5',
                icon: 'file-code-2',
                iconColor: 'primary',
                category: 'Navigation',
                shortcut: '3',
                action: () => window.tabsManager?.switchTab('scripts')
            },
            {
                id: 'nav-network',
                title: 'Supervision réseau',
                description: 'Interfaces, bande passante et diagnostics',
                icon: 'globe-2',
                iconColor: 'primary',
                category: 'Navigation',
                shortcut: '4',
                action: () => window.tabsManager?.switchTab('network')
            },
            {
                id: 'nav-docker',
                title: 'Gestion Docker',
                description: 'Conteneurs, santé et redémarrages',
                icon: 'ship-wheel',
                iconColor: 'primary',
                category: 'Navigation',
                shortcut: '5',
                action: () => window.tabsManager?.switchTab('docker')
            },
            {
                id: 'nav-info',
                title: 'Référentiel services',
                description: 'Détails, identifiants et commandes utiles',
                icon: 'badge-help',
                iconColor: 'primary',
                category: 'Navigation',
                shortcut: '6',
                action: () => window.tabsManager?.switchTab('info')
            },
            {
                id: 'nav-history',
                title: 'Historique des exécutions',
                description: 'Suivre les scripts exécutés et leurs statuts',
                icon: 'history',
                iconColor: 'primary',
                category: 'Navigation',
                shortcut: '7',
                action: () => window.tabsManager?.switchTab('history')
            },
            {
                id: 'nav-scheduler',
                title: 'Tâches planifiées',
                description: 'Programmer et gérer les automatismes',
                icon: 'calendar-clock',
                iconColor: 'primary',
                category: 'Navigation',
                shortcut: '8',
                action: () => window.tabsManager?.switchTab('scheduler')
            },

            // Actions rapides
            {
                id: 'focus-mode-toggle',
                title: 'Basculer le mode focus',
                description: 'Masquer les panneaux secondaires de l’onglet actif',
                icon: 'crosshair',
                iconColor: 'success',
                category: 'Actions rapides',
                action: () => document.getElementById('toggle-focus-mode')?.click()
            },
            {
                id: 'terminal-toggle',
                title: 'Afficher le terminal',
                description: 'Ouvrir ou masquer la barre latérale du terminal',
                icon: 'terminal',
                iconColor: 'success',
                category: 'Actions rapides',
                action: () => window.terminalSidebarManager?.toggle()
            },
            {
                id: 'refresh-dashboard',
                title: 'Rafraîchir le dashboard',
                description: 'Recharge les métriques système et Docker',
                icon: 'refresh-cw',
                iconColor: 'success',
                category: 'Actions rapides',
                action: () => {
                    window.systemStatsManager?.load();
                    window.dockerManager?.load();
                    window.toastManager?.success('Dashboard', 'Statistiques rafraîchies');
                }
            },
            {
                id: 'run-backup',
                title: 'Lancer un backup complet',
                description: 'Déclencher le script de sauvegarde depuis les actions rapides',
                icon: 'hard-drive',
                iconColor: 'warning',
                category: 'Actions rapides',
                action: () => {
                    window.tabsManager?.switchTab('dashboard');
                    setTimeout(() => {
                        document.querySelector('.quick-actions [data-action="backup"]')?.click();
                    }, 50);
                }
            },

            // Contexte réseau
            {
                id: 'network-refresh',
                title: 'Rafraîchir le réseau',
                description: 'Recharge interfaces, bande passante et connexions',
                icon: 'wifi',
                iconColor: 'info',
                category: 'Réseau',
                context: ['network'],
                action: () => {
                    document.getElementById('refresh-network')?.click();
                    document.getElementById('refresh-firewall')?.click();
                }
            },
            {
                id: 'network-focus-diagnostics',
                title: 'Ouvrir les diagnostics réseau',
                description: 'Accès rapide aux tests Ping et DNS',
                icon: 'radar',
                iconColor: 'info',
                category: 'Réseau',
                context: ['network'],
                action: () => {
                    const testsSection = document.querySelector('#network-content .network-tests');
                    testsSection?.scrollIntoView({ behavior: 'smooth', block: 'start' });
                    setTimeout(() => document.getElementById('ping-host')?.focus(), 200);
                }
            },

            // Contexte Docker
            {
                id: 'docker-reload',
                title: 'Actualiser les conteneurs',
                description: 'Recharger l’état des conteneurs Docker',
                icon: 'box',
                iconColor: 'info',
                category: 'Docker',
                context: ['docker', 'dashboard'],
                action: () => document.getElementById('refresh-docker')?.click()
            },

            // Contexte Scripts
            {
                id: 'scripts-search',
                title: 'Chercher un script',
                description: 'Positionner le focus sur la recherche de scripts',
                icon: 'search',
                iconColor: 'info',
                category: 'Scripts',
                context: ['scripts'],
                action: () => document.getElementById('search-scripts')?.focus()
            },

            // Contexte Historique
            {
                id: 'history-refresh',
                title: 'Mettre à jour l’historique',
                description: 'Rafraîchir les dernières exécutions de scripts',
                icon: 'history',
                iconColor: 'info',
                category: 'Historique',
                context: ['history'],
                action: () => document.getElementById('refresh-history')?.click()
            },

            // Contexte Planificateur
            {
                id: 'scheduler-new-task',
                title: 'Ajouter une tâche planifiée',
                description: 'Ouvrir le formulaire de création de tâche',
                icon: 'calendar-plus',
                iconColor: 'info',
                category: 'Planificateur',
                context: ['scheduler'],
                action: () => document.getElementById('add-task')?.click()
            },

            // Alimentation
            {
                id: 'reboot-pi',
                title: 'Redémarrer le Pi',
                description: 'Redémarrer le Raspberry Pi sélectionné',
                icon: 'rotate-cw',
                iconColor: 'warning',
                category: 'Alimentation',
                action: () => {
                    this.close();
                    setTimeout(() => {
                        const module = window.powerModule || {};
                        if (module.rebootPi) module.rebootPi();
                    }, 100);
                }
            },
            {
                id: 'shutdown-pi',
                title: 'Arrêter le Pi',
                description: 'Éteindre en toute sécurité le Raspberry Pi actif',
                icon: 'power',
                iconColor: 'danger',
                category: 'Alimentation',
                action: () => {
                    this.close();
                    setTimeout(() => {
                        const module = window.powerModule || {};
                        if (module.shutdownPi) module.shutdownPi();
                    }, 100);
                }
            }
        ];

        commands.forEach(cmd => this.registerCommand(cmd));
    }

    registerCommand(command) {
        const normalized = {
            ...command,
            context: command.context
                ? Array.isArray(command.context) ? command.context : [command.context]
                : null
        };

        const existingIndex = this.commands.findIndex(cmd => cmd.id === normalized.id);
        if (existingIndex >= 0) {
            this.commands[existingIndex] = { ...this.commands[existingIndex], ...normalized };
        } else {
            this.commands.push(normalized);
        }
    }

    toggle() {
        if (this.isOpen) {
            this.close();
        } else {
            this.open();
        }
    }

    open() {
        this.isOpen = true;
        const overlay = document.getElementById('command-palette-overlay');
        const input = document.getElementById('command-palette-input');

        overlay.classList.add('active');
        input.value = '';
        input.focus();

        this.filteredCommands = this.getCommandsForContext();
        this.selectedIndex = 0;
        this.render();

        // Re-init icons
        if (typeof lucide !== 'undefined') {
            lucide.createIcons();
        }
    }

    close() {
        this.isOpen = false;
        const overlay = document.getElementById('command-palette-overlay');
        overlay.classList.remove('active');
    }

    handleSearch(query) {
        const lowerQuery = query.toLowerCase();

        const commands = this.getCommandsForContext();

        if (!query) {
            this.filteredCommands = [...commands];
        } else {
            this.filteredCommands = commands.filter(cmd => {
                return (
                    cmd.title?.toLowerCase().includes(lowerQuery) ||
                    cmd.description?.toLowerCase().includes(lowerQuery) ||
                    cmd.category?.toLowerCase().includes(lowerQuery)
                );
            });
        }

        this.selectedIndex = 0;
        this.render();
    }

    handleKeyboard(e) {
        switch (e.key) {
            case 'ArrowDown':
                e.preventDefault();
                this.selectedIndex = Math.min(this.selectedIndex + 1, this.filteredCommands.length - 1);
                this.render();
                this.scrollToSelected();
                break;

            case 'ArrowUp':
                e.preventDefault();
                this.selectedIndex = Math.max(this.selectedIndex - 1, 0);
                this.render();
                this.scrollToSelected();
                break;

            case 'Enter':
                e.preventDefault();
                this.executeSelected();
                break;

            case 'Escape':
                e.preventDefault();
                this.close();
                break;
        }
    }

    getCommandsForContext() {
        return this.commands.filter(cmd => {
            if (!cmd.context || cmd.context.length === 0) return true;
            return cmd.context.includes(this.currentContext);
        });
    }

    scrollToSelected() {
        const container = document.getElementById('command-palette-results');
        const selected = container.querySelector('.command-item.selected');
        if (selected) {
            selected.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        }
    }

    executeSelected() {
        const command = this.filteredCommands[this.selectedIndex];
        if (command && command.action) {
            this.close();
            setTimeout(() => command.action(), 50);
        }
    }

    render() {
        const container = document.getElementById('command-palette-results');

        if (this.filteredCommands.length === 0) {
            container.innerHTML = `
                <div class="command-empty">
                    <div class="command-empty-icon"><i data-lucide="search-x" size="24"></i></div>
                    <div class="command-empty-text">Aucune commande disponible</div>
                </div>
            `;
            return;
        }

        // Group by category
        const grouped = this.filteredCommands.reduce((acc, cmd) => {
            if (!acc[cmd.category]) acc[cmd.category] = [];
            acc[cmd.category].push(cmd);
            return acc;
        }, {});

        let html = '';
        let globalIndex = 0;

        Object.keys(grouped).forEach(category => {
            html += `<div class="command-section">`;
            html += `<div class="command-section-title">${category}</div>`;

            grouped[category].forEach(cmd => {
                const isSelected = globalIndex === this.selectedIndex;
                html += `
                    <div class="command-item ${isSelected ? 'selected' : ''}"
                         data-index="${globalIndex}"
                         onclick="window.commandPalette.executeCommand('${cmd.id}')">
                        <div class="command-icon icon-${cmd.iconColor || 'primary'}">
                            <i data-lucide="${cmd.icon}" size="18"></i>
                        </div>
                        <div class="command-content">
                            <div class="command-title">${cmd.title}</div>
                            ${cmd.description ? `<div class="command-description">${cmd.description}</div>` : ''}
                        </div>
                        ${cmd.shortcut ? `
                            <div class="command-shortcut-hint">
                                <span class="command-palette-kbd">${cmd.shortcut}</span>
                            </div>
                        ` : ''}
                    </div>
                `;
                globalIndex++;
            });

            html += `</div>`;
        });

        container.innerHTML = html;

        // Re-init icons
        if (typeof lucide !== 'undefined') {
            lucide.createIcons({ root: container });
        }
    }

    executeCommand(commandId) {
        const command = this.commands.find(c => c.id === commandId);
        if (command && command.action) {
            this.close();
            setTimeout(() => command.action(), 50);
        }
    }
}

// Export singleton
const commandPalette = new CommandPalette();
export default commandPalette;

// Make available globally
window.commandPalette = commandPalette;
