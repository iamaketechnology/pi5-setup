// =============================================================================
// Database Security Module
// =============================================================================
import api from '../utils/api.js';

class DatabaseSecurityManager {
    constructor() {
        this.isAuditing = false;
    }

    init() {
        this.setupEventListeners();
        console.log('✅ Database Security module initialized');
    }

    load() {
        // Called when database tab is loaded
        console.log('📊 Database tab loaded');
    }

    setupEventListeners() {
        const runAuditBtn = document.getElementById('run-security-audit');
        const viewDocsBtn = document.getElementById('view-security-docs');

        if (runAuditBtn) {
            runAuditBtn.addEventListener('click', () => this.runSecurityAudit());
        }

        if (viewDocsBtn) {
            viewDocsBtn.addEventListener('click', () => this.viewDocumentation());
        }
    }

    async runSecurityAudit() {
        if (this.isAuditing) return;

        this.isAuditing = true;
        const btn = document.getElementById('run-security-audit');
        const resultsDiv = document.getElementById('security-audit-results');

        const originalHTML = btn.innerHTML;
        btn.disabled = true;
        btn.innerHTML = '<i data-lucide="loader-2" size="18" class="spinning"></i><span>Audit en cours...</span>';
        if (window.lucide) window.lucide.createIcons();

        resultsDiv.style.display = 'block';
        resultsDiv.innerHTML = '<div class="audit-loading"><i data-lucide="loader-2" size="24" class="spinning"></i><p>Vérification...</p></div>';
        if (window.lucide) window.lucide.createIcons();

        try {
            const response = await api.post('/database/security-audit');
            this.displayResults(response);
        } catch (error) {
            resultsDiv.innerHTML = `<div class="audit-error"><i data-lucide="alert-circle" size="32"></i><h4>❌ Erreur</h4><p>${error.message}</p></div>`;
            if (window.lucide) window.lucide.createIcons();
        } finally {
            this.isAuditing = false;
            btn.disabled = false;
            btn.innerHTML = originalHTML;
            if (window.lucide) window.lucide.createIcons();
        }
    }

