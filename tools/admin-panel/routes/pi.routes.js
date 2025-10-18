function registerPiRoutes({ app, piManager, middlewares }) {
  const { authOnly, adminOnly } = middlewares;

  app.post('/api/pis/select', ...authOnly, (req, res) => {
    try {
      const { piId } = req.body;
      const piConfig = piManager.setCurrentPi(piId);
      res.json({ success: true, pi: piConfig });
    } catch (error) {
      res.status(400).json({ success: false, error: error.message });
    }
  });

  app.post('/api/pis/:piId/test', ...authOnly, async (req, res) => {
    try {
      const { piId } = req.params;
      const result = await piManager.testConnection(piId);
      res.json(result);
    } catch (error) {
      res.status(500).json({ success: false, error: error.message });
    }
  });

  app.get('/api/pis', ...authOnly, async (req, res) => {
    try {
      const pis = await piManager.getAllPis();
      const currentPi = piManager.getCurrentPi();
      res.json({ pis, current: currentPi });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/pis/pair', ...adminOnly, async (req, res) => {
    try {
      const { token } = req.body;

      if (!token) {
        return res.status(400).json({ error: 'Token required' });
      }

      const result = await piManager.pairPi(token);

      if (result.success) {
        res.json({
          success: true,
          message: result.message,
          pi: result.pi
        });
      } else {
        res.status(400).json({
          success: false,
          error: result.message,
          pi: result.pi
        });
      }
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/pis/refresh', ...authOnly, async (req, res) => {
    try {
      await piManager.refreshPisCache();
      const pis = await piManager.getAllPis();
      res.json({
        success: true,
        message: 'Pis cache refreshed',
        pis
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
}

module.exports = {
  registerPiRoutes
};
