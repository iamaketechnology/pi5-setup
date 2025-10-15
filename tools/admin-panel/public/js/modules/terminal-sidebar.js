// =============================================================================
// Terminal Sidebar Module
// =============================================================================
// Manages global terminal sidebar (VS Code style)
// =============================================================================

class TerminalSidebarManager {
    constructor() {
        this.isOpen = false;
    }

    init() {
        this.setupEventListeners();
        console.log('✅ Terminal Sidebar initialized');
    }

    setupEventListeners() {
        // Toggle button in header
        const toggleBtn = document.getElementById('toggle-terminal-sidebar');
        if (toggleBtn) {
            toggleBtn.addEventListener('click', () => this.toggle());
        }

        // Close button in sidebar
        const closeBtn = document.getElementById('close-terminal-sidebar');
        if (closeBtn) {
            closeBtn.addEventListener('click', () => this.close());
        }

        // Open terminal hint button in Installation tab
        const hintBtn = document.getElementById('open-terminal-hint');
        if (hintBtn) {
            hintBtn.addEventListener('click', () => this.open());
        }

        // Keyboard shortcut: Ctrl+` (like VS Code)
        document.addEventListener('keydown', (e) => {
            if (e.ctrlKey && e.key === '`') {
                e.preventDefault();
                this.toggle();
            }
            // Escape to close
            if (e.key === 'Escape' && this.isOpen) {
                this.close();
            }
        });

        // Close on overlay click (mobile)
        document.addEventListener('click', (e) => {
            if (this.isOpen && window.innerWidth <= 768) {
                const sidebar = document.getElementById('terminal-sidebar');
                const toggleBtn = document.getElementById('toggle-terminal-sidebar');
                if (!sidebar.contains(e.target) && e.target !== toggleBtn) {
                    this.close();
                }
            }
        });
    }

    toggle() {
        if (this.isOpen) {
            this.close();
        } else {
            this.open();
        }
    }

    open() {
        document.body.classList.add('sidebar-open');
        this.isOpen = true;

        // Focus terminal input
        setTimeout(() => {
            const activeInput = document.querySelector('#terminal-sidebar .terminal-wrapper.active .terminal-input');
            if (activeInput) {
                activeInput.focus();
            }
        }, 300); // Wait for animation

        // Store state
        localStorage.setItem('terminal-sidebar-open', 'true');
    }

    close() {
        document.body.classList.remove('sidebar-open');
        this.isOpen = false;

        // Store state
        localStorage.setItem('terminal-sidebar-open', 'false');
    }

    // Restore state on load
    restoreState() {
        const wasOpen = localStorage.getItem('terminal-sidebar-open') === 'true';
        if (wasOpen) {
            this.open();
        }
    }
}

// Export singleton
const terminalSidebarManager = new TerminalSidebarManager();
export default terminalSidebarManager;
