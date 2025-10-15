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
}

// Create singleton instance
const systemStatsManager = new SystemStatsManager();

// Export
export default systemStatsManager;

// Global access for backward compatibility
window.systemStatsManager = systemStatsManager;
window.updateSystemStats = () => systemStatsManager.load();
