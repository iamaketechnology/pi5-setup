# 🔧 Installation Assistant Refactoring Plan

## 📊 Current State
- **File**: `installation-assistant.js`
- **Size**: 1,881 lines
- **Methods**: 24 methods
- **Problem**: Monolithic, hard to maintain

## 🎯 Refactoring Goals
1. **Modularity**: Separate concerns into focused modules
2. **Maintainability**: Easier to understand and modify
3. **Testability**: Each module can be tested independently
4. **No Breaking Changes**: Keep same external API

## 📁 New Module Structure

```
js/modules/installation/
├── installation-coordinator.js      ← Main entry point (coordinator pattern)
├── installation-terminal.js         ← Terminal controls & AI
├── installation-widgets.js          ← Stats widgets (Docker, Disk, Updates)
├── installation-sidebar.js          ← Sidebar navigation & filtering
├── installation-updates-ui.js       ← Updates section rendering
├── installation-backups.js          ← Backup management
├── installation-services.js         ← Service installation logic
└── REFACTORING-PLAN.md              ← This file
```

## 🔄 Module Responsibilities

### 1. **installation-coordinator.js** (~200 lines)
**Role**: Main orchestrator, creates and coordinates all modules

**Exports**:
- `InstallationAssistant` class (singleton)

**Responsibilities**:
- Initialize all sub-modules
- Provide compatibility layer for existing code
- Coordinate between modules

**Dependencies**:
- All other installation modules
- SystemDiagnostics
- TerminalIntelligent

---

### 2. **installation-terminal.js** ✅ (~100 lines)
**Role**: Manage terminal interface

**Exports**:
- `InstallationTerminal` class

**Methods**:
- `init()` - Initialize terminal
- `initControls()` - Setup toggle/clear/export buttons
- `write(text, type)` - Write to terminal
- `clear()` - Clear terminal
- `download()` - Export terminal output
- `displaySuggestions(suggestions)` - Show AI suggestions

**Dependencies**:
- TerminalIntelligent

**Status**: ✅ Created

---

### 3. **installation-widgets.js** ✅ (~150 lines)
**Role**: Manage stats widgets at top of Installation tab

**Exports**:
- `InstallationWidgets` class

**Methods**:
- `load()` - Load all widgets
- `updateWidget(id, value)` - Update single widget
- `loadUpdatesCount()` - Load updates count
- `sendDiagnostics()` - Send to AI

**Dependencies**:
- SystemDiagnostics
- InstallationTerminal (for AI suggestions)

**Status**: ✅ Created

---

### 4. **installation-sidebar.js** (~200 lines)
**Role**: Sidebar navigation, category filtering

**Exports**:
- `InstallationSidebar` class

**Methods**:
- `init()` - Initialize sidebar
- `initCategoryHandlers()` - Setup category click handlers
- `initServiceCardHandlers()` - Setup service card handlers
- `toggleCollapse(button)` - Collapse/expand categories
- `filterServicesByCategory(category)` - Filter services
- `setActiveCategory(category)` - Mark category as active

**Dependencies**:
- InstallationBackups (for backups category)
- InstallationUpdatesUI (for updates categories)
- InstallationServices (for service details)

**Status**: ⏳ Pending

---

### 5. **installation-updates-ui.js** (~300 lines)
**Role**: Render Updates sections UI

**Exports**:
- `InstallationUpdatesUI` class

**Methods**:
- `showSection(section)` - Show updates section
- `renderSectionContent(section)` - Render section content
- `getServiceIcon(service)` - Get service icon

**Dependencies**:
- UpdatesManager
- InstallationWidgets (reload after updates loaded)

**Status**: ⏳ Pending

---

### 6. **installation-backups.js** (~400 lines)
**Role**: Backup management (list, create, restore)

**Exports**:
- `InstallationBackups` class

**Methods**:
- `showBackupsList()` - Show all backups
- `loadAllBackups()` - Load backups from API
- `listBackups(type)` - List backups for service
- `generateBackupScript(type)` - Generate backup script
- `generateRestoreScript(type, backup)` - Generate restore script

**Dependencies**:
- API (for backup operations)
- InstallationTerminal (for messages)

**Status**: ⏳ Pending

---

### 7. **installation-services.js** (~600 lines)
**Role**: Service installation workflow

**Exports**:
- `InstallationServices` class

**Methods**:
- `handleQuickInstall(type, btn)` - Handle install button
- `showServiceDetails(type)` - Show service details
- `proceedWithInstall(type, btn, needsBaseSetup)` - Install service
- `proceedWithReinstall(type, btn, cleanFirst)` - Reinstall service
- `generateCleanupScript(type)` - Generate cleanup script
- `getServiceName(type)` - Get service display name

**Dependencies**:
- API (for service operations)
- InstallationTerminal (for output)
- TerminalManager (for script execution)

**Status**: ⏳ Pending

---

## 🔗 Module Dependencies Graph

```
installation-coordinator.js (main)
    ├──> installation-terminal.js
    ├──> installation-widgets.js
    │       └──> installation-terminal.js
    ├──> installation-sidebar.js
    │       ├──> installation-backups.js
    │       ├──> installation-updates-ui.js
    │       └──> installation-services.js
    ├──> installation-updates-ui.js
    │       └──> installation-widgets.js
    ├──> installation-backups.js
    │       └──> installation-terminal.js
    └──> installation-services.js
            └──> installation-terminal.js
```

## 📝 Migration Steps

1. ✅ Create `installation/` directory
2. ✅ Create `installation-terminal.js`
3. ✅ Create `installation-widgets.js`
4. ⏳ Create `installation-sidebar.js`
5. ⏳ Create `installation-updates-ui.js`
6. ⏳ Create `installation-backups.js`
7. ⏳ Create `installation-services.js`
8. ⏳ Create `installation-coordinator.js`
9. ⏳ Update `index.html` to load coordinator
10. ⏳ Test all functionality
11. ⏳ Remove old `installation-assistant.js`

## ✅ Benefits

- **Smaller files** (100-600 lines vs 1,881 lines)
- **Clear responsibilities** (single responsibility principle)
- **Easy to test** (isolated modules)
- **Better collaboration** (multiple people can work on different modules)
- **Reusable** (modules can be reused in other contexts)

## 🚀 Next Steps

Continue creating remaining modules following this plan!
