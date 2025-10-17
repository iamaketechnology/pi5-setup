// =============================================================================
// System Stats Module
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

import api from '../utils/api.js';

/**
 * SystemStatsManager - Monitors system statistics
 */
class SystemStatsManager {
    constructor() {
        this.stats = null;
        this.refreshInterval = null;
        this.autoRefreshEnabled = false;
    }

    /**
     * Initialize system stats module
     * @param {number} interval - Refresh interval in milliseconds
     */
    init(interval = 5000) {
        this.load();
        this.startAutoRefresh(interval);
        console.log('✅ System stats module initialized');
    }

    /**
     * Load system stats from API
     */
    async load() {
        try {
            const piId = window.currentPiId;
            const params = piId ? `?piId=${piId}` : '';

            const stats = await api.get(`/system/stats${params}`);

            if (stats.error) {
                console.error('Stats error:', stats.error);
                return null;
            }

            this.stats = stats;
            this.render();

            // Update charts if available
            if (window.chartsManager) {
                window.chartsManager.updateData(stats);
            }

            return stats;
        } catch (error) {
            console.error('Failed to fetch system stats:', error);
            return null;
        }
    }

    /**
     * Render all stats
     */
    render() {
        if (!this.stats) return;

        this.renderCPU(this.stats.cpu);
        this.renderRAM(this.stats.memory);
        this.renderTemperature(this.stats.temperature);
        this.renderDisk(this.stats.disk);
        this.renderUptime(this.stats.uptime);
        this.renderDockerServices(this.stats.docker);
        this.updateSystemHealth();
        this.updateSummary();
        this.updateFooter();
    }

    /**
     * Render CPU usage
     * @param {number} percent - CPU usage percentage
     */
    renderCPU(percent) {
        this.updateProgressRing('stat-cpu', percent);
    }

    /**
     * Render RAM usage
     * @param {Object} memory - Memory stats
     */
    renderRAM(memory) {
        this.updateProgressRing('stat-ram', memory.percent);

        const ramDetail = document.querySelector('#stat-ram .stat-detail');
        if (ramDetail) {
            const ramUsedGB = (memory.used / 1024).toFixed(1);
            const ramTotalGB = (memory.total / 1024).toFixed(1);
            ramDetail.textContent = `${ramUsedGB} / ${ramTotalGB} GB`;
        }
    }

    /**
     * Render temperature
     * @param {number} temp - Temperature in Celsius
     */
    renderTemperature(temp) {
        const tempEl = document.querySelector('#stat-temp .temp-display');
        if (!tempEl) return;

        tempEl.textContent = `${temp.toFixed(1)}°C`;
        tempEl.className = 'temp-display';

        if (temp > 70) {
            tempEl.classList.add('danger');
        } else if (temp > 60) {
            tempEl.classList.add('warning');
        }
    }

    /**
     * Render disk usage
     * @param {Object} disk - Disk stats
     */
    renderDisk(disk) {
        this.updateProgressRing('stat-disk', disk.percent);

        const diskDetail = document.querySelector('#stat-disk .stat-detail');
        if (diskDetail) {
            diskDetail.textContent = `${disk.used} / ${disk.total}`;
        }
    }

    /**
     * Render uptime
     * @param {string} uptime - Formatted uptime string
     */
    renderUptime(uptime) {
        const uptimeEl = document.getElementById('stat-uptime');
        if (uptimeEl) {
            uptimeEl.textContent = uptime;
        }
    }

    /**
     * Render Docker services (dashboard)
     * @param {Array} dockerStats - Array of Docker service stats
     */
    renderDockerServices(dockerStats) {
        const container = document.getElementById('docker-services-dash');
        if (!container) return;

        if (!dockerStats || dockerStats.length === 0) {
            container.innerHTML = '<div class="loading">Aucun service Docker</div>';
            if (window.uiStatus) {
                window.uiStatus.header.set('docker', {
                    state: 'warning',
                    value: '0 service',
                    tooltip: 'Aucun service Docker détecté'
                });
                window.uiStatus.summary.setAlerts('docker', {
                    message: 'Aucun service Docker en cours d’exécution',
                    priority: 1
                });
            }
            return;
        }

        container.innerHTML = dockerStats.slice(0, 5).map(service => `
            <div class="service-item">
                <div>
                    <div class="service-name">${service.name}</div>
                    <div class="service-status running">
                        CPU: ${service.cpu || 'N/A'} | RAM: ${service.mem || 'N/A'}
                    </div>
                </div>
            </div>
        `).join('');

        if (window.uiStatus) {
            const total = dockerStats.length;
            const running = dockerStats.filter(service => {
                if (typeof service.running === 'boolean') {
                    return service.running;
                }
                const status = (service.status || service.state || '').toString().toLowerCase();
                if (!status) return true;
                return status.includes('running') || status.includes('healthy') || status.includes('up');
            }).length;

            const stopped = total - running;
            const state = stopped === 0 ? 'ok' : stopped >= Math.ceil(total / 2) ? 'error' : 'warning';
            const tooltip = stopped === 0
                ? `${running} service(s) en cours`
                : `${stopped} service(s) à relancer`;

            window.uiStatus.header.set('docker', {
                state,
                value: `${running}/${total} actifs`,
                tooltip
            });

            if (stopped > 0) {
                window.uiStatus.summary.setAlerts('docker', {
                    message: `${stopped} service(s) Docker arrêtés`,
                    priority: state === 'error' ? 4 : 2
                });
            } else {
                window.uiStatus.summary.setAlerts('docker', null);
            }
        }
    }

