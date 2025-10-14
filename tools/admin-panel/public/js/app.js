// =============================================================================
// PI5 Admin Panel - Client Application
// =============================================================================

const socket = io();

// DOM Elements
const sshStatus = document.getElementById('ssh-status');
const sshTarget = document.getElementById('ssh-target');
const scriptsContainer = document.getElementById('scripts-container');
const dockerContainer = document.getElementById('docker-container');
const terminal = document.getElementById('terminal');
const clearTerminalBtn = document.getElementById('clear-terminal');
const refreshDockerBtn = document.getElementById('refresh-docker');
const confirmModal = document.getElementById('confirm-modal');
const confirmMessage = document.getElementById('confirm-message');
const confirmYes = document.getElementById('confirm-yes');
const confirmNo = document.getElementById('confirm-no');

let pendingScript = null;

// =============================================================================
// WebSocket Events
// =============================================================================

socket.on('connect', () => {
    log('🔌 Connected to server', 'info');
    socket.emit('test-connection');
});

socket.on('disconnect', () => {
    log('🔌 Disconnected from server', 'error');
    updateSSHStatus(false);
});

socket.on('connection-status', (data) => {
    updateSSHStatus(data.connected, data.host, data.error);
});

socket.on('log', (data) => {
    log(data.data, data.type);
});

socket.on('execution-start', (data) => {
    log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`, 'info');
    log(`🚀 Executing: ${data.scriptPath}`, 'info');
    log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`, 'info');
});

socket.on('execution-end', (data) => {
    log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`, 'info');
    if (data.success) {
        log(`✅ Script completed successfully (exit code: ${data.exitCode})`, 'success');
    } else {
        log(`❌ Script failed: ${data.error || 'Unknown error'}`, 'error');
    }
    log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`, 'info');
});

// =============================================================================
// UI Functions
// =============================================================================

function updateSSHStatus(connected, host = null, error = null) {
    if (connected) {
        sshStatus.textContent = '🟢 Connected';
        sshStatus.className = 'value status connected';
        if (host) sshTarget.textContent = host;
    } else {
        sshStatus.textContent = '🔴 Disconnected';
        sshStatus.className = 'value status disconnected';
        if (error) log(`❌ SSH Error: ${error}`, 'error');
    }
}

function log(message, type = 'stdout') {
    const line = document.createElement('div');
    line.className = `terminal-line ${type}`;
    line.textContent = message;
    terminal.appendChild(line);
    terminal.scrollTop = terminal.scrollHeight;
}

function clearTerminal() {
    terminal.innerHTML = '';
    log('🎯 Terminal cleared', 'info');
}

// =============================================================================
// Scripts Management
// =============================================================================

async function loadScripts() {
    try {
        const response = await fetch('/api/scripts');
        const data = await response.json();

        if (data.scripts.length === 0) {
            scriptsContainer.innerHTML = '<div class="loading">No scripts found</div>';
            return;
        }

        // Group by category
        const grouped = data.scripts.reduce((acc, script) => {
            if (!acc[script.category]) acc[script.category] = [];
            acc[script.category].push(script);
            return acc;
        }, {});

        scriptsContainer.innerHTML = '';

        Object.entries(grouped).forEach(([category, scripts]) => {
            const categoryDiv = document.createElement('div');
            categoryDiv.className = 'script-category-group';
            categoryDiv.innerHTML = `<div class="script-category">${category}</div>`;

            scripts.forEach(script => {
                const scriptDiv = document.createElement('div');
                scriptDiv.className = 'script-item';
                scriptDiv.innerHTML = `
                    <div class="script-service">${script.service}</div>
                    <div class="script-name">${script.name}</div>
                `;
                scriptDiv.onclick = () => confirmExecution(script);
                categoryDiv.appendChild(scriptDiv);
            });

            scriptsContainer.appendChild(categoryDiv);
        });

    } catch (error) {
        scriptsContainer.innerHTML = '<div class="loading">Error loading scripts</div>';
        log(`❌ Error loading scripts: ${error.message}`, 'error');
    }
}

function confirmExecution(script) {
    pendingScript = script;
    confirmMessage.textContent = `Exécuter "${script.name}" sur le Pi ?`;
    confirmModal.classList.remove('hidden');
}

