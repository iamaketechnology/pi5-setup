// =============================================================================
// PI5 Dashboard - Client WebSocket
// =============================================================================

const socket = io();
let notifications = [];
let currentFilter = 'all';

// DOM Elements
const notificationsContainer = document.getElementById('notifications-container');
const notifCount = document.getElementById('notif-count');
const clientsCount = document.getElementById('clients-count');
const connectionStatus = document.getElementById('connection-status');
const clearBtn = document.getElementById('clear-btn');
const filterBtns = document.querySelectorAll('.filter-btn');

// =============================================================================
// WebSocket Events
// =============================================================================

socket.on('connect', () => {
    console.log('[Dashboard] Connected to server');
    updateConnectionStatus('connected');
});

socket.on('disconnect', () => {
    console.log('[Dashboard] Disconnected from server');
    updateConnectionStatus('disconnected');
});

socket.on('init', (data) => {
    console.log('[Dashboard] Initial data received', data);
    notifications = data.notifications || [];
    clientsCount.textContent = data.connectedClients || 1;
    renderNotifications();
});

socket.on('notification', (notification) => {
    console.log('[Dashboard] New notification', notification);
    notifications.unshift(notification);
    renderNotifications();
    playNotificationSound();
});

socket.on('action', (data) => {
    console.log('[Dashboard] Action received', data);
    // Update UI to show action result
    showToast(`Action ${data.action} exécutée`, 'success');
});

socket.on('clear', () => {
    notifications = [];
    renderNotifications();
    showToast('Notifications effacées', 'info');
});

// =============================================================================
// UI Functions
// =============================================================================

function updateConnectionStatus(status) {
    connectionStatus.textContent = status === 'connected' ? '🟢 Connecté' : '🔴 Déconnecté';
    connectionStatus.className = `value status ${status}`;
}

function renderNotifications() {
    notifCount.textContent = notifications.length;

    const filteredNotifications = notifications.filter(notif => {
        if (currentFilter === 'all') return true;
        return notif.status === currentFilter;
    });

    if (filteredNotifications.length === 0) {
        notificationsContainer.innerHTML = `
            <div class="empty-state">
                <p>🔔 Aucune notification</p>
                <small>${currentFilter === 'all' ? 'En attente de workflows n8n...' : `Aucune notification "${currentFilter}"`}</small>
            </div>
        `;
        return;
    }

    notificationsContainer.innerHTML = filteredNotifications
        .map(notif => createNotificationCard(notif))
        .join('');

    // Attach event listeners to action buttons
    document.querySelectorAll('.action-btn').forEach(btn => {
        btn.addEventListener('click', handleAction);
    });
}

function createNotificationCard(notif) {
    const statusClass = `badge-${notif.status || 'info'}`;
    const timestamp = new Date(notif.timestamp).toLocaleString('fr-FR');

    return `
        <div class="notification-card" data-id="${notif.id}">
            <div class="notification-header">
                <div class="notification-title">${notif.workflow || 'Workflow'}</div>
                <span class="notification-badge ${statusClass}">${notif.status || 'info'}</span>
            </div>
            <div class="notification-body">
                <p class="notification-message">${notif.message || 'Aucun message'}</p>
                <div class="notification-meta">
                    <span>⏱️ ${timestamp}</span>
                    ${notif.executionId ? `<span>🔗 ID: ${notif.executionId}</span>` : ''}
                </div>
            </div>
            ${notif.requiresAction ? createActionButtons(notif) : ''}
        </div>
    `;
}

function createActionButtons(notif) {
    return `
        <div class="notification-actions">
            <button class="btn btn-success action-btn" data-id="${notif.id}" data-action="approve">
                ✅ Approuver
            </button>
            <button class="btn btn-secondary action-btn" data-id="${notif.id}" data-action="reject">
                ❌ Rejeter
            </button>
        </div>
    `;
}

// =============================================================================
// Action Handlers
// =============================================================================

async function handleAction(event) {
    const notificationId = event.target.dataset.id;
    const action = event.target.dataset.action;

    try {
        const response = await fetch(`/api/action/${notificationId}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action })
        });

        if (response.ok) {
            showToast(`Action "${action}" envoyée`, 'success');
            // Remove the notification from the list
            notifications = notifications.filter(n => n.id !== parseInt(notificationId));
            renderNotifications();
        } else {
            showToast('Erreur lors de l\'action', 'error');
        }
    } catch (error) {
        console.error('Action error:', error);
        showToast('Erreur réseau', 'error');
    }
}

async function clearAllNotifications() {
    if (!confirm('Effacer toutes les notifications ?')) return;

    try {
        const response = await fetch('/api/notifications', { method: 'DELETE' });
        if (response.ok) {
            notifications = [];
            renderNotifications();
        }
    } catch (error) {
        console.error('Clear error:', error);
        showToast('Erreur lors de l\'effacement', 'error');
    }
}

function setFilter(filter) {
    currentFilter = filter;
    filterBtns.forEach(btn => {
        btn.classList.toggle('active', btn.dataset.filter === filter);
    });
    renderNotifications();
}

// =============================================================================
// Utility Functions
// =============================================================================

function showToast(message, type = 'info') {
    // Simple console log for now (can be replaced with a proper toast library)
    console.log(`[Toast ${type}] ${message}`);
}

function playNotificationSound() {
    // Optional: Add notification sound
    // const audio = new Audio('/sounds/notification.mp3');
    // audio.play().catch(e => console.log('Sound play failed:', e));
}

// =============================================================================
// Event Listeners
// =============================================================================

clearBtn.addEventListener('click', clearAllNotifications);

filterBtns.forEach(btn => {
    btn.addEventListener('click', () => setFilter(btn.dataset.filter));
});

// Initial render
renderNotifications();
