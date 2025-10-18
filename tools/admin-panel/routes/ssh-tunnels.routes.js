function registerSshTunnelRoutes({ app, sshTunnelManager, piManager, middlewares }) {
  const { authOnly, adminOnly } = middlewares;

  app.get('/api/ssh-tunnels', ...authOnly, async (req, res) => {
    try {
      const tunnels = await sshTunnelManager.getTunnels();
      res.json({ tunnels });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/ssh-tunnels/:id', ...authOnly, async (req, res) => {
    try {
      const { id } = req.params;
      const tunnel = await sshTunnelManager.getTunnel(id);

      if (!tunnel) {
        return res.status(404).json({ error: 'Tunnel not found' });
      }

      res.json({ tunnel });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/ssh-tunnels', ...adminOnly, async (req, res) => {
    try {
      const tunnel = await sshTunnelManager.createTunnel(req.body);
      res.json({
        success: true,
        tunnel,
        message: 'Tunnel created successfully'
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/ssh-tunnels/:id/start', ...adminOnly, async (req, res) => {
    try {
      const { id } = req.params;
      const result = await sshTunnelManager.startTunnel(id);
      res.json({
        success: true,
        tunnel: result,
        message: 'Tunnel started successfully'
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/ssh-tunnels/:id/stop', ...adminOnly, async (req, res) => {
    try {
      const { id } = req.params;
      const result = await sshTunnelManager.stopTunnel(id);
      res.json({
        success: true,
        message: 'Tunnel stopped successfully'
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.put('/api/ssh-tunnels/:id', ...adminOnly, async (req, res) => {
    try {
      const { id } = req.params;
      const tunnel = await sshTunnelManager.updateTunnel(id, req.body);
      res.json({
        success: true,
        tunnel,
        message: 'Tunnel updated successfully'
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.delete('/api/ssh-tunnels/:id', ...adminOnly, async (req, res) => {
    try {
      const { id } = req.params;
      await sshTunnelManager.deleteTunnel(id);
      res.json({
        success: true,
        message: 'Tunnel deleted successfully'
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/ssh-tunnels/:id/logs', ...authOnly, async (req, res) => {
    try {
      const { id } = req.params;
      const limit = parseInt(req.query.limit) || 50;
      const logs = await sshTunnelManager.getTunnelLogs(id, limit);
      res.json({ logs });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/ssh-tunnels/discover', ...adminOnly, async (req, res) => {
    try {
      const { piId } = req.body;
      const services = await piManager.discoverDockerServices(piId);

      res.json({
        success: true,
        services,
        count: services.length,
        message: `Discovered ${services.length} Docker service(s)`
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });
}

module.exports = {
  registerSshTunnelRoutes
};
