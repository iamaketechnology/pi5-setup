// =============================================================================
// Debounce Utility
// =============================================================================
// Delays function execution until after a specified delay
// =============================================================================

/**
 * Debounce function - delays execution
 * @param {Function} func - Function to debounce
 * @param {number} delay - Delay in milliseconds
 * @returns {Function}
 */
export function debounce(func, delay = 300) {
    let timeoutId;

    return function debounced(...args) {
        clearTimeout(timeoutId);

        timeoutId = setTimeout(() => {
            func.apply(this, args);
        }, delay);
    };
}

/**
 * Throttle function - limits execution rate
 * @param {Function} func - Function to throttle
 * @param {number} delay - Minimum delay between calls
 * @returns {Function}
 */
export function throttle(func, delay = 300) {
    let lastCall = 0;
    let timeoutId;

    return function throttled(...args) {
        const now = Date.now();
        const timeSinceLastCall = now - lastCall;

        if (timeSinceLastCall >= delay) {
            lastCall = now;
            func.apply(this, args);
        } else {
            clearTimeout(timeoutId);
            timeoutId = setTimeout(() => {
                lastCall = Date.now();
                func.apply(this, args);
            }, delay - timeSinceLastCall);
        }
    };
}

/**
 * Add debounced event listener
 * @param {HTMLElement} element - Element to attach listener
 * @param {string} event - Event type
 * @param {Function} callback - Callback function
 * @param {number} delay - Debounce delay
 */
export function addDebouncedListener(element, event, callback, delay = 300) {
    const debouncedCallback = debounce(callback, delay);
    element.addEventListener(event, debouncedCallback);

    // Return function to remove listener
    return () => {
        element.removeEventListener(event, debouncedCallback);
    };
}

/**
 * Create a debounced search handler
 * @param {Function} searchFunction - Function that performs search
 * @param {number} delay - Debounce delay (default 300ms)
 * @returns {Function}
 */
export function createDebouncedSearch(searchFunction, delay = 300) {
    return debounce((query) => {
        if (query.length >= 2 || query.length === 0) {
            searchFunction(query);
        }
    }, delay);
}
