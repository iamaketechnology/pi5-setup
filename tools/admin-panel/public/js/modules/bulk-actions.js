// =============================================================================
// Bulk Actions Module - Multi-select & Batch Operations
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// =============================================================================

class BulkActionsManager {
    constructor() {
        this.selectedItems = new Set();
        this.isEnabled = false;
        this.context = null; // 'scripts', 'docker', etc.
    }

    init() {
        this.setupGlobalListeners();
        console.log('✅ Bulk actions module initialized');
    }

    setupGlobalListeners() {
        // Listen for Shift key to enable bulk mode
        document.addEventListener('keydown', (e) => {
            if (e.shiftKey && !this.isEnabled) {
                this.enable();
            }
        });

        document.addEventListener('keyup', (e) => {
            if (!e.shiftKey && this.isEnabled) {
                this.disable();
            }
        });
    }

    /**
     * Enable bulk selection mode
     * @param {string} context - Context ('scripts', 'docker', etc.)
     */
    enable(context = 'scripts') {
        this.isEnabled = true;
        this.context = context;
        document.body.classList.add('bulk-mode-active');

        if (!document.getElementById('bulk-actions-bar')) {
            this.createBulkActionsBar();
        }

        this.updateUI();
    }

    /**
     * Disable bulk selection mode
     */
    disable() {
        this.isEnabled = false;
        this.selectedItems.clear();
        document.body.classList.remove('bulk-mode-active');

        const bar = document.getElementById('bulk-actions-bar');
        if (bar) bar.remove();

        this.updateUI();
    }

    /**
     * Toggle item selection
     * @param {string} itemId - Item ID
     */
    toggleItem(itemId) {
        if (this.selectedItems.has(itemId)) {
            this.selectedItems.delete(itemId);
        } else {
            this.selectedItems.add(itemId);
        }

        this.updateUI();
    }

    /**
     * Select all items in current context
     */
    selectAll() {
        if (this.context === 'scripts') {
            const scripts = document.querySelectorAll('.script-card');
            scripts.forEach(card => {
                const scriptId = card.dataset.scriptId;
                if (scriptId) this.selectedItems.add(scriptId);
            });
        }

        this.updateUI();
    }

    /**
     * Clear all selections
     */
    clearAll() {
        this.selectedItems.clear();
        this.updateUI();
    }

    /**
     * Create bulk actions bar
     */
    createBulkActionsBar() {
        const bar = document.createElement('div');
        bar.id = 'bulk-actions-bar';
        bar.className = 'bulk-actions-bar';
        bar.innerHTML = `
            <div class="bulk-actions-content">
                <div class="bulk-actions-info">
                    <i data-lucide="check-square" size="18"></i>
                    <span id="bulk-count">0 selected</span>
                </div>
                <div class="bulk-actions-buttons">
                    <button class="btn btn-sm" onclick="window.bulkActionsManager.selectAll()">
                        Select All
                    </button>
                    <button class="btn btn-sm" onclick="window.bulkActionsManager.clearAll()">
                        Clear
                    </button>
                    <button class="btn btn-sm btn-primary" onclick="window.bulkActionsManager.executeSelected()">
                        <i data-lucide="play" size="14"></i>
                        Run Selected
                    </button>
                    <button class="btn btn-sm" onclick="window.bulkActionsManager.disable()">
                        <i data-lucide="x" size="14"></i>
                    </button>
                </div>
            </div>
        `;

        document.body.appendChild(bar);

        // Initialize icons
        if (typeof lucide !== 'undefined') {
            lucide.createIcons();
        }
    }

    /**
     * Update UI to reflect current selection
     */
    updateUI() {
        // Update count in bar
        const countEl = document.getElementById('bulk-count');
        if (countEl) {
            countEl.textContent = `${this.selectedItems.size} selected`;
        }

        // Update visual selection on items
        if (this.context === 'scripts') {
            const scripts = document.querySelectorAll('.script-card');
            scripts.forEach(card => {
                const scriptId = card.dataset.scriptId;
                if (this.selectedItems.has(scriptId)) {
                    card.classList.add('selected');
                } else {
                    card.classList.remove('selected');
                }
            });
        }
    }

    /**
     * Execute selected scripts
     */
    async executeSelected() {
        if (this.selectedItems.size === 0) {
            if (window.toastManager) {
                window.toastManager.warning('No scripts selected', 'Select at least one script to run');
            }
            return;
        }

        const count = this.selectedItems.size;
        const confirmed = confirm(`Run ${count} script${count > 1 ? 's' : ''}?`);

        if (!confirmed) return;

        if (window.toastManager) {
            window.toastManager.info(`Running ${count} script${count > 1 ? 's' : ''}...`, 'Please wait');
        }

        const scripts = Array.from(this.selectedItems);
        let successCount = 0;
        let errorCount = 0;

        for (const scriptId of scripts) {
            try {
                // Find script element
                const scriptCard = document.querySelector(`[data-script-id="${scriptId}"]`);
                if (scriptCard) {
                    // Trigger click to run (reuse existing logic)
                    scriptCard.click();
                    successCount++;
                    await new Promise(resolve => setTimeout(resolve, 500)); // Delay between runs
                }
            } catch (error) {
                console.error(`Failed to run script ${scriptId}:`, error);
                errorCount++;
            }
        }

        if (window.toastManager) {
            if (errorCount === 0) {
                window.toastManager.success('Bulk execution complete', `${successCount} script${successCount > 1 ? 's' : ''} executed`);
            } else {
                window.toastManager.warning('Bulk execution completed with errors', `${successCount} succeeded, ${errorCount} failed`);
            }
        }

        this.disable();
    }

    /**
     * Get selected items
     * @returns {Set} - Set of selected item IDs
     */
    getSelected() {
        return new Set(this.selectedItems);
    }

    /**
     * Check if item is selected
     * @param {string} itemId - Item ID
     * @returns {boolean}
     */
    isSelected(itemId) {
        return this.selectedItems.has(itemId);
    }
}

// Export singleton
const bulkActionsManager = new BulkActionsManager();
export default bulkActionsManager;

// Make available globally
window.bulkActionsManager = bulkActionsManager;
