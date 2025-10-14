# Changelog - PI5 Control Center

All notable changes to the PI5 Admin Panel will be documented in this file.

---

## [2.0.0] - 2025-01-14

### 🎉 MAJOR RELEASE - Complete Rewrite

**Breaking Changes:**
- Panel now deploys **ON the Pi** (not local Mac tool anymore)
- SSH connection changed from `Mac → Pi` to `localhost → localhost`
- Configuration format changed (see `config.pi.js`)
- Docker deployment required

### ✨ Added

**Dashboard & Monitoring:**
- **System Stats Dashboard**: Real-time CPU, RAM, Temperature, Disk monitoring (updates every 5s)
- **Docker Stats**: Live container metrics (CPU/RAM per container)
- **Quick Actions**: One-click Backup, Healthcheck, Security Scan, Update
- **Uptime Display**: System uptime tracking

**Navigation & Organization:**
- **Multi-tab Interface**: 6 distinct sections (Dashboard, Deploy, Maintenance, Tests, Docker, Config)
- **Script Categories**: Auto-categorization by type (deploy, maintenance, utils, test, common)
- **Search/Filter**: Search scripts by name or category in each section
- **Script Type Icons**: Visual indicators (🚀 Deploy, 🔧 Maintenance, 🧪 Tests, ⚙️ Config, 📦 Common)

**Script Discovery:**
- **Extended Patterns**: Auto-discover ALL script types
  - Deploy scripts (`*-deploy.sh`)
  - Maintenance scripts (`/maintenance/*.sh`)
  - Utils scripts (`/utils/*.sh`)
  - Test scripts (`*-test.sh`, `diagnose*.sh`)
  - Common scripts (`common-scripts/*.sh`)
- **Metadata Enrichment**: Each script has type, icon, color-coded badge

**Docker Management:**
- **Enhanced Container View**: Grid layout with detailed status
- **Per-Container Actions**: Start, Stop, Restart, View Logs
- **Container Logs**: Inline log viewer (last 50 lines)
- **Auto-refresh**: Manual refresh button + auto-update on actions

**Deployment:**
- **Docker Container**: Panel runs as Docker container on Pi
- **Traefik Integration**: Labels for automatic reverse proxy setup
- **Health Check**: Built-in Docker healthcheck
- **Volume Mounts**: SSH keys, project root, Docker socket
- **Bootstrap Script**: One-liner installer (`00-install-panel-on-pi.sh`)

**API Enhancements:**
- **New Endpoint**: `GET /api/system/stats` (CPU, RAM, Temp, Disk, Uptime, Docker)
- **Enhanced Scripts API**: Returns type, icon, typeLabel metadata
- **Better Error Handling**: Graceful degradation on SSH failures

### 🔧 Changed

**Architecture:**
- **Deployment Model**: Local Mac tool → Dockerized Pi service
- **SSH Target**: Remote Pi → Localhost
- **Config File**: `config.example.js` → `config.pi.js` (localhost mode)
- **Project Access**: Network mount → Volume mount (`/app/project`)

**UI/UX:**
- **Layout**: Single-page → Multi-tab navigation
- **Theme**: Enhanced dark theme with better contrast
- **Cards**: List view → Card grid with hover effects
- **Terminal**: Side panel → Full-width in Dashboard tab

**Performance:**
- **Script Discovery**: Faster with parallel glob patterns
- **Stats Updates**: Polling every 5s (previously manual only)
- **Docker Stats**: Cached in system stats (reduces API calls)

### 🐛 Fixed
- Script discovery now skips internal files (e.g., `_common.sh`)
- Better handling of scripts without services (common-scripts)
- Terminal auto-scroll works correctly
- Modal confirmation switches to Dashboard to show terminal
- WebSocket reconnection on container restart

### 🗑️ Removed
- **Mac SSH Config**: No longer needed (localhost only)
- **Manual Script Patterns**: Replaced with auto-detection
- **Old Config Format**: Removed multi-Pi support (will return in v3.0)

### 📝 Documentation
- Complete README rewrite with installation instructions
- API documentation with examples
- Troubleshooting section
- Security best practices
- Comparison table v1.0 vs v2.0

---

## [1.0.0] - 2025-01-13

### ✨ Initial Release

**Features:**
- Local Mac tool to manage Pi via SSH
- Script discovery from `01-infrastructure/*/scripts/*-deploy.sh`
- Docker container management (basic start/stop/logs)
- Terminal with WebSocket logs
- Confirmation modal before execution
- SSH status indicator

**Tech Stack:**
- Node.js + Express
- Socket.io for WebSocket
- node-ssh for SSH connection
- Simple single-page UI

---

## Roadmap

### [3.0.0] - Future
- [ ] Multi-Pi support (switch between multiple Pis)
- [ ] Execution history with SQLite database
- [ ] Cron scheduler via UI
- [ ] Webhook/Telegram notifications
- [ ] User authentication (login/password)
- [ ] Configuration export/import
- [ ] Historical stats graphs (Chart.js)
- [ ] Automatic scheduled backups
- [ ] Mobile PWA mode
- [ ] Dark/Light theme toggle

---

**Legend:**
- ✨ Added
- 🔧 Changed
- 🐛 Fixed
- 🗑️ Removed
- 🎉 Major Release
- ⚠️ Breaking Change
