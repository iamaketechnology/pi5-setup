function registerNetworkRoutes({ app, networkManager, middlewares }) {
  const { authOnly, adminOnly } = middlewares;

  app.get('/api/network/interfaces', ...authOnly, async (req, res) => {
    try {
      const { piId } = req.query;
      const interfaces = await networkManager.getNetworkInterfaces(piId);
      res.json({ interfaces });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/network/bandwidth', ...authOnly, async (req, res) => {
    try {
      const { piId, interface: iface } = req.query;
      const stats = await networkManager.getBandwidthStats(piId, iface || 'eth0');
      res.json({ stats });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/network/connections', ...authOnly, async (req, res) => {
    try {
      const { piId } = req.query;
      const connections = await networkManager.getActiveConnections(piId);
      res.json({ connections });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/network/firewall', ...authOnly, async (req, res) => {
    try {
      const { piId } = req.query;
      const firewall = await networkManager.getFirewallStatus(piId);
      res.json({ firewall });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/network/public-ip', ...authOnly, async (req, res) => {
    try {
      const { piId } = req.query;
      const publicIP = await networkManager.getPublicIP(piId);
      res.json({ publicIP });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/network/ping', ...adminOnly, async (req, res) => {
    try {
      const { piId, host, count } = req.body;
      const result = await networkManager.testPing(piId, host, count);
      res.json({ result });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/network/dns', ...adminOnly, async (req, res) => {
    try {
      const { piId, domain } = req.body;
      const result = await networkManager.testDNS(piId, domain);
      res.json({ result });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/network/ports', ...authOnly, async (req, res) => {
    try {
      const { piId } = req.query;
      const ports = await networkManager.getListeningPorts(piId);
      res.json({ ports });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // Get local IP of the admin panel server (Mac)
  app.get('/api/network/local-ip', async (req, res) => {
    try {
      const os = require('os');
      const interfaces = os.networkInterfaces();
      let localIP = null;

      // Find first non-internal IPv4 address
      for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
          // Skip internal (localhost) and IPv6
          if (iface.family === 'IPv4' && !iface.internal) {
            localIP = iface.address;
            break;
          }
        }
        if (localIP) break;
      }

      res.json({
        success: true,
        ip: localIP || 'localhost'
      });
    } catch (error) {
      res.json({
        success: false,
        error: error.message,
        ip: 'localhost'
      });
    }
  });
}

module.exports = {
  registerNetworkRoutes
};
