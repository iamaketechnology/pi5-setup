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

        this.portFilterTerm = '';
    }

    init() {
        this.setupEventListeners();
        this.setupCollapsibleSections();
        this.setupCategoryNavigation();
        this.updateOverview();
        this.load();
    }

    /**
     * Setup category navigation (sidebar)
     */
    setupCategoryNavigation() {
        const categoryButtons = document.querySelectorAll('.network-category-item');
        categoryButtons.forEach(btn => {
            btn.addEventListener('click', () => {
                const category = btn.dataset.networkCategory;
                this.switchToCategory(category);
            });
        });
    }

    /**
     * Update category badges with counts
     */
    updateCategoryBadges() {
        // Interfaces count
        const interfacesCount = this.interfaces?.length || 0;
        const interfacesBadge = document.querySelector('[data-network-category="interfaces"] .category-badge');
        if (interfacesBadge) interfacesBadge.textContent = interfacesCount;

        // Ports count
        const portsCount = Object.values(this.listeningPorts || {}).reduce((acc, list) => acc + list.length, 0);
        const portsBadge = document.querySelector('[data-network-category="ports"] .category-badge');
        if (portsBadge) portsBadge.textContent = portsCount;
    }

    /**
     * Switch to a specific category section
     */
    switchToCategory(category) {
        // Update active button
        document.querySelectorAll('.network-category-item').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.networkCategory === category);
        });

        // Update active section
        document.querySelectorAll('.network-section').forEach(section => {
            section.classList.toggle('active', section.id === `network-section-${category}`);
        });

        // Refresh icons
        if (window.lucide) window.lucide.createIcons();
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

        const portFilterInput = document.getElementById('port-filter');
        if (portFilterInput) {
            portFilterInput.addEventListener('input', (e) => {
                this.portFilterTerm = (e.target.value || '').trim().toLowerCase();
                portFilterInput.parentElement?.classList.toggle('port-filter-active', this.portFilterTerm.length > 0);
                this.renderListeningPortsList();
                this.updatePortSummary();
            });
        }

        document.getElementById('clear-port-filter')?.addEventListener('click', () => {
            const filterInput = document.getElementById('port-filter');
            if (filterInput) {
                filterInput.value = '';
                filterInput.dispatchEvent(new Event('input'));
                filterInput.focus();
            }
        });

        document.getElementById('listening-ports')?.addEventListener('dblclick', (event) => this.handlePortCopy(event));
        document.getElementById('active-connections')?.addEventListener('dblclick', (event) => this.handlePortCopy(event));
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

        if (this.interfaces.length === 0) {
            this.renderInterfaceTable('network-interfaces', []);
            this.renderInterfaceTable('network-interfaces-traffic', []);
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

        // Render in both locations (overview + traffic section)
        this.renderInterfaceTable('network-interfaces', normalized);
        this.renderInterfaceTable('network-interfaces-traffic', normalized);

        this.updateInterfaceSelector(normalized);
        this.updateCategoryBadges();
        this.updateOverview();
    }

    renderInterfaceTable(containerId, interfaces) {
        const container = document.getElementById(containerId);
        if (!container) return;

        if (interfaces.length === 0) {
            container.innerHTML = '<p class="no-data">Aucune interface détectée</p>';
            return;
        }

        const rows = interfaces.map((iface) => {
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
                <button class="collapse-toggle" data-target="${containerId}-table-content">
                    <i data-lucide="chevron-down" size="16"></i>
                    <span>Interfaces réseau (${interfaces.length})</span>
                </button>
                <div id="${containerId}-table-content" class="collapsible-content">
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

        const listeningCount = this.connections.filter((conn) => conn.state === 'LISTEN').length;
        const establishedCount = this.connections.filter((conn) => (conn.state || '').toUpperCase().startsWith('ESTAB')).length;
        const remoteHosts = new Set(this.connections.map((conn) => this.extractHost(conn.peerAddr)).filter(Boolean));

        const rows = this.connections.slice(0, 50).map((conn) => {
            const protocol = (conn.protocol || '').toUpperCase();
            const state = conn.state || '—';
            const localAddr = conn.localAddr || '—';
            const peerAddr = conn.peerAddr || '—';
            const recvQ = conn.recvQ ?? '0';
            const sendQ = conn.sendQ ?? '0';
            const normalizedState = state.toUpperCase();
            const badgeClass = normalizedState === 'LISTEN'
                ? 'badge-success'
                : normalizedState.startsWith('ESTAB')
                    ? 'badge-info'
                    : 'badge-secondary';
            const localPort = this.extractPort(conn.localAddr);
            const portCopyAttr = localPort
                ? ` data-port-copy="${this.escapeHtml(localPort)}" data-copy-label="${this.escapeHtml(`Port ${localPort}`)}"`
                : '';

            return `
                <tr>
                    <td>${protocol ? `<span class="badge badge-info">${this.escapeHtml(protocol)}</span>` : '—'}</td>
                    <td><span class="badge ${badgeClass}">${this.escapeHtml(state)}</span></td>
                    <td><code${portCopyAttr}>${this.escapeHtml(localAddr)}</code></td>
                    <td><code>${this.escapeHtml(peerAddr)}</code></td>
                    <td>${this.escapeHtml(String(recvQ))}</td>
                    <td>${this.escapeHtml(String(sendQ))}</td>
                </tr>
            `;
        }).join('');

        container.innerHTML = `
            <div class="connections-summary">
                <div><strong>${this.connections.length}</strong> connexion${this.connections.length > 1 ? 's' : ''} suivie${this.connections.length > 1 ? 's' : ''}</div>
                <div class="connections-badges">
                    <span class="badge badge-success">${listeningCount} en écoute</span>
                    <span class="badge badge-info">${establishedCount} établies</span>
                    <span class="badge badge-secondary">${remoteHosts.size} hôte${remoteHosts.size > 1 ? 's' : ''} distant${remoteHosts.size > 1 ? 's' : ''}</span>
                </div>
            </div>
            <div class="connections-table-wrapper">
                <table class="connections-table compact">
                    <thead>
                        <tr>
                            <th>Protocol</th>
                            <th>État</th>
                            <th>Adresse locale</th>
                            <th>Adresse distante</th>
                            <th>Recv-Q</th>
                            <th>Send-Q</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${rows}
                    </tbody>
                </table>
            </div>
            ${[
                this.connections.length > 50 ? `Affichage des 50 premières connexions sur ${this.connections.length}.` : null,
                'Double-cliquez sur une adresse locale pour copier son port.'
            ].filter(Boolean).map((note) => `<p class="connections-footnote">${this.escapeHtml(note)}</p>`).join('')}
        `;

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
            this.updatePortSummary();
            this.updateCategoryBadges();
            this.updateOverview();
            return;
        }

        this.renderListeningPortsList();
        this.updatePortSummary();
        this.updateCategoryBadges();
        this.updateOverview();
    }

    getListeningPortEntries() {
        if (!this.listeningPorts || typeof this.listeningPorts !== 'object') {
            return [];
        }

        const entries = [];
        Object.entries(this.listeningPorts).forEach(([processName, portList]) => {
            if (!Array.isArray(portList)) return;

            portList.forEach((port) => {
                if (!port) return;

                const rawPort = port.port ?? port.localPort ?? port.local_port ?? null;
                const numericPort = typeof rawPort === 'number' ? rawPort : parseInt(rawPort, 10);
                const hasNumericPort = !Number.isNaN(numericPort);
                const protocol = (port.protocol || port.proto || '').toString().toUpperCase();
                const normalizedProtocol = protocol ? protocol : '—';
                const address = port.address || port.localAddress || port.local_address || '0.0.0.0';
                const label = port.name || port.service || port.description || processName || 'Service';
                const pid = port.pid || port.processId || port.process_id || null;
                const command = port.command || port.cmd || port.commandline || '';

                entries.push({
                    process: processName || label,
                    label,
                    protocol: normalizedProtocol,
                    address,
                    port: hasNumericPort ? numericPort : null,
                    portDisplay: hasNumericPort ? numericPort : (rawPort ?? '—'),
                    pid,
                    command,
                    raw: port
                });
            });
        });

        return entries;
    }

    getPortEntries() {
        const entries = this.getListeningPortEntries();
        const filterValue = (document.getElementById('port-filter')?.value || '').trim();
        if (!this.portFilterTerm) {
            return {
                entries,
                filtered: entries,
                filterActive: false,
                filterValue
            };
        }

        const filtered = entries.filter((entry) => this.matchesPortFilter(entry, this.portFilterTerm));
        return {
            entries,
            filtered,
            filterActive: true,
            filterValue
        };
    }

    matchesPortFilter(entry, term) {
        if (!term) return true;
        const haystack = [
            entry.process,
            entry.label,
            entry.protocol,
            entry.address,
            entry.portDisplay,
            entry.pid,
            entry.command
        ].filter(Boolean).join(' ').toLowerCase();

        return haystack.includes(term);
    }

    renderListeningPortsList() {
        const container = document.getElementById('listening-ports');
        if (!container) return;

        if (!this.listeningPorts || Object.keys(this.listeningPorts).length === 0) {
            container.innerHTML = '<p class="no-data">Aucun port en écoute détecté</p>';
            return;
        }

        const { entries, filtered, filterActive, filterValue } = this.getPortEntries();

        if (entries.length === 0) {
            container.innerHTML = '<p class="no-data">Aucun port en écoute détecté</p>';
            return;
        }

        if (filtered.length === 0) {
            const displayFilter = filterValue || this.portFilterTerm;
            container.innerHTML = `
                <div class="port-no-result">
                    Aucun port ne correspond à « ${this.escapeHtml(displayFilter)} »
                </div>
            `;
            return;
        }

        const sorted = [...filtered].sort((a, b) => {
            const portA = typeof a.port === 'number' ? a.port : Number.POSITIVE_INFINITY;
            const portB = typeof b.port === 'number' ? b.port : Number.POSITIVE_INFINITY;
            if (portA !== portB) return portA - portB;

            const protoCompare = (a.protocol || '').localeCompare(b.protocol || '');
            if (protoCompare !== 0) return protoCompare;

            return (a.label || '').localeCompare(b.label || '');
        });

        const rows = sorted.map((entry) => {
            const serviceName = entry.label || entry.process || 'Service';
            const metaParts = [];
            if (entry.process && entry.process !== serviceName) {
                metaParts.push(entry.process);
            }
            if (entry.pid) {
                metaParts.push(`PID ${entry.pid}`);
            }
            if (entry.command) {
                metaParts.push(entry.command.split(' ')[0]);
            }

            const meta = metaParts.join(' • ');
            const portDisplay = entry.portDisplay ?? '—';
            const hasPort = portDisplay !== '—' && portDisplay !== null && portDisplay !== undefined;
            const portCopyAttr = hasPort
                ? ` data-port-copy="${this.escapeHtml(String(portDisplay))}" data-copy-label="${this.escapeHtml(`Port ${portDisplay}`)}"`
                : '';
            const addressDisplay = this.formatPortAddress(entry.address);
            const protocolBadge = entry.protocol && entry.protocol !== '—'
                ? `<span class="badge badge-info">${this.escapeHtml(entry.protocol)}</span>`
                : '—';
            const commandTitle = entry.command ? ` title="${this.escapeHtml(entry.command)}"` : '';

            return `
                <tr${commandTitle}>
                    <td class="port-service">
                        <strong>${this.escapeHtml(serviceName)}</strong>
                        ${meta ? `<span class="port-process">${this.escapeHtml(meta)}</span>` : ''}
                    </td>
                    <td><code${portCopyAttr}>${this.escapeHtml(String(portDisplay))}</code></td>
                    <td>${protocolBadge}</td>
                    <td><code>${this.escapeHtml(addressDisplay)}</code></td>
                </tr>
            `;
        }).join('');

        const table = `
            ${filterActive ? `<div class="port-filter-info">${this.escapeHtml(`${filtered.length}/${entries.length} correspondance(s)`)}</div>` : ''}
            <div class="port-table-wrapper">
                <table class="ports-table">
                    <thead>
                        <tr>
                            <th>Service / Process</th>
                            <th>Port</th>
                            <th>Protocole</th>
                            <th>Adresse</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${rows}
                    </tbody>
                </table>
            </div>
        `;

        container.innerHTML = table;
    }

    updatePortSummary() {
        const container = document.getElementById('port-usage-summary');
        if (!container) return;

        if (!this.listeningPortsLoaded) {
            container.innerHTML = '<div class="loading">Analyse des ports…</div>';
            return;
        }

        const { entries, filtered, filterActive, filterValue } = this.getPortEntries();

        if (entries.length === 0) {
            container.innerHTML = '<p class="no-data">Aucun port exposé actuellement.</p>';
            return;
        }

        const tcpCount = entries.filter((entry) => entry.protocol.includes('TCP')).length;
        const udpCount = entries.filter((entry) => entry.protocol.includes('UDP')).length;
        const privilegedPorts = entries.filter((entry) => this.isPrivilegedPort(entry.port)).length;
        const uniquePorts = new Set(entries.filter((entry) => entry.portDisplay !== '—').map((entry) => String(entry.portDisplay))).size;
        const services = new Set(entries.map((entry) => entry.process || entry.label)).size;

        const serviceCounts = entries.reduce((acc, entry) => {
            const key = entry.process || entry.label || 'Service';
            acc[key] = (acc[key] || 0) + 1;
            return acc;
        }, {});

        const topServices = Object.entries(serviceCounts)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 3);

        const watchPorts = ['22', '53', '80', '443', '3306', '5432'];
        const exposedHighlights = entries
            .filter((entry) => watchPorts.includes(String(entry.portDisplay)))
            .map((entry) => String(entry.portDisplay));

        const filterNote = filterActive
            ? `<p class="connections-footnote">Filtre actif : « ${this.escapeHtml(filterValue)} » — ${filtered.length}/${entries.length} correspondance(s).</p>`
            : '';

        const highlightNote = exposedHighlights.length
            ? `<p class="connections-footnote">Ports sensibles détectés : ${[...new Set(exposedHighlights)].map((port) => `<code>${this.escapeHtml(port)}</code>`).join(', ')}.</p>`
            : '';

        container.innerHTML = `
            <div class="port-summary-stats">
                <div class="port-summary-card">
                    <span class="label">Ports actifs</span>
                    <span class="value">${entries.length}</span>
                    <small>${uniquePorts} port${uniquePorts > 1 ? 's' : ''} unique${uniquePorts > 1 ? 's' : ''}</small>
                </div>
                <div class="port-summary-card">
                    <span class="label">Services</span>
                    <span class="value">${services}</span>
                </div>
                <div class="port-summary-card">
                    <span class="label">TCP / UDP</span>
                    <span class="value">${tcpCount}/${udpCount}</span>
                </div>
                <div class="port-summary-card">
                    <span class="label">Ports privilégiés</span>
                    <span class="value">${privilegedPorts}</span>
                </div>
            </div>
            ${topServices.length ? `
                <div class="port-summary-hotports">
                    ${topServices.map(([service, count]) => `<span class="badge badge-info">${this.escapeHtml(service)} • ${count}</span>`).join('')}
                </div>
            ` : ''}
            ${filterNote}
            ${highlightNote}
        `;
    }

    formatPortAddress(address) {
        if (!address) return '—';
        if (address === '0.0.0.0' || address === '*') return '0.0.0.0 (toutes)';
        if (address === '::') return ':: (IPv6)';
        if (address === '127.0.0.1') return '127.0.0.1 (loopback)';
        return address;
    }

    isPrivilegedPort(port) {
        if (typeof port !== 'number') return false;
        return port > 0 && port <= 1024;
    }

    async handlePortCopy(event) {
        const target = event.target.closest('[data-port-copy]');
        if (!target) return;

        const value = target.dataset.portCopy;
        if (!value) return;

        event.preventDefault();

        const success = await this.copyToClipboard(value);
        if (success) {
            const label = target.dataset.copyLabel || `Valeur ${value}`;
            window.showToast?.(`${label} copié !`, 'success');
        } else {
            window.showToast?.('Impossible de copier la valeur', 'error');
        }
    }

    async copyToClipboard(text) {
        if (!text) return false;
        try {
            if (navigator?.clipboard?.writeText) {
                await navigator.clipboard.writeText(text);
                return true;
            }
        } catch (error) {
            console.warn('Clipboard API write failed:', error);
        }

        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        textarea.style.pointerEvents = 'none';
        document.body.appendChild(textarea);
        textarea.focus();
        textarea.select();

        let result = false;
        try {
            result = document.execCommand('copy');
        } catch (error) {
            console.warn('execCommand copy failed:', error);
            result = false;
        }

        document.body.removeChild(textarea);
        return result;
    }

    escapeHtml(text) {
        if (text === null || text === undefined) return '';
        return String(text).replace(/[&<>"']/g, (char) => ({
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            '\'': '&#39;'
        }[char]));
    }

    extractHost(address = '') {
        if (!address) return '';
        const trimmed = address.trim();
        const ipv6Match = trimmed.match(/^\[([^\]]+)\](?::\d+)?$/);
        if (ipv6Match) {
            return ipv6Match[1];
        }

        const parts = trimmed.split(':');
        if (parts.length > 2) {
            const maybePort = parts[parts.length - 1];
            if (/^\d+$/.test(maybePort)) {
                return parts.slice(0, -1).join(':');
            }
        }

        if (parts.length === 2 && /^\d+$/.test(parts[1])) {
            return parts[0];
        }

        return trimmed;
    }

    extractPort(address = '') {
        if (!address) return '';
        const trimmed = address.trim();
        const ipv6Match = trimmed.match(/^\[[^\]]+\]:(\d+)$/);
        if (ipv6Match) {
            return ipv6Match[1];
        }

        const parts = trimmed.split(':');
        const candidate = parts[parts.length - 1];
        if (/^\d+$/.test(candidate)) {
            return candidate;
        }

        return '';
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
