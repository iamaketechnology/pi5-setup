// =============================================================================
// PI5 Control Center - Server v3.0 (Refactored)
// =============================================================================
// Modularized server setup with separated route registrations
// Author: PI5-SETUP Project
// Version: 3.0.0
// =============================================================================

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { version: appVersion } = require('./package.json');

let config;
try {
  config = require('./config.js');
} catch (error) {
  console.error('❌ config.js not found. Copy config.example.js to config.js and configure it.');
  process.exit(1);
}

const db = require('./lib/database');
const piManager = require('./lib/pi-manager');
const supabaseClient = require('./lib/supabase-client');
const sqlSource = require('./lib/sql-source');
const scheduler = require('./lib/scheduler');
const notifications = require('./lib/notifications');
const auth = require('./lib/auth');
const servicesInfo = require('./lib/services-info');
const networkManager = require('./lib/network-manager');
const sshTunnelManager = require('./lib/ssh-tunnel-manager');

const { getScriptType, discoverScripts: discoverProjectScripts } = require('./lib/script-utils');
const { createSystemStats } = require('./lib/system-stats');
const { createExecuteScript } = require('./lib/execute-script');

const { registerAuthRoutes } = require('./routes/auth.routes');
const { registerConfigRoutes } = require('./routes/config.routes');
const { registerPiRoutes } = require('./routes/pi.routes');
const { registerScriptRoutes } = require('./routes/script.routes');
const { registerSystemRoutes } = require('./routes/system.routes');
const { registerHistoryRoutes } = require('./routes/history.routes');
const { registerSchedulerRoutes } = require('./routes/scheduler.routes');
const { registerDatabaseRoutes } = require('./routes/database.routes');
const { registerDockerRoutes } = require('./routes/docker.routes');
const { registerNotificationRoutes } = require('./routes/notifications.routes');
const { registerServiceRoutes } = require('./routes/services.routes');
const { registerSetupRoutes } = require('./routes/setup.routes');
const { registerNetworkRoutes } = require('./routes/network.routes');
const { registerBootstrapRoutes } = require('./routes/bootstrap.routes');
const { registerQuickLaunchRoutes } = require('./routes/quick-launch.routes');
const { registerSshTunnelRoutes } = require('./routes/ssh-tunnels.routes');
const { registerUpdatesRoutes } = require('./routes/updates.routes');
const { registerSocketEvents } = require('./socket');

// Initialize Express and Socket.IO
const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.set('trust proxy', 1);

app.use(express.json());
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false
}));

const loginLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false
});

const sensitiveLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false
});

const authOnly = [auth.requireAuth];
const adminOnly = [auth.requireAuth, auth.requireAdmin, sensitiveLimiter];

const middlewares = {
  authOnly,
  adminOnly,
  loginLimiter,
  sensitiveLimiter
};

const sessionMiddleware = auth.initAuth(config);
if (sessionMiddleware) {
  app.use(sessionMiddleware);
}

app.use(express.static(path.join(__dirname, 'public')));
app.use('/data', express.static(path.join(__dirname, 'data')));

// Core module initialisation
db.initDatabase(config.paths.database);
notifications.initNotifications(config);
servicesInfo.initServicesInfo(piManager, config);

(async () => {
  try {
    await piManager.initPiManager(config);
    await sshTunnelManager.initTunnelManager();
  } catch (error) {
    console.error('Failed to initialize managers:', error.message);
  }
})();

const discoverScripts = () => discoverProjectScripts(config.paths.projectRoot);
const getSystemStats = createSystemStats(piManager, db);
const executeScript = createExecuteScript({
  config,
  db,
  piManager,
  notifications,
  io,
  getScriptType
});

scheduler.initScheduler(executeScript);

// Route registration
registerAuthRoutes({ app, auth, config, middlewares });
registerConfigRoutes({ app, config, piManager, appVersion });
registerPiRoutes({ app, piManager, middlewares });
registerScriptRoutes({ app, io, piManager, discoverScripts, executeScript, middlewares });
registerSystemRoutes({ app, getSystemStats, db, piManager, middlewares });
registerHistoryRoutes({ app, db, middlewares });
registerSchedulerRoutes({ app, db, scheduler, executeScript, middlewares });
registerDatabaseRoutes({ app, piManager, sqlSource, middlewares });
registerDockerRoutes({ app, piManager, middlewares });
registerNotificationRoutes({ app, notifications, middlewares });
registerServiceRoutes({ app, servicesInfo, piManager, middlewares });
registerSetupRoutes({ app, piManager, middlewares });
registerNetworkRoutes({ app, networkManager, middlewares });
registerBootstrapRoutes({ app, supabaseClient });
registerQuickLaunchRoutes({ app, piManager, middlewares });
registerSshTunnelRoutes({ app, sshTunnelManager, piManager, middlewares });
registerUpdatesRoutes({ app, piManager, middlewares });

registerSocketEvents(io, piManager);

// Server startup
const PORT = config.server.port;
const HOST = config.server.host;

server.listen(PORT, HOST, () => {
  console.log('');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`🚀 PI5 Control Center v${appVersion}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`📍 URL: http://${HOST}:${PORT}`);
  const currentPiConfig = piManager.getCurrentPiConfig();
  console.log(`🎯 Current Pi: ${currentPiConfig?.name || 'N/A'}`);
  console.log(`📊 Database: ${config.paths.database}`);
  console.log(`🔒 Auth: ${config.auth?.enabled ? 'Enabled' : 'Disabled'}`);
  console.log(`📢 Notifications: ${config.notifications?.enabled ? 'Enabled' : 'Disabled'}`);
  console.log(`📅 Scheduler: ${config.scheduler?.enabled ? 'Enabled' : 'Disabled'}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('🛑 Shutting down...');
  scheduler.stopAll();
  piManager.disconnectAll();
  await sshTunnelManager.cleanup();
  server.close();
});
