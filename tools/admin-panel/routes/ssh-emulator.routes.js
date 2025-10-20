// =============================================================================
// SSH Emulator Routes - API Endpoints
// =============================================================================
// API routes for managing SSH configs and Pi emulators
// Version: 1.0.0
// =============================================================================

function registerSshEmulatorRoutes({ app, sshEmulatorManager, middlewares = {} }) {
  const { authOnly = [], adminOnly = [] } = middlewares;

  // ===========================================================================
  // SSH Configuration Routes
  // ===========================================================================

  // GET /api/ssh/config - Get SSH configuration
  app.get('/api/ssh/config', ...authOnly, async (req, res) => {
    try {
      const config = await sshEmulatorManager.getSSHConfig();
      res.json({ success: true, ...config });
    } catch (error) {
      console.error('Error getting SSH config:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // POST /api/ssh/hosts - Add SSH host
  app.post('/api/ssh/hosts', ...authOnly, async (req, res) => {
    try {
      const { alias, hostname, port, username, identityFile, password } = req.body;

      if (!alias || !hostname || !username) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: alias, hostname, username'
        });
      }

      const result = await sshEmulatorManager.addSSHHost({
        alias,
        hostname,
        port: port || 22,
        username,
        identityFile,
        password
      });

      res.json(result);
    } catch (error) {
      console.error('Error adding SSH host:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // DELETE /api/ssh/hosts/:alias - Remove SSH host
  app.delete('/api/ssh/hosts/:alias', ...authOnly, async (req, res) => {
    try {
      const { alias } = req.params;
      const result = await sshEmulatorManager.removeSSHHost(alias);
      res.json(result);
    } catch (error) {
      console.error('Error removing SSH host:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // POST /api/ssh/test/:alias - Test SSH connection
  app.post('/api/ssh/test/:alias', ...authOnly, async (req, res) => {
    try {
      const { alias } = req.params;
      const result = await sshEmulatorManager.testSSHConnection(alias);
      res.json(result);
    } catch (error) {
      console.error('Error testing SSH connection:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // ===========================================================================
  // Pi Emulator Routes
  // ===========================================================================

  // GET /api/emulator/status - Get emulator status
  app.get('/api/emulator/status', ...authOnly, async (req, res) => {
    try {
      const status = await sshEmulatorManager.getEmulatorStatus();
      res.json({ success: true, ...status });
    } catch (error) {
      console.error('Error getting emulator status:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // POST /api/emulator/deploy - Deploy emulator on remote host
  app.post('/api/emulator/deploy', ...authOnly, async (req, res) => {
    try {
      const { targetHost, targetUser, targetPassword } = req.body;

      if (!targetHost || !targetUser) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: targetHost, targetUser'
        });
      }

      const result = await sshEmulatorManager.deployEmulator({
        targetHost,
        targetUser,
        targetPassword
      });

      res.json(result);
    } catch (error) {
      console.error('Error deploying emulator:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // POST /api/emulator/start - Start emulator
  app.post('/api/emulator/start', ...authOnly, async (req, res) => {
    try {
      const { remote = false, remoteHost } = req.body;

      const result = await sshEmulatorManager.startEmulator({
        remote,
        remoteHost
      });

      res.json(result);
    } catch (error) {
      console.error('Error starting emulator:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // POST /api/emulator/stop - Stop emulator
  app.post('/api/emulator/stop', ...authOnly, async (req, res) => {
    try {
      const { remote = false, remoteHost } = req.body;

      const result = await sshEmulatorManager.stopEmulator({
        remote,
        remoteHost
      });

      res.json(result);
    } catch (error) {
      console.error('Error stopping emulator:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // GET /api/emulator/info - Get emulator connection info
  app.get('/api/emulator/info', ...authOnly, async (req, res) => {
    try {
      const { remoteHost } = req.query;

      const result = await sshEmulatorManager.getEmulatorInfo({
        remoteHost
      });

      res.json(result);
    } catch (error) {
      console.error('Error getting emulator info:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // ===========================================================================
  // Network Utilities Routes
  // ===========================================================================

  // GET /api/network/scan - Scan local network
  app.get('/api/network/scan', ...authOnly, async (req, res) => {
    try {
      const result = await sshEmulatorManager.scanNetwork();
      res.json(result);
    } catch (error) {
      console.error('Error scanning network:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });
}

module.exports = { registerSshEmulatorRoutes };
