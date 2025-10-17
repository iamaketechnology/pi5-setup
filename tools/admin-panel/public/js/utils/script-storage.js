// =============================================================================
// Script Storage Utility - LocalStorage Management
// =============================================================================
// Manages favorites and recent executions
// =============================================================================

const FAVORITES_KEY = 'pi5_script_favorites';
const RECENT_KEY = 'pi5_script_recent';
const MAX_RECENT = 5;

export class ScriptStorage {
    /**
     * Get favorite scripts
     * @returns {Array} Array of script IDs
     */
    static getFavorites() {
        try {
            const data = localStorage.getItem(FAVORITES_KEY);
            return data ? JSON.parse(data) : [];
        } catch (error) {
            console.error('Failed to load favorites:', error);
            return [];
        }
    }

    /**
     * Check if script is favorite
     * @param {string} scriptId - Script ID
     * @returns {boolean}
     */
    static isFavorite(scriptId) {
        const favorites = this.getFavorites();
        return favorites.includes(scriptId);
    }

    /**
     * Toggle favorite status
     * @param {string} scriptId - Script ID
     * @returns {boolean} New favorite status
     */
    static toggleFavorite(scriptId) {
        const favorites = this.getFavorites();
        const index = favorites.indexOf(scriptId);

        if (index > -1) {
            // Remove from favorites
            favorites.splice(index, 1);
        } else {
            // Add to favorites
            favorites.push(scriptId);
        }

        localStorage.setItem(FAVORITES_KEY, JSON.stringify(favorites));
        return index === -1; // Return true if now favorite
    }

    /**
     * Get recent script executions
     * @returns {Array} Array of recent executions
     */
    static getRecent() {
        try {
            const data = localStorage.getItem(RECENT_KEY);
            return data ? JSON.parse(data) : [];
        } catch (error) {
            console.error('Failed to load recent:', error);
            return [];
        }
    }

    /**
     * Add script to recent executions
     * @param {Object} execution - Execution details
     */
    static addRecent(execution) {
        try {
            let recent = this.getRecent();

            // Remove existing entry for same script
            recent = recent.filter(item => item.scriptId !== execution.scriptId);

            // Add to beginning
            recent.unshift({
                scriptId: execution.scriptId,
                scriptName: execution.scriptName,
                timestamp: Date.now(),
                status: execution.status || 'pending',
                duration: execution.duration || null
            });

            // Keep only MAX_RECENT items
            recent = recent.slice(0, MAX_RECENT);

            localStorage.setItem(RECENT_KEY, JSON.stringify(recent));
        } catch (error) {
            console.error('Failed to save recent:', error);
        }
    }

    /**
     * Update recent execution status
     * @param {string} scriptId - Script ID
     * @param {string} status - New status (success, failed)
     * @param {number} duration - Execution duration in ms
     */
    static updateRecentStatus(scriptId, status, duration = null) {
        try {
            const recent = this.getRecent();
            const item = recent.find(r => r.scriptId === scriptId);

            if (item) {
                item.status = status;
                if (duration !== null) {
                    item.duration = duration;
                }
                localStorage.setItem(RECENT_KEY, JSON.stringify(recent));
            }
        } catch (error) {
            console.error('Failed to update recent status:', error);
        }
    }

    /**
     * Clear all recent executions
     */
    static clearRecent() {
        localStorage.removeItem(RECENT_KEY);
    }

    /**
     * Clear all favorites
     */
    static clearFavorites() {
        localStorage.removeItem(FAVORITES_KEY);
    }

    /**
     * Format relative time
     * @param {number} timestamp - Unix timestamp
     * @returns {string} Relative time string
     */
    static formatRelativeTime(timestamp) {
        const now = Date.now();
        const diff = now - timestamp;
        const seconds = Math.floor(diff / 1000);
        const minutes = Math.floor(seconds / 60);
        const hours = Math.floor(minutes / 60);
        const days = Math.floor(hours / 24);

        if (seconds < 60) return 'À l\'instant';
        if (minutes < 60) return `Il y a ${minutes}min`;
        if (hours < 24) return `Il y a ${hours}h`;
        return `Il y a ${days}j`;
    }

    /**
     * Format duration
     * @param {number} duration - Duration in ms
     * @returns {string} Formatted duration
     */
    static formatDuration(duration) {
        if (!duration) return '';
        const seconds = Math.floor(duration / 1000);
        if (seconds < 60) return `${seconds}s`;
        const minutes = Math.floor(seconds / 60);
        const remainingSeconds = seconds % 60;
        return `${minutes}m ${remainingSeconds}s`;
    }
}

export default ScriptStorage;
