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
