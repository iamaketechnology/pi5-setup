// =============================================================================
// Network Monitoring Module
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

import api from '../utils/api.js';

class NetworkManager {
    constructor() {
        this.selectedInterface = 'eth0';
        this.bandwidthHistory = {};
        this.refreshInterval = null;
        this.refreshRate = 5000; // 5 seconds

        this.interfaces = [];
        this.firewallStatus = null;
        this.publicIp = null;
        this.listeningPorts = {};
        this.connections = [];

        this.interfacesLoaded = false;
        this.firewallStatusLoaded = false;
        this.publicIpLoaded = false;
        this.listeningPortsLoaded = false;
        this.connectionsLoaded = false;
    }

    init() {
        this.setupEventListeners();
        this.setupCollapsibleSections();
        this.updateOverview();
        this.load();
    }

    /**
     * Setup collapsible sections for tables
     */
    setupCollapsibleSections() {
        document.addEventListener('click', (e) => {
            if (e.target.matches('.collapse-toggle') || e.target.closest('.collapse-toggle')) {
                const btn = e.target.matches('.collapse-toggle') ? e.target : e.target.closest('.collapse-toggle');
                const targetId = btn.dataset.target;
                const target = document.getElementById(targetId);

                if (target) {
                    const isCollapsed = target.classList.toggle('collapsed');
                    btn.classList.toggle('collapsed', isCollapsed);

                    // Update icon
                    const icon = btn.querySelector('i[data-lucide]');
                    if (icon) {
                        icon.setAttribute('data-lucide', isCollapsed ? 'chevron-right' : 'chevron-down');
                        if (window.lucide) window.lucide.createIcons();
                    }
                }
            }
        });
    }

    setupEventListeners() {
        // Interface selector
        document.getElementById('network-interface-selector')?.addEventListener('change', (e) => {
            this.selectedInterface = e.target.value;
            this.loadBandwidthStats();
        });

        // Refresh buttons
        document.getElementById('refresh-network')?.addEventListener('click', () => this.load());
        document.getElementById('refresh-connections')?.addEventListener('click', () => this.loadConnections());
        document.getElementById('refresh-firewall')?.addEventListener('click', () => this.loadFirewall());

        // Test buttons
        document.getElementById('test-ping-btn')?.addEventListener('click', () => this.testPing());
        document.getElementById('test-dns-btn')?.addEventListener('click', () => this.testDNS());

        // Auto-refresh toggle
        document.getElementById('network-auto-refresh')?.addEventListener('change', (e) => {
            if (e.target.checked) {
                this.startAutoRefresh();
            } else {
                this.stopAutoRefresh();
            }
        });
    }

    async load() {
        await Promise.all([
            this.loadInterfaces(),
            this.loadBandwidthStats(),
            this.loadConnections(),
            this.loadFirewall(),
            this.loadPublicIP(),
            this.loadListeningPorts()
        ]);
    }

    async loadInterfaces() {
        try {
            const selectedPi = document.getElementById('pi-selector')?.value;
            const data = await api.get('/network/interfaces', { piId: selectedPi });

            this.renderInterfaces(data.interfaces);
        } catch (error) {
            console.error('Failed to load interfaces:', error);
            this.interfaces = [];
            this.interfacesLoaded = true;
            this.updateInterfaceSelector([]);
            this.updateOverview();
        }
    }

