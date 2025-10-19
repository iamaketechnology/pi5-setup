/**
 * Terminal Intelligent - Smart Terminal with AI Assistant
 * Combines terminal output with intelligent suggestions
 */

class TerminalIntelligent {
    constructor(containerId = 'terminal-output-install', aiZoneId = 'assistant-messages') {
        this.container = document.getElementById(containerId);
        this.aiZone = document.getElementById(aiZoneId);
        this.brain = new TerminalAIBrain();
        this.outputBuffer = [];
        this.isScrolledToBottom = true;
    }

    /**
     * Initialize terminal
     */
    init() {
        console.log('🤖 Terminal Intelligent initialized');
        this.setupEventListeners();
        this.showWelcomeMessage();
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Auto-scroll detection
        if (this.container) {
            this.container.addEventListener('scroll', () => {
                const { scrollTop, scrollHeight, clientHeight } = this.container;
                this.isScrolledToBottom = scrollTop + clientHeight >= scrollHeight - 10;
            });
        }
    }

    /**
     * Show welcome message
     */
    showWelcomeMessage() {
        if (!this.container) return;

        this.container.innerHTML = `
            <div class="terminal-welcome">
                <i data-lucide="terminal" size="24"></i>
                <p>Terminal Intelligent prêt. Les commandes s'afficheront ici.</p>
                <p class="terminal-hint">💡 Lancez une installation pour voir la sortie en temps réel</p>
            </div>
        `;

        if (window.lucide) window.lucide.createIcons();
    }

    /**
     * Write output to terminal
     * @param {string} text - Text to write
     * @param {string} type - Type: 'normal', 'success', 'error', 'warning'
     */
    write(text, type = 'normal') {
        if (!this.container) return;

        // Remove welcome message on first write
        const welcome = this.container.querySelector('.terminal-welcome');
        if (welcome) {
            this.container.innerHTML = '';
        }

        const line = document.createElement('div');
        line.className = `terminal-line ${type}`;

        // Add prompt for commands
        if (type === 'command') {
            const prompt = document.createElement('span');
            prompt.className = 'terminal-prompt';
            prompt.textContent = '$ ';
            line.appendChild(prompt);
        }

        const content = document.createElement('span');
        content.textContent = text;
        line.appendChild(content);

        this.container.appendChild(line);

        // Store in buffer
        this.outputBuffer.push({ text, type, timestamp: Date.now() });

        // Auto-scroll if at bottom
        if (this.isScrolledToBottom) {
            this.scrollToBottom();
        }

        // Analyze output with AI brain
        this.analyzeAndSuggest();
    }

    /**
     * Write command to terminal
     * @param {string} command - Command text
     */
    writeCommand(command) {
        this.write(command, 'command');

        // Learn from command
        this.brain.learn({
            command,
            context: { timestamp: Date.now() }
        });
    }

    /**
     * Write error to terminal
     * @param {string} error - Error message
     */
    writeError(error) {
        this.write(`ERROR: ${error}`, 'error');
    }

    /**
     * Write success message to terminal
     * @param {string} message - Success message
     */
    writeSuccess(message) {
        this.write(`✓ ${message}`, 'success');
    }

    /**
     * Write warning to terminal
     * @param {string} warning - Warning message
     */
    writeWarning(warning) {
        this.write(`⚠ ${warning}`, 'warning');
    }

    /**
     * Clear terminal
     */
    clear() {
        if (this.container) {
            this.container.innerHTML = '';
            this.outputBuffer = [];
            this.showWelcomeMessage();
        }
    }

    /**
     * Scroll to bottom
     */
    scrollToBottom() {
        if (this.container) {
            this.container.scrollTop = this.container.scrollHeight;
        }
    }

    /**
     * Analyze output and generate AI suggestions
     */
    analyzeAndSuggest() {
        // Get recent output (last 20 lines)
        const recentOutput = this.outputBuffer
            .slice(-20)
            .map(item => item.text)
            .join('\n');

        // Analyze with AI brain
        const analysis = this.brain.analyzeOutput(recentOutput);

        if (analysis) {
            // Generate suggestions
            const suggestions = this.brain.generateSuggestions({
                output: recentOutput,
                analysis
            });

            // Display suggestions in AI zone
            if (suggestions.length > 0) {
                this.displaySuggestions(suggestions);
            }
        }
    }

