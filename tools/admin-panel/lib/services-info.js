// =============================================================================
// Services Info Module - Auto-discovery and credentials extraction
// =============================================================================
// Discovers running services, extracts URLs, credentials, and useful info
// =============================================================================

const fs = require('fs');
const path = require('path');

let piManager = null;
let config = null;

// =============================================================================
// Initialization
// =============================================================================

function initServicesInfo(piManagerInstance, configInstance) {
  piManager = piManagerInstance;
  config = configInstance;
}

// =============================================================================
// Service Discovery
// =============================================================================

async function discoverServices(piId = null) {
  try {
    const containers = await getDockerContainers(piId);
    const services = [];

    for (const container of containers) {
      const service = await parseContainerInfo(container, piId);
      if (service) {
        services.push(service);
      }
    }

    // Group by application
    const grouped = groupServicesByApp(services);

    return grouped;
  } catch (error) {
    console.error('Error discovering services:', error);
    return [];
  }
}

async function getDockerContainers(piId) {
  const cmd = 'docker ps --format "{{json .}}"';
  const result = await piManager.executeCommand(cmd, piId);

  if (result.code !== 0) {
    throw new Error('Failed to get Docker containers');
  }

  const lines = result.stdout.trim().split('\n').filter(Boolean);
  return lines.map(line => JSON.parse(line));
}

async function parseContainerInfo(container, piId) {
  try {
    // Get detailed container info
    const inspectCmd = `docker inspect ${container.Names}`;
    const inspectResult = await piManager.executeCommand(inspectCmd, piId);

    if (inspectResult.code !== 0) {
      return null;
    }

    const details = JSON.parse(inspectResult.stdout)[0];
    const labels = details.Config.Labels || {};
    const env = details.Config.Env || [];

    // Extract Traefik URLs
    const urls = extractTraefikUrls(labels);

    // Detect service type
    const serviceInfo = detectServiceType(container.Names, labels, env);

    return {
      id: container.ID.substring(0, 12),
      name: container.Names,
      image: container.Image,
      state: container.State,
      status: container.Status,
      ports: parsePorts(container.Ports),
      urls,
      ...serviceInfo
    };
  } catch (error) {
    console.error(`Error parsing container ${container.Names}:`, error);
    return null;
  }
}

function extractTraefikUrls(labels) {
  const urls = [];

  Object.keys(labels).forEach(key => {
    // Extract host from traefik router rules
    if (key.match(/traefik\.http\.routers\..*\.rule/)) {
      const rule = labels[key];
      const hostMatch = rule.match(/Host\(`([^`]+)`\)/);
      if (hostMatch) {
        const host = hostMatch[1];
        // Determine protocol
        const tlsKey = key.replace('.rule', '.tls');
        const protocol = labels[tlsKey] ? 'https' : 'http';
        urls.push(`${protocol}://${host}`);
      }
    }
  });

  return urls;
}

function detectServiceType(name, labels, env) {
  const nameLower = name.toLowerCase();

  // Supabase services
  if (nameLower.includes('supabase')) {
    return {
      app: 'Supabase',
      icon: '🐘',
      category: 'Backend',
      description: 'Backend-as-a-Service platform'
    };
  }

  // n8n
  if (nameLower.includes('n8n')) {
    return {
      app: 'n8n',
      icon: '🤖',
      category: 'Automation',
      description: 'Workflow automation'
    };
  }

  // Grafana
  if (nameLower.includes('grafana')) {
    return {
      app: 'Grafana',
      icon: '📊',
      category: 'Monitoring',
      description: 'Metrics visualization'
    };
  }

  // Prometheus
  if (nameLower.includes('prometheus')) {
    return {
      app: 'Prometheus',
      icon: '🔥',
      category: 'Monitoring',
      description: 'Metrics collection'
    };
  }

  // Traefik
  if (nameLower.includes('traefik')) {
    return {
      app: 'Traefik',
      icon: '🚦',
      category: 'Infrastructure',
      description: 'Reverse proxy & load balancer'
    };
  }

  // Portainer
  if (nameLower.includes('portainer')) {
    return {
      app: 'Portainer',
      icon: '🦘',
      category: 'Management',
      description: 'Docker GUI management'
    };
  }

  // Ollama
  if (nameLower.includes('ollama')) {
    return {
      app: 'Ollama',
      icon: '🦙',
      category: 'AI',
      description: 'Local LLM runner'
    };
  }

  // Open WebUI
  if (nameLower.includes('open-webui')) {
    return {
      app: 'Open WebUI',
      icon: '🤖',
      category: 'AI',
      description: 'LLM chat interface'
    };
  }

  // Homepage
  if (nameLower.includes('homepage')) {
    return {
      app: 'Homepage',
      icon: '🏠',
      category: 'Dashboard',
      description: 'Service dashboard'
    };
  }

  // Default
  return {
    app: name,
    icon: '📦',
    category: 'Other',
    description: 'Container service'
  };
}