    renderInterfaces(interfaces = []) {
        this.interfaces = Array.isArray(interfaces) ? interfaces : [];
        this.interfacesLoaded = true;
        const container = document.getElementById('network-interfaces');
        if (!container) return;

        if (this.interfaces.length === 0) {
            container.innerHTML = '<p class="no-data">Aucune interface détectée</p>';
            this.updateInterfaceSelector([]);
            this.updateOverview();
            return;
        }

        const normalized = this.interfaces.map((iface) => ({
            ...iface,
            state: (iface.state || '').toUpperCase(),
            addresses: Array.isArray(iface.addresses) ? iface.addresses : []
        }));

        const active = normalized.filter((iface) => iface.state === 'UP');
        if (!active.find((iface) => iface.name === this.selectedInterface)) {
            this.selectedInterface = (active[0]?.name) || normalized[0].name;
        }

        const rows = normalized.map((iface) => {
            const ipv4 = iface.addresses.find((addr) => addr.family === 'inet')?.ip || '—';
            const ipv6 = iface.addresses.find((addr) => addr.family === 'inet6')?.ip || '—';
            const isSelected = iface.name === this.selectedInterface;
            const badgeClass = iface.state === 'UP' ? 'badge-success' : 'badge-secondary';
            return `
                <tr class="${isSelected ? 'is-selected' : ''}">
                    <td><code>${iface.name}</code></td>
                    <td><span class="badge ${badgeClass}">${iface.state}</span></td>
                    <td>${ipv4}</td>
                    <td>${ipv6}</td>
                    <td><code>${iface.mac || 'N/D'}</code></td>
                    <td>${iface.mtu || '—'}</td>
                </tr>
            `;
        }).join('');

        container.innerHTML = `
            <div class="collapsible-section">
                <button class="collapse-toggle" data-target="interfaces-table-content">
                    <i data-lucide="chevron-down" size="16"></i>
                    <span>Interfaces réseau (${normalized.length})</span>
                </button>
                <div id="interfaces-table-content" class="collapsible-content">
                    <table class="network-interfaces-table">
                        <thead>
                            <tr>
                                <th>Interface</th>
                                <th>État</th>
                                <th>IPv4</th>
                                <th>IPv6</th>
                                <th>MAC</th>
                                <th>MTU</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${rows}
                        </tbody>
                    </table>
                </div>
            </div>
        `;

        if (window.lucide) window.lucide.createIcons();

        this.updateInterfaceSelector(normalized);
        this.updateOverview();
    }

    updateInterfaceSelector(interfaces) {
        const selector = document.getElementById('network-interface-selector');
        if (!selector) return;

        if (!interfaces || interfaces.length === 0) {
            selector.innerHTML = '<option value="">Aucune interface</option>';
            selector.disabled = true;
            return;
        }

        selector.disabled = false;
        selector.innerHTML = interfaces.map((iface) => {
            const label = `${iface.name}${iface.state === 'UP' ? '' : ' (down)'}`;
            const selected = iface.name === this.selectedInterface ? 'selected' : '';
            return `<option value="${iface.name}" ${selected}>${label}</option>`;
        }).join('');
    }

    async loadBandwidthStats() {
        try {
            const selectedPi = document.getElementById('pi-selector')?.value;
            const data = await api.get('/network/bandwidth', {
                piId: selectedPi,
                interface: this.selectedInterface
            });

            if (data.stats) {
                this.updateBandwidthHistory(data.stats);
                this.renderBandwidthStats(data.stats);
            }
        } catch (error) {
            console.error('Failed to load bandwidth stats:', error);
        }
    }

    updateBandwidthHistory(stats) {
        if (!this.bandwidthHistory[stats.interface]) {
            this.bandwidthHistory[stats.interface] = [];
        }

        const history = this.bandwidthHistory[stats.interface];
        history.push(stats);

        // Keep last 60 data points (5 minutes at 5s intervals)
        if (history.length > 60) {
            history.shift();
        }

        // Calculate rate (bytes/sec)
        if (history.length > 1) {
            const prev = history[history.length - 2];
            const curr = stats;
            const timeDiff = (curr.timestamp - prev.timestamp) / 1000; // seconds

            stats.rx_rate = (curr.rx_bytes - prev.rx_bytes) / timeDiff;
            stats.tx_rate = (curr.tx_bytes - prev.tx_bytes) / timeDiff;
        }
    }

