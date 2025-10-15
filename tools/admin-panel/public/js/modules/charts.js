// =============================================================================
// Charts Module - Real-time performance charts with Chart.js
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// =============================================================================

class ChartsManager {
    constructor() {
        this.charts = {};
        this.dataPoints = {
            cpu: [],
            ram: [],
            temp: []
        };
        this.maxDataPoints = 20; // 20 points = ~100 seconds at 5s refresh
        this.initialized = false;
    }

    init() {
        if (typeof Chart === 'undefined') {
            console.warn('Chart.js not loaded, skipping charts initialization');
            return;
        }

        // Set Chart.js defaults for dark theme
        this.setChartDefaults();

        // Create charts
        this.createCPUChart();
        this.createRAMChart();
        this.createTempChart();

        this.initialized = true;
        console.log('✅ Charts module initialized');

        // Listen for theme changes
        window.addEventListener('theme:changed', (e) => {
            this.updateChartsTheme(e.detail.theme);
        });
    }

    setChartDefaults() {
        const isDark = !window.themeManager || window.themeManager.isDark();

        Chart.defaults.color = isDark ? '#94a3b8' : '#64748b';
        Chart.defaults.borderColor = isDark ? '#475569' : '#cbd5e1';
        Chart.defaults.font.family = "'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace";
        Chart.defaults.plugins.legend.display = false;
        Chart.defaults.plugins.tooltip.enabled = true;
        Chart.defaults.plugins.tooltip.backgroundColor = isDark ? 'rgba(30, 41, 59, 0.95)' : 'rgba(248, 250, 252, 0.95)';
        Chart.defaults.plugins.tooltip.borderColor = isDark ? '#475569' : '#cbd5e1';
        Chart.defaults.plugins.tooltip.borderWidth = 1;
        Chart.defaults.plugins.tooltip.titleColor = isDark ? '#f1f5f9' : '#0f172a';
        Chart.defaults.plugins.tooltip.bodyColor = isDark ? '#f1f5f9' : '#0f172a';
        Chart.defaults.animation.duration = 300;
    }

    createCPUChart() {
        const ctx = document.getElementById('cpu-chart');
        if (!ctx) return;

        this.charts.cpu = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'CPU Usage',
                    data: [],
                    borderColor: '#3b82f6',
                    backgroundColor: 'rgba(59, 130, 246, 0.1)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 0,
                    pointHoverRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        ticks: {
                            callback: (value) => value + '%'
                        },
                        grid: {
                            color: 'rgba(71, 85, 105, 0.2)'
                        }
                    },
                    x: {
                        display: false
                    }
                },
                plugins: {
                    tooltip: {
                        callbacks: {
                            label: (context) => 'CPU: ' + context.parsed.y.toFixed(1) + '%'
                        }
                    }
                }
            }
        });
    }

    createRAMChart() {
        const ctx = document.getElementById('ram-chart');
        if (!ctx) return;

        this.charts.ram = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'RAM Usage',
                    data: [],
                    borderColor: '#10b981',
                    backgroundColor: 'rgba(16, 185, 129, 0.1)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 0,
                    pointHoverRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        ticks: {
                            callback: (value) => value + '%'
                        },
                        grid: {
                            color: 'rgba(71, 85, 105, 0.2)'
                        }
                    },
                    x: {
                        display: false
                    }
                },
                plugins: {
                    tooltip: {
                        callbacks: {
                            label: (context) => 'RAM: ' + context.parsed.y.toFixed(1) + '%'
                        }
                    }
                }
            }
        });
    }

    createTempChart() {
        const ctx = document.getElementById('temp-chart');
        if (!ctx) return;

        this.charts.temp = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'Temperature',
                    data: [],
                    borderColor: '#f59e0b',
                    backgroundColor: 'rgba(245, 158, 11, 0.1)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 0,
                    pointHoverRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: false,
                        min: 30,
                        max: 90,
                        ticks: {
                            callback: (value) => value + '°C'
                        },
                        grid: {
                            color: 'rgba(71, 85, 105, 0.2)'
                        }
                    },
                    x: {
                        display: false
                    }
                },
                plugins: {
                    tooltip: {
                        callbacks: {
                            label: (context) => 'Temp: ' + context.parsed.y.toFixed(1) + '°C'
                        }
                    }
                }
            }
        });
    }

    /**
     * Update charts with new data
     * @param {Object} stats - System stats object
     */
    updateData(stats) {
        if (!this.initialized || !stats) return;

        const timestamp = new Date().toLocaleTimeString('fr-FR', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });

        // Update CPU
        if (this.charts.cpu && stats.cpu !== undefined) {
            this.addDataPoint(this.charts.cpu, timestamp, stats.cpu);
        }

        // Update RAM
        if (this.charts.ram && stats.memory?.percent !== undefined) {
            this.addDataPoint(this.charts.ram, timestamp, stats.memory.percent);
        }

        // Update Temperature
        if (this.charts.temp && stats.temperature !== undefined) {
            this.addDataPoint(this.charts.temp, timestamp, stats.temperature);
        }
    }

    /**
     * Add data point to chart and maintain max points
     * @param {Chart} chart - Chart.js instance
     * @param {string} label - X-axis label
     * @param {number} value - Y-axis value
     */
    addDataPoint(chart, label, value) {
        chart.data.labels.push(label);
        chart.data.datasets[0].data.push(value);

        // Keep only last N points
        if (chart.data.labels.length > this.maxDataPoints) {
            chart.data.labels.shift();
            chart.data.datasets[0].data.shift();
        }

        chart.update('none'); // Update without animation for smooth real-time
    }

    /**
     * Update charts theme when theme changes
     * @param {string} theme - 'dark' or 'light'
     */
    updateChartsTheme(theme) {
        const isDark = theme === 'dark';

        Object.values(this.charts).forEach(chart => {
            if (!chart) return;

            // Update text colors
            chart.options.scales.y.ticks.color = isDark ? '#94a3b8' : '#64748b';
            chart.options.scales.y.grid.color = isDark ? 'rgba(71, 85, 105, 0.2)' : 'rgba(203, 213, 225, 0.4)';

            // Update tooltip
            if (chart.options.plugins.tooltip) {
                chart.options.plugins.tooltip.backgroundColor = isDark ? 'rgba(30, 41, 59, 0.95)' : 'rgba(248, 250, 252, 0.95)';
                chart.options.plugins.tooltip.borderColor = isDark ? '#475569' : '#cbd5e1';
                chart.options.plugins.tooltip.titleColor = isDark ? '#f1f5f9' : '#0f172a';
                chart.options.plugins.tooltip.bodyColor = isDark ? '#f1f5f9' : '#0f172a';
            }

            chart.update();
        });
    }

    /**
     * Destroy all charts (cleanup)
     */
    destroy() {
        Object.values(this.charts).forEach(chart => {
            if (chart) chart.destroy();
        });
        this.charts = {};
        this.initialized = false;
    }
}

// Export singleton
const chartsManager = new ChartsManager();
export default chartsManager;

// Make available globally
window.chartsManager = chartsManager;