async function executeScript(script) {
    try {
        log(`\n🎬 Requesting execution of: ${script.name}`, 'info');

        const response = await fetch('/api/execute', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ scriptPath: script.path })
        });

        const data = await response.json();

        if (!data.success) {
            log(`❌ Execution request failed: ${data.error}`, 'error');
        }

    } catch (error) {
        log(`❌ Error: ${error.message}`, 'error');
    }
}

// =============================================================================
// Docker Management
// =============================================================================

async function loadDockerContainers() {
    dockerContainer.innerHTML = '<div class="loading">Loading containers...</div>';

    try {
        const response = await fetch('/api/docker/containers');
        const data = await response.json();

        if (data.containers.length === 0) {
            dockerContainer.innerHTML = '<div class="loading">No containers running</div>';
            return;
        }

        dockerContainer.innerHTML = '';

        data.containers.forEach(container => {
            const containerDiv = document.createElement('div');
            containerDiv.className = 'docker-item';

            const status = container.State === 'running' ? 'running' : 'stopped';

            containerDiv.innerHTML = `
                <div class="docker-header">
                    <div class="docker-name">${container.Names}</div>
                    <div class="docker-status ${status}">
                        ${status === 'running' ? '🟢' : '🔴'} ${container.State}
                    </div>
                </div>
                <div class="docker-actions">
                    <button class="btn btn-secondary btn-icon" onclick="dockerAction('restart', '${container.Names}')">🔄</button>
                    <button class="btn btn-secondary btn-icon" onclick="dockerAction('stop', '${container.Names}')">⏸️</button>
                    <button class="btn btn-secondary btn-icon" onclick="viewLogs('${container.Names}')">📋</button>
                </div>
            `;

            dockerContainer.appendChild(containerDiv);
        });

    } catch (error) {
        dockerContainer.innerHTML = '<div class="loading">Error loading containers</div>';
        log(`❌ Error loading containers: ${error.message}`, 'error');
    }
}

async function dockerAction(action, container) {
    try {
        log(`\n🐳 ${action} container: ${container}`, 'info');

        const response = await fetch(`/api/docker/${action}/${container}`, {
            method: 'POST'
        });

        const data = await response.json();

        if (data.success) {
            log(`✅ Container ${container} ${action}ed successfully`, 'success');
            setTimeout(loadDockerContainers, 1000);
        } else {
            log(`❌ Failed to ${action} container: ${data.error}`, 'error');
        }

    } catch (error) {
        log(`❌ Error: ${error.message}`, 'error');
    }
}

async function viewLogs(container) {
    try {
        log(`\n📋 Fetching logs for: ${container}`, 'info');

        const response = await fetch(`/api/docker/logs/${container}`);
        const data = await response.json();

        log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`, 'info');
        log(data.logs, 'stdout');
        log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`, 'info');

    } catch (error) {
        log(`❌ Error: ${error.message}`, 'error');
    }
}

// =============================================================================
// Event Listeners
// =============================================================================

clearTerminalBtn.addEventListener('click', clearTerminal);
refreshDockerBtn.addEventListener('click', loadDockerContainers);

confirmYes.addEventListener('click', () => {
    if (pendingScript) {
        executeScript(pendingScript);
        pendingScript = null;
    }
    confirmModal.classList.add('hidden');
});

confirmNo.addEventListener('click', () => {
    pendingScript = null;
    confirmModal.classList.add('hidden');
});

// Close modal on outside click
confirmModal.addEventListener('click', (e) => {
    if (e.target === confirmModal) {
        pendingScript = null;
        confirmModal.classList.add('hidden');
    }
});

// =============================================================================
// Initialize
// =============================================================================

(async function init() {
    log('🎯 PI5 Admin Panel initialized', 'info');
    log('📡 Connecting to server...', 'info');

    // Check SSH status
    try {
        const response = await fetch('/api/status');
        const data = await response.json();
        updateSSHStatus(data.connected, data.host, data.error);
    } catch (error) {
        log(`❌ Failed to check status: ${error.message}`, 'error');
    }

    // Load data
    await loadScripts();
    await loadDockerContainers();

    log('✅ Ready to execute scripts', 'success');
})();