    /**
     * Display AI suggestions in the AI zone
     * @param {Array} suggestions - Array of suggestion objects
     */
    displaySuggestions(suggestions) {
        if (!this.aiZone) return;

        // Clear previous suggestions
        this.aiZone.innerHTML = '';

        suggestions.forEach(suggestion => {
            const messageEl = document.createElement('div');
            messageEl.className = `message assistant-message assistant-${suggestion.type}`;

            let actionsHtml = '';
            if (suggestion.actions && suggestion.actions.length > 0) {
                actionsHtml = `
                    <div class="message-actions">
                        ${suggestion.actions.map(action => `
                            <button class="btn btn-sm btn-primary assistant-action-btn"
                                    data-command="${action.command || ''}">
                                <i data-lucide="arrow-right" size="14"></i>
                                <span>${action.label}</span>
                            </button>
                        `).join('')}
                    </div>
                `;
            }

            messageEl.innerHTML = `
                <div class="message-avatar message-avatar-${suggestion.type}">
                    <i data-lucide="${suggestion.icon}" size="20"></i>
                </div>
                <div class="message-content">
                    <div class="message-title">${suggestion.title}</div>
                    <div class="message-text">${suggestion.text}</div>
                    ${actionsHtml}
                </div>
            `;

            this.aiZone.appendChild(messageEl);
        });

        if (window.lucide) window.lucide.createIcons();

        // Attach event listeners to action buttons
        this.aiZone.querySelectorAll('.assistant-action-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const command = btn.dataset.command;
                if (command === 'show-errors') {
                    this.showErrors();
                } else if (command === 'show-warnings') {
                    this.showWarnings();
                }
            });
        });
    }

    /**
     * Show detailed errors
     */
    showErrors() {
        if (!this.brain.lastAnalysis || !this.brain.lastAnalysis.hasErrors) {
            return;
        }

        this.write('\n=== ERREURS DÉTECTÉES ===', 'warning');
        this.brain.lastAnalysis.errors.forEach((error, index) => {
            this.write(`${index + 1}. ${error.line}`, 'error');
            if (error.suggestions && error.suggestions.length > 0) {
                this.write(`   Suggestions: ${error.suggestions.join(', ')}`, 'normal');
            }
        });
        this.write('=========================\n', 'warning');
    }

    /**
     * Show detailed warnings
     */
    showWarnings() {
        if (!this.brain.lastAnalysis || !this.brain.lastAnalysis.hasWarnings) {
            return;
        }

        this.write('\n=== AVERTISSEMENTS ===', 'warning');
        this.brain.lastAnalysis.warnings.forEach((warning, index) => {
            this.write(`${index + 1}. ${warning.line}`, 'warning');
            if (warning.suggestions && warning.suggestions.length > 0) {
                this.write(`   Suggestions: ${warning.suggestions.join(', ')}`, 'normal');
            }
        });
        this.write('======================\n', 'warning');
    }

    /**
     * Write streaming output (for real-time SSH output)
     * @param {string} chunk - Output chunk
     */
    writeStream(chunk) {
        const lines = chunk.split('\n');
        lines.forEach(line => {
            if (line.trim()) {
                this.write(line);
            }
        });
    }

    /**
     * Get terminal statistics
     */
    getStats() {
        return {
            linesWritten: this.outputBuffer.length,
            brainStats: this.brain.getStatistics()
        };
    }

    /**
     * Export terminal output
     * @returns {string} Terminal output as text
     */
    export() {
        return this.outputBuffer
            .map(item => `[${new Date(item.timestamp).toLocaleTimeString()}] ${item.text}`)
            .join('\n');
    }

    /**
     * Download terminal output as file
     */
    download() {
        const content = this.export();
        const blob = new Blob([content], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `terminal-output-${Date.now()}.txt`;
        a.click();
        URL.revokeObjectURL(url);
    }
}

// Export for use in other modules
if (typeof window !== 'undefined') {
    window.TerminalIntelligent = TerminalIntelligent;
}
