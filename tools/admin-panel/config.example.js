// =============================================================================
// PI5 Control Center - Configuration (Example)
// =============================================================================
// Copy this file to config.js and update with your Pi credentials
// config.js is gitignored for security
// Version: 3.0.0 - Multi-Pi + Notifications + Auth
// =============================================================================

const fs = require('fs');
const path = require('path');
const os = require('os');

module.exports = {
  // Server configuration
  server: {
    port: 4000,
    host: 'localhost'
  },

  // Multiple Raspberry Pi configurations
  pis: [
    {
      id: 'pi-prod',
      name: 'Pi Production',
      host: '192.168.1.118',  // Your Pi IP or hostname (pi5.local)
      port: 22,
      username: 'pi',
      tags: ['production', 'main'],
      color: '#10b981',  // Green for production

      // Option 1: SSH Key authentication (recommended)
      privateKey: fs.readFileSync(path.join(os.homedir(), '.ssh', 'id_rsa'), 'utf8'),

      // Option 2: Password authentication (uncomment if needed)
      // password: 'your_password_here',

      // SSH options
      readyTimeout: 20000,
      keepaliveInterval: 10000,

      // Remote paths for this Pi
      remoteStacksDir: '/home/pi/stacks',
      remoteTempDir: '/tmp'
    },

    // Example: Second Pi (staging)
    {
      id: 'pi-staging',
      name: 'Pi Staging',
      host: '192.168.1.119',
      port: 22,
      username: 'pi',
      tags: ['staging', 'test'],
      color: '#f59e0b',  // Orange for staging
      privateKey: fs.readFileSync(path.join(os.homedir(), '.ssh', 'id_rsa'), 'utf8'),
      readyTimeout: 20000,
      keepaliveInterval: 10000,
      remoteStacksDir: '/home/pi/stacks',
      remoteTempDir: '/tmp'
    }
  ],

  // Default Pi (used if no Pi selected)
  defaultPi: 'pi-prod',

  // Project paths
  paths: {
    // Local project root (where pi5-setup repo is)
    projectRoot: path.resolve(__dirname, '../..'),

    // Database path (SQLite for execution history)
    database: path.resolve(__dirname, 'data', 'pi5-control.db')
  },

  // Script discovery patterns
  scripts: {
    patterns: [
      '*/*/scripts/*-deploy.sh',
      '*/*/scripts/maintenance/*.sh',
      '*/*/scripts/utils/*.sh',
      'common-scripts/*.sh'
    ]
  },

  // Notifications configuration
  notifications: {
    enabled: false,  // Set to true to enable notifications

    // Webhook notifications (Discord, Slack, custom)
    webhooks: [
      // {
      //   name: 'Discord',
      //   url: 'https://discord.com/api/webhooks/...',
      //   events: ['execution.success', 'execution.failed', 'system.critical']
      // }
    ],

    // Telegram notifications
    telegram: {
      enabled: false,
      botToken: 'YOUR_BOT_TOKEN',
      chatId: 'YOUR_CHAT_ID'
    }
  },

  // Authentication configuration
  auth: {
    enabled: false,  // Set to true to enable authentication

    // Users (password will be hashed with bcrypt)
    users: [
      // {
      //   username: 'admin',
      //   password: 'hashed_password_here',  // Use bcrypt hash
      //   role: 'admin'  // admin or user
      // }
    ],

    // Session configuration
    session: {
      secret: 'change-this-to-a-random-secret',
      maxAge: 24 * 60 * 60 * 1000  // 24 hours
    }
  },

  // Scheduler configuration
  scheduler: {
    enabled: true,

    // Predefined scheduled tasks
    tasks: [
      // {
      //   id: 'daily-backup',
      //   name: 'Daily Backup',
      //   script: 'common-scripts/04-backup-rotate.sh',
      //   cron: '0 2 * * *',  // Every day at 2 AM
      //   piId: 'pi-prod',
      //   enabled: true
      // }
    ]
  }
};