function parsePorts(portsString) {
  if (!portsString) return [];

  const ports = [];
  const segments = portsString.split(', ');

  segments.forEach(segment => {
    const match = segment.match(/(\d+\.\d+\.\d+\.\d+):(\d+)->(\d+)\/(tcp|udp)/);
    if (match) {
      ports.push({
        host: match[1],
        external: match[2],
        internal: match[3],
        protocol: match[4]
      });
    } else {
      const simpleMatch = segment.match(/(\d+)\/(tcp|udp)/);
      if (simpleMatch) {
        ports.push({
          internal: simpleMatch[1],
          protocol: simpleMatch[2]
        });
      }
    }
  });

  return ports;
}

function groupServicesByApp(services) {
  const grouped = {};

  services.forEach(service => {
    const appName = service.app;

    if (!grouped[appName]) {
      grouped[appName] = {
        app: appName,
        icon: service.icon,
        category: service.category,
        description: service.description,
        containers: [],
        urls: [],
        ports: []
      };
    }

    grouped[appName].containers.push({
      id: service.id,
      name: service.name,
      image: service.image,
      state: service.state,
      status: service.status
    });

    // Merge URLs (deduplicate)
    service.urls.forEach(url => {
      if (!grouped[appName].urls.includes(url)) {
        grouped[appName].urls.push(url);
      }
    });

    // Merge ports
    grouped[appName].ports.push(...service.ports);
  });

  return Object.values(grouped);
}

// =============================================================================
// Credentials Extraction
// =============================================================================

async function getServiceCredentials(serviceName, piId = null) {
  try {
    const credentials = {};

    // Try to read from common locations
    const stackPath = `~/stacks/${serviceName.toLowerCase()}`;

    // Check for .env file
    const envFile = await readEnvFile(`${stackPath}/.env`, piId);
    if (envFile) {
      Object.assign(credentials, envFile);
    }

    // Check for docker-compose.yml
    const composeEnv = await extractFromDockerCompose(`${stackPath}/docker-compose.yml`, piId);
    if (composeEnv) {
      Object.assign(credentials, composeEnv);
    }

    // Service-specific credential extraction
    const specificCreds = await getServiceSpecificCredentials(serviceName, piId);
    if (specificCreds) {
      Object.assign(credentials, specificCreds);
    }

    return credentials;
  } catch (error) {
    console.error(`Error getting credentials for ${serviceName}:`, error);
    return {};
  }
}

