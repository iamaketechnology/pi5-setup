/**
 * Terminal AI Brain - Neural Network for Intelligent Terminal
 * Analyzes terminal output and provides context-aware suggestions
 */

class TerminalAIBrain {
    constructor() {
        this.outputHistory = [];
        this.commandHistory = [];
        this.errorPatterns = this.initErrorPatterns();
        this.successPatterns = this.initSuccessPatterns();
        this.lastAnalysis = null;
    }

    /**
     * Initialize error detection patterns
     */
    initErrorPatterns() {
        return [
            {
                pattern: /error|failed|failure|exception/i,
                severity: 'critical',
                suggestions: ['Check logs', 'Verify configuration', 'Restart service']
            },
            {
                pattern: /permission denied|access denied/i,
                severity: 'critical',
                suggestions: ['Run with sudo', 'Check file permissions', 'Verify user access']
            },
            {
                pattern: /port.*already.*in.*use/i,
                severity: 'warning',
                suggestions: ['Kill process using port', 'Change port number', 'Check running services']
            },
            {
                pattern: /connection refused|cannot connect/i,
                severity: 'warning',
                suggestions: ['Check service is running', 'Verify network connectivity', 'Check firewall rules']
            },
            {
                pattern: /no space left|disk full/i,
                severity: 'critical',
                suggestions: ['Clean Docker images', 'Remove old logs', 'Expand storage']
            },
            {
                pattern: /timeout|timed out/i,
                severity: 'warning',
                suggestions: ['Increase timeout value', 'Check network latency', 'Verify service health']
            },
            {
                pattern: /not found|does not exist/i,
                severity: 'warning',
                suggestions: ['Check file path', 'Install missing dependency', 'Verify configuration']
            }
        ];
    }

    /**
     * Initialize success detection patterns
     */
    initSuccessPatterns() {
        return [
            {
                pattern: /successfully|success|completed|done|ready/i,
                type: 'success'
            },
            {
                pattern: /started|running|up|healthy/i,
                type: 'running'
            },
            {
                pattern: /installed|deployed|created/i,
                type: 'deployed'
            }
        ];
    }

    /**
     * Analyze terminal output line by line
     * @param {string} output - Terminal output to analyze
     * @returns {Object} Analysis result with suggestions
     */
    analyzeOutput(output) {
        if (!output) return null;

        const lines = output.split('\n').filter(line => line.trim());
        const analysis = {
            hasErrors: false,
            hasWarnings: false,
            hasSuccess: false,
            errors: [],
            warnings: [],
            successes: [],
            suggestions: [],
            sentiment: 'neutral'
        };

        // Analyze each line
        lines.forEach(line => {
            // Check for errors
            this.errorPatterns.forEach(errorPattern => {
                if (errorPattern.pattern.test(line)) {
                    const error = {
                        line: line.trim(),
                        severity: errorPattern.severity,
                        suggestions: errorPattern.suggestions
                    };

                    if (errorPattern.severity === 'critical') {
                        analysis.errors.push(error);
                        analysis.hasErrors = true;
                    } else {
                        analysis.warnings.push(error);
                        analysis.hasWarnings = true;
                    }

                    // Add unique suggestions
                    errorPattern.suggestions.forEach(suggestion => {
                        if (!analysis.suggestions.includes(suggestion)) {
                            analysis.suggestions.push(suggestion);
                        }
                    });
                }
            });

            // Check for success
            this.successPatterns.forEach(successPattern => {
                if (successPattern.pattern.test(line)) {
                    analysis.successes.push({
                        line: line.trim(),
                        type: successPattern.type
                    });
                    analysis.hasSuccess = true;
                }
            });
        });

        // Determine overall sentiment
        if (analysis.hasErrors) {
            analysis.sentiment = 'negative';
        } else if (analysis.hasWarnings) {
            analysis.sentiment = 'caution';
        } else if (analysis.hasSuccess) {
            analysis.sentiment = 'positive';
        }

        // Store in history
        this.outputHistory.push({
            timestamp: Date.now(),
            output,
            analysis
        });

        // Keep only last 50 entries
        if (this.outputHistory.length > 50) {
            this.outputHistory.shift();
        }

        this.lastAnalysis = analysis;
        return analysis;
    }

    /**
     * Generate AI suggestions based on context
     * @param {Object} context - Current context (command, output, etc.)
     * @returns {Array} Array of intelligent suggestions
     */
    generateSuggestions(context = {}) {
        const suggestions = [];

        // Analyze recent output
        if (this.lastAnalysis) {
            if (this.lastAnalysis.hasErrors) {
                suggestions.push({
                    type: 'error',
                    icon: 'alert-circle',
                    title: `${this.lastAnalysis.errors.length} erreur(s) détectée(s)`,
                    text: 'Des erreurs ont été détectées dans la sortie. Cliquez pour voir les détails.',
                    actions: [{
                        label: 'Voir les erreurs',
                        command: 'show-errors'
                    }]
                });
            }

            if (this.lastAnalysis.hasWarnings && !this.lastAnalysis.hasErrors) {
                suggestions.push({
                    type: 'warning',
                    icon: 'alert-triangle',
                    title: `${this.lastAnalysis.warnings.length} avertissement(s)`,
                    text: 'Quelques avertissements à surveiller.',
                    actions: [{
                        label: 'Voir les détails',
                        command: 'show-warnings'
                    }]
                });
            }

            if (this.lastAnalysis.hasSuccess && !this.lastAnalysis.hasErrors && !this.lastAnalysis.hasWarnings) {
                suggestions.push({
                    type: 'success',
                    icon: 'check-circle',
                    title: 'Opération réussie',
                    text: `${this.lastAnalysis.successes.length} opération(s) complétée(s) avec succès.`,
                    actions: []
                });
            }
        }

        // Context-based suggestions
        if (context.command) {
            if (context.command.includes('docker')) {
                suggestions.push({
                    type: 'info',
                    icon: 'info',
                    title: 'Commande Docker détectée',
                    text: 'Vous pouvez vérifier les logs avec `docker logs <container>`',
                    actions: []
                });
            }

            if (context.command.includes('install')) {
                suggestions.push({
                    type: 'info',
                    icon: 'info',
                    title: 'Installation en cours',
                    text: 'Surveillez la sortie pour détecter d\'éventuelles erreurs.',
                    actions: []
                });
            }
        }

        return suggestions;
    }

