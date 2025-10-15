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
    }

    init() {
        this.createDOM();
        this.registerGlobalShortcut();
        this.setupDefaultCommands();
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
                        placeholder="Type a command or search..."
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
                            <span>Navigate</span>
                        </div>
                        <div class="command-hint">
                            <span class="command-palette-kbd">Enter</span>
                            <span>Execute</span>
                        </div>
                        <div class="command-hint">
                            <span class="command-palette-kbd">ESC</span>
                            <span>Close</span>
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

    setupDefaultCommands() {
        // Navigation
        this.registerCommand({
            id: 'nav-dashboard',
            title: 'Go to Dashboard',
            description: 'View system overview and stats',
            icon: 'home',
            iconColor: 'primary',
            category: 'Navigation',
            shortcut: '1',
            action: () => window.tabsManager?.switchTab('dashboard')
        });

        this.registerCommand({
            id: 'nav-installation',
            title: 'Go to Installation',
            description: 'Setup wizard and installation assistant',
            icon: 'clapperboard',
            iconColor: 'primary',
            category: 'Navigation',
            shortcut: '2',
            action: () => window.tabsManager?.switchTab('installation')
        });

        this.registerCommand({
            id: 'nav-scripts',
            title: 'Go to Scripts',
            description: 'Manage and execute scripts',
            icon: 'scroll',
            iconColor: 'primary',
            category: 'Navigation',
            shortcut: '3',
            action: () => window.tabsManager?.switchTab('scripts')
        });

        this.registerCommand({
            id: 'nav-network',
            title: 'Go to Network',
            description: 'Monitor network interfaces and connections',
            icon: 'globe',
            iconColor: 'primary',
            category: 'Navigation',
            shortcut: '4',
            action: () => window.tabsManager?.switchTab('network')
        });

        this.registerCommand({
            id: 'nav-docker',
            title: 'Go to Docker',
            description: 'Manage Docker containers',
            icon: 'container',
            iconColor: 'primary',
            category: 'Navigation',
            shortcut: '5',
            action: () => window.tabsManager?.switchTab('docker')
        });

        this.registerCommand({
            id: 'nav-info',
            title: 'Go to Services Info',
            description: 'View services details and credentials',
            icon: 'clipboard-list',
            iconColor: 'primary',
            category: 'Navigation',
            shortcut: '6',
            action: () => window.tabsManager?.switchTab('info')
        });

        this.registerCommand({
            id: 'nav-history',
            title: 'Go to History',
            description: 'View execution history',
            icon: 'clock',
            iconColor: 'primary',
            category: 'Navigation',
            shortcut: '7',
            action: () => window.tabsManager?.switchTab('history')
        });

        this.registerCommand({
            id: 'nav-scheduler',
            title: 'Go to Scheduler',
            description: 'Manage scheduled tasks',
            icon: 'calendar',
            iconColor: 'primary',
            category: 'Navigation',
            shortcut: '8',
            action: () => window.tabsManager?.switchTab('scheduler')
        });

        // Quick Actions
        this.registerCommand({
            id: 'terminal-toggle',
            title: 'Toggle Terminal',
            description: 'Show/hide terminal sidebar',
            icon: 'terminal',
            iconColor: 'success',
            category: 'Quick Actions',
            shortcut: 'Ctrl+`',
            action: () => window.terminalSidebarManager?.toggle()
        });

        this.registerCommand({
            id: 'refresh-all',
            title: 'Refresh All Data',
            description: 'Reload system stats, Docker, and services',
            icon: 'rotate-cw',
            iconColor: 'success',
            category: 'Quick Actions',
            action: () => {
                window.systemStatsManager?.load();
                window.dockerManager?.load();
                window.toast?.success('Data refreshed', 'All data reloaded successfully');
            }
        });

        // Power Actions
        this.registerCommand({
            id: 'reboot-pi',
            title: 'Reboot Pi',
            description: 'Restart the Raspberry Pi',
            icon: 'rotate-cw',
            iconColor: 'warning',
            category: 'Power',
            action: () => {
                this.close();
                setTimeout(() => {
                    const module = window.powerModule || {};
                    if (module.rebootPi) module.rebootPi();
                }, 100);
            }
        });

        this.registerCommand({
            id: 'shutdown-pi',
            title: 'Shutdown Pi',
            description: 'Power off the Raspberry Pi',
            icon: 'power',
            iconColor: 'danger',
            category: 'Power',
            action: () => {
                this.close();
                setTimeout(() => {
                    const module = window.powerModule || {};
                    if (module.shutdownPi) module.shutdownPi();
                }, 100);
            }
        });
    }

    registerCommand(command) {
        this.commands.push(command);
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

        this.filteredCommands = [...this.commands];
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

        if (!query) {
            this.filteredCommands = [...this.commands];
        } else {
            this.filteredCommands = this.commands.filter(cmd => {
                return (
                    cmd.title.toLowerCase().includes(lowerQuery) ||
                    cmd.description.toLowerCase().includes(lowerQuery) ||
                    cmd.category.toLowerCase().includes(lowerQuery)
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
                    <div class="command-empty-icon">🔍</div>
                    <div class="command-empty-text">No commands found</div>
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
                            <div class="command-description">${cmd.description}</div>
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
            lucide.createIcons();
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
