/**
 * Installation Terminal Module
 * Manages the terminal interface in the Installation tab
 */

export class InstallationTerminal {
    constructor() {
        this.terminal = null;
    }

    /**
     * Initialize terminal with TerminalIntelligent
     */
    init() {
        this.terminal = new TerminalIntelligent('terminal-output-install', 'ai-messages-install');
        this.initControls();
        this.showWelcomeMessage();
    }

    /**
     * Initialize terminal controls (toggle AI, clear, export)
     */
    initControls() {
        // Toggle AI Assistant
        const toggleAIBtn = document.getElementById('toggle-ai-install');
        if (toggleAIBtn) {
            toggleAIBtn.addEventListener('click', () => {
                const aiZone = document.getElementById('terminal-ai-install');
                if (aiZone) {
                    aiZone.classList.toggle('collapsed');
                    const icon = toggleAIBtn.querySelector('i');
                    const text = toggleAIBtn.querySelector('span');
                    if (aiZone.classList.contains('collapsed')) {
                        icon.setAttribute('data-lucide', 'eye-off');
                        text.textContent = 'AI OFF';
                    } else {
                        icon.setAttribute('data-lucide', 'sparkles');
                        text.textContent = 'AI';
                    }
                    if (window.lucide) window.lucide.createIcons();
                }
            });
        }

        // Clear Terminal
        const clearBtn = document.getElementById('clear-terminal-install');
        if (clearBtn) {
            clearBtn.addEventListener('click', () => {
                this.clear();
                this.write('Terminal effacé', 'info');
            });
        }

        // Export Terminal
        const exportBtn = document.getElementById('export-terminal-install');
        if (exportBtn) {
            exportBtn.addEventListener('click', () => {
                this.download();
            });
        }
    }

    /**
     * Show welcome message
     */
    showWelcomeMessage() {
        this.write('🤖 Assistant Installation initialisé. Prêt à analyser vos commandes...', 'success');
    }

    /**
     * Write to terminal
     */
    write(text, type = 'normal') {
        if (this.terminal) {
            this.terminal.write(text, type);
        }
    }

    /**
     * Clear terminal
     */
    clear() {
        if (this.terminal) {
            this.terminal.clear();
        }
    }

    /**
     * Download terminal output
     */
    download() {
        if (this.terminal) {
            this.terminal.download();
        }
    }

    /**
     * Display AI suggestions
     */
    displaySuggestions(suggestions) {
        if (this.terminal) {
            this.terminal.displaySuggestions(suggestions);
        }
    }

    /**
     * Get terminal instance
     */
    getTerminal() {
        return this.terminal;
    }
}
