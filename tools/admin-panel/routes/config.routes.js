function registerConfigRoutes({ app, config, piManager, appVersion }) {
  app.get('/api/config', (req, res) => {
    const appConfig = {
      version: appVersion,
      name: 'PI5 Control Center',
      features: {
        multiPi: piManager.getAllPis().length > 1,
        authentication: config.auth?.enabled || false,
        notifications: config.notifications?.enabled || false,
        scheduler: config.scheduler?.enabled || false,
        monitoring: true,
        networkMonitoring: true
      },
      tabs: [
        { id: 'dashboard', name: '📊 Dashboard', enabled: true },
        { id: 'scripts', name: '📜 Scripts', enabled: true },
        { id: 'network', name: '🌐 Network', enabled: true },
        { id: 'docker', name: '🐳 Docker', enabled: true },
        { id: 'info', name: '📋 Info', enabled: true },
        { id: 'history', name: '📝 History', enabled: true },
        { id: 'scheduler', name: '⏰ Scheduler', enabled: config.scheduler?.enabled || false }
      ].filter(tab => tab.enabled),
      serviceCategories: [
        { id: 'backend', name: 'Backend', icon: '🗄️' },
        { id: 'monitoring', name: 'Monitoring', icon: '📊' },
        { id: 'automation', name: 'Automation', icon: '🤖' },
        { id: 'proxy', name: 'Proxy', icon: '🔀' }
      ],
      refreshIntervals: {
        systemStats: parseInt(process.env.REFRESH_SYSTEM_STATS) || 5000,
        bandwidth: parseInt(process.env.REFRESH_BANDWIDTH) || 5000,
        docker: parseInt(process.env.REFRESH_DOCKER) || 10000,
        connections: parseInt(process.env.REFRESH_CONNECTIONS) || 10000,
        history: parseInt(process.env.REFRESH_HISTORY) || 30000
      },
      capabilities: {
        ssh: true,
        docker: true,
        firewall: true,
        systemd: true
      }
    };

    res.json(appConfig);
  });
}

module.exports = {
  registerConfigRoutes
};
