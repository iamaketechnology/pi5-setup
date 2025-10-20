/**
 * Global Terminal AI Assistant
 * Provides intelligent assistance across all tabs in the global terminal sidebar
 */

class GlobalTerminalAI {
    constructor() {
        this.brain = new TerminalAIBrain();
        this.diagnostics = new SystemDiagnostics();
        this.messagesContainer = null;
        this.isVisible = true;
        this.activeTerminalId = null;
    }

    /**
     * Initialize global terminal AI
     */
    init() {
        console.log('🤖 Global Terminal AI initialized');

        this.messagesContainer = document.getElementById('ai-assistant-messages-global');
        this.setupEventListeners();
        this.showWelcomeMessage();

        // Connect to terminal manager events
        this.connectToTerminalManager();
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Toggle AI Assistant button
        const toggleBtn = document.getElementById('toggle-ai-assistant-global');
        if (toggleBtn) {
            toggleBtn.addEventListener('click', () => {
                this.toggleVisibility();
            });
        }
    }

    /**
     * Toggle AI assistant visibility
     */
    toggleVisibility() {
        const container = document.getElementById('terminal-ai-assistant-global');
        if (!container) return;

        this.isVisible = !this.isVisible;

        if (this.isVisible) {
            container.classList.remove('collapsed');
        } else {
            container.classList.add('collapsed');
        }

        // Update button
        const btn = document.getElementById('toggle-ai-assistant-global');
        if (btn) {
            const icon = btn.querySelector('i');
            const text = btn.querySelector('span');
            if (this.isVisible) {
                icon.setAttribute('data-lucide', 'sparkles');
                text.textContent = 'AI';
            } else {
                icon.setAttribute('data-lucide', 'eye-off');
                text.textContent = 'AI OFF';
            }
            if (window.lucide) window.lucide.createIcons();
        }
    }

