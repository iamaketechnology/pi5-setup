// =============================================================================
// Add Pi Modal Module
// =============================================================================

class AddPiModal {
    constructor() {
        this.modal = document.getElementById('add-pi-modal');
        this.steps = {
            instructions: document.getElementById('add-pi-step-instructions'),
            manual: document.getElementById('add-pi-step-manual'),
            pairing: document.getElementById('add-pi-step-pairing'),
            success: document.getElementById('add-pi-step-success')
        };

        this.elements = {
            // Buttons
            btnAddPi: document.getElementById('btn-add-pi'),
            btnClose: document.getElementById('close-add-pi-modal'),
            btnGotoManual: document.getElementById('goto-manual-mode'),
            btnBackFromManual: document.getElementById('back-from-manual'),
            btnGotoPairing: document.getElementById('goto-pairing-step'),
            btnBackToInstructions: document.getElementById('back-to-instructions'),
            btnPairPi: document.getElementById('pair-pi-btn'),
            btnCloseSuccess: document.getElementById('close-success-modal'),
            btnCopyBootstrap: document.getElementById('copy-bootstrap-cmd'),

            // Inputs
            pairingToken: document.getElementById('pairing-token'),

            // Manual form
            manualForm: document.getElementById('manual-pi-form'),
            manualName: document.getElementById('manual-pi-name'),
            manualHost: document.getElementById('manual-pi-host'),
            manualPort: document.getElementById('manual-pi-port'),
            manualUsername: document.getElementById('manual-pi-username'),
            manualPassword: document.getElementById('manual-pi-password'),
            manualTags: document.getElementById('manual-pi-tags'),
            manualColor: document.getElementById('manual-pi-color'),
            manualStatus: document.getElementById('manual-pi-status'),

            // Status
            pairingStatus: document.getElementById('pairing-status'),
            pairedPiInfo: document.getElementById('paired-pi-info'),

            // Command
            bootstrapCommand: document.getElementById('bootstrap-command')
        };

        this.currentStep = 'instructions';
        this.init();
    }