    displayResults(data) {
        const resultsDiv = document.getElementById('security-audit-results');

        if (data.secure) {
            const databasesList = data.databases && data.databases.length > 0
                ? data.databases.map(db => `
                    <div style="display: flex; align-items: center; gap: 8px; padding: 8px; background: rgba(16,185,129,0.1); border-radius: 6px; margin: 4px 0;">
                        <i data-lucide="database" size="16" style="color: #10b981;"></i>
                        <span style="font-weight: 500;">${db.name}</span>
                        <span style="color: #6b7280; font-size: 12px;">(${db.container})</span>
                        <i data-lucide="check-circle" size="16" style="color: #10b981; margin-left: auto;"></i>
                    </div>
                `).join('')
                : '<p style="color: #6b7280; font-size: 14px;">Aucune base détectée</p>';

            resultsDiv.innerHTML = `
                <div class="audit-success" style="padding: 24px; background: linear-gradient(135deg, rgba(16,185,129,0.1), rgba(16,185,129,0.05)); border: 2px solid #10b981; border-radius: 12px;">
                    <div style="text-align: center;">
                        <i data-lucide="shield-check" size="48" style="color: #10b981;"></i>
                        <h3 style="margin: 16px 0; color: #10b981;">🎉 Toutes les Bases Sécurisées !</h3>
                        <p>${data.message}</p>
                        <div style="margin: 20px 0; padding: 16px; background: rgba(255,255,255,0.8); border-radius: 8px; display: flex; gap: 20px; justify-content: center;">
                            <div>
                                <div style="font-size: 32px; font-weight: bold; color: #10b981;">${data.totalDatabases}</div>
                                <div style="font-size: 12px; color: #6b7280;">Bases auditées</div>
                            </div>
                            <div>
                                <div style="font-size: 32px; font-weight: bold; color: #10b981;">${data.secureDatabases}</div>
                                <div style="font-size: 12px; color: #6b7280;">Sécurisées</div>
                            </div>
                            <div>
                                <div style="font-size: 32px; font-weight: bold; color: #10b981;">12</div>
                                <div style="font-size: 12px; color: #6b7280;">Checks effectués</div>
                            </div>
                        </div>
                    </div>

                    <div style="margin-top: 24px; padding: 16px; background: rgba(255,255,255,0.9); border-radius: 8px; text-align: left;">
                        <h4 style="margin: 0 0 12px 0; font-size: 14px; font-weight: 600; color: #374151;">
                            <i data-lucide="server" size="16"></i> Bases de données auditées
                        </h4>
                        ${databasesList}
                    </div>

                    <div style="text-align: center; margin-top: 16px;">
                        <button onclick="databaseSecurityManager.showFullReport()" class="btn btn-ghost">
                            <i data-lucide="file-text" size="18"></i>
                            <span>Voir rapport complet</span>
                        </button>
                    </div>
                </div>
            `;
        } else {
            const databasesList = data.databases && data.databases.length > 0
                ? data.databases.map(db => `
                    <div style="display: flex; align-items: center; gap: 8px; padding: 8px; background: ${db.status === 'secure' ? 'rgba(16,185,129,0.1)' : 'rgba(239,68,68,0.1)'}; border-radius: 6px; margin: 4px 0;">
                        <i data-lucide="database" size="16" style="color: ${db.status === 'secure' ? '#10b981' : '#ef4444'};"></i>
                        <span style="font-weight: 500;">${db.name}</span>
                        <span style="color: #6b7280; font-size: 12px;">(${db.container})</span>
                        <i data-lucide="${db.status === 'secure' ? 'check-circle' : 'alert-circle'}" size="16" style="color: ${db.status === 'secure' ? '#10b981' : '#ef4444'}; margin-left: auto;"></i>
                    </div>
                `).join('')
                : '<p style="color: #6b7280; font-size: 14px;">Aucune base détectée</p>';

            resultsDiv.innerHTML = `
                <div class="audit-warning" style="padding: 24px; background: linear-gradient(135deg, rgba(245,158,11,0.1), rgba(245,158,11,0.05)); border: 2px solid #f59e0b; border-radius: 12px;">
                    <div style="text-align: center;">
                        <i data-lucide="alert-triangle" size="48" style="color: #f59e0b;"></i>
                        <h3 style="margin: 16px 0; color: #f59e0b;">⚠️ Problèmes de Sécurité Détectés</h3>
                        <p>${data.message}</p>
                        <div style="margin: 20px 0; padding: 16px; background: rgba(255,255,255,0.8); border-radius: 8px; display: flex; gap: 20px; justify-content: center;">
                            <div>
                                <div style="font-size: 32px; font-weight: bold; color: #3b82f6;">${data.totalDatabases}</div>
                                <div style="font-size: 12px; color: #6b7280;">Bases auditées</div>
                            </div>
                            <div>
                                <div style="font-size: 32px; font-weight: bold; color: #10b981;">${data.secureDatabases}</div>
                                <div style="font-size: 12px; color: #6b7280;">Sécurisées</div>
                            </div>
                            <div>
                                <div style="font-size: 32px; font-weight: bold; color: #ef4444;">${data.vulnerableDatabases}</div>
                                <div style="font-size: 12px; color: #6b7280;">Vulnérables</div>
                            </div>
                        </div>
                    </div>

                    <div style="margin-top: 24px; padding: 16px; background: rgba(255,255,255,0.9); border-radius: 8px; text-align: left;">
                        <h4 style="margin: 0 0 12px 0; font-size: 14px; font-weight: 600; color: #374151;">
                            <i data-lucide="server" size="16"></i> Bases de données auditées
                        </h4>
                        ${databasesList}
                    </div>

                    <div style="text-align: center; margin-top: 16px;">
                        <button onclick="databaseSecurityManager.showFullReport()" class="btn btn-primary">
                            <i data-lucide="file-text" size="18"></i>
                            <span>Voir rapport détaillé</span>
                        </button>
                    </div>
                </div>
            `;
        }

        // Store full output for detailed view
        this.lastAuditOutput = data.fullOutput;

        if (window.lucide) window.lucide.createIcons();
    }

    showFullReport() {
        if (!this.lastAuditOutput) {
            alert('Aucun rapport disponible. Lancez un audit d\'abord.');
            return;
        }

        // Create modal
        const modal = document.createElement('div');
        modal.className = 'logs-modal';
        modal.innerHTML = `
            <div class="logs-modal-overlay" onclick="this.parentElement.remove()"></div>
            <div class="logs-modal-content">
                <div class="logs-modal-header">
                    <h3><i data-lucide="shield-check" size="18"></i> Rapport de Sécurité Complet</h3>
                    <button class="btn-close" onclick="this.closest('.logs-modal').remove()">
                        <i data-lucide="x" size="18"></i>
                    </button>
                </div>
                <pre class="logs-content">${this.escapeHtml(this.lastAuditOutput)}</pre>
            </div>
        `;

        document.body.appendChild(modal);

        if (window.lucide) window.lucide.createIcons();
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    viewDocumentation() {
        alert('Documentation : voir /certidoc-proof/docs/SECURITY-AUDIT.md');
    }
}

const databaseSecurityManager = new DatabaseSecurityManager();
export default databaseSecurityManager;
window.databaseSecurityManager = databaseSecurityManager;
