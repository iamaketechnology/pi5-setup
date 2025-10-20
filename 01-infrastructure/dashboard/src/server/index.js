// =============================================================================
// PI5 Dashboard Server - Express + Socket.io
// =============================================================================
// Version: 1.2.0 - Added Quick Actions (n8n integration, stats, health checks)
// Description: Real-time notification hub for n8n workflows
// Author: PI5-SETUP Project
// =============================================================================

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const cookieParser = require('cookie-parser');
const path = require('path');
const auth = require('./auth');
const { N8nService, registerN8nRoutes } = require('./n8n-integration');
const { registerStatsRoutes } = require('./stats');

// Configuration
const PORT = process.env.PORT || 3000;
const NODE_ENV = process.env.NODE_ENV || 'development';

// Initialize Express app
const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(cors());
app.use(express.json());
app.use(cookieParser());

// Apply auth middleware to protected routes
app.use((req, res, next) => {
  if (auth.isPublicRoute(req.path)) {
    return next();
  }
  auth.requireAuth(req, res, next);
});

app.use(express.static(path.join(__dirname, '../public')));

// In-memory storage for notifications (can be replaced with Redis/DB later)
const notifications = [];
const MAX_NOTIFICATIONS = 100;

// Logging helper
const log = {
  info: (msg) => console.log(`[INFO] ${new Date().toISOString()} - ${msg}`),
  error: (msg) => console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`),
  success: (msg) => console.log(`[SUCCESS] ${new Date().toISOString()} - ${msg}`)
};

// =============================================================================
// HTTP Routes
// =============================================================================

// Health check endpoint (public)
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    authEnabled: auth.isAuthEnabled()
  });
});

// Login endpoint (public)
app.post('/api/login', (req, res) => {
  const { password } = req.body;

  if (!password) {
    return res.status(400).json({ error: 'Password required' });
  }

  if (!auth.verifyPassword(password)) {
    log.error(`Failed login attempt from ${req.ip}`);
    return res.status(401).json({ error: 'Mot de passe incorrect' });
  }

  // Create session
  const token = auth.generateToken();
  auth.createSession(token);

  // Set cookie
  res.cookie('dashboard_session', token, {
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000, // 24 hours
    sameSite: 'strict'
  });

  log.success(`Login successful from ${req.ip}`);
  res.json({ success: true });
});

// Logout endpoint
app.post('/api/logout', (req, res) => {
  res.clearCookie('dashboard_session');
  res.json({ success: true });
});

// Get all notifications
app.get('/api/notifications', (req, res) => {
  res.json({
    total: notifications.length,
    data: notifications
  });
});

// Webhook endpoint for n8n workflows
app.post('/api/webhook', (req, res) => {
  const notification = {
    id: Date.now(),
    timestamp: new Date().toISOString(),
    ...req.body
  };

  // Add to storage
  notifications.unshift(notification);
  if (notifications.length > MAX_NOTIFICATIONS) {
    notifications.pop();
  }

  // Broadcast to all connected clients
  io.emit('notification', notification);

  log.info(`New notification: ${notification.workflow || 'Unknown'} - ${notification.status || 'unknown'}`);

  res.status(200).json({
    success: true,
    message: 'Notification received',
    id: notification.id
  });
});

// Action endpoint (approve/reject buttons)
app.post('/api/action/:notificationId', (req, res) => {
  const { notificationId } = req.params;
  const { action, data } = req.body;

  log.info(`Action received: ${action} for notification ${notificationId}`);

  // Broadcast action to all clients
  io.emit('action', {
    notificationId: parseInt(notificationId),
    action,
    data,
    timestamp: new Date().toISOString()
  });

  res.json({
    success: true,
    message: `Action ${action} executed`
  });
});

// Clear all notifications
app.delete('/api/notifications', (req, res) => {
  const count = notifications.length;
  notifications.length = 0;

  io.emit('clear');

  res.json({
    success: true,
    cleared: count
  });
});

// =============================================================================
// Quick Actions Integration
// =============================================================================

// Initialize n8n service
const n8nService = new N8nService();

// Register n8n routes
registerN8nRoutes(app, n8nService, io);

// Register stats & health routes
registerStatsRoutes(app, notifications);

log.info('Quick Actions enabled: n8n integration, stats, health checks');

// =============================================================================
// WebSocket Events
// =============================================================================

io.on('connection', (socket) => {
  log.info(`Client connected: ${socket.id}`);

  // Send existing notifications to new client
  socket.emit('init', {
    notifications,
    connectedClients: io.engine.clientsCount
  });

  // Handle client actions
  socket.on('action', (data) => {
    log.info(`Action from ${socket.id}: ${JSON.stringify(data)}`);
    io.emit('action', data);
  });

  socket.on('disconnect', () => {
    log.info(`Client disconnected: ${socket.id}`);
  });
});

// =============================================================================
// Server Startup
// =============================================================================

server.listen(PORT, () => {
  log.success(`Dashboard server running on port ${PORT}`);
  log.info(`Environment: ${NODE_ENV}`);
  log.info(`WebSocket endpoint: ws://localhost:${PORT}`);
  log.info(`Webhook endpoint: http://localhost:${PORT}/api/webhook`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  log.info('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    log.info('HTTP server closed');
  });
});
