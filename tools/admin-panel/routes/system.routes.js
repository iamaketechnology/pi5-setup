function registerSystemRoutes({ app, getSystemStats, db, piManager, middlewares }) {
  const { authOnly } = middlewares;

  app.get('/api/system/stats', ...authOnly, async (req, res) => {
    try {
      const { piId } = req.query;
      const stats = await getSystemStats(piId);
      res.json(stats);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/stats/history', (req, res) => {
    try {
      const { piId, hours = 24, interval = 300 } = req.query;
      const targetPi = piId || piManager.getCurrentPi();

      const history = db.getStatsHistory(targetPi, {
        hours: parseInt(hours),
        interval: parseInt(interval)
      });

      res.json({ history });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
}

module.exports = {
  registerSystemRoutes
};
