// =============================================================================
// WebSocket Wrapper
// =============================================================================

class SocketManager {
    constructor() {
        this.socket = io();
        this.listeners = new Map();
    }

    on(event, callback) {
        if (!this.listeners.has(event)) {
            this.listeners.set(event, []);
            this.socket.on(event, (...args) => {
                const callbacks = this.listeners.get(event) || [];
                callbacks.forEach(cb => cb(...args));
            });
        }
        this.listeners.get(event).push(callback);
    }

    emit(event, data) {
        this.socket.emit(event, data);
    }

    off(event, callback) {
        if (!this.listeners.has(event)) return;
        const callbacks = this.listeners.get(event);
        const index = callbacks.indexOf(callback);
        if (index > -1) {
            callbacks.splice(index, 1);
        }
    }
}

// Export singleton
const socketManager = new SocketManager();
export default socketManager;
