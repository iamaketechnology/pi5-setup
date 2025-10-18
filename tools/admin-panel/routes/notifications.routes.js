function registerNotificationRoutes({ app, notifications, middlewares }) {
  const { adminOnly } = middlewares;

  app.post('/api/notifications/test', ...adminOnly, async (req, res) => {
    try {
      const result = await notifications.testNotification();
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
}

module.exports = {
  registerNotificationRoutes
};
