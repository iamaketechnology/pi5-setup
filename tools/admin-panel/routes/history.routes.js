function registerHistoryRoutes({ app, db, middlewares }) {
  const { authOnly } = middlewares;

  app.get('/api/history', ...authOnly, (req, res) => {
    try {
      const { piId, status, scriptType, search, limit = 50 } = req.query;

      const executions = db.getExecutions({
        piId,
        status,
        scriptType,
        search,
        limit: parseInt(limit)
      });

      const stats = {
        total: executions.length,
        success: executions.filter(e => e.status === 'success').length,
        failed: executions.filter(e => e.status === 'failed').length,
        running: executions.filter(e => e.status === 'running').length,
        avgDuration: '-'
      };

      const completedExecs = executions.filter(e => e.duration);
      if (completedExecs.length > 0) {
        const avgMs = completedExecs.reduce((sum, e) => sum + e.duration, 0) / completedExecs.length;
        stats.avgDuration = `${Math.round(avgMs / 1000)}s`;
      }

      res.json({ executions, stats });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/history/:id', ...authOnly, (req, res) => {
    try {
      const execution = db.getExecutionById(req.params.id);

      if (!execution) {
        return res.status(404).json({ error: 'Execution not found' });
      }

      res.json(execution);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/history/stats', ...authOnly, (req, res) => {
    try {
      const { piId } = req.query;
      const stats = db.getExecutionStats(piId);
      res.json({ stats });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
}

module.exports = {
  registerHistoryRoutes
};
