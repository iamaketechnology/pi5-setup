const path = require('path');
const { glob } = require('glob');

function getScriptType(scriptPath) {
  if (scriptPath.includes('/maintenance/')) return 'maintenance';
  if (scriptPath.includes('/utils/')) return 'utils';
  if (scriptPath.includes('common-scripts/')) return 'common';
  if (scriptPath.includes('/scripts/') && scriptPath.match(/\d+-.*-deploy(-.*)?\.sh$/)) return 'deploy';
  if (scriptPath.includes('-test.sh') || scriptPath.includes('diagnose')) return 'test';
  return 'other';
}

function getCategoryMeta(type) {
  const categories = {
    'deploy': { icon: '🚀', label: 'Déploiement', color: '#3b82f6' },
    'maintenance': { icon: '🔧', label: 'Maintenance', color: '#f59e0b' },
    'utils': { icon: '⚙️', label: 'Configuration', color: '#8b5cf6' },
    'test': { icon: '🧪', label: 'Tests', color: '#10b981' },
    'common': { icon: '📦', label: 'Commun', color: '#6366f1' },
    'other': { icon: '📄', label: 'Autre', color: '#6b7280' }
  };
  return categories[type] || categories.other;
}

function getServiceIcon(service) {
  // Map services to Lucide icon names
  const serviceIcons = {
    'supabase': 'database',
    'traefik': 'globe',
    'email': 'mail',
    'appwrite': 'rocket',
    'pocketbase': 'archive',
    'vaultwarden': 'shield-check',
    'dashboard': 'monitor',
    'webserver': 'server',
    'pihole': 'shield',
    'vpn-wireguard': 'lock',
    'external-access': 'arrow-up-right',
    'apps': 'grid',
    'authelia': 'key',
    'passwords': 'lock',
    'hardening': 'shield-check',
    'prometheus-grafana': 'bar-chart',
    'uptime-kuma': 'check-circle',
    'gitea': 'git-branch',
    'filebrowser-nextcloud': 'folder',
    'syncthing': 'refresh-cw',
    'jellyfin-arr': 'play-circle',
    'navidrome': 'music',
    'calibre-web': 'book',
    'qbittorrent': 'download',
    'homeassistant': 'zap',
    'homepage': 'home',
    'portainer': 'container',
    'paperless-ngx': 'file-text',
    'immich': 'image',
    'joplin': 'clipboard',
    'n8n': 'workflow',
    'ollama': 'brain',
    'restic-offsite': 'cloud-upload',
    'system': 'cpu'
  };

  return serviceIcons[service] || 'package';
}

async function discoverScripts(projectRoot) {
  const scripts = [];

  const allPatterns = [
    '*/*/scripts/*-deploy.sh',
    '*/*/scripts/*-deploy-*.sh',  // Traefik variants: -deploy-cloudflare, -deploy-duckdns, etc.
    '*/*/scripts/maintenance/*.sh',
    '*/*/scripts/utils/*.sh',
    'common-scripts/*.sh',
    '*/*/scripts/*-test.sh',
    '*/*/scripts/*/diagnose*.sh'
  ];

  for (const pattern of allPatterns) {
    try {
      const matches = await glob(pattern, { cwd: projectRoot });

      for (const match of matches) {
        if (match.includes('_') && match.includes('-common.sh')) continue;

        const fullPath = path.join(projectRoot, match);
        const parts = match.split('/');
        const filename = parts[parts.length - 1];

        let category = parts[0];
        let service = parts.length > 1 ? parts[1] : 'common';

        if (match.startsWith('common-scripts/')) {
          category = 'common-scripts';
          service = 'system';
        }

        const scriptType = getScriptType(match);
        const typeMeta = getCategoryMeta(scriptType);
        const serviceIcon = getServiceIcon(service);

        scripts.push({
          id: Buffer.from(match).toString('base64'),
          name: filename.replace(/\.sh$/, '').replace(/^\d+-/, '').replace(/-/g, ' '),
          filename,
          category,
          service,
          type: scriptType,
          icon: `<i data-lucide="${serviceIcon}" size="20"></i>`,
          typeLabel: typeMeta.label,
          color: typeMeta.color,
          typeIcon: typeMeta.icon,
          path: match,
          fullPath
        });
      }
    } catch (error) {
      console.error(`Error discovering pattern ${pattern}:`, error.message);
    }
  }

  return scripts.sort((a, b) => {
    if (a.type !== b.type) return a.type.localeCompare(b.type);
    if (a.category !== b.category) return a.category.localeCompare(b.category);
    return a.service.localeCompare(b.service);
  });
}

module.exports = {
  getScriptType,
  getCategoryMeta,
  getServiceIcon,
  discoverScripts
};
