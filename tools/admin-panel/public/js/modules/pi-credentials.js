// =============================================================================
// Pi Credentials Module
// =============================================================================
// Displays current Pi credentials (username, host, SSH key info)
// =============================================================================

import api from '../utils/api.js';
import piSelectorManager from './pi-selector.js';

class PiCredentialsManager {
    constructor() {
        this.visible = false;
    }

    init() {
        this.setupEventListeners();
        console.log('✅ Pi Credentials module initialized');
    }

    setupEventListeners() {
        const toggleBtn = document.getElementById('toggle-credentials');
        if (toggleBtn) {
            toggleBtn.addEventListener('click', () => this.toggleVisibility());
        }

        // Listen to Pi switch events
        window.addEventListener('pi:switched', () => {
            if (this.visible) {
                this.load();
            }
        });
    }

    async toggleVisibility() {
        this.visible = !this.visible;
        const container = document.getElementById('pi-credentials');
        const toggleBtn = document.getElementById('toggle-credentials');

        if (!container || !toggleBtn) return;

        if (this.visible) {
            container.classList.remove('hidden');
            toggleBtn.textContent = '👁️ Masquer';
            await this.load();
        } else {
            container.classList.add('hidden');
            toggleBtn.textContent = '👁️ Afficher';
        }
    }

    async load() {
        const container = document.getElementById('pi-credentials');
        if (!container) return;

        try {
            container.innerHTML = '<div class="loading">Chargement...</div>';

            const data = await api.get('/pis');
            const currentPi = data.pis.find(p => p.id === data.current);

            if (!currentPi) {
                container.innerHTML = '<div class="error">❌ Aucun Pi sélectionné</div>';
                return;
            }

            container.innerHTML = this.renderCredentials(currentPi);
        } catch (error) {
            console.error('Failed to load Pi credentials:', error);
            container.innerHTML = '<div class="error">❌ Erreur chargement credentials</div>';
        }
    }

    renderCredentials(pi) {
        const hasPassword = !!pi.password;
        const hasPrivateKey = !!pi.privateKey;

        return `
            <div class="credentials-grid">
                <div class="credential-item">
                    <div class="credential-label">🖥️ Hostname</div>
                    <div class="credential-value">${pi.host}</div>
                    <button class="btn-copy" onclick="navigator.clipboard.writeText('${pi.host}')">📋</button>
                </div>

                <div class="credential-item">
                    <div class="credential-label">🔌 Port SSH</div>
                    <div class="credential-value">${pi.port || 22}</div>
                    <button class="btn-copy" onclick="navigator.clipboard.writeText('${pi.port || 22}')">📋</button>
                </div>

                <div class="credential-item">
                    <div class="credential-label">👤 Username</div>
                    <div class="credential-value">${pi.username}</div>
                    <button class="btn-copy" onclick="navigator.clipboard.writeText('${pi.username}')">📋</button>
                </div>

                ${hasPassword ? `
                <div class="credential-item">
                    <div class="credential-label">🔑 Password</div>
                    <div class="credential-value password-value">
                        <span class="password-hidden">••••••••</span>
                        <span class="password-shown hidden">${this.escapeHtml(pi.password)}</span>
                    </div>
                    <button class="btn-toggle-password" onclick="window.piCredentialsManager.togglePassword(this)">👁️</button>
                    <button class="btn-copy" onclick="navigator.clipboard.writeText('${this.escapeHtml(pi.password)}')">📋</button>
                </div>
                ` : ''}

                <div class="credential-item full-width">
                    <div class="credential-label">🔐 Auth Method</div>
                    <div class="credential-value">
                        ${hasPrivateKey ? '🔑 SSH Key (Private Key)' : hasPassword ? '🔒 Password' : '❓ Unknown'}
                    </div>
                </div>

                ${hasPrivateKey ? `
                <div class="credential-item full-width">
                    <div class="credential-label">📝 SSH Command</div>
                    <div class="credential-value code">
                        ssh ${pi.username}@${pi.host} -p ${pi.port || 22}
                    </div>
                    <button class="btn-copy" onclick="navigator.clipboard.writeText('ssh ${pi.username}@${pi.host} -p ${pi.port || 22}')">📋</button>
                </div>
                ` : ''}

                <div class="credential-item full-width">
                    <div class="credential-label">🏷️ Tags</div>
                    <div class="credential-value">
                        ${(pi.tags || []).map(tag => `<span class="tag">${tag}</span>`).join('')}
                    </div>
                </div>

                <div class="credential-item full-width">
                    <div class="credential-label">📂 Remote Paths</div>
                    <div class="credential-paths">
                        <div><strong>Stacks:</strong> ${pi.remoteStacksDir || '/home/pi/stacks'}</div>
                        <div><strong>Temp:</strong> ${pi.remoteTempDir || '/tmp'}</div>
                    </div>
                </div>
            </div>
        `;
    }

    togglePassword(button) {
        const item = button.closest('.credential-item');
        const hidden = item.querySelector('.password-hidden');
        const shown = item.querySelector('.password-shown');

        hidden.classList.toggle('hidden');
        shown.classList.toggle('hidden');
        button.textContent = hidden.classList.contains('hidden') ? '🙈' : '👁️';
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Export singleton
const piCredentialsManager = new PiCredentialsManager();
export default piCredentialsManager;

// Make available globally
window.piCredentialsManager = piCredentialsManager;
