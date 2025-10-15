// =============================================================================
// Global Error Handler
// =============================================================================
// Catches and handles errors gracefully with user-friendly messages
// =============================================================================

class ErrorHandler {
    constructor() {
        this.errorCount = 0;
        this.maxErrors = 10; // Prevent spam
        this.errorLog = [];
    }

    init() {
        this.setupGlobalHandlers();
        console.log('✅ Error Handler initialized');
    }

    setupGlobalHandlers() {
        // Catch unhandled promise rejections
        window.addEventListener('unhandledrejection', (event) => {
            console.error('Unhandled Promise Rejection:', event.reason);
            this.handleError(event.reason, 'Promise Rejection');
            event.preventDefault();
        });

        // Catch global errors
        window.addEventListener('error', (event) => {
            console.error('Global Error:', event.error);
            this.handleError(event.error, 'JavaScript Error');
            event.preventDefault();
        });
    }

    /**
     * Handle an error gracefully
     * @param {Error|string} error - Error object or message
     * @param {string} context - Error context
     */
    handleError(error, context = 'Error') {
        if (this.errorCount >= this.maxErrors) {
            return; // Stop showing errors to prevent spam
        }

        this.errorCount++;
        const errorMessage = error instanceof Error ? error.message : String(error);

        // Log to console
        console.error(`[${context}]`, error);

        // Store in log
        this.errorLog.push({
            context,
            message: errorMessage,
            timestamp: new Date(),
            stack: error instanceof Error ? error.stack : null
        });

        // Show user-friendly toast
        if (window.toastManager) {
            const friendlyMessage = this.getFriendlyMessage(errorMessage);
            window.toastManager.error(`${context}`, friendlyMessage);
        }

        // Report to analytics (if implemented)
        this.reportError(error, context);
    }

    /**
     * Convert technical error to user-friendly message
     * @param {string} errorMessage - Technical error message
     * @returns {string} - User-friendly message
     */
    getFriendlyMessage(errorMessage) {
        const errorMap = {
            'Network': 'Unable to connect to the Pi. Check your network connection.',
            'ECONNREFUSED': 'Connection refused. Is the Pi powered on?',
            'ETIMEDOUT': 'Connection timed out. Check network or Pi status.',
            'Failed to fetch': 'Network error. Check connection to the Pi.',
            '404': 'Resource not found. This may be a configuration issue.',
            '500': 'Server error. Check Pi logs for details.',
            '403': 'Permission denied. Check authentication.',
            'SSH': 'SSH connection failed. Verify credentials.',
            'Docker': 'Docker command failed. Is Docker running?',
            'undefined': 'An unexpected error occurred.',
            'null': 'Missing data. Try refreshing the page.'
        };

        // Find matching error pattern
        for (const [key, friendlyMsg] of Object.entries(errorMap)) {
            if (errorMessage.includes(key)) {
                return friendlyMsg;
            }
        }

        // Default message
        return 'Something went wrong. Check console for details.';
    }

    /**
     * Wrap async function with error handling
     * @param {Function} fn - Async function
     * @param {string} context - Context for error messages
     * @returns {Function} - Wrapped function
     */
    wrap(fn, context = 'Operation') {
        return async (...args) => {
            try {
                return await fn(...args);
            } catch (error) {
                this.handleError(error, context);
                throw error; // Re-throw for caller to handle if needed
            }
        };
    }

    /**
     * Handle API errors with retries
     * @param {Function} apiFn - API function
     * @param {number} retries - Number of retries
     * @param {number} delay - Delay between retries (ms)
     * @returns {Promise}
     */
    async withRetry(apiFn, retries = 3, delay = 1000) {
        for (let i = 0; i < retries; i++) {
            try {
                return await apiFn();
            } catch (error) {
                if (i === retries - 1) {
                    this.handleError(error, 'API Error (after retries)');
                    throw error;
                }
                console.warn(`Retry ${i + 1}/${retries} after error:`, error.message);
                await new Promise(resolve => setTimeout(resolve, delay));
            }
        }
    }

    /**
     * Report error to analytics/monitoring
     * @param {Error} error - Error object
     * @param {string} context - Error context
     */
    reportError(error, context) {
        // TODO: Implement error reporting (e.g., Sentry, custom endpoint)
        // For now, just log
        if (this.errorCount === 1) {
            console.info('Error reporting not implemented yet');
        }
    }

    /**
     * Get error log
     * @returns {Array} - Array of error objects
     */
    getErrorLog() {
        return [...this.errorLog];
    }

    /**
     * Clear error log
     */
    clearLog() {
        this.errorLog = [];
        this.errorCount = 0;
    }

    /**
     * Show error in UI (for critical errors)
     * @param {string} title - Error title
     * @param {string} message - Error message
     */
    showCriticalError(title, message) {
        const overlay = document.createElement('div');
        overlay.className = 'error-overlay';
        overlay.innerHTML = `
            <div class="error-modal">
                <div class="error-icon">⚠️</div>
                <h2>${title}</h2>
                <p>${message}</p>
                <button class="btn btn-primary" onclick="this.parentElement.parentElement.remove()">
                    Close
                </button>
            </div>
        `;
        document.body.appendChild(overlay);
    }
}

// Export singleton
const errorHandler = new ErrorHandler();
export default errorHandler;

// Make available globally
window.errorHandler = errorHandler;

// Helper to wrap promises with error handling
export async function safeAsync(promise, context = 'Operation') {
    try {
        return await promise;
    } catch (error) {
        errorHandler.handleError(error, context);
        return null; // Return null on error instead of throwing
    }
}
