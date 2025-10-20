function registerScriptRoutes({ app, io, piManager, discoverScripts, executeScript, executeScriptInteractive, middlewares }) {
  const { authOnly, adminOnly } = middlewares;

  app.get('/api/status', ...authOnly, async (req, res) => {
    try {
      const currentPi = piManager.getCurrentPi();
      const piConfig = piManager.getCurrentPiConfig();
      const ssh = await piManager.getSSH();

      res.json({
        connected: ssh.isConnected(),
        host: piConfig.host,
        username: piConfig.username,
        piId: currentPi,
        piName: piConfig.name
      });
    } catch (error) {
      res.json({
        connected: false,
        error: error.message
      });
    }
  });

  app.get('/api/scripts', ...authOnly, async (req, res) => {
    try {
      const scripts = await discoverScripts();
      res.json({ scripts });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get('/api/setup-status', ...authOnly, async (req, res) => {
    try {
      const ssh = await piManager.getSSH();
      const status = {
        docker: false,
        network: { configured: false },
        security: { configured: false, services: [] },
        traefik: { running: false, containers: 0 },
        monitoring: { running: false, services: [] }
      };

      try {
        const dockerCheck = await ssh.execCommand('docker --version');
        status.docker = dockerCheck.code === 0;
      } catch (e) {}

      try {
        const dockerPs = await ssh.execCommand('docker ps --format "{{.Names}}"');
        if (dockerPs.code === 0) {
          const containers = dockerPs.stdout.split('\n').filter(Boolean);

          const traefikContainers = containers.filter(c => c.toLowerCase().includes('traefik'));
          status.traefik.running = traefikContainers.length > 0;
          status.traefik.containers = traefikContainers.length;

          const monitoringServices = [];
          if (containers.some(c => c.toLowerCase().includes('prometheus'))) monitoringServices.push('Prometheus');
          if (containers.some(c => c.toLowerCase().includes('grafana'))) monitoringServices.push('Grafana');
          if (containers.some(c => c.toLowerCase().includes('node-exporter') || c.toLowerCase().includes('node_exporter'))) monitoringServices.push('Node Exporter');
          status.monitoring.running = monitoringServices.length > 0;
          status.monitoring.services = monitoringServices;
        }
      } catch (e) {}

      try {
        const ufwCheck = await ssh.execCommand('systemctl is-active ufw 2>/dev/null || echo inactive');
        const fail2banCheck = await ssh.execCommand('systemctl is-active fail2ban 2>/dev/null || echo inactive');

        const securityServices = [];
        if (ufwCheck.stdout.trim() === 'active') securityServices.push('UFW');
        if (fail2banCheck.stdout.trim() === 'active') securityServices.push('Fail2ban');

        status.security.configured = securityServices.length > 0;
        status.security.services = securityServices;
      } catch (e) {}

      try {
        const hostnameCheck = await ssh.execCommand('hostname');
        const ipCheck = await ssh.execCommand('hostname -I | awk \'{print $1}\'');

        status.network.hostname = hostnameCheck.stdout.trim();
        status.network.ip = ipCheck.stdout.trim();
        status.network.configured = status.network.hostname !== 'raspberrypi' && !!status.network.ip;
      } catch (e) {}

      res.json({ status });
    } catch (error) {
      console.error('Setup status check error:', error);
      res.status(500).json({ error: error.message });
    }
  });

  app.post('/api/execute', ...adminOnly, async (req, res) => {
    const { scriptPath, piId } = req.body;

    if (!scriptPath) {
      return res.status(400).json({ error: 'scriptPath required' });
    }

    try {
      const executionId = Date.now().toString();

      res.json({
        success: true,
        executionId,
        message: 'Script execution started. Connect to WebSocket for logs.'
      });

      setImmediate(async () => {
        try {
          io.emit('execution-start', { executionId, scriptPath, piId });
          const result = await executeScript(scriptPath, piId, 'manual');
          io.emit('execution-end', {
            executionId,
            success: result.success,
            exitCode: result.exitCode
          });
        } catch (error) {
          io.emit('log', { type: 'error', data: `❌ Error: ${error.message}\n` });
          io.emit('execution-end', {
            executionId,
            success: false,
            error: error.message
          });
        }
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });

  // POST /api/execute-interactive - Execute script in interactive mode with PTY
  app.post('/api/execute-interactive', ...adminOnly, async (req, res) => {
    const { scriptPath, piId } = req.body;

    if (!scriptPath) {
      return res.status(400).json({ error: 'scriptPath required' });
    }

    try {
      const executionId = Date.now().toString();

      res.json({
        success: true,
        executionId,
        interactive: true,
        message: 'Interactive script execution started. Use WebSocket for I/O.'
      });

      // Execute in background with interactive shell
      setImmediate(async () => {
        try {
          await executeScriptInteractive(scriptPath, piId, 'manual');
        } catch (error) {
          io.emit('log', { type: 'error', data: `❌ Error: ${error.message}\n` });
          io.emit('execution-end', {
            executionId,
            success: false,
            error: error.message
          });
        }
      });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
}

module.exports = {
  registerScriptRoutes
};