    init() {
        // Open modal
        this.elements.btnAddPi?.addEventListener('click', () => this.open());

        // Close modal
        this.elements.btnClose?.addEventListener('click', () => this.close());
        this.modal?.addEventListener('click', (e) => {
            if (e.target === this.modal) this.close();
        });

        // Step navigation
        this.elements.btnGotoManual?.addEventListener('click', () => this.showStep('manual'));
        this.elements.btnBackFromManual?.addEventListener('click', () => this.showStep('instructions'));
        this.elements.btnGotoPairing?.addEventListener('click', () => this.showStep('pairing'));
        this.elements.btnBackToInstructions?.addEventListener('click', () => this.showStep('instructions'));

        // Copy bootstrap command
        this.elements.btnCopyBootstrap?.addEventListener('click', () => this.copyBootstrapCommand());

        // Manual form submit
        this.elements.manualForm?.addEventListener('submit', (e) => {
            e.preventDefault();
            this.addPiManually();
        });

        // Pair Pi
        this.elements.btnPairPi?.addEventListener('click', () => this.pairPi());
        this.elements.pairingToken?.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.pairPi();
        });

        // Close success modal
        this.elements.btnCloseSuccess?.addEventListener('click', () => this.close());

        // Set bootstrap command URL
        this.updateBootstrapCommand();
    }

    async updateBootstrapCommand() {
        // Try to get Mac IP from server
        let macIp = null;
        try {
            const response = await fetch('/api/network/local-ip');
            const data = await response.json();
            if (data.success && data.ip) {
                macIp = data.ip;
            }
        } catch (error) {
            console.warn('Failed to get local IP:', error);
        }

        // Fallback to localhost if IP detection fails
        const host = macIp || window.location.hostname;
        const port = window.location.port ? `:${window.location.port}` : '';
        const protocol = window.location.protocol;

        const controlCenterUrl = `${protocol}//${host}${port}`;
        const command = `curl -fsSL ${controlCenterUrl}/bootstrap | sudo bash`;

        if (this.elements.bootstrapCommand) {
            this.elements.bootstrapCommand.textContent = command;
        }
    }

    open() {
        this.modal?.classList.remove('hidden');
        this.showStep('instructions');
        this.elements.pairingToken.value = '';
        this.elements.pairingStatus.classList.add('hidden');
    }

    close() {
        this.modal?.classList.add('hidden');
        this.currentStep = 'instructions';
    }

    showStep(step) {
        // Hide all steps
        Object.values(this.steps).forEach(el => el?.classList.add('hidden'));

        // Show requested step
        this.steps[step]?.classList.remove('hidden');
        this.currentStep = step;

        // Focus on token input if pairing step
        if (step === 'pairing') {
            setTimeout(() => this.elements.pairingToken?.focus(), 100);
        }
    }

    copyBootstrapCommand() {
        const command = this.elements.bootstrapCommand.textContent;

        navigator.clipboard.writeText(command).then(() => {
            window.showToast?.('Commande copiée !', 'success');
        }).catch(err => {
            console.error('Failed to copy:', err);
            window.showToast?.('Échec de la copie', 'error');
        });
    }

    async pairPi() {
        const token = this.elements.pairingToken.value.trim();

        if (!token) {
            this.showPairingStatus('error', 'Veuillez entrer un token');
            return;
        }

        // Disable button and show loading
        this.elements.btnPairPi.disabled = true;
        this.showPairingStatus('loading', 'Appairage en cours...');

        try {
            const response = await fetch('/api/pis/pair', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ token })
            });

            const data = await response.json();

            if (response.ok && data.success) {
                // Success
                this.showPairingStatus('success', data.message);

                // Update success step info
                const piInfo = `${data.pi.name} (${data.pi.hostname})`;
                this.elements.pairedPiInfo.textContent = piInfo;

                // Show success step after 1 second
                setTimeout(() => {
                    this.showStep('success');

                    // Refresh Pi selector
                    if (window.piSelectorManager) {
                        window.piSelectorManager.loadPis();
                    }

                    // Emit event for other modules
                    document.dispatchEvent(new CustomEvent('pi-added', {
                        detail: data.pi
                    }));

                    window.showToast?.(`Pi ${data.pi.name} appairé avec succès !`, 'success');
                }, 1000);

            } else {
                // Error
                this.showPairingStatus('error', data.error || 'Échec de l\'appairage');
            }

        } catch (error) {
            console.error('Pairing error:', error);
            this.showPairingStatus('error', `Erreur réseau : ${error.message}`);
        } finally {
            this.elements.btnPairPi.disabled = false;
        }
    }

    async addPiManually() {
        const piData = {
            name: this.elements.manualName.value.trim(),
            hostname: this.elements.manualHost.value.trim(),
            port: parseInt(this.elements.manualPort.value),
            username: this.elements.manualUsername.value.trim(),
            password: this.elements.manualPassword.value || null,
            tags: this.elements.manualTags.value.split(',').map(t => t.trim()).filter(t => t),
            color: this.elements.manualColor.value
        };

        if (!piData.name || !piData.hostname || !piData.username) {
            this.showManualStatus('error', 'Veuillez remplir tous les champs requis');
            return;
        }

        // Show loading
        this.showManualStatus('loading', 'Ajout en cours...');

        try {
            const response = await fetch('/api/pis', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(piData)
            });

            const data = await response.json();

            if (response.ok && data.success) {
                // Success
                this.showManualStatus('success', 'Pi ajouté avec succès !');

                // Update success step info
                const piInfo = `${data.pi.name} (${data.pi.hostname}:${data.pi.port})`;
                this.elements.pairedPiInfo.textContent = piInfo;

                // Show success step after 1 second
                setTimeout(() => {
                    this.showStep('success');

                    // Refresh Pi selector
                    if (window.piSelectorManager) {
                        window.piSelectorManager.loadPis();
                    }

                    // Emit event for other modules
                    document.dispatchEvent(new CustomEvent('pi-added', {
                        detail: data.pi
                    }));

                    window.showToast?.(`Pi ${data.pi.name} ajouté avec succès !`, 'success');
                }, 1000);

            } else {
                // Error
                this.showManualStatus('error', data.error || 'Échec de l\'ajout');
            }

        } catch (error) {
            console.error('Add Pi manually error:', error);
            this.showManualStatus('error', `Erreur réseau : ${error.message}`);
        }
    }

    showManualStatus(type, message) {
        const status = this.elements.manualStatus;
        if (!status) return;

        status.className = 'manual-pi-status';
        status.classList.add(type);
        status.classList.remove('hidden');

        const icon = type === 'success' ? 'check-circle' :
                     type === 'error' ? 'x-circle' : 'loader';

        status.innerHTML = `
            <i data-lucide="${icon}" size="16"></i>
            <span>${message}</span>
        `;

        // Refresh Lucide icons
        if (window.lucide) {
            window.lucide.createIcons();
        }
    }

    showPairingStatus(type, message) {
        const status = this.elements.pairingStatus;
        if (!status) return;

        status.className = 'pairing-status';
        status.classList.add(type);
        status.classList.remove('hidden');

        const icon = type === 'success' ? 'check-circle' :
                     type === 'error' ? 'x-circle' : 'loader';

        status.innerHTML = `
            <i data-lucide="${icon}" size="16"></i>
            <span>${message}</span>
        `;

        // Refresh Lucide icons
        if (window.lucide) {
            window.lucide.createIcons();
        }
    }
}

// Initialize on DOM load
let addPiModal;
document.addEventListener('DOMContentLoaded', () => {
    addPiModal = new AddPiModal();
});

export { AddPiModal };
