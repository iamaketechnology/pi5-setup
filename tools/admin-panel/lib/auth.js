// =============================================================================
// PI5 Control Center - Authentication Module
// =============================================================================
// Simple username/password authentication with sessions
// Version: 3.0.0
// =============================================================================

const bcrypt = require('bcrypt');
const session = require('express-session');

let config = null;

// =============================================================================
// Initialize Authentication
// =============================================================================

function initAuth(appConfig) {
  config = appConfig.auth || {};

  if (!config.enabled) {
    console.log('🔒 Authentication disabled');
    return null;
  }

  console.log('🔒 Authentication enabled');
  console.log(`  • ${config.users?.length || 0} user(s) configured`);

  const maxAge = config.session?.maxAge || 24 * 60 * 60 * 1000; // 24 hours
  const secureCookie = typeof config.session?.secure === 'boolean'
    ? config.session.secure
    : process.env.NODE_ENV === 'production';

  return session({
    name: config.session?.name || 'pi5.sid',
    secret: config.session?.secret || 'change-me-in-production',
    resave: false,
    saveUninitialized: false,
    rolling: config.session?.rolling ?? false,
    cookie: {
      secure: secureCookie,
      sameSite: config.session?.sameSite || 'lax',
      httpOnly: true,
      maxAge
    }
  });
}

// =============================================================================
// Middleware: Require Authentication
// =============================================================================

function requireAuth(req, res, next) {
  if (!config || !config.enabled) {
    return next();
  }

  if (req.session && req.session.user) {
    return next();
  }

  res.status(401).json({ error: 'Authentication required' });
}

// =============================================================================
// Middleware: Require Admin Role
// =============================================================================

function requireAdmin(req, res, next) {
  if (!config || !config.enabled) {
    return next();
  }

  if (req.session && req.session.user && req.session.user.role === 'admin') {
    return next();
  }

  res.status(403).json({ error: 'Admin role required' });
}

// =============================================================================
// Login
// =============================================================================

async function login(username, password) {
  if (!config || !config.enabled) {
    return { success: false, message: 'Authentication disabled' };
  }

  const user = config.users.find(u => u.username === username);

  if (!user) {
    return { success: false, message: 'Invalid username or password' };
  }

  const validPassword = await bcrypt.compare(password, user.password);

  if (!validPassword) {
    return { success: false, message: 'Invalid username or password' };
  }

  return {
    success: true,
    user: {
      username: user.username,
      role: user.role || 'user'
    }
  };
}

// =============================================================================
// Logout
// =============================================================================

function logout(req) {
  if (req.session) {
    req.session.destroy();
  }
}

// =============================================================================
// Hash Password (Utility)
// =============================================================================

async function hashPassword(password) {
  return await bcrypt.hash(password, 10);
}

// =============================================================================
// Get Current User
// =============================================================================

function getCurrentUser(req) {
  if (!config || !config.enabled) {
    return { username: 'guest', role: 'admin' };
  }

  return req.session?.user || null;
}

// =============================================================================
// Export Functions
// =============================================================================

module.exports = {
  initAuth,
  requireAuth,
  requireAdmin,
  login,
  logout,
  hashPassword,
  getCurrentUser,
  isEnabled: () => config?.enabled || false
};
