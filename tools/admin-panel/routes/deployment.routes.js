const { exec } = require('child_process');
const path = require('path');
const util = require('util');
const execPromise = util.promisify(exec);

function registerDeploymentRoutes({ app, piManager, middlewares }) {
  const { authOnly } = middlewares;

  /**
   * Deploy dashboard updates to Pi
   */
  app.post('/api/deploy/dashboard', ...authOnly, async (req, res) => {
    try {
      const currentPi = piManager.getCurrentPi();
      if (!currentPi) {
        return res.status(400).json({
          success: false,
          error: 'No Pi configured'
        });
      }

      const piHost = currentPi.hostname || 'pi5.local';
      const scriptPath = path.join(
        __dirname,
        '../../../01-infrastructure/dashboard/scripts/deploy-to-pi.sh'
      );

      console.log(`[Deployment] Starting dashboard deployment to ${piHost}`);

      // Execute deployment script
      const { stdout, stderr } = await execPromise(`bash "${scriptPath}" ${piHost}`, {
        timeout: 120000, // 2 minutes
        maxBuffer: 1024 * 1024 * 10 // 10MB buffer
      });

      console.log(`[Deployment] Output:\n${stdout}`);

      if (stderr && !stderr.includes('[INFO]') && !stderr.includes('[SUCCESS]')) {
        console.error(`[Deployment] Errors:\n${stderr}`);
      }

      res.json({
        success: true,
        message: 'Dashboard deployed successfully',
        output: stdout,
        piHost
      });
    } catch (error) {
      console.error('[Deployment] Failed:', error);

      res.status(500).json({
        success: false,
        error: error.message,
        output: error.stdout || '',
        stderr: error.stderr || ''
      });
    }
  });

  /**
   * Get deployment status
   */
  app.get('/api/deploy/status', ...authOnly, async (req, res) => {
    try {
      const currentPi = piManager.getCurrentPi();
      if (!currentPi || !currentPi.ssh) {
        return res.json({
          success: true,
          deployed: false,
          message: 'Pi not connected'
        });
      }

      // Check if dashboard is running
      const cmd = 'docker ps --filter "name=pi5-dashboard" --format "{{.Status}}"';
      const result = await currentPi.ssh.execCommand(cmd);

      const isRunning = result.stdout && result.stdout.includes('Up');

      res.json({
        success: true,
        deployed: true,
        running: isRunning,
        status: result.stdout || 'Not deployed',
        piHost: currentPi.hostname
      });
    } catch (error) {
      console.error('[Deployment] Status check failed:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });

  /**
   * Restart dashboard container
   */
  app.post('/api/deploy/restart', ...authOnly, async (req, res) => {
    try {
      const currentPi = piManager.getCurrentPi();
      if (!currentPi || !currentPi.ssh) {
        return res.status(400).json({
          success: false,
          error: 'Pi not connected'
        });
      }

      console.log('[Deployment] Restarting dashboard container...');

      const cmd = 'docker restart pi5-dashboard 2>/dev/null || docker compose -f ~/stacks/dashboard/compose/docker-compose.yml restart dashboard';
      const result = await currentPi.ssh.execCommand(cmd);

      if (result.code !== 0) {
        throw new Error(result.stderr || 'Restart failed');
      }

      // Wait for service to be ready
      await new Promise(resolve => setTimeout(resolve, 3000));

      res.json({
        success: true,
        message: 'Dashboard restarted successfully'
      });
    } catch (error) {
      console.error('[Deployment] Restart failed:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });

  /**
   * Get dashboard logs
   */
  app.get('/api/deploy/logs', ...authOnly, async (req, res) => {
    try {
      const currentPi = piManager.getCurrentPi();
      if (!currentPi || !currentPi.ssh) {
        return res.status(400).json({
          success: false,
          error: 'Pi not connected'
        });
      }

      const lines = parseInt(req.query.lines) || 50;
      const cmd = `docker logs pi5-dashboard --tail ${lines} 2>&1`;

      const result = await currentPi.ssh.execCommand(cmd);

      res.json({
        success: true,
        logs: result.stdout || result.stderr || 'No logs available'
      });
    } catch (error) {
      console.error('[Deployment] Logs fetch failed:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });
}

module.exports = {
  registerDeploymentRoutes
};