    /**
     * Update progress ring
     * @param {string} elementId - Element ID
     * @param {number} percent - Percentage value
     */
    updateProgressRing(elementId, percent) {
        const el = document.getElementById(elementId);
        if (!el) return;

        const ring = el.querySelector('.progress-ring');
        const percentEl = ring?.querySelector('.percent');

        if (!ring || !percentEl) return;

        percentEl.textContent = `${Math.round(percent)}%`;

        ring.className = 'progress-ring';
        if (percent > 80) {
            ring.classList.add('danger');
        } else if (percent > 60) {
            ring.classList.add('warning');
        }
    }

    /**
     * Start auto-refresh
     * @param {number} interval - Refresh interval in milliseconds
     */
    startAutoRefresh(interval = 5000) {
        this.stopAutoRefresh();
        this.autoRefreshEnabled = true;
        this.refreshInterval = setInterval(() => this.load(), interval);
        console.log(`🔄 System stats auto-refresh started (${interval}ms)`);
    }

    /**
     * Stop auto-refresh
     */
    stopAutoRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }
        this.autoRefreshEnabled = false;
        console.log('⏸️ System stats auto-refresh stopped');
    }

    /**
     * Get current stats
     * @returns {Object|null} Current stats or null
     */
    getStats() {
        return this.stats;
    }

    /**
     * Get specific stat
     * @param {string} key - Stat key (cpu, memory, temperature, disk, uptime)
     * @returns {*} Stat value or null
     */
    getStat(key) {
        return this.stats ? this.stats[key] : null;
    }

    /**
     * Update header health badge for system resources
     */
    updateSystemHealth() {
        if (!window.uiStatus || !this.stats) return;

        const cpu = Number(this.stats.cpu || 0);
        const ram = Number(this.stats.memory?.percent || 0);
        const disk = Number(this.stats.disk?.percent || 0);
        const temp = Number(this.stats.temperature || 0);

        const worstUsage = Math.max(cpu, ram, disk);
        let state = 'ok';

        if (temp >= 80 || worstUsage >= 92) {
            state = 'error';
        } else if (temp >= 70 || worstUsage >= 80) {
            state = 'warning';
        }

        const value = `CPU ${Math.round(cpu)}%`;
        const tooltip = `RAM ${Math.round(ram)}% • Disque ${Math.round(disk)}% • Temp ${Math.round(temp)}°C`;

        window.uiStatus.header.set('system', { state, value, tooltip });

        if (state === 'ok') {
            window.uiStatus.summary.setAlerts('system', null);
        } else {
            const cpuText = `CPU ${Math.round(cpu)}%`;
            const ramText = `RAM ${Math.round(ram)}%`;
            const message = state === 'error'
                ? `Charge critique détectée (${cpuText}, ${ramText})`
                : `Charge élevée observée (${cpuText}, ${ramText})`;
            window.uiStatus.summary.setAlerts('system', {
                message,
                priority: state === 'error' ? 4 : 3
            });
        }
    }

    /**
     * Update summary meta information (uptime tooltip)
     */
    updateSummary() {
        if (!this.stats) return;

        const uptimeEl = document.getElementById('stat-uptime');
        if (uptimeEl && this.stats.lastBoot) {
            uptimeEl.setAttribute('title', `Dernier démarrage : ${this.stats.lastBoot}`);
        }
    }

    /**
     * Update footer with system stats
     */
    updateFooter() {
        if (!window.footerManager || !this.stats) return;

        window.footerManager.updateStats({
            uptime: this.stats.uptime || '--',
            cpu: Math.round(this.stats.cpu || 0),
            ram: Math.round(this.stats.memory?.percent || 0)
        });
    }
}

// Create singleton instance
const systemStatsManager = new SystemStatsManager();

// Export
export default systemStatsManager;

// Global access for backward compatibility
window.systemStatsManager = systemStatsManager;
window.updateSystemStats = () => systemStatsManager.load();
