// =============================================================================
// Pi Selector Module - Multi-Pi Management
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

import api from '../utils/api.js';

class PiSelectorManager {
    constructor() {
        this.allPis = [];
        this.currentPiId = null;
        this.switchCallbacks = [];
    }

    init() {
        this.setupEventListeners();
        this.loadPis();
        console.log('✅ Pi Selector module initialized');
    }

    setupEventListeners() {
        const selector = document.getElementById('pi-selector');
        if (!selector) return;

        selector.addEventListener('change', (e) => {
            const selectedPiId = e.target.value;
            this.switchPi(selectedPiId);
        });
    }

    /**
     * Register a callback to be called when Pi is switched
     * @param {Function} callback - Function to call after Pi switch
     */
    onPiSwitch(callback) {
        this.switchCallbacks.push(callback);
    }

    async loadPis() {
        try {
            const data = await api.get('/pis');
            this.allPis = data.pis;
            this.currentPiId = data.current;
            window.allPis = this.allPis;
            window.currentPiId = this.currentPiId;

            this.renderPiSelector();

            // Auto-select first Pi if none is selected
            if (!this.currentPiId && this.allPis.length > 0) {
                console.log('🔄 No Pi selected, auto-selecting first available Pi...');
                await this.switchPi(this.allPis[0].id);
                return; // switchPi will handle the rest
            }

            // Update terminal prompt with current Pi
            const currentPi = this.allPis.find(p => p.id === this.currentPiId);
            if (currentPi && window.terminalManager) {
                window.terminalManager.updatePrompt(currentPi);
            }

            this.updatePiContext(currentPi);

            window.dispatchEvent(new CustomEvent('pi:list-updated', {
                detail: { pis: this.allPis }
            }));
        } catch (error) {
            console.error('Failed to load Pis:', error);
        }
    }

    renderPiSelector() {
        const selector = document.getElementById('pi-selector');
        if (!selector) return;

        selector.innerHTML = this.allPis.map(pi => {
            const statusLabel = pi.connected ? '[OK]' : '[OFF]';
            const selected = pi.id === this.currentPiId ? 'selected' : '';
            return `<option value="${pi.id}" ${selected}>${statusLabel} ${pi.name}</option>`;
        }).join('');
    }

    async switchPi(piId) {
        try {
            const result = await api.post('/pis/select', { piId });

            if (result.success) {
                this.currentPiId = piId;
                window.currentPiId = piId;

                // Notify terminal
                if (window.terminalManager) {
                    window.terminalManager.addLine(
                        `✅ Switched to ${result.pi.name} (${result.pi.host})`,
                        'success'
                    );
                    // Update terminal prompt
                    window.terminalManager.updatePrompt(result.pi);
                }

                // Call registered callbacks
                this.switchCallbacks.forEach(callback => {
                    try {
                        callback(piId, result.pi);
                    } catch (error) {
                        console.error('Error in Pi switch callback:', error);
                    }
                });

                // Emit custom event
                window.dispatchEvent(new CustomEvent('pi:switched', {
                    detail: { piId, pi: result.pi }
                }));

                this.updatePiContext(result.pi);
                window.dispatchEvent(new CustomEvent('pi:list-updated', {
                    detail: { pis: this.allPis }
                }));
            } else {
                if (window.terminalManager) {
                    window.terminalManager.addLine(
                        `❌ Failed to switch Pi: ${result.error}`,
                        'error'
                    );
                }
            }
        } catch (error) {
            console.error('Error switching Pi:', error);
            if (window.terminalManager) {
                window.terminalManager.addLine(
                    `❌ Error switching Pi: ${error.message}`,
                    'error'
                );
            }
        }
    }

    getCurrentPi() {
        return this.allPis.find(pi => pi.id === this.currentPiId);
    }

    getCurrentPiId() {
        return this.currentPiId;
    }

    getAllPis() {
        return this.allPis;
    }

    updatePiContext(pi) {
        if (!window.uiStatus) return;

        // Update footer Pi status
        if (window.footerManager) {
            if (pi) {
                const statusLabel = pi.connected ? pi.name : `${pi.name} (OFF)`;
                const state = pi.connected ? 'connected' : 'disconnected';
                window.footerManager.updatePiStatus(statusLabel, state);
            } else {
                window.footerManager.updatePiStatus('Aucun Pi', 'disconnected');
            }
        }

        if (pi) {
            const hostInfo = [pi.host, pi.ip].filter(Boolean).join(' • ');
            window.uiStatus.summary.setPi(pi.name, hostInfo || 'Connexion active');
            window.uiStatus.header.set('ssh', {
                state: pi.connected ? 'ok' : 'error',
                value: pi.connected ? 'Connecté' : 'Déconnecté',
                tooltip: hostInfo || ''
            });

            if (pi.connected) {
                window.uiStatus.summary.setAlerts('ssh', null);
            } else {
                window.uiStatus.summary.setAlerts('ssh', {
                    message: `${pi.name} est injoignable en SSH`,
                    priority: 5
                });
            }
        } else {
            window.uiStatus.summary.setPi('Aucun Pi sélectionné', 'Choisissez un Pi pour commencer');
            window.uiStatus.header.set('ssh', {
                state: 'warning',
                value: 'En attente',
                tooltip: 'Sélectionnez un Pi'
            });
            window.uiStatus.summary.setAlerts('ssh', {
                message: 'Aucun Pi sélectionné',
                priority: 1
            });
        }
    }
}

// Export singleton
const piSelectorManager = new PiSelectorManager();
export default piSelectorManager;

// Make available globally
window.piSelectorManager = piSelectorManager;
