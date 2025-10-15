// =============================================================================
// Icon Utilities
// =============================================================================
// Helper functions to render Lucide icons
// =============================================================================

/**
 * Create an icon element
 * @param {string} name - Lucide icon name (e.g., 'home', 'settings')
 * @param {Object} options - Icon options
 * @returns {HTMLElement}
 */
export function icon(name, options = {}) {
    const {
        size = 16,
        color = 'currentColor',
        strokeWidth = 2,
        className = ''
    } = options;

    const i = document.createElement('i');
    i.setAttribute('data-lucide', name);
    i.setAttribute('stroke-width', strokeWidth);

    if (size) {
        i.style.width = `${size}px`;
        i.style.height = `${size}px`;
    }

    if (color && color !== 'currentColor') {
        i.style.color = color;
    }

    if (className) {
        i.className = className;
    }

    return i;
}

/**
 * Initialize all lucide icons in the DOM
 */
export function initIcons() {
    if (typeof lucide !== 'undefined') {
        lucide.createIcons();
        console.log('✅ Icons initialized');
    }
}

/**
 * Icon mapping from emojis to Lucide names
 */
export const iconMap = {
    // Navigation
    '🏠': 'home',
    '🎬': 'clapperboard',
    '📜': 'scroll',
    '🌐': 'globe',
    '🐳': 'container',
    '📋': 'clipboard-list',
    '📅': 'calendar',

    // Actions
    '🔄': 'rotate-cw',
    '⚡': 'power',
    '💻': 'terminal',
    '🔍': 'search',
    '➕': 'plus',
    '✕': 'x',
    '✓': 'check',
    '⚠': 'alert-triangle',
    'ℹ': 'info',

    // System
    '📊': 'bar-chart-2',
    '🖥️': 'monitor',
    '🔒': 'lock',
    '🔓': 'unlock',
    '🔐': 'key',
    '👁️': 'eye',
    '🗑️': 'trash-2',

    // Status
    '✅': 'check-circle',
    '❌': 'x-circle',
    '⏸️': 'pause-circle',
    '▶️': 'play-circle',
    '⏹️': 'square',

    // Tools
    '🔧': 'wrench',
    '⚙️': 'settings',
    '🧪': 'flask',
    '💾': 'save',
    '📦': 'package',
    '🚀': 'rocket',

    // Communication
    '📢': 'megaphone',
    '🤖': 'bot',
    '📡': 'radio',

    // Time
    '⏱️': 'timer',
    '⏰': 'clock',

    // Network
    '🔥': 'flame',
    '🏓': 'activity',

    // Misc
    '🎯': 'target',
    '🎨': 'palette',
    '🌙': 'moon',
    '☀️': 'sun'
};

/**
 * Get Lucide icon name from emoji
 * @param {string} emoji - Emoji character
 * @returns {string} - Lucide icon name
 */
export function getIconName(emoji) {
    return iconMap[emoji] || 'circle';
}

/**
 * Replace emoji with icon in a text string
 * @param {string} text - Text containing emojis
 * @returns {HTMLElement}
 */
export function replaceEmojisWithIcons(text) {
    const container = document.createElement('span');

    // Simple emoji detection and replacement
    const parts = text.split(/(\p{Emoji})/gu);

    parts.forEach(part => {
        if (iconMap[part]) {
            container.appendChild(icon(iconMap[part], { size: 16 }));
        } else {
            container.appendChild(document.createTextNode(part));
        }
    });

    return container;
}
