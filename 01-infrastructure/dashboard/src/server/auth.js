// =============================================================================
// PI5 Dashboard - Simple Authentication (Optional)
// =============================================================================
// Basic password protection for dashboard access
// Enable by setting DASHBOARD_PASSWORD environment variable
// Version: 1.1.0
// =============================================================================

const crypto = require('crypto');

// Session storage (in-memory for simplicity, use Redis in production)
const sessions = new Map();
const SESSION_DURATION = 24 * 60 * 60 * 1000; // 24 hours

// Check if auth is enabled
const isAuthEnabled = () => {
  return !!process.env.DASHBOARD_PASSWORD;
};

// Generate session token
const generateToken = () => {
  return crypto.randomBytes(32).toString('hex');
};

// Create session
const createSession = (token) => {
  sessions.set(token, {
    created: Date.now(),
    lastAccess: Date.now()
  });
  return token;
};

// Validate session
const isValidSession = (token) => {
  if (!token) return false;

  const session = sessions.get(token);
  if (!session) return false;

  // Check if session expired
  if (Date.now() - session.lastAccess > SESSION_DURATION) {
    sessions.delete(token);
    return false;
  }

  // Update last access
  session.lastAccess = Date.now();
  return true;
};

// Verify password
const verifyPassword = (password) => {
  const correctPassword = process.env.DASHBOARD_PASSWORD;
  if (!correctPassword) return true; // Auth disabled

  return password === correctPassword;
};

// Middleware: Require authentication
const requireAuth = (req, res, next) => {
  // Skip if auth disabled
  if (!isAuthEnabled()) {
    return next();
  }

  // Check session cookie
  const token = req.cookies?.dashboard_session;

  if (isValidSession(token)) {
    return next();
  }

  // Not authenticated
  if (req.path.startsWith('/api/')) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  // Redirect to login page
  res.redirect('/login.html');
};

// Public routes (no auth required)
const publicRoutes = [
  '/login.html',
  '/api/login',
  '/css/style.css',
  '/js/app.js',
  '/manifest.json',
  '/sw.js',
  '/icons/'
];

const isPublicRoute = (path) => {
  return publicRoutes.some(route => path.startsWith(route));
};

module.exports = {
  isAuthEnabled,
  generateToken,
  createSession,
  isValidSession,
  verifyPassword,
  requireAuth,
  isPublicRoute
};
