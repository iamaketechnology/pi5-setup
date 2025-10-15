// =============================================================================
// Toast Notifications Module
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// Architecture: Modular (ES6 Module)
// =============================================================================

class ToastManager {
    constructor() {
        this.container = null;
        this.toasts = new Map();
        this.defaultDuration = 4000;
        this.toastIdCounter = 0;
    }

    init() {
        // Create toast container
        this.container = document.createElement('div');
        this.container.className = 'toast-container';
        document.body.appendChild(this.container);
        console.log('✅ Toast module initialized');
    }

    /**
     * Show a toast notification
     * @param {string} type - success, error, warning, info
     * @param {string} title - Toast title
     * @param {string} message - Optional message
     * @param {number} duration - Duration in ms (0 = no auto-dismiss)
     */
    show(type, title, message = '', duration = null) {
        const id = this.toastIdCounter++;
        const toast = this.createToast(id, type, title, message);

        this.container.appendChild(toast);
        this.toasts.set(id, toast);

        // Auto-dismiss
        const autoDismissDuration = duration !== null ? duration : this.defaultDuration;
        if (autoDismissDuration > 0) {
            setTimeout(() => this.dismiss(id), autoDismissDuration);
        }

        return id;
    }

    createToast(id, type, title, message) {
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.dataset.toastId = id;

        const iconMap = {
            success: '✓',
            error: '✕',
            warning: '⚠',
            info: 'ℹ'
        };

        toast.innerHTML = `
            <div class="toast-icon">${iconMap[type] || 'ℹ'}</div>
            <div class="toast-content">
                <div class="toast-title">${title}</div>
                ${message ? `<div class="toast-message">${message}</div>` : ''}
            </div>
            <button class="toast-close" onclick="window.toastManager.dismiss(${id})">×</button>
        `;

        return toast;
    }

    dismiss(id) {
        const toast = this.toasts.get(id);
        if (!toast) return;

        toast.classList.add('removing');

        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
            this.toasts.delete(id);
        }, 200); // Match animation duration
    }

    // Convenience methods
    success(title, message = '', duration = null) {
        return this.show('success', title, message, duration);
    }

    error(title, message = '', duration = null) {
        return this.show('error', title, message, duration || 6000); // Errors stay longer
    }

    warning(title, message = '', duration = null) {
        return this.show('warning', title, message, duration);
    }

    info(title, message = '', duration = null) {
        return this.show('info', title, message, duration);
    }

    /**
     * Show a promise-based toast (loading → success/error)
     * @param {Promise} promise - Promise to track
     * @param {Object} messages - { loading, success, error }
     */
    async promise(promise, messages = {}) {
        const loadingMsg = messages.loading || 'Processing...';
        const successMsg = messages.success || 'Success!';
        const errorMsg = messages.error || 'Error occurred';

        const loadingId = this.info(loadingMsg, '', 0); // No auto-dismiss

        try {
            const result = await promise;
            this.dismiss(loadingId);
            this.success(successMsg);
            return result;
        } catch (error) {
            this.dismiss(loadingId);
            this.error(errorMsg, error.message || '');
            throw error;
        }
    }

    /**
     * Clear all toasts
     */
    clearAll() {
        this.toasts.forEach((toast, id) => {
            this.dismiss(id);
        });
    }
}

// Export singleton
const toastManager = new ToastManager();
export default toastManager;

// Make available globally
window.toastManager = toastManager;

// Global convenience functions
window.toast = {
    success: (title, msg) => toastManager.success(title, msg),
    error: (title, msg) => toastManager.error(title, msg),
    warning: (title, msg) => toastManager.warning(title, msg),
    info: (title, msg) => toastManager.info(title, msg),
    promise: (promise, messages) => toastManager.promise(promise, messages)
};
