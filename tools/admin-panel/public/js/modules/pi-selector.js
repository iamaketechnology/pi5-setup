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

            this.renderPiSelector();

            // Update terminal prompt with current Pi
            const currentPi = this.allPis.find(p => p.id === this.currentPiId);
            if (currentPi && window.terminalManager) {
                window.terminalManager.updatePrompt(currentPi);
            }
        } catch (error) {
            console.error('Failed to load Pis:', error);
        }
    }

    renderPiSelector() {
        const selector = document.getElementById('pi-selector');
        if (!selector) return;

        selector.innerHTML = this.allPis.map(pi => {
            const statusIcon = pi.connected ? '🟢' : '🔴';
            const selected = pi.id === this.currentPiId ? 'selected' : '';
            return `<option value="${pi.id}" ${selected}>${statusIcon} ${pi.name}</option>`;
        }).join('');
    }

    async switchPi(piId) {
        try {
            const result = await api.post('/pis/select', { piId });

            if (result.success) {
                this.currentPiId = piId;

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
}

// Export singleton
const piSelectorManager = new PiSelectorManager();
export default piSelectorManager;

// Make available globally
window.piSelectorManager = piSelectorManager;