    renderBandwidthStats(stats) {
        const container = document.getElementById('bandwidth-stats');
        if (!container) return;

        const formatBytes = (bytes) => {
            if (bytes < 1024) return `${bytes} B`;
            if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(2)} KB`;
            if (bytes < 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
            return `${(bytes / 1024 / 1024 / 1024).toFixed(2)} GB`;
        };

        const formatRate = (bytesPerSec) => {
            return `${formatBytes(bytesPerSec)}/s`;
        };

        container.innerHTML = `
            <div class="bandwidth-grid">
                <div class="bandwidth-card">
                    <div class="bandwidth-icon">📥</div>
                    <div class="bandwidth-info">
                        <div class="bandwidth-label">Download</div>
                        <div class="bandwidth-value">${formatRate(stats.rx_rate || 0)}</div>
                        <div class="bandwidth-total">Total: ${formatBytes(stats.rx_bytes)}</div>
                    </div>
                </div>
                <div class="bandwidth-card">
                    <div class="bandwidth-icon">📤</div>
                    <div class="bandwidth-info">
                        <div class="bandwidth-label">Upload</div>
                        <div class="bandwidth-value">${formatRate(stats.tx_rate || 0)}</div>
                        <div class="bandwidth-total">Total: ${formatBytes(stats.tx_bytes)}</div>
                    </div>
                </div>
                <div class="bandwidth-card">
                    <div class="bandwidth-icon">📊</div>
                    <div class="bandwidth-info">
                        <div class="bandwidth-label">Packets</div>
                        <div class="bandwidth-value">↓ ${stats.rx_packets.toLocaleString()}</div>
                        <div class="bandwidth-total">↑ ${stats.tx_packets.toLocaleString()}</div>
                    </div>
                </div>
                <div class="bandwidth-card ${stats.rx_errors + stats.tx_errors > 0 ? 'error' : ''}">
                    <div class="bandwidth-icon">${stats.rx_errors + stats.tx_errors > 0 ? '⚠️' : '✅'}</div>
                    <div class="bandwidth-info">
                        <div class="bandwidth-label">Errors</div>
                        <div class="bandwidth-value">${stats.rx_errors + stats.tx_errors}</div>
                        <div class="bandwidth-total">RX: ${stats.rx_errors} | TX: ${stats.tx_errors}</div>
                    </div>
                </div>
            </div>
        `;
    }

    async loadConnections() {
        try {
            const selectedPi = document.getElementById('pi-selector')?.value;
            const data = await api.get('/network/connections', { piId: selectedPi });

            this.renderConnections(data.connections);
        } catch (error) {
            console.error('Failed to load connections:', error);
            this.connections = [];
            this.connectionsLoaded = true;
            this.updateOverview();
        }
    }

    renderConnections(connections) {
        const container = document.getElementById('active-connections');
        if (!container) return;

        this.connections = Array.isArray(connections) ? connections : [];
        this.connectionsLoaded = true;

        if (this.connections.length === 0) {
            container.innerHTML = '<p class="no-data">Aucune connexion active</p>';
            this.updateOverview();
            return;
        }

        container.innerHTML = `
            <div class="collapsible-section">
                <button class="collapse-toggle" data-target="connections-table-content">
                    <i data-lucide="chevron-down" size="16"></i>
                    <span>Connexions actives (${this.connections.length})</span>
                </button>
                <div id="connections-table-content" class="collapsible-content">
                    <table class="connections-table">
                        <thead>
                            <tr>
                                <th>Protocol</th>
                                <th>State</th>
                                <th>Local Address</th>
                                <th>Peer Address</th>
                                <th>Recv-Q</th>
                                <th>Send-Q</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${this.connections.slice(0, 50).map(conn => `
                                <tr>
                                    <td><span class="badge badge-info">${conn.protocol}</span></td>
                                    <td><span class="badge badge-${conn.state === 'LISTEN' ? 'success' : 'secondary'}">${conn.state}</span></td>
                                    <td><code>${conn.localAddr}</code></td>
                                    <td><code>${conn.peerAddr}</code></td>
                                    <td>${conn.recvQ}</td>
                                    <td>${conn.sendQ}</td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                    ${this.connections.length > 50 ? `<p class="table-note">Affichage des 50 premières connexions sur ${this.connections.length}</p>` : ''}
                </div>
            </div>
        `;

        if (window.lucide) window.lucide.createIcons();

        this.updateOverview();
    }

    async loadFirewall() {
        try {
            const selectedPi = document.getElementById('pi-selector')?.value;
            const data = await api.get('/network/firewall', { piId: selectedPi });

            this.renderFirewall(data.firewall);
        } catch (error) {
            console.error('Failed to load firewall:', error);
            this.firewallStatus = null;
            this.firewallStatusLoaded = true;
            this.updateOverview();
        }
    }

    renderFirewall(firewall) {
        const container = document.getElementById('firewall-status');
        if (!container) return;

        this.firewallStatus = firewall || null;
        this.firewallStatusLoaded = true;

        const statusBadge = firewall.enabled
            ? '<span class="badge badge-success">✅ Active</span>'
            : '<span class="badge badge-error">⏸️ Inactive</span>';

        const rulesCount = firewall.rules?.length || 0;

        container.innerHTML = `
            <div class="collapsible-section">
                <div class="firewall-header">
                    <h4>UFW Firewall ${statusBadge}</h4>
                    ${firewall.enabled ? `
                        <div class="firewall-defaults">
                            <span>Default Incoming: <strong>${firewall.defaultIncoming}</strong></span>
                            <span>Default Outgoing: <strong>${firewall.defaultOutgoing}</strong></span>
                        </div>
                    ` : ''}
                </div>
                ${rulesCount > 0 ? `
                    <button class="collapse-toggle" data-target="firewall-rules-content">
                        <i data-lucide="chevron-down" size="16"></i>
                        <span>Règles de pare-feu (${rulesCount})</span>
                    </button>
                    <div id="firewall-rules-content" class="collapsible-content">
                        <table class="firewall-rules-table">
                            <thead>
                                <tr>
                                    <th>#</th>
                                    <th>To</th>
                                    <th>Action</th>
                                    <th>From</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${firewall.rules.map(rule => `
                                    <tr>
                                        <td>${rule.number}</td>
                                        <td><code>${rule.to}</code></td>
                                        <td><span class="badge badge-${rule.action === 'ALLOW' ? 'success' : 'error'}">${rule.action}</span></td>
                                        <td><code>${rule.from}</code></td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    </div>
                ` : '<p class="no-data">Aucune règle de pare-feu configurée</p>'}
            </div>
        `;

        if (window.lucide) window.lucide.createIcons();

        this.updateOverview();
    }

    async loadPublicIP() {
        try {
            const selectedPi = document.getElementById('pi-selector')?.value;
            const data = await api.get('/network/public-ip', { piId: selectedPi });

            this.renderPublicIP(data.publicIP);
        } catch (error) {
            console.error('Failed to load public IP:', error);
            this.publicIp = null;
            this.publicIpLoaded = true;
            this.updateOverview();
        }
    }

    renderPublicIP(publicIP) {
        const container = document.getElementById('public-ip-info');
        if (!container) return;

        this.publicIpLoaded = true;

        if (!publicIP) {
            container.innerHTML = '<p class="no-data">Impossible de récupérer l\'adresse publique</p>';
            this.publicIp = null;
            this.updateOverview();
            return;
        }

        this.publicIp = publicIP;
        container.innerHTML = `
            <div class="public-ip-card">
                <div class="public-ip-main">
                    <h3>🌍 ${publicIP.ip}</h3>
                    ${publicIP.location ? `
                        <div class="location-info">
                            <p>📍 ${publicIP.location.city}, ${publicIP.location.region}, ${publicIP.location.country}</p>
                            <p>🏢 ${publicIP.location.isp}</p>
                            <p>🕒 ${publicIP.location.timezone}</p>
                        </div>
                    ` : ''}
                </div>
            </div>
        `;

        this.updateOverview();
    }

    async loadListeningPorts() {
        try {
            const selectedPi = document.getElementById('pi-selector')?.value;
            const data = await api.get('/network/ports', { piId: selectedPi });

            this.renderListeningPorts(data.ports);
        } catch (error) {
            console.error('Failed to load listening ports:', error);
            this.listeningPorts = {};
            this.listeningPortsLoaded = true;
            this.updateOverview();
        }
    }

    renderListeningPorts(ports) {
        const container = document.getElementById('listening-ports');
        if (!container) return;

        this.listeningPorts = ports || {};
        this.listeningPortsLoaded = true;

        if (Object.keys(this.listeningPorts).length === 0) {
            container.innerHTML = '<p class="no-data">Aucun port en écoute détecté</p>';
            this.updateOverview();
            return;
        }

        const servicesCount = Object.keys(this.listeningPorts).length;
        const totalPorts = Object.values(this.listeningPorts).reduce((acc, list) => acc + list.length, 0);

        container.innerHTML = `
            <div class="collapsible-section">
                <button class="collapse-toggle" data-target="ports-content">
                    <i data-lucide="chevron-down" size="16"></i>
                    <span>Ports en écoute (${servicesCount} services, ${totalPorts} ports)</span>
                </button>
                <div id="ports-content" class="collapsible-content">
                    ${Object.entries(this.listeningPorts).map(([process, portList]) => `
                        <div class="ports-group">
                            <h4>🔧 ${process} <span class="badge badge-info">${portList.length} port${portList.length > 1 ? 's' : ''}</span></h4>
                            <div class="ports-list">
                                ${portList.map(port => `
                                    <div class="port-item">
                                        <span class="port-protocol">${port.protocol}</span>
                                        <span class="port-number">${port.address}:${port.port}</span>
                                    </div>
                                `).join('')}
                            </div>
                        </div>
                    `).join('')}
                </div>
            </div>
        `;

        if (window.lucide) window.lucide.createIcons();

        this.updateOverview();
    }

    updateOverview() {
        const connectivityCard = document.querySelector('[data-summary="connectivity"]');
        const firewallCard = document.querySelector('[data-summary="firewall"]');
        const portsCard = document.querySelector('[data-summary="ports"]');

        const connectivityText = document.getElementById('network-summary-connection');
        const firewallText = document.getElementById('network-summary-firewall');
        const portsText = document.getElementById('network-summary-ports');

        const apply = (card, textEl, state, message) => {
            if (textEl) textEl.textContent = message;
            if (card) card.dataset.state = state;
        };

        if (!this.interfacesLoaded) {
            apply(connectivityCard, connectivityText, 'loading', 'Analyse en cours…');
        } else if (this.interfaces.length === 0) {
            apply(connectivityCard, connectivityText, 'warning', 'Aucune interface détectée');
        } else {
            const active = this.interfaces.filter((iface) => (iface.state || '').toUpperCase() === 'UP');
            const names = active.slice(0, 3).map((iface) => iface.name).join(', ');
            let message = `${active.length}/${this.interfaces.length} interface(s) UP`;
            if (names) {
                message += ` (${names}${active.length > 3 ? '…' : ''})`;
            }

            if (this.publicIpLoaded && this.publicIp?.ip) {
                message += ` • IP pub: ${this.publicIp.ip}`;
            } else if (this.publicIpLoaded && !this.publicIp) {
                message += ' • IP publique indisponible';
            }

            const state = active.length > 0 ? 'ok' : 'warning';
            if (active.length === 0) {
                message = 'Aucune interface UP';
                if (this.publicIpLoaded && this.publicIp?.ip) {
                    message += ` • IP pub: ${this.publicIp.ip}`;
                }
            }

            apply(connectivityCard, connectivityText, state, message);
        }

        if (!this.firewallStatusLoaded) {
            apply(firewallCard, firewallText, 'loading', 'Analyse en cours…');
        } else if (!this.firewallStatus) {
            apply(firewallCard, firewallText, 'warning', 'Impossible de récupérer l\'état du pare-feu');
        } else if (this.firewallStatus.enabled) {
            const rules = this.firewallStatus.rules?.length || 0;
            apply(firewallCard, firewallText, 'ok', `Actif • ${rules} règle(s)`);
        } else {
            apply(firewallCard, firewallText, 'warning', 'UFW désactivé');
        }

        if (!this.listeningPortsLoaded) {
            apply(portsCard, portsText, 'loading', 'Analyse en cours…');
        } else {
            const services = Object.keys(this.listeningPorts || {}).length;
            const totalPorts = Object.values(this.listeningPorts || {}).reduce((acc, list) => acc + list.length, 0);
            const connectionsInfo = this.connectionsLoaded ? ` • ${this.connections.length} connexion(s)` : '';

            if (totalPorts === 0) {
                apply(portsCard, portsText, 'ok', `Aucun port exposé${connectionsInfo}`);
            } else {
                const state = totalPorts > 10 ? 'warning' : 'ok';
                apply(portsCard, portsText, state, `${services} service(s) • ${totalPorts} port(s)${connectionsInfo}`);
            }
        }
    }

    async testPing() {
        const host = document.getElementById('ping-host')?.value || '8.8.8.8';
        const count = parseInt(document.getElementById('ping-count')?.value) || 4;
        const resultContainer = document.getElementById('ping-result');

        if (!resultContainer) return;

        resultContainer.innerHTML = '<p class="loading">⏳ Testing ping...</p>';

        try {
            const selectedPi = document.getElementById('pi-selector')?.value;
            const data = await api.post('/network/ping', { piId: selectedPi, host, count });

            const result = data.result;
            resultContainer.innerHTML = `
                <div class="test-result ${result.success ? 'success' : 'error'}">
                    <h4>${result.success ? '✅' : '❌'} Ping to ${result.host}</h4>
                    ${result.stats ? `
                        <p><strong>Packets:</strong> ${result.stats.transmitted} transmitted, ${result.stats.received} received, ${result.stats.loss}% loss</p>
                    ` : ''}
                    ${result.rtt ? `
                        <p><strong>RTT:</strong> min ${result.rtt.min}ms / avg ${result.rtt.avg}ms / max ${result.rtt.max}ms</p>
                    ` : ''}
                    ${result.error ? `<p class="error-message">${result.error}</p>` : ''}
                </div>
            `;
        } catch (error) {
            resultContainer.innerHTML = `<p class="error">❌ Failed: ${error.message}</p>`;
        }
    }

    async testDNS() {
        const domain = document.getElementById('dns-domain')?.value || 'google.com';
        const resultContainer = document.getElementById('dns-result');

        if (!resultContainer) return;

        resultContainer.innerHTML = '<p class="loading">⏳ Testing DNS...</p>';

        try {
            const selectedPi = document.getElementById('pi-selector')?.value;
            const data = await api.post('/network/dns', { piId: selectedPi, domain });

            const result = data.result;
            resultContainer.innerHTML = `
                <div class="test-result ${result.success ? 'success' : 'error'}">
                    <h4>${result.success ? '✅' : '❌'} DNS Lookup: ${result.domain}</h4>
                    <pre>${result.output || result.error}</pre>
                </div>
            `;
        } catch (error) {
            resultContainer.innerHTML = `<p class="error">❌ Failed: ${error.message}</p>`;
        }
    }

    startAutoRefresh() {
        this.stopAutoRefresh();
        this.refreshInterval = setInterval(() => {
            this.load();
        }, this.refreshRate);
    }

    stopAutoRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }
    }
}

// Export singleton
const networkManager = new NetworkManager();
export default networkManager;

// Make available globally for onclick handlers
window.networkManager = networkManager;
