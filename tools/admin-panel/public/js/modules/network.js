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
    }

    init() {
        this.setupEventListeners();
        this.load();
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
        }
    }

    renderInterfaces(interfaces) {
        const container = document.getElementById('network-interfaces');
        if (!container) return;

        container.innerHTML = interfaces.map(iface => {
            const statusClass = iface.state === 'UP' ? 'success' : 'secondary';
            const ips = iface.addresses.map(addr => addr.ip).join(', ') || 'No IP';

            return `
                <div class="network-interface-card">
                    <div class="interface-header">
                        <h4>${iface.name}</h4>
                        <span class="badge badge-${statusClass}">${iface.state}</span>
                    </div>
                    <div class="interface-details">
                        <div class="detail-row">
                            <span class="label">IP:</span>
                            <span class="value">${ips}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">MAC:</span>
                            <span class="value">${iface.mac || 'N/A'}</span>
                        </div>
                        <div class="detail-row">
                            <span class="label">MTU:</span>
                            <span class="value">${iface.mtu}</span>
                        </div>
                    </div>
                </div>
            `;
        }).join('');

        // Update interface selector
        const selector = document.getElementById('network-interface-selector');
        if (selector) {
            selector.innerHTML = interfaces
                .filter(iface => iface.state === 'UP')
                .map(iface => `<option value="${iface.name}" ${iface.name === this.selectedInterface ? 'selected' : ''}>${iface.name}</option>`)
                .join('');
        }
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
        }
    }

    renderConnections(connections) {
        const container = document.getElementById('active-connections');
        if (!container) return;

        if (connections.length === 0) {
            container.innerHTML = '<p class="no-data">No active connections</p>';
            return;
        }

        container.innerHTML = `
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
                    ${connections.slice(0, 50).map(conn => `
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
            ${connections.length > 50 ? `<p class="table-note">Showing 50 of ${connections.length} connections</p>` : ''}
        `;
    }

    async loadFirewall() {
        try {
            const selectedPi = document.getElementById('pi-selector')?.value;
            const data = await api.get('/network/firewall', { piId: selectedPi });

            this.renderFirewall(data.firewall);
        } catch (error) {
            console.error('Failed to load firewall:', error);
        }
    }

    renderFirewall(firewall) {
        const container = document.getElementById('firewall-status');
        if (!container) return;

        const statusBadge = firewall.enabled
            ? '<span class="badge badge-success">✅ Active</span>'
            : '<span class="badge badge-error">⏸️ Inactive</span>';

        container.innerHTML = `
            <div class="firewall-header">
                <h4>UFW Firewall ${statusBadge}</h4>
                ${firewall.enabled ? `
                    <div class="firewall-defaults">
                        <span>Default Incoming: <strong>${firewall.defaultIncoming}</strong></span>
                        <span>Default Outgoing: <strong>${firewall.defaultOutgoing}</strong></span>
                    </div>
                ` : ''}
            </div>
            ${firewall.rules && firewall.rules.length > 0 ? `
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
            ` : '<p class="no-data">No firewall rules configured</p>'}
        `;
    }

    async loadPublicIP() {
        try {
            const selectedPi = document.getElementById('pi-selector')?.value;
            const data = await api.get('/network/public-ip', { piId: selectedPi });

            this.renderPublicIP(data.publicIP);
        } catch (error) {
            console.error('Failed to load public IP:', error);
        }
    }

    renderPublicIP(publicIP) {
        const container = document.getElementById('public-ip-info');
        if (!container) return;

        if (!publicIP) {
            container.innerHTML = '<p class="no-data">Failed to get public IP</p>';
            return;
        }

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
    }

    async loadListeningPorts() {
        try {
            const selectedPi = document.getElementById('pi-selector')?.value;
            const data = await api.get('/network/ports', { piId: selectedPi });

            this.renderListeningPorts(data.ports);
        } catch (error) {
            console.error('Failed to load listening ports:', error);
        }
    }

    renderListeningPorts(ports) {
        const container = document.getElementById('listening-ports');
        if (!container) return;

        if (Object.keys(ports).length === 0) {
            container.innerHTML = '<p class="no-data">No listening ports found</p>';
            return;
        }

        container.innerHTML = Object.entries(ports).map(([process, portList]) => `
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
        `).join('');
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