    /**
     * Show welcome message
     */
    showWelcomeMessage() {
        if (!this.messagesContainer) return;

        this.messagesContainer.innerHTML = `
            <div class="ai-welcome-message">
                <i data-lucide="sparkles" size="20"></i>
                <p>L'assistant AI analyse vos commandes en temps réel et vous propose des suggestions contextuelles.</p>
            </div>
        `;

        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Connect to terminal manager to listen for command execution
     */
    connectToTerminalManager() {
        // Listen for terminal output
        if (window.terminalManager && typeof window.terminalManager.write === 'function') {
            // Hook into terminal output
            const originalWrite = window.terminalManager.write;
            window.terminalManager.write = (terminalId, text, type) => {
                // Call original write
                originalWrite.call(window.terminalManager, terminalId, text, type);

                // Analyze with AI
                this.analyzeTerminalOutput(terminalId, text, type);
            };
        }
    }

    /**
     * Analyze terminal output and provide suggestions
     * @param {string} terminalId - Terminal ID
     * @param {string} text - Output text
     * @param {string} type - Output type
     */
    analyzeTerminalOutput(terminalId, text, type) {
        // Analyze with AI brain
        const analysis = this.brain.analyzeOutput(text);

        if (analysis) {
            // Generate suggestions based on analysis
            const suggestions = this.generateSuggestions(analysis, text);

            if (suggestions.length > 0) {
                this.displaySuggestions(suggestions);
            }
        }
    }

    /**
     * Generate AI suggestions based on analysis
     * @param {Object} analysis - Analysis from TerminalAIBrain
     * @param {string} output - Terminal output
     * @returns {Array} Suggestions array
     */
    generateSuggestions(analysis, output) {
        const suggestions = [];

        // Critical errors
        if (analysis.hasErrors && analysis.errors.length > 0) {
            suggestions.push({
                type: 'error',
                icon: 'alert-circle',
                title: `${analysis.errors.length} erreur(s) critique(s)`,
                text: this.getErrorSummary(analysis.errors),
                actions: analysis.errors[0].suggestions.slice(0, 2).map(suggestion => ({
                    label: suggestion,
                    action: 'suggestion',
                    value: suggestion
                }))
            });
        }

        // Warnings
        if (analysis.hasWarnings && analysis.warnings.length > 0 && !analysis.hasErrors) {
            suggestions.push({
                type: 'warning',
                icon: 'alert-triangle',
                title: `${analysis.warnings.length} avertissement(s)`,
                text: this.getWarningSummary(analysis.warnings),
                actions: []
            });
        }

        // Success
        if (analysis.hasSuccess && !analysis.hasErrors && !analysis.hasWarnings) {
            suggestions.push({
                type: 'success',
                icon: 'check-circle',
                title: 'Opération réussie',
                text: `${analysis.successes.length} opération(s) complétée(s) avec succès`,
                actions: []
            });
        }

        // Context-based suggestions
        if (output.includes('docker')) {
            const dockerSuggestion = this.getDockerSuggestion(output, analysis);
            if (dockerSuggestion) {
                suggestions.push(dockerSuggestion);
            }
        }

        return suggestions;
    }

    /**
     * Get error summary text
     */
    getErrorSummary(errors) {
        if (errors.length === 1) {
            return errors[0].line.substring(0, 100);
        }
        return `Plusieurs erreurs détectées. La première : ${errors[0].line.substring(0, 80)}...`;
    }

    /**
     * Get warning summary text
     */
    getWarningSummary(warnings) {
        if (warnings.length === 1) {
            return warnings[0].line.substring(0, 100);
        }
        return `${warnings.length} avertissements détectés`;
    }

    /**
     * Get Docker-specific suggestion
     */
    getDockerSuggestion(output, analysis) {
        if (output.includes('docker compose up') || output.includes('docker-compose up')) {
            if (analysis.hasSuccess) {
                return {
                    type: 'info',
                    icon: 'info',
                    title: 'Services Docker démarrés',
                    text: 'Utilisez `docker ps` pour voir les conteneurs actifs ou `docker logs <name>` pour les logs',
                    actions: [
                        { label: 'docker ps', action: 'execute', value: 'docker ps' },
                        { label: 'Voir les logs', action: 'info', value: 'logs' }
                    ]
                };
            }
        }

        if (output.includes('docker ps')) {
            return {
                type: 'info',
                icon: 'layers',
                title: 'Conteneurs listés',
                text: 'Vous pouvez utiliser `docker logs <name>`, `docker exec -it <name> bash`, ou `docker stats` pour plus de détails',
                actions: []
            };
        }

        return null;
    }

    /**
     * Display suggestions in AI zone
     * @param {Array} suggestions - Array of suggestion objects
     */
    displaySuggestions(suggestions) {
        if (!this.messagesContainer) return;

        // Clear previous suggestions
        this.messagesContainer.innerHTML = '';

        suggestions.forEach(suggestion => {
            const messageEl = document.createElement('div');
            messageEl.className = `ai-suggestion ai-suggestion-${suggestion.type}`;

            let actionsHtml = '';
            if (suggestion.actions && suggestion.actions.length > 0) {
                actionsHtml = `
                    <div class="ai-suggestion-actions">
                        ${suggestion.actions.map(action => `
                            <button class="btn btn-xs btn-primary ai-action-btn"
                                    data-action="${action.action}"
                                    data-value="${action.value}">
                                <i data-lucide="arrow-right" size="12"></i>
                                <span>${action.label}</span>
                            </button>
                        `).join('')}
                    </div>
                `;
            }

            messageEl.innerHTML = `
                <div class="ai-suggestion-icon ai-icon-${suggestion.type}">
                    <i data-lucide="${suggestion.icon}" size="16"></i>
                </div>
                <div class="ai-suggestion-content">
                    <div class="ai-suggestion-title">${suggestion.title}</div>
                    <div class="ai-suggestion-text">${suggestion.text}</div>
                    ${actionsHtml}
                </div>
            `;

            this.messagesContainer.appendChild(messageEl);
        });

        if (window.lucide) window.lucide.createIcons();

        // Attach event listeners to action buttons
        this.messagesContainer.querySelectorAll('.ai-action-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const action = btn.dataset.action;
                const value = btn.dataset.value;
                this.handleAction(action, value);
            });
        });
    }

    /**
     * Handle action button clicks
     * @param {string} action - Action type
     * @param {string} value - Action value
     */
    handleAction(action, value) {
        if (action === 'execute') {
            // Execute command in active terminal
            if (window.terminalManager && this.activeTerminalId) {
                const input = document.querySelector(`#${this.activeTerminalId} .terminal-input`);
                if (input) {
                    input.value = value;
                    input.focus();
                }
            }
        } else if (action === 'suggestion') {
            // Show more info about suggestion
            console.log('Suggestion:', value);
        }
    }

    /**
     * Update system diagnostics in AI zone
     * @param {number} updatesCount - Number of updates available
     * @param {number} servicesCount - Number of services
     * @param {string} diskFree - Free disk space
     */
    updateSystemDiagnostics(updatesCount, servicesCount, diskFree) {
        const messages = this.diagnostics.analyze(updatesCount, servicesCount, diskFree);

        if (messages && messages.length > 0) {
            // Convert system diagnostics to AI suggestions format
            const suggestions = messages.map(msg => ({
                type: msg.type,
                icon: msg.icon,
                title: msg.title,
                text: msg.text,
                actions: msg.actions || []
            }));

            this.displaySuggestions(suggestions);
        }
    }

    /**
     * Set active terminal
     * @param {string} terminalId - Terminal ID
     */
    setActiveTerminal(terminalId) {
        this.activeTerminalId = terminalId;
    }

    /**
     * Get AI statistics
     */
    getStatistics() {
        return {
            brain: this.brain.getStatistics(),
            diagnostics: this.diagnostics
        };
    }

    /**
     * Reset AI (clear history)
     */
    reset() {
        this.brain.reset();
        this.showWelcomeMessage();
    }
}

// Create global instance
if (typeof window !== 'undefined') {
    window.GlobalTerminalAI = GlobalTerminalAI;

    // Auto-initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            window.globalTerminalAI = new GlobalTerminalAI();
            window.globalTerminalAI.init();
        });
    } else {
        window.globalTerminalAI = new GlobalTerminalAI();
        window.globalTerminalAI.init();
    }
}
