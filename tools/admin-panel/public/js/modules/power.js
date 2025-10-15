// =============================================================================
// Power Management Module
// =============================================================================
// Handles Pi reboot and shutdown operations
// =============================================================================

import { runCommand } from './terminal.js';

// =============================================================================
// Power Control Functions
// =============================================================================

/**
 * Show confirmation modal for power operation
 */
function showPowerConfirmation(action, callback) {
    const modal = document.getElementById('confirm-modal');
    const message = document.getElementById('confirm-message');
    const yesBtn = document.getElementById('confirm-yes');
    const noBtn = document.getElementById('confirm-no');

    const actionTexts = {
        reboot: {
            emoji: '🔄',
            title: 'Redémarrer le Pi',
            message: 'Êtes-vous sûr de vouloir redémarrer le Pi ? Tous les services seront interrompus temporairement.',
            confirm: '✅ Redémarrer'
        },
        shutdown: {
            emoji: '⚡',
            title: 'Éteindre le Pi',
            message: 'Êtes-vous sûr de vouloir éteindre le Pi ? Vous devrez le rallumer manuellement.',
            confirm: '✅ Éteindre'
        }
    };

    const config = actionTexts[action];
    message.innerHTML = `<strong>${config.emoji} ${config.title}</strong><br><br>${config.message}`;
    yesBtn.textContent = config.confirm;

    // Show modal
    modal.classList.remove('hidden');

    // Handle confirmation
    const handleYes = () => {
        modal.classList.add('hidden');
        callback();
        cleanup();
    };

    const handleNo = () => {
        modal.classList.add('hidden');
        cleanup();
    };

    const cleanup = () => {
        yesBtn.removeEventListener('click', handleYes);
        noBtn.removeEventListener('click', handleNo);
    };

    yesBtn.addEventListener('click', handleYes);
    noBtn.addEventListener('click', handleNo);
}

/**
 * Reboot the Pi
 */
export function rebootPi() {
    showPowerConfirmation('reboot', () => {
        if (window.toastManager) {
            window.toastManager.warning('Redémarrage en cours...', 'Le Pi va redémarrer dans quelques secondes');
        }
        runCommand('sudo reboot');
    });
}

/**
 * Shutdown the Pi
 */
export function shutdownPi() {
    showPowerConfirmation('shutdown', () => {
        if (window.toastManager) {
            window.toastManager.warning('Extinction en cours...', 'Le Pi va s\'éteindre dans quelques secondes');
        }
        runCommand('sudo shutdown -h now');
    });
}

// =============================================================================
// Initialize Power Controls
// =============================================================================

export function initPowerControls() {
    const rebootBtn = document.getElementById('btn-reboot');
    const shutdownBtn = document.getElementById('btn-shutdown');

    if (rebootBtn) {
        rebootBtn.addEventListener('click', rebootPi);
    }

    if (shutdownBtn) {
        shutdownBtn.addEventListener('click', shutdownPi);
    }

    console.log('✅ Power controls initialized');
}