    /**
     * Get command suggestions based on history and context
     * @param {string} partialCommand - Partial command typed by user
     * @returns {Array} Suggested commands
     */
    suggestCommands(partialCommand = '') {
        const commonCommands = [
            { cmd: 'docker ps', description: 'Liste les conteneurs actifs' },
            { cmd: 'docker compose up -d', description: 'Démarre les services' },
            { cmd: 'docker compose down', description: 'Arrête les services' },
            { cmd: 'docker logs', description: 'Affiche les logs d\'un conteneur' },
            { cmd: 'docker system prune', description: 'Nettoie Docker' },
            { cmd: 'systemctl status', description: 'Vérifie le statut d\'un service' },
            { cmd: 'sudo apt update', description: 'Met à jour les paquets' },
            { cmd: 'df -h', description: 'Affiche l\'espace disque' },
            { cmd: 'free -h', description: 'Affiche la mémoire disponible' }
        ];

        if (!partialCommand) {
            return commonCommands;
        }

        // Filter based on partial command
        return commonCommands.filter(item =>
            item.cmd.toLowerCase().includes(partialCommand.toLowerCase())
        );
    }

    /**
     * Detect command intent and provide help
     * @param {string} command - Command to analyze
     * @returns {Object} Intent analysis
     */
    detectIntent(command) {
        const intents = {
            docker_management: /docker (ps|compose|logs|system)/i,
            system_info: /(df|free|top|htop|uptime)/i,
            service_management: /systemctl (start|stop|restart|status)/i,
            package_management: /(apt|dpkg) (install|update|upgrade)/i,
            network: /(ping|curl|wget|netstat|ss)/i
        };

        for (const [intent, pattern] of Object.entries(intents)) {
            if (pattern.test(command)) {
                return {
                    intent,
                    confidence: 0.9,
                    help: this.getHelpForIntent(intent)
                };
            }
        }

        return {
            intent: 'unknown',
            confidence: 0.1,
            help: 'Commande non reconnue. Tapez `help` pour voir les commandes disponibles.'
        };
    }

    /**
     * Get contextual help for intent
     */
    getHelpForIntent(intent) {
        const helpTexts = {
            docker_management: 'Gestion Docker : Utilisez `docker ps` pour voir les conteneurs, `docker logs <name>` pour les logs.',
            system_info: 'Info système : Ces commandes affichent l\'état de votre système.',
            service_management: 'Gestion services : Utilisez `sudo systemctl status <service>` pour vérifier un service.',
            package_management: 'Gestion paquets : N\'oubliez pas `sudo` pour installer des paquets.',
            network: 'Réseau : Ces commandes diagnostiquent la connectivité réseau.'
        };

        return helpTexts[intent] || 'Aucune aide disponible.';
    }

    /**
     * Learn from user interactions
     * @param {Object} interaction - User interaction data
     */
    learn(interaction) {
        // Store command in history
        this.commandHistory.push({
            timestamp: Date.now(),
            command: interaction.command,
            success: interaction.success,
            context: interaction.context
        });

        // Keep only last 100 commands
        if (this.commandHistory.length > 100) {
            this.commandHistory.shift();
        }

        // TODO: Implement ML-based learning in future
        // For now, just store history for pattern recognition
    }

    /**
     * Get statistics about terminal usage
     */
    getStatistics() {
        return {
            totalCommands: this.commandHistory.length,
            totalOutputAnalyzed: this.outputHistory.length,
            errorRate: this.calculateErrorRate(),
            mostUsedCommands: this.getMostUsedCommands(),
            commonErrors: this.getCommonErrors()
        };
    }

    /**
     * Calculate error rate from history
     */
    calculateErrorRate() {
        if (this.outputHistory.length === 0) return 0;

        const errorsCount = this.outputHistory.filter(entry =>
            entry.analysis.hasErrors
        ).length;

        return ((errorsCount / this.outputHistory.length) * 100).toFixed(2);
    }

    /**
     * Get most used commands
     */
    getMostUsedCommands() {
        const commandCounts = {};

        this.commandHistory.forEach(entry => {
            const cmd = entry.command.split(' ')[0]; // Get first word
            commandCounts[cmd] = (commandCounts[cmd] || 0) + 1;
        });

        return Object.entries(commandCounts)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 5)
            .map(([cmd, count]) => ({ command: cmd, count }));
    }

    /**
     * Get most common errors
     */
    getCommonErrors() {
        const errorCounts = {};

        this.outputHistory.forEach(entry => {
            if (entry.analysis.hasErrors) {
                entry.analysis.errors.forEach(error => {
                    const key = error.line.substring(0, 50); // First 50 chars
                    errorCounts[key] = (errorCounts[key] || 0) + 1;
                });
            }
        });

        return Object.entries(errorCounts)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 3)
            .map(([error, count]) => ({ error, count }));
    }

    /**
     * Reset brain (clear history)
     */
    reset() {
        this.outputHistory = [];
        this.commandHistory = [];
        this.lastAnalysis = null;
    }
}

// Export for use in other modules
if (typeof window !== 'undefined') {
    window.TerminalAIBrain = TerminalAIBrain;
}
