// =============================================================================
// Footer Manager - System status bar
// =============================================================================

class FooterManager {
    constructor() {
        this.elements = {
            piStatus: document.getElementById('footer-pi-status'),
            version: document.getElementById('footer-version'),
            uptime: document.getElementById('footer-uptime'),
            cpu: document.getElementById('footer-cpu'),
            ram: document.getElementById('footer-ram')
        };
    }

    init() {
        // Initial state
        this.updateVersion('--');
        this.updatePiStatus('Déconnecté', 'disconnected');
    }

    updatePiStatus(name, state = 'connected') {
        if (!this.elements.piStatus) return;

        const span = this.elements.piStatus.querySelector('span');
        if (span) {
            span.textContent = name;
        }

        // Update status class
        this.elements.piStatus.className = 'footer-item';
        if (state === 'disconnected') {
            this.elements.piStatus.classList.add('disconnected');
        } else if (state === 'warning') {
            this.elements.piStatus.classList.add('warning');
        }
    }

    updateVersion(version) {
        if (this.elements.version) {
            this.elements.version.textContent = version;
        }
    }

    updateUptime(uptime) {
        if (this.elements.uptime) {
            this.elements.uptime.textContent = uptime || '--';
        }
    }

    updateCPU(percent) {
        if (this.elements.cpu) {
            this.elements.cpu.textContent = percent !== null ? `${percent}%` : '--';

            // Add warning/danger classes
            this.elements.cpu.classList.remove('warning', 'danger');
            if (percent >= 90) {
                this.elements.cpu.classList.add('danger');
            } else if (percent >= 75) {
                this.elements.cpu.classList.add('warning');
            }
        }
    }

    updateRAM(percent, used, total) {
        if (this.elements.ram) {
            if (percent !== null) {
                this.elements.ram.textContent = `${percent}%`;
            } else {
                this.elements.ram.textContent = '--';
            }

            // Add warning/danger classes
            this.elements.ram.classList.remove('warning', 'danger');
            if (percent >= 90) {
                this.elements.ram.classList.add('danger');
            } else if (percent >= 75) {
                this.elements.ram.classList.add('warning');
            }
        }
    }

    updateStats(stats) {
        if (!stats) return;

        // Update uptime
        if (stats.uptime) {
            this.updateUptime(stats.uptime);
        }

        // Update CPU
        if (stats.cpu !== undefined) {
            this.updateCPU(stats.cpu);
        }

        // Update RAM
        if (stats.ram !== undefined) {
            const ramPercent = Math.round(stats.ram);
            this.updateRAM(ramPercent);
        }
    }
}

// Export singleton
const footerManager = new FooterManager();
export default footerManager;
