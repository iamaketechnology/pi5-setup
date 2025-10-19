function registerSetupRoutes({ app, piManager, middlewares }) {
  const { authOnly } = middlewares;

  // Check if base prerequisites are installed
  app.get('/api/setup/check-prerequisites', ...authOnly, async (req, res) => {
    try {
      const { piId } = req.query;
      const ssh = await piManager.getSSH(piId);

      const checks = {
        docker: false,
        dockerCompose: false,
        portainer: false,
        ufw: false,
        fail2ban: false,
        pageSize: false
      };

      let passed = 0;
      const total = 6;

      // Check Docker
      try {
        const result = await ssh.execCommand('docker ps');
        checks.docker = result.code === 0;
        if (checks.docker) passed++;
      } catch (e) {}

      // Check Docker Compose
      try {
        const result = await ssh.execCommand('docker compose version');
        checks.dockerCompose = result.code === 0;
        if (checks.dockerCompose) passed++;
      } catch (e) {}

      // Check Portainer
      try {
        const result = await ssh.execCommand('docker ps --format "{{.Names}}" | grep -q "^portainer$"');
        checks.portainer = result.code === 0;
        if (checks.portainer) passed++;
      } catch (e) {}

      // Check UFW
      try {
        const result = await ssh.execCommand('sudo ufw status');
        checks.ufw = result.code === 0 && result.stdout.includes('Status: active');
        if (checks.ufw) passed++;
      } catch (e) {}

      // Check Fail2ban
      try {
        const result = await ssh.execCommand('systemctl is-active fail2ban');
        checks.fail2ban = result.stdout.trim() === 'active';
        if (checks.fail2ban) passed++;
      } catch (e) {}

      // Check Page Size
      try {
        const result = await ssh.execCommand('getconf PAGESIZE');
        checks.pageSize = result.stdout.trim() === '4096';
        if (checks.pageSize) passed++;
      } catch (e) {}

      const isComplete = passed >= 5; // Tolérer 1 échec

      res.json({
        status: isComplete ? 'COMPLETE' : 'MISSING',
        checks,
        passed,
        total,
        needsBaseSetup: !isComplete
      });
    } catch (error) {
      res.status(500).json({
        error: error.message,
        status: 'ERROR',
        needsBaseSetup: true
      });
    }
  });

  // Check if a specific service is already installed
  app.get('/api/setup/check-service', ...authOnly, async (req, res) => {
    try {
      const { piId, service } = req.query;
      const ssh = await piManager.getSSH(piId);

      const serviceChecks = {
        'supabase': {
          container: 'supabase-db',
          directory: '~/stacks/supabase',
          ports: ['8001', '54321']
        },
        'pocketbase': {
          systemd: 'pocketbase',
          directory: '~/apps/pocketbase',
          ports: ['8090']
        },
        'vaultwarden': {
          container: 'vaultwarden',
          directory: '~/stacks/vaultwarden',
          ports: ['8000']
        },
        'nginx': {
          container: 'nginx',
          directory: '~/stacks/nginx',
          ports: ['80', '443']
        },
        'pihole': {
          container: 'pihole',
          directory: '~/stacks/pihole',
          ports: ['53', '80']
        }
      };

      const config = serviceChecks[service];
      if (!config) {
        return res.json({ installed: false, status: 'UNKNOWN' });
      }

      let installed = false;
      let details = {
        container: false,
        directory: false,
        systemd: false,
        running: false,
        version: null,
        uptime: null
      };

      // Check Docker container
      if (config.container) {
        try {
          const result = await ssh.execCommand(`docker ps -a --filter "name=^${config.container}$" --format "{{.Names}}|{{.Status}}|{{.CreatedAt}}"`);
          if (result.stdout) {
            const [name, status, created] = result.stdout.split('|');
            details.container = true;
            details.running = status.includes('Up');
            details.uptime = status.match(/Up (.*)/)?.[1] || null;
            installed = true;
          }
        } catch (e) {}
      }

      // Check systemd service
      if (config.systemd) {
        try {
          const result = await ssh.execCommand(`systemctl is-active ${config.systemd}`);
          details.systemd = result.stdout.trim() === 'active';
          if (details.systemd) {
            installed = true;
            details.running = true;
          }
        } catch (e) {}
      }

      // Check directory
      if (config.directory) {
        try {
          const result = await ssh.execCommand(`[ -d "${config.directory}" ] && echo "exists" || echo "missing"`);
          details.directory = result.stdout.trim() === 'exists';
          if (details.directory) {
            // Get directory size
            const sizeResult = await ssh.execCommand(`du -sh "${config.directory}" | cut -f1`);
            details.size = sizeResult.stdout.trim();
          }
        } catch (e) {}
      }

      res.json({
        service,
        installed,
        details,
        status: installed ? (details.running ? 'RUNNING' : 'STOPPED') : 'NOT_INSTALLED'
      });
    } catch (error) {
      res.status(500).json({
        error: error.message,
        installed: false,
        status: 'ERROR'
      });
    }
  });

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

  // List backups for a specific service
  app.get('/api/setup/list-backups', ...authOnly, async (req, res) => {
    try {
      const { piId, service } = req.query;
      const ssh = await piManager.getSSH(piId);

      // Intelligent multi-pattern backup search
      const searchCommand = `
        (
          [ -d ~/backups/${service} ] && find ~/backups/${service} -mindepth 1 -maxdepth 1 -type d 2>/dev/null
          find ~/backups -maxdepth 1 -type d -name "${service}_*" 2>/dev/null
          find ~/backups -maxdepth 1 -type d -name "${service}-*" 2>/dev/null
        ) | sort -r | uniq
      `.trim();

      const result = await ssh.execCommand(searchCommand);

      if (result.code !== 0 || !result.stdout) {
        return res.json({
          success: true,
          backups: []
        });
      }

      const backupDirs = result.stdout.trim().split('\n').filter(d => d && d !== '');
      const backups = [];

      // Get details for each backup
      for (const dir of backupDirs) {
        const dirName = dir.split('/').pop();

        // Get size
        const sizeResult = await ssh.execCommand(`du -sh "${dir}" 2>/dev/null | cut -f1`);
        const size = sizeResult.stdout.trim() || 'Unknown';

        // Get files list
        const filesResult = await ssh.execCommand(`ls -1 "${dir}" 2>/dev/null`);
        const files = filesResult.stdout.trim().split('\n').filter(f => f);

        // Intelligent date extraction - multiple patterns
        let date = 'Unknown';

        // Pattern 1: service_YYYYMMDD_HHMMSS or service-YYYYMMDD-HHMMSS
        let dateMatch = dirName.match(/[-_](\d{8})[-_](\d{6})$/);
        if (dateMatch) {
          const dateStr = dateMatch[1];
          const timeStr = dateMatch[2];
          const year = dateStr.substr(0, 4);
          const month = dateStr.substr(4, 2);
          const day = dateStr.substr(6, 2);
          const hour = timeStr.substr(0, 2);
          const minute = timeStr.substr(2, 2);
          const second = timeStr.substr(4, 2);
          date = `${year}-${month}-${day} ${hour}:${minute}:${second}`;
        } else {
          // Pattern 2: Just timestamp at the end
          dateMatch = dirName.match(/(\d{8})[-_]?(\d{6})$/);
          if (dateMatch) {
            const dateStr = dateMatch[1];
            const timeStr = dateMatch[2];
            const year = dateStr.substr(0, 4);
            const month = dateStr.substr(4, 2);
            const day = dateStr.substr(6, 2);
            const hour = timeStr.substr(0, 2);
            const minute = timeStr.substr(2, 2);
            const second = timeStr.substr(4, 2);
            date = `${year}-${month}-${day} ${hour}:${minute}:${second}`;
          }
        }

        // If no date found in name, use directory modification time
        if (date === 'Unknown') {
          const statResult = await ssh.execCommand(`stat -c %y "${dir}" 2>/dev/null || stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "${dir}" 2>/dev/null`);
          if (statResult.stdout) {
            date = statResult.stdout.trim().split('.')[0];
          }
        }

        backups.push({
          name: dirName,
          path: dir,
          size,
          date,
          files
        });
      }

      res.json({
        success: true,
        backups
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: error.message,
        backups: []
      });
    }
  });
}

module.exports = {
  registerSetupRoutes
};
