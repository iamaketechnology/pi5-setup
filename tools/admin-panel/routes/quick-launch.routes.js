function registerQuickLaunchRoutes({ app, piManager, middlewares }) {
  const { authOnly } = middlewares;

  app.get('/api/quick-launch/services', ...authOnly, async (req, res) => {
    try {
      const currentPi = piManager.getCurrentPi();
      if (!currentPi || !currentPi.ssh) {
        return res.json({ services: [] });
      }

      const cmd = `docker ps --format '{{.Names}}|{{.Ports}}' | grep -v PORTS`;
      const result = await currentPi.ssh.execCommand(cmd);

      if (!result.stdout) {
        return res.json({ services: [] });
      }

      const services = [];
      const lines = result.stdout.trim().split('\n');

      const serviceConfig = {
        'vaultwarden': { icon: 'lock', description: 'Password Manager', color: '#10b981' },
        'portainer': { icon: 'container', description: 'Docker Management', color: '#3b82f6' },
        'homepage': { icon: 'layout-dashboard', description: 'Services Dashboard', color: '#06b6d4' },
        'supabase-studio': { icon: 'database', description: 'Database UI', color: '#8b5cf6' },
        'supabase-kong': { icon: 'database', description: 'Supabase API', color: '#8b5cf6' },
        'grafana': { icon: 'bar-chart-2', description: 'Monitoring Dashboards', color: '#ef4444' },
        'prometheus': { icon: 'activity', description: 'Metrics Collection', color: '#ec4899' },
        'traefik': { icon: 'route', description: 'Reverse Proxy', color: '#f59e0b' },
        'pi5-dashboard': { icon: 'gauge', description: 'Status & Metrics', color: '#10b981' },
        'n8n': { icon: 'workflow', description: 'Workflow Automation', color: '#ea5a0c' },
        'ollama': { icon: 'brain', description: 'AI Models API', color: '#000000' },
        'open-webui': { icon: 'message-square', description: 'AI Chat Interface', color: '#8b5cf6' },
        'certidoc-frontend': { icon: 'file-check', description: 'Document Verification', color: '#0ea5e9' }
      };

      for (const line of lines) {
        const [name, ports] = line.split('|');
        if (!ports || !name) continue;

        const portMatches = ports.matchAll(/(?:0\.0\.0\.0|127\.0\.0\.1|\[::\]):(\d+)->(\d+)/g);

        for (const match of portMatches) {
          const externalPort = parseInt(match[1]);
          const internalPort = parseInt(match[2]);

          const config = serviceConfig[name] || {
            icon: 'server',
            description: 'Service',
            color: '#6b7280'
          };

          // Quick Launch will find and use existing SSH tunnels
          // No need to determine tunnel necessity here
          services.push({
            id: name,
            name: name.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' '),
            description: config.description,
            icon: config.icon,
            color: config.color,
            localPort: externalPort,
            remotePort: internalPort
          });
        }
      }

      res.json({ services });
    } catch (error) {
      console.error('Failed to detect services:', error);
      res.json({ services: [] });
    }
  });
}

module.exports = {
  registerQuickLaunchRoutes
};
