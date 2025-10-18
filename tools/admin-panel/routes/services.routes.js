function registerServiceRoutes({ app, servicesInfo, piManager, middlewares }) {
  const { authOnly, adminOnly } = middlewares;

  app.get('/api/services/discover', ...authOnly, async (req, res) => {
    try {
      const { piId } = req.query;
      const services = await servicesInfo.discoverServices(piId);
      res.json({ services });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/services/:serviceName/credentials', ...adminOnly, async (req, res) => {
    try {
      const { serviceName } = req.params;
      const { piId } = req.query;
      const credentials = await servicesInfo.getServiceCredentials(serviceName, piId);
      res.json({ credentials });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/services/:serviceName/commands', ...adminOnly, (req, res) => {
    try {
      const { serviceName } = req.params;
      const commands = servicesInfo.getServiceCommands(serviceName);
      res.json({ commands });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/services/:serviceName/command', ...adminOnly, async (req, res) => {
    try {
      const { serviceName } = req.params;
      const { command, piId } = req.body;

      if (!command) {
        return res.status(400).json({ error: 'command required' });
      }

      const result = await piManager.executeCommand(command, piId);

      res.json({
        success: result.code === 0,
        output: result.stdout,
        error: result.stderr,
        exitCode: result.code
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/execute-command', ...adminOnly, async (req, res) => {
    try {
      const { command, piId } = req.body;

      if (!command) {
        return res.status(400).json({ error: 'command required' });
      }

      const result = await piManager.executeCommand(command, piId);

      res.json({
        success: result.code === 0,
        output: result.stdout,
        error: result.stderr,
        exitCode: result.code
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/services/:serviceName/paths', ...adminOnly, (req, res) => {
    try {
      const { serviceName } = req.params;
      const paths = servicesInfo.getServicePaths(serviceName);
      res.json({ paths });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/services/:serviceName/maintenance', ...adminOnly, (req, res) => {
    try {
      const { serviceName } = req.params;
      const commands = servicesInfo.getMaintenanceCommands(serviceName);
      res.json({ commands });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/services/:serviceName/backup', ...adminOnly, (req, res) => {
    try {
      const { serviceName } = req.params;
      const backup = servicesInfo.getBackupInfo(serviceName);
      res.json({ backup });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
}

module.exports = {
  registerServiceRoutes
};
