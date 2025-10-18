function registerSetupRoutes({ app, piManager, middlewares }) {
  const { authOnly } = middlewares;

  app.get('/api/setup/status', ...authOnly, async (req, res) => {
    try {
      const { piId } = req.query;
      const ssh = await piManager.getSSH(piId);

      const status = {
        docker: false,
        network: false,
        security: false,
        traefik: false,
        monitoring: false
      };

      try {
        const dockerCheck = await ssh.execCommand('docker --version');
        status.docker = dockerCheck.code === 0;
      } catch (e) {}

      try {
        const netCheck = await ssh.execCommand('cat /etc/dhcpcd.conf | grep -E "^interface|^static ip_address"');
        status.network = netCheck.code === 0 && netCheck.stdout.includes('static');
      } catch (e) {}

      try {
        const ufwCheck = await ssh.execCommand('sudo ufw status');
        const f2bCheck = await ssh.execCommand('systemctl is-active fail2ban');
        status.security = ufwCheck.code === 0 && ufwCheck.stdout.includes('active') &&
                          f2bCheck.stdout.trim() === 'active';
      } catch (e) {}

      try {
        const traefikCheck = await ssh.execCommand('docker ps --filter "name=traefik" --format "{{.Names}}"');
        status.traefik = traefikCheck.stdout.includes('traefik');
      } catch (e) {}

      try {
        const prometheusCheck = await ssh.execCommand('docker ps --filter "name=prometheus" --format "{{.Names}}"');
        const grafanaCheck = await ssh.execCommand('docker ps --filter "name=grafana" --format "{{.Names}}"');
        status.monitoring = prometheusCheck.stdout.includes('prometheus') && grafanaCheck.stdout.includes('grafana');
      } catch (e) {}

      res.json({ status });
    } catch (error) {
      res.status(500).json({ error: error.message, status: {} });
    }
  });
}

module.exports = {
  registerSetupRoutes
};