async function readEnvFile(filePath, piId) {
  try {
    const cmd = `cat ${filePath} 2>/dev/null || echo ""`;
    const result = await piManager.executeCommand(cmd, piId);

    if (result.code !== 0 || !result.stdout.trim()) {
      return null;
    }

    const env = {};
    const lines = result.stdout.split('\n');

    lines.forEach(line => {
      line = line.trim();
      if (!line || line.startsWith('#')) return;

      const match = line.match(/^([A-Z_][A-Z0-9_]*)=(.*)$/);
      if (match) {
        const key = match[1];
        let value = match[2];

        // Remove quotes
        value = value.replace(/^["']|["']$/g, '');

        env[key] = value;
      }
    });

    return env;
  } catch (error) {
    return null;
  }
}

async function extractFromDockerCompose(filePath, piId) {
  try {
    const cmd = `cat ${filePath} 2>/dev/null || echo ""`;
    const result = await piManager.executeCommand(cmd, piId);

    if (result.code !== 0 || !result.stdout.trim()) {
      return null;
    }

    // Simple extraction of environment variables from docker-compose
    const env = {};
    const lines = result.stdout.split('\n');

    lines.forEach(line => {
      const match = line.match(/^\s*-\s*([A-Z_][A-Z0-9_]*)=(.*)$/);
      if (match) {
        let value = match[2];
        value = value.replace(/^["']|["']$/g, '');
        env[match[1]] = value;
      }
    });

    return Object.keys(env).length > 0 ? env : null;
  } catch (error) {
    return null;
  }
}

async function getServiceSpecificCredentials(serviceName, piId) {
  const name = serviceName.toLowerCase();

  // Supabase
  if (name === 'supabase') {
    return await getSupabaseCredentials(piId);
  }

  // Grafana
  if (name === 'grafana') {
    return {
      'ADMIN_USER': 'admin',
      'ADMIN_PASSWORD': 'admin',
      'NOTE': 'Change on first login'
    };
  }

  // Portainer
  if (name === 'portainer') {
    return {
      'NOTE': 'Admin user created on first access',
      'URL': 'http://localhost:8080'
    };
  }

  return null;
}

async function getSupabaseCredentials(piId) {
  const creds = {};

  // Try to extract JWT secret and keys
  const envFile = await readEnvFile('~/stacks/supabase/.env', piId);
  if (envFile) {
    const relevantKeys = [
      'ANON_KEY',
      'SERVICE_ROLE_KEY',
      'JWT_SECRET',
      'POSTGRES_PASSWORD',
      'DASHBOARD_USERNAME',
      'DASHBOARD_PASSWORD'
    ];

    relevantKeys.forEach(key => {
      if (envFile[key]) {
        creds[key] = envFile[key];
      }
    });
  }

  return creds;
}

// =============================================================================
// Quick Commands
// =============================================================================

function getServiceCommands(serviceName) {
  const name = serviceName.toLowerCase();
  const commands = [];

  // Common commands for all services
  commands.push({
    label: 'View Logs (last 100 lines)',
    command: `docker logs ${name} --tail 100`,
    icon: '📜'
  });

  commands.push({
    label: 'View Logs (follow)',
    command: `docker logs ${name} -f`,
    icon: '📜'
  });

  commands.push({
    label: 'Restart Container',
    command: `docker restart ${name}`,
    icon: '🔄'
  });

  commands.push({
    label: 'Container Stats',
    command: `docker stats ${name} --no-stream`,
    icon: '📊'
  });

  // Service-specific commands
  if (name === 'supabase-db' || name.includes('postgres')) {
    commands.push({
      label: 'Connect to PostgreSQL',
      command: `docker exec -it ${name} psql -U postgres`,
      icon: '🐘'
    });

    commands.push({
      label: 'List Databases',
      command: `docker exec -it ${name} psql -U postgres -c "\\l"`,
      icon: '📋'
    });
  }

  if (name.includes('supabase')) {
    commands.push({
      label: 'Restart All Supabase',
      command: `cd ~/stacks/supabase && docker-compose restart`,
      icon: '🔄'
    });
  }

  if (name === 'n8n') {
    commands.push({
      label: 'Export all workflows',
      command: `docker exec -it n8n n8n export:workflow --all`,
      icon: '💾'
    });
  }

  return commands;
}

// =============================================================================
// Get useful file paths for a service
// =============================================================================

function getServicePaths(serviceName) {
  const paths = {
    common: [
      { label: 'Stack Directory', path: `~/stacks/${serviceName.toLowerCase()}`, type: 'directory' },
      { label: 'Docker Compose', path: `~/stacks/${serviceName.toLowerCase()}/docker-compose.yml`, type: 'file' },
      { label: 'Environment Variables', path: `~/stacks/${serviceName.toLowerCase()}/.env`, type: 'file' }
    ],
    logs: []
  };

  // Service-specific paths
  const nameLower = serviceName.toLowerCase();

  if (nameLower.includes('supabase')) {
    paths.specific = [
      { label: 'Supabase Stack', path: '~/stacks/supabase', type: 'directory' },
      { label: 'Main Config', path: '~/stacks/supabase/docker-compose.yml', type: 'file' },
      { label: 'Environment', path: '~/stacks/supabase/.env', type: 'file' },
      { label: 'Kong Config', path: '~/stacks/supabase/kong/kong.yml', type: 'file' },
      { label: 'DB Data', path: '~/stacks/supabase/volumes/db/data', type: 'directory' },
      { label: 'Storage Files', path: '~/stacks/supabase/volumes/storage', type: 'directory' }
    ];
    paths.logs = [
      { label: 'Kong Logs', command: 'docker logs supabase-kong --tail 100' },
      { label: 'PostgreSQL Logs', command: 'docker logs supabase-db --tail 100' },
      { label: 'Auth Logs', command: 'docker logs supabase-auth --tail 100' },
      { label: 'Storage Logs', command: 'docker logs supabase-storage --tail 100' }
    ];
  }

  if (nameLower.includes('traefik')) {
    paths.specific = [
      { label: 'Traefik Stack', path: '~/stacks/traefik', type: 'directory' },
      { label: 'Main Config', path: '~/stacks/traefik/traefik.yml', type: 'file' },
      { label: 'Dynamic Config', path: '~/stacks/traefik/config', type: 'directory' },
      { label: 'Certificates', path: '~/stacks/traefik/letsencrypt', type: 'directory' },
      { label: 'Access Logs', path: '~/stacks/traefik/logs/access.log', type: 'file' }
    ];
    paths.logs = [
      { label: 'Traefik Logs', command: 'docker logs traefik --tail 100' },
      { label: 'Access Log', command: 'tail -100 ~/stacks/traefik/logs/access.log' }
    ];
  }

  if (nameLower.includes('portainer')) {
    paths.specific = [
      { label: 'Portainer Data', path: '/var/lib/docker/volumes/portainer_data', type: 'directory' }
    ];
    paths.logs = [
      { label: 'Portainer Logs', command: 'docker logs portainer --tail 100' }
    ];
  }

  if (nameLower.includes('grafana')) {
    paths.specific = [
      { label: 'Grafana Stack', path: '~/stacks/monitoring', type: 'directory' },
      { label: 'Grafana Data', path: '~/stacks/monitoring/grafana', type: 'directory' },
      { label: 'Prometheus Data', path: '~/stacks/monitoring/prometheus', type: 'directory' },
      { label: 'Prometheus Config', path: '~/stacks/monitoring/prometheus/prometheus.yml', type: 'file' }
    ];
    paths.logs = [
      { label: 'Grafana Logs', command: 'docker logs grafana --tail 100' },
      { label: 'Prometheus Logs', command: 'docker logs prometheus --tail 100' }
    ];
  }

  if (nameLower.includes('n8n')) {
    paths.specific = [
      { label: 'n8n Stack', path: '~/stacks/n8n', type: 'directory' },
      { label: 'n8n Data', path: '~/stacks/n8n/data', type: 'directory' },
      { label: 'Workflows', path: '~/stacks/n8n/data/.n8n', type: 'directory' }
    ];
    paths.logs = [
      { label: 'n8n Logs', command: 'docker logs n8n --tail 100' }
    ];
  }

  return paths;
}

// =============================================================================
// Get maintenance commands for a service
// =============================================================================

function getMaintenanceCommands(serviceName) {
  const nameLower = serviceName.toLowerCase();
  const commands = [];

  if (nameLower.includes('supabase')) {
    commands.push(
      { label: 'Backup Database', command: 'sudo bash ~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-backup.sh', category: 'Backup', icon: '💾' },
      { label: 'Health Check', command: 'sudo bash ~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-healthcheck.sh', category: 'Monitoring', icon: '🏥' },
      { label: 'Reset Stack', command: 'sudo bash ~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-reset.sh', category: 'Maintenance', icon: '🔄' },
      { label: 'Update Stack', command: 'sudo bash ~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-update.sh', category: 'Maintenance', icon: '⬆️' },
      { label: 'View All Credentials', command: 'sudo bash ~/pi5-setup/01-infrastructure/traefik/scripts/get-supabase-credentials.sh', category: 'Security', icon: '🔐' }
    );
  }

  if (nameLower.includes('traefik')) {
    commands.push(
      { label: 'View Dashboard Credentials', command: 'cat ~/stacks/traefik/.env | grep DASHBOARD', category: 'Security', icon: '🔐' },
      { label: 'Reload Configuration', command: 'docker restart traefik', category: 'Maintenance', icon: '🔄' },
      { label: 'View Access Logs', command: 'tail -50 ~/stacks/traefik/logs/access.log', category: 'Monitoring', icon: '📊' }
    );
  }

  if (nameLower.includes('grafana') || nameLower.includes('prometheus')) {
    commands.push(
      { label: 'Restart Monitoring Stack', command: 'cd ~/stacks/monitoring && docker-compose restart', category: 'Maintenance', icon: '🔄' },
      { label: 'Backup Grafana Dashboards', command: 'tar -czf ~/backups/grafana-$(date +%Y%m%d).tar.gz ~/stacks/monitoring/grafana', category: 'Backup', icon: '💾' }
    );
  }

  // Common commands for all services
  commands.push(
    { label: 'Check Disk Usage', command: 'df -h', category: 'System', icon: '💽' },
    { label: 'Docker Disk Usage', command: 'docker system df', category: 'System', icon: '🐳' },
    { label: 'Clean Docker System', command: 'docker system prune -a --volumes', category: 'Maintenance', icon: '🧹' }
  );

  return commands;
}

// =============================================================================
// Get backup information for a service
// =============================================================================

function getBackupInfo(serviceName) {
  const nameLower = serviceName.toLowerCase();
  const info = {
    hasAutoBackup: false,
    backupLocation: null,
    backupCommands: []
  };

  if (nameLower.includes('supabase')) {
    info.hasAutoBackup = true;
    info.backupLocation = '~/backups/supabase';
    info.backupCommands = [
      { label: 'Manual Backup', command: 'sudo bash ~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-backup.sh' },
      { label: 'List Backups', command: 'ls -lh ~/backups/supabase/' },
      { label: 'Restore Last Backup', command: 'sudo bash ~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-restore.sh' }
    ];
  }

  if (nameLower.includes('grafana')) {
    info.backupLocation = '~/backups/monitoring';
    info.backupCommands = [
      { label: 'Backup Grafana', command: 'tar -czf ~/backups/grafana-$(date +%Y%m%d).tar.gz ~/stacks/monitoring/grafana' },
      { label: 'Backup Prometheus', command: 'tar -czf ~/backups/prometheus-$(date +%Y%m%d).tar.gz ~/stacks/monitoring/prometheus' }
    ];
  }

  if (nameLower.includes('n8n')) {
    info.backupLocation = '~/backups/n8n';
    info.backupCommands = [
      { label: 'Backup n8n Data', command: 'tar -czf ~/backups/n8n-$(date +%Y%m%d).tar.gz ~/stacks/n8n/data' },
      { label: 'List Backups', command: 'ls -lh ~/backups/n8n/' }
    ];
  }

  return info;
}

// =============================================================================
// Exports
// =============================================================================

module.exports = {
  initServicesInfo,
  discoverServices,
  getServiceCredentials,
  getServiceCommands,
  getServicePaths,
  getMaintenanceCommands,
  getBackupInfo
};
