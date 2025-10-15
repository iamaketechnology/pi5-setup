// =============================================================================
// Setup Wizard Module
// =============================================================================
// Checks Pi setup status and displays progress
// =============================================================================

import api from '../utils/api.js';

class SetupWizardManager {
    constructor() {
        this.setupSteps = [
            { id: 'docker', name: 'Docker installé', check: 'docker' },
            { id: 'network', name: 'Configuration réseau', check: 'network' },
            { id: 'security', name: 'Sécurité de base', check: 'security' },
            { id: 'traefik', name: 'Reverse Proxy (Traefik)', check: 'traefik' },
            { id: 'monitoring', name: 'Monitoring', check: 'monitoring' }
        ];
    }

    init() {
        this.setupEventListeners();
        this.load();
        console.log('✅ Setup Wizard module initialized');
    }

    setupEventListeners() {
        const dismissBtn = document.getElementById('dismiss-setup');
        if (dismissBtn) {
            dismissBtn.addEventListener('click', () => this.dismiss());
        }

        // Listen to Pi switch events
        window.addEventListener('pi:switched', () => this.load());
    }

    async load() {
        try {
            const data = await api.get('/setup-status');
            this.renderStatus(data.status || {});
        } catch (error) {
            console.error('Failed to load setup status:', error);
            // Fallback: show default state
            this.renderStatus({});
        }
    }

    renderStatus(status) {
        const panel = document.querySelector('.setup-panel');
        if (!panel) return;

        const steps = [
            {
                id: 'docker',
                title: 'Docker installé',
                desc: 'Environnement conteneurisé prêt',
                completed: status.docker || false,
                action: null
            },
            {
                id: 'network',
                title: 'Configuration réseau',
                desc: status.network?.configured
                    ? `IP: ${status.network.ip || 'N/A'}, Hostname: ${status.network.hostname || 'N/A'}`
                    : 'IP statique, hostname, DNS',
                completed: status.network?.configured || false,
                action: 'quickSetupNetwork()'
            },
            {
                id: 'security',
                title: 'Sécurité de base',
                desc: status.security?.services
                    ? `${status.security.services.join(', ')}`
                    : 'UFW, Fail2ban, SSH hardening',
                completed: status.security?.configured || false,
                action: 'quickSetupSecurity()'
            },
            {
                id: 'traefik',
                title: 'Reverse Proxy (Traefik)',
                desc: status.traefik?.running
                    ? `Running (${status.traefik.containers || 1} container${status.traefik.containers > 1 ? 's' : ''})`
                    : 'Routage et certificats SSL',
                completed: status.traefik?.running || false,
                action: 'quickSetupTraefik()'
            },
            {
                id: 'monitoring',
                title: 'Monitoring',
                desc: status.monitoring?.services
                    ? `${status.monitoring.services.join(', ')}`
                    : 'Prometheus, Grafana, Node Exporter',
                completed: status.monitoring?.running || false,
                action: 'quickSetupMonitoring()'
            }
        ];

        const checklist = panel.querySelector('.setup-checklist');
        if (!checklist) return;

        checklist.innerHTML = steps.map(step => `
            <div class="setup-item" data-step="${step.id}">
                <div class="setup-status">${step.completed ? '✅' : '⏸️'}</div>
                <div class="setup-info">
                    <div class="setup-title">${step.title}</div>
                    <div class="setup-desc">${step.desc}</div>
                </div>
                ${!step.completed && step.action ? `
                    <button class="btn btn-sm btn-primary" onclick="${step.action}">Configurer</button>
                ` : ''}
            </div>
        `).join('');

        // Update progress
        const completed = steps.filter(s => s.completed).length;
        const total = steps.length;
        const progressText = panel.querySelector('.setup-progress');
        if (progressText) {
            progressText.textContent = `${completed}/${total} étapes complétées`;
        }

        // Auto-dismiss if all completed
        if (completed === total) {
            setTimeout(() => this.dismiss(), 2000);
        }
    }

    dismiss() {
        const panel = document.querySelector('.setup-panel');
        if (panel) {
            panel.style.display = 'none';
            localStorage.setItem('setup-wizard-dismissed', 'true');
        }
    }
}

// Export singleton
const setupWizardManager = new SetupWizardManager();
export default setupWizardManager;

// Global functions for onclick handlers
window.quickSetupNetwork = () => {
    if (window.terminalManager) {
        window.terminalManager.executeCommand('sudo bash common-scripts/set-static-ip.sh');
    }
};

window.quickSetupSecurity = () => {
    if (window.terminalManager) {
        window.terminalManager.executeCommand('sudo bash common-scripts/01-system-hardening.sh');
    }
};

window.quickSetupTraefik = () => {
    if (window.terminalManager) {
        window.terminalManager.executeCommand('sudo bash common-scripts/03-traefik-setup.sh');
    }
};

window.quickSetupMonitoring = () => {
    if (window.terminalManager) {
        window.terminalManager.executeCommand('sudo bash 03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh');
    }
};
