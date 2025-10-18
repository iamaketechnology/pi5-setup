function registerAuthRoutes({ app, auth, config, middlewares }) {
  const { loginLimiter } = middlewares;

  app.post('/api/auth/login', loginLimiter, async (req, res) => {
    const { username, password } = req.body;

    const result = await auth.login(username, password);

    if (result.success) {
      req.session.regenerate((err) => {
        if (err) {
          return res.status(500).json({ success: false, message: 'Session initialization failed' });
        }
        req.session.user = result.user;
        res.json({ success: true, user: result.user });
      });
    } else {
      res.status(401).json({ success: false, message: result.message });
    }
  });

  app.post('/api/auth/logout', (req, res) => {
    auth.logout(req);
    res.json({ success: true });
  });

  app.get('/api/auth/me', (req, res) => {
    const user = auth.getCurrentUser(req);
    res.json({ user, authEnabled: config.auth?.enabled || false });
  });
}

module.exports = {
  registerAuthRoutes
};
