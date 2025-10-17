// =============================================================================
// Multi-Terminal System Module
// =============================================================================

import socket from '../utils/socket.js';
import api from '../utils/api.js';

class TerminalManager {
    constructor() {
        this.terminals = {};
        this.activeTerminalId = 'terminal-1';
        this.terminalCounter = 1;
        this.currentExecutionId = null;
        this.currentPrompt = 'pi@pi5:~$'; // Default prompt
    }

    init() {
        // Initialize first terminal
        this.terminals['terminal-1'] = {
            id: 'terminal-1',
            element: document.getElementById('terminal-1'),
            outputElement: document.querySelector('#terminal-1 .terminal-output'),
            inputElement: document.querySelector('#terminal-1 .terminal-input'),
            lines: [],
            commandHistory: [],
            historyIndex: -1
        };

        this.setupTerminalInput('terminal-1');
        this.setupEventListeners();
        this.setupWebSocketListeners();
    }

    setupEventListeners() {
        // New Terminal button
        document.getElementById('new-terminal')?.addEventListener('click', () => this.createNewTerminal());

        // Clear Terminal button
        document.getElementById('clear-active-terminal')?.addEventListener('click', () => {
            this.clearTerminal(this.activeTerminalId);
        });

        // Terminal tab clicks (delegated)
        document.getElementById('terminal-tabs')?.addEventListener('click', (e) => {
            const tab = e.target.closest('.terminal-tab');
            if (tab && !e.target.classList.contains('terminal-tab-close')) {
                const terminalId = tab.dataset.terminalId;
                this.switchTerminal(terminalId);
            }
        });
    }

    setupWebSocketListeners() {
        socket.on('log', (data) => {
            this.addLine(data.data, data.type);
        });

        socket.on('execution-start', (data) => {
            this.currentExecutionId = data.executionId;
            this.addLine(`\n▶️ Starting execution: ${data.scriptPath}\n`, 'info');
        });

        socket.on('execution-end', (data) => {
            if (data.success) {
                this.addLine(`\n✅ Execution completed (exit code: ${data.exitCode})\n`, 'success');
            } else {
                this.addLine(`\n❌ Execution failed: ${data.error || 'Unknown error'}\n`, 'error');
            }
            this.currentExecutionId = null;

            // Reload history after execution
            if (document.querySelector('[data-tab="history"]').classList.contains('active')) {
                window.dispatchEvent(new CustomEvent('terminal:execution-end'));
            }
        });
    }

    createNewTerminal() {
        this.terminalCounter++;
        const terminalId = `terminal-${this.terminalCounter}`;

        // Create terminal wrapper
        const terminalWrapper = document.createElement('div');
        terminalWrapper.id = terminalId;
        terminalWrapper.className = 'terminal-wrapper';
        terminalWrapper.dataset.terminalId = terminalId;
        terminalWrapper.innerHTML = `
            <div class="terminal-output">
                <div class="terminal-line info">🎯 Terminal ${this.terminalCounter} - Ready</div>
            </div>
            <div class="terminal-input-wrapper">
                <span class="terminal-prompt">${this.currentPrompt}</span>
                <input type="text" class="terminal-input" placeholder="Type command and press Enter..." autocomplete="off" spellcheck="false">
            </div>
        `;

        document.getElementById('terminals-container').appendChild(terminalWrapper);

        // Create tab
        const tab = document.createElement('div');
        tab.className = 'terminal-tab';
        tab.dataset.terminalId = terminalId;
        tab.innerHTML = `
            <span class="terminal-tab-label">Terminal ${this.terminalCounter}</span>
            <button class="terminal-tab-close" onclick="terminalManager.closeTerminal('${terminalId}')" title="Close">✕</button>
        `;

        document.getElementById('terminal-tabs').appendChild(tab);

        // Register terminal
        this.terminals[terminalId] = {
            id: terminalId,
            element: terminalWrapper,
            outputElement: terminalWrapper.querySelector('.terminal-output'),
            inputElement: terminalWrapper.querySelector('.terminal-input'),
            lines: [],
            commandHistory: [],
            historyIndex: -1
        };

        this.setupTerminalInput(terminalId);
        this.switchTerminal(terminalId);
        this.addLine(`✨ Created Terminal ${this.terminalCounter}`, 'success', terminalId);
    }

    switchTerminal(terminalId) {
        if (!this.terminals[terminalId]) return;

        this.activeTerminalId = terminalId;

        // Update tabs
        document.querySelectorAll('.terminal-tab').forEach(t => t.classList.remove('active'));
        document.querySelector(`.terminal-tab[data-terminal-id="${terminalId}"]`)?.classList.add('active');

        // Update terminal views
        document.querySelectorAll('.terminal-wrapper').forEach(t => t.classList.remove('active'));
        this.terminals[terminalId].element.classList.add('active');

        // Focus input
        this.terminals[terminalId].inputElement?.focus();
    }

