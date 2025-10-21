const { DockerContextDetector } = require('../lib/docker-context-detector');

function registerDockerRoutes({ app, piManager, middlewares }) {
  const { authOnly, adminOnly } = middlewares;

  // Initialiser le détecteur de contexte Docker
  const dockerDetector = new DockerContextDetector(piManager);

  app.get('/api/docker/containers', ...authOnly, async (req, res) => {
    try {
      const { piId } = req.query;

      // Détecter le contexte Docker (DinD ou direct)
      const adaptedCommand = await dockerDetector.adaptCommand('docker ps -a --format "{{json .}}"', piId);
      const result = await piManager.executeCommand(adaptedCommand, piId);

      if (result.code !== 0) {
        throw new Error(result.stderr);
      }

      const lines = result.stdout.trim().split('\n').filter(Boolean);
      const containers = lines.map(line => JSON.parse(line));

      res.json({ containers });
    } catch (error) {
      res.status(500).json({ error: error.message, containers: [] });
    }
  });

  app.post('/api/docker/:action/:container', ...adminOnly, async (req, res) => {
    const { action, container } = req.params;
    const { piId } = req.query;

    const allowedActions = ['start', 'stop', 'restart'];
    if (!allowedActions.includes(action)) {
      return res.status(400).json({ success: false, error: 'Invalid action' });
    }

    try {
      const adaptedCommand = await dockerDetector.adaptCommand(`docker ${action} ${container}`, piId);
      const result = await piManager.executeCommand(adaptedCommand, piId);

      res.json({
        success: result.code === 0,
        output: result.stdout,
        error: result.stderr
      });
    } catch (error) {
      res.status(500).json({ success: false, error: error.message });
    }
  });

  app.post('/api/docker/restart', ...adminOnly, async (req, res) => {
    try {
      const { container } = req.body;
      const { piId } = req.query;

      if (!container) {
        return res.status(400).json({ success: false, error: 'Container name required' });
      }

      const adaptedCommand = await dockerDetector.adaptCommand(`docker restart ${container}`, piId);
      const result = await piManager.executeCommand(adaptedCommand, piId);

      res.json({
        success: result.code === 0,
        output: result.stdout,
        error: result.stderr
      });
    } catch (error) {
      res.status(500).json({ success: false, error: error.message });
    }
  });

  app.get('/api/docker/status/:container', ...authOnly, async (req, res) => {
    try {
      const { container } = req.params;
      const { piId } = req.query;

      const inspectCmd = await dockerDetector.adaptCommand(
        `docker inspect ${container} --format '{{json .State}}'`,
        piId
      );
      const result = await piManager.executeCommand(inspectCmd, piId);

      if (result.code !== 0) {
        return res.status(404).json({ success: false, error: 'Container not found' });
      }

      const state = JSON.parse(result.stdout.trim());

      const uptimeCmd = await dockerDetector.adaptCommand(
        `docker inspect ${container} --format '{{.State.StartedAt}}'`,
        piId
      );
      const uptimeResult = await piManager.executeCommand(uptimeCmd, piId);

      res.json({
        success: true,
        status: {
          state: state.Status,
          health: state.Health?.Status || 'N/A',
          uptime: uptimeResult.stdout.trim(),
          running: state.Running,
          paused: state.Paused,
          restarting: state.Restarting,
          exitCode: state.ExitCode
        }
      });
    } catch (error) {
      res.status(500).json({ success: false, error: error.message });
    }
  });

  app.get('/api/docker/logs/:container', ...authOnly, async (req, res) => {
    const { container } = req.params;
    const { piId } = req.query;
    const lines = req.query.lines || 100;

    try {
      const logsCmd = await dockerDetector.adaptCommand(`docker logs ${container} --tail ${lines}`, piId);
      const result = await piManager.executeCommand(logsCmd, piId);

      res.json({
        logs: result.stdout + result.stderr
      });
    } catch (error) {
      res.status(500).json({ error: error.message, logs: '' });
    }
  });
}

module.exports = {
  registerDockerRoutes
};
