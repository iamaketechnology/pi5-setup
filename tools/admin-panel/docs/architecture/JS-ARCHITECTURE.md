# JavaScript Architecture - PI5 Control Center v3.4.0

Complete modular ES6 architecture using native browser modules.

## 📊 Structure

```
public/js/
├── main.js                     # Entry point (120 lines)
├── config.js                   # Client configuration
├── modules/                    # Feature modules (10 files)
│   ├── tabs.js                # Tab navigation
│   ├── pi-selector.js         # Multi-Pi selector
│   ├── system-stats.js        # System monitoring
│   ├── terminal.js            # Terminal UI
│   ├── scripts.js             # Script execution
│   ├── docker.js              # Docker management
│   ├── history.js             # Execution history
│   ├── scheduler.js           # Task scheduler
│   ├── services.js            # Services info
│   └── network.js             # Network monitoring
└── utils/                      # Shared utilities (2 files)
    ├── api.js                 # HTTP client
    └── socket.js              # WebSocket client
```

## 🎯 Module System

### Native ES6 Modules

**Before (v3.3.0):**
```javascript
// Monolithic app.js (1800+ lines)
// Everything in global scope
// No imports/exports
```

**After (v3.4.0):**
```javascript
// main.js - Entry point
import tabsManager from './modules/tabs.js';
import terminalManager from './modules/terminal.js';
// ... other imports

// Each module exports clean API
export default terminalManager;
```

## 📦 Module Details

### Entry Point

**`main.js`** (120 lines)
- Orchestrates all modules
- Handles DOMContentLoaded
- Initializes modules in order
- Sets up global references (backward compat)

```javascript
document.addEventListener('DOMContentLoaded', async () => {
    // Load config first
    await configManager.load();

    // Initialize modules
    await initModules();

    // Setup tab lazy loading
    setupTabLazyLoading();
});
```

### Core Modules

**`tabs.js`**
- Tab navigation system
- URL state management
- Lazy loading support

**`pi-selector.js`**
- Multi-Pi support
- Pi switching
- Connection status

**`system-stats.js`**
- Real-time system metrics
- Auto-refresh (5s interval)
- CPU, Memory, Disk, Temperature
- Docker stats

**`terminal.js`**
- Multi-tab terminal
- Real-time log streaming
- WebSocket integration
- Tab management (create, close, switch)

### Feature Modules

**`scripts.js`**
- Script discovery
- Script execution
- Category filtering
- Search functionality

**`docker.js`**
- Container listing
- Container actions (start/stop/restart)
- Container logs
- Status monitoring

**`history.js`**
- Execution history table
- Filtering (status, type, search)
- Stats dashboard
- Execution details

**`scheduler.js`**
- Scheduled tasks management
- Cron expression UI
- Task toggle (enable/disable)
- Add/Edit/Delete tasks

**`services.js`**
- Service discovery
- Credentials display
- Quick commands
- Service-specific actions

**`network.js`**
- Network interfaces
- Bandwidth monitoring
- Active connections
- Firewall status
- Port scanning

### Utilities

**`api.js`** - HTTP Client
```javascript
class APIClient {
    constructor(baseURL = '/api') { }
    get(endpoint, params) { }
    post(endpoint, data) { }
    put(endpoint, data) { }
    delete(endpoint) { }
}
export default new APIClient('/api');
```

**`socket.js`** - WebSocket Client
```javascript
class SocketManager {
    connect() { }
    on(event, callback) { }
    emit(event, data) { }
}
export default new SocketManager();
```

## 🔄 Module Pattern

Each module follows this structure:

```javascript
/* ============================================
   Module Name
   ============================================ */

import api from '../utils/api.js';
import socket from '../utils/socket.js';

class ModuleManager {
    constructor() {
        this.state = {};
        this.elements = {};
    }

    /**
     * Initialize module
     */
    async init() {
        this.cacheElements();
        this.attachEvents();
        await this.load();
    }

    /**
     * Cache DOM elements
     */
    cacheElements() {
        this.elements.container = document.getElementById('module-container');
    }

    /**
     * Attach event listeners
     */
    attachEvents() {
        // Event handlers
    }

    /**
     * Load data from API
     */
    async load() {
        const data = await api.get('/endpoint');
        this.render(data);
    }

    /**
     * Render UI
     */
    render(data) {
        // Update DOM
    }
}

// Export singleton
const moduleManager = new ModuleManager();
export default moduleManager;
```

## 🚀 Loading Strategy

### 1. Eager Loading (on page load)
- `tabs.js`
- `pi-selector.js`
- `system-stats.js`
- `config.js`

### 2. Lazy Loading (on tab switch)
- `scripts.js` - Loaded when Scripts tab opened
- `docker.js` - Loaded when Docker tab opened
- `history.js` - Loaded when History tab opened
- `scheduler.js` - Loaded when Scheduler tab opened
- `services.js` - Loaded when Info tab opened
- `network.js` - Loaded when Network tab opened

**Benefits:**
- Faster initial page load
- Reduced memory usage
- Better performance

## 🔌 API Communication

### HTTP Client Pattern

```javascript
// GET request
const data = await api.get('/scripts');

// POST request
const result = await api.post('/execute', { scriptPath });

// With query params
const stats = await api.get('/system/stats', { piId: 'pi-prod' });
```

### WebSocket Pattern

```javascript
// Listen for events
socket.on('log', (data) => {
    terminal.addLine(data.data, data.type);
});

// Emit events
socket.emit('test-connection');
```

## ✅ Benefits

1. **Modularity**: Each feature in its own file
2. **Maintainability**: Easy to find and fix code
3. **Testability**: Modules can be tested independently
4. **Reusability**: Modules can be reused
5. **Performance**: Lazy loading improves initial load
6. **Type Safety**: JSDoc for IDE autocomplete

## 📝 Adding New Modules

1. Create new file: `public/js/modules/your-module.js`
2. Follow module pattern (class + singleton export)
3. Import in `main.js`:
   ```javascript
   import yourModule from './modules/your-module.js';
   ```
4. Initialize in `initModules()` function
5. Add lazy loading if needed

## 🔧 Common Patterns

### Error Handling

```javascript
async load() {
    try {
        const data = await api.get('/endpoint');
        this.render(data);
    } catch (error) {
        console.error('Failed to load:', error);
        this.renderError('Failed to load data');
    }
}
```

### Loading States

```javascript
async load() {
    this.showLoading();
    const data = await api.get('/endpoint');
    this.hideLoading();
    this.render(data);
}
```

### Auto-refresh

```javascript
startAutoRefresh(interval = 5000) {
    this.stopAutoRefresh();
    this.refreshInterval = setInterval(() => {
        this.load();
    }, interval);
}

stopAutoRefresh() {
    if (this.refreshInterval) {
        clearInterval(this.refreshInterval);
    }
}
```

## 🐛 Debugging

### Console Output

Each module logs initialization:
```
✅ Tabs module initialized
✅ System stats module initialized
📡 Loading network tab...
```

### Module Access

Modules are accessible via `window` for debugging:
```javascript
window.terminalManager.addLine('test', 'info');
window.scriptsManager.load();
```

## 📚 Related Documentation

- [CSS-ARCHITECTURE.md](./CSS-ARCHITECTURE.md) - CSS structure
- [REFACTORING-PLAN.md](../../REFACTORING-PLAN.md) - Refactoring strategy
- [README.md](../../README.md) - Project overview

---

**Version:** 3.4.0
**Last Updated:** 2025-01-14
**Maintainer:** PI5-SETUP Project
