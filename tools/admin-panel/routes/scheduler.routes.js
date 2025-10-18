function registerSchedulerRoutes({ app, db, scheduler, executeScript, middlewares }) {
  const { authOnly, adminOnly } = middlewares;

  app.get('/api/scheduler/tasks', ...authOnly, (req, res) => {
    try {
      const { piId, enabled } = req.query;
      const tasks = db.getScheduledTasks({
        piId,
        enabled: enabled !== undefined ? enabled === 'true' : undefined
      });

      res.json({ tasks });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/scheduler/tasks', ...adminOnly, async (req, res) => {
    try {
      const { name, piId, scriptPath, cron, enabled } = req.body;

      const taskId = db.createScheduledTask({
        name,
        pi_id: piId,
        script_path: scriptPath,
        cron_expression: cron,
        enabled: enabled !== false
      });

      if (enabled !== false) {
        const task = db.getScheduledTaskById(taskId);
        scheduler.scheduleTask(task, executeScript);
      }

      res.json({ success: true, id: taskId });
    } catch (error) {
      res.status(500).json({ success: false, error: error.message });
    }
  });

  app.put('/api/scheduler/tasks/:id', ...adminOnly, async (req, res) => {
    try {
      const { id } = req.params;
      const updates = req.body;

      db.updateScheduledTask(id, updates);

      if (updates.enabled !== undefined) {
        scheduler.stopTask(id);

        if (updates.enabled) {
          const task = db.getScheduledTaskById(id);
          scheduler.scheduleTask(task, executeScript);
        }
      }

      res.json({ success: true });
    } catch (error) {
      res.status(500).json({ success: false, error: error.message });
    }
  });

  app.delete('/api/scheduler/tasks/:id', ...adminOnly, (req, res) => {
    try {
      const { id } = req.params;

      scheduler.stopTask(id);
      db.deleteScheduledTask(id);

      res.json({ success: true });
    } catch (error) {
      res.status(500).json({ success: false, error: error.message });
    }
  });
}

module.exports = {
  registerSchedulerRoutes
};
