const path = require('path');
const { glob } = require('glob');

function getScriptType(scriptPath) {
  if (scriptPath.includes('/maintenance/')) return 'maintenance';
  if (scriptPath.includes('/utils/')) return 'utils';
  if (scriptPath.includes('common-scripts/')) return 'common';
  if (scriptPath.includes('/scripts/') && scriptPath.match(/\d+-.*-deploy\.sh$/)) return 'deploy';
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

async function discoverScripts(projectRoot) {
  const scripts = [];

  const allPatterns = [
    '*/*/scripts/*-deploy.sh',
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
        const meta = getCategoryMeta(scriptType);

        scripts.push({
          id: Buffer.from(match).toString('base64'),
          name: filename.replace(/\.sh$/, '').replace(/^\d+-/, '').replace(/-/g, ' '),
          filename,
          category,
          service,
          type: scriptType,
          icon: meta.icon,
          typeLabel: meta.label,
          color: meta.color,
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
  discoverScripts
};