    closeTerminal(terminalId) {
        if (Object.keys(this.terminals).length === 1) {
            this.addLine('⚠️ Cannot close the last terminal', 'error');
            return;
        }

        // Remove tab
        const tab = document.querySelector(`.terminal-tab[data-terminal-id="${terminalId}"]`);
        if (tab) tab.remove();

        // Remove terminal element
        if (this.terminals[terminalId]) {
            this.terminals[terminalId].element.remove();
            delete this.terminals[terminalId];
        }

        // Switch to another terminal if this was active
        if (this.activeTerminalId === terminalId) {
            const remainingTerminalId = Object.keys(this.terminals)[0];
            this.switchTerminal(remainingTerminalId);
        }
    }

    clearTerminal(terminalId) {
        const terminal = this.terminals[terminalId];
        if (!terminal) return;

        terminal.outputElement.innerHTML = '<div class="terminal-line info">🎯 Terminal cleared</div>';
        terminal.lines = [];
    }

    addLine(text, type = 'info', terminalId = null) {
        const targetId = terminalId || this.activeTerminalId;
        const terminal = this.terminals[targetId];

        if (!terminal) return;

        const line = document.createElement('div');
        line.className = `terminal-line ${type}`;
        line.textContent = text;
        terminal.outputElement.appendChild(line);
        terminal.outputElement.scrollTop = terminal.outputElement.scrollHeight;

        terminal.lines.push({ text, type, timestamp: Date.now() });

        // Limit history
        if (terminal.lines.length > 1000) {
            terminal.lines.shift();
            terminal.outputElement.removeChild(terminal.outputElement.firstChild);
        }
    }

    setupTerminalInput(terminalId) {
        const terminal = this.terminals[terminalId];
        if (!terminal || !terminal.inputElement) return;

        const inputEl = terminal.inputElement;

        inputEl.addEventListener('keydown', async (e) => {
            if (e.key === 'Enter') {
                const command = inputEl.value.trim();
                if (!command) return;

                terminal.commandHistory.push(command);
                terminal.historyIndex = terminal.commandHistory.length;

                this.addLine(`$ ${command}`, 'command', terminalId);
                inputEl.value = '';

                await this.executeCommand(command, terminalId);
            }
            else if (e.key === 'ArrowUp') {
                e.preventDefault();
                if (terminal.historyIndex > 0) {
                    terminal.historyIndex--;
                    inputEl.value = terminal.commandHistory[terminal.historyIndex] || '';
                }
            }
            else if (e.key === 'ArrowDown') {
                e.preventDefault();
                if (terminal.historyIndex < terminal.commandHistory.length - 1) {
                    terminal.historyIndex++;
                    inputEl.value = terminal.commandHistory[terminal.historyIndex] || '';
                } else {
                    terminal.historyIndex = terminal.commandHistory.length;
                    inputEl.value = '';
                }
            }
        });
    }

    async executeCommand(command, terminalId) {
        try {
            const selectedPi = document.getElementById('pi-selector')?.value;
            if (!selectedPi) {
                this.addLine('⚠️ Aucun Pi sélectionné', 'error', terminalId);
                return;
            }

            this.addLine('⏳ Executing...', 'info', terminalId);

            const result = await api.post('/execute-command', { command, piId: selectedPi });

            if (result.success) {
                if (result.output) {
                    result.output.split('\n').forEach(line => {
                        this.addLine(line, 'output', terminalId);
                    });
                }
                if (result.error) {
                    result.error.split('\n').forEach(line => {
                        this.addLine(line, 'error', terminalId);
                    });
                }
                this.addLine(`✅ Exit code: ${result.exitCode}`, 'success', terminalId);
            } else {
                this.addLine(`❌ Error: ${result.error}`, 'error', terminalId);
            }
        } catch (error) {
            this.addLine(`❌ Failed to execute: ${error.message}`, 'error', terminalId);
        }
    }

    /**
     * Update terminal prompt based on selected Pi
     */
    updatePrompt(piInfo) {
        if (!piInfo) {
            this.currentPrompt = 'pi@pi5:~$';
        } else {
            const username = piInfo.username || 'pi';
            const hostname = piInfo.host?.split('.')[0] || piInfo.id || 'pi5';
            this.currentPrompt = `${username}@${hostname}:~$`;
        }

        // Update all existing terminal prompts
        document.querySelectorAll('.terminal-prompt').forEach(prompt => {
            prompt.textContent = this.currentPrompt;
        });
    }
}

// Export singleton
const terminalManager = new TerminalManager();
export default terminalManager;

// Export helper function for direct command execution
export function runCommand(command, terminalId = null) {
    const targetId = terminalId || terminalManager.activeTerminalId;
    terminalManager.executeCommand(command, targetId);
}

// Make available globally for onclick handlers
window.terminalManager = terminalManager;
