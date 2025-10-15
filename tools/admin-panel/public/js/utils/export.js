// =============================================================================
// Export Utilities - CSV/JSON Export
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// =============================================================================

/**
 * Export data to CSV
 * @param {Array} data - Array of objects
 * @param {string} filename - Output filename
 */
export function exportToCSV(data, filename = 'export.csv') {
    if (!data || data.length === 0) {
        console.error('No data to export');
        return;
    }

    // Get headers from first object
    const headers = Object.keys(data[0]);

    // Build CSV content
    let csv = headers.join(',') + '\n';

    data.forEach(row => {
        const values = headers.map(header => {
            const value = row[header];
            // Escape quotes and wrap in quotes if contains comma
            if (typeof value === 'string') {
                const escaped = value.replace(/"/g, '""');
                return escaped.includes(',') ? `"${escaped}"` : escaped;
            }
            return value;
        });
        csv += values.join(',') + '\n';
    });

    downloadFile(csv, filename, 'text/csv');
}

/**
 * Export data to JSON
 * @param {Array|Object} data - Data to export
 * @param {string} filename - Output filename
 */
export function exportToJSON(data, filename = 'export.json') {
    if (!data) {
        console.error('No data to export');
        return;
    }

    const json = JSON.stringify(data, null, 2);
    downloadFile(json, filename, 'application/json');
}

/**
 * Trigger file download
 * @param {string} content - File content
 * @param {string} filename - Filename
 * @param {string} mimeType - MIME type
 */
function downloadFile(content, filename, mimeType) {
    const blob = new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);

    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.style.display = 'none';

    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    // Clean up
    setTimeout(() => URL.revokeObjectURL(url), 100);
}

/**
 * Export history to CSV with formatted data
 * @param {Array} history - History array
 */
export function exportHistoryToCSV(history) {
    if (!history || history.length === 0) {
        if (window.toastManager) {
            window.toastManager.warning('No history to export', 'Execute some scripts first');
        }
        return;
    }

    // Format history for CSV
    const formatted = history.map(item => ({
        timestamp: new Date(item.timestamp).toLocaleString('fr-FR'),
        script: item.script || 'Unknown',
        status: item.status || 'unknown',
        duration: item.duration ? `${item.duration}ms` : 'N/A',
        output: (item.output || '').substring(0, 100) // Limit output length
    }));

    const filename = `pi5-history-${Date.now()}.csv`;
    exportToCSV(formatted, filename);

    if (window.toastManager) {
        window.toastManager.success('History exported', `Downloaded ${filename}`);
    }
}

/**
 * Export history to JSON
 * @param {Array} history - History array
 */
export function exportHistoryToJSON(history) {
    if (!history || history.length === 0) {
        if (window.toastManager) {
            window.toastManager.warning('No history to export', 'Execute some scripts first');
        }
        return;
    }

    const filename = `pi5-history-${Date.now()}.json`;
    exportToJSON(history, filename);

    if (window.toastManager) {
        window.toastManager.success('History exported', `Downloaded ${filename}`);
    }
}

/**
 * Export system stats to CSV
 * @param {Array} stats - Stats array
 */
export function exportStatsToCSV(stats) {
    const filename = `pi5-stats-${Date.now()}.csv`;
    exportToCSV(stats, filename);

    if (window.toastManager) {
        window.toastManager.success('Stats exported', `Downloaded ${filename}`);
    }
}

/**
 * Export docker info to JSON
 * @param {Array} containers - Containers array
 */
export function exportDockerToJSON(containers) {
    const filename = `pi5-docker-${Date.now()}.json`;
    exportToJSON(containers, filename);

    if (window.toastManager) {
        window.toastManager.success('Docker info exported', `Downloaded ${filename}`);
    }
}

// Make available globally
window.exportUtils = {
    exportToCSV,
    exportToJSON,
    exportHistoryToCSV,
    exportHistoryToJSON,
    exportStatsToCSV,
    exportDockerToJSON
};
