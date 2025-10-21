// =============================================================================
// Docker Context Detector - Intelligent Docker Detection
// =============================================================================
// Détecte automatiquement le contexte Docker (DinD vs Direct) et adapte
// les commandes en conséquence pour fonctionner sur Pi physique et émulateurs
// Version: 1.0.0
// Author: PI5-SETUP Project
// =============================================================================

/**
 * Détecte si un Pi est un émulateur Docker-in-Docker
 * @param {Object} pi - Objet Pi (avec name, host, tags, etc.)
 * @returns {boolean} - True si c'est un émulateur DinD
 */
function isDockerInDocker(pi) {
  if (!pi) return false;

  // Vérifier le nom
  const nameIndicators = ['emulator', 'dind', 'docker-in-docker'];
  if (pi.name && nameIndicators.some(indicator =>
    pi.name.toLowerCase().includes(indicator)
  )) {
    return true;
  }

  // Vérifier les tags
  if (pi.tags && Array.isArray(pi.tags)) {
    const emulatorTags = ['emulator', 'dind', 'docker-in-docker'];
    if (pi.tags.some(tag => emulatorTags.includes(tag.toLowerCase()))) {
      return true;
    }
  }

  return false;
}

/**
 * Détecte le nom du conteneur émulateur pour un Pi DinD
 * @param {Object} pi - Objet Pi
 * @param {Function} executeCommand - Fonction pour exécuter des commandes SSH
 * @returns {Promise<string|null>} - Nom du conteneur ou null
 */
async function detectEmulatorContainerName(pi, executeCommand) {
  if (!isDockerInDocker(pi)) {
    return null;
  }

  try {
    // Essayer de trouver le conteneur par pattern de nom
    const patterns = [
      'pi-emulator-test',
      'pi-emulator',
      'debian-pi',
      'raspbian-emulator'
    ];

    for (const pattern of patterns) {
      const result = await executeCommand(
        `docker ps --filter "name=${pattern}" --format "{{.Names}}" | head -1`,
        pi.id
      );

      if (result.code === 0 && result.stdout.trim()) {
        return result.stdout.trim();
      }
    }

    // Fallback : chercher tous les conteneurs qui tournent
    const allResult = await executeCommand(
      'docker ps --format "{{.Names}}" | grep -E "(emulator|pi)" | head -1',
      pi.id
    );

    if (allResult.code === 0 && allResult.stdout.trim()) {
      return allResult.stdout.trim();
    }

    return null;
  } catch (error) {
    console.error('[DOCKER-CONTEXT] Error detecting container name:', error.message);
    return null;
  }
}

/**
 * Adapte une commande Docker pour le contexte (DinD ou direct)
 * @param {string} dockerCommand - Commande Docker (ex: "docker ps", "docker logs mycontainer")
 * @param {Object} pi - Objet Pi
 * @param {string|null} containerName - Nom du conteneur DinD (si détecté)
 * @returns {string} - Commande adaptée au contexte
 */
function adaptDockerCommand(dockerCommand, pi, containerName = null) {
  if (!isDockerInDocker(pi) || !containerName) {
    // Contexte direct : commande normale
    return dockerCommand;
  }

  // Contexte DinD : enrober la commande dans docker exec
  // Échapper les guillemets pour éviter les problèmes d'injection
  const escapedCommand = dockerCommand.replace(/"/g, '\\"');
  return `docker exec ${containerName} bash -c "${escapedCommand}"`;
}

/**
 * Détecte le répertoire stacks (~/stacks vs /root/stacks)
 * @param {Object} pi - Objet Pi
 * @param {Function} executeCommand - Fonction pour exécuter des commandes SSH
 * @param {string|null} containerName - Nom du conteneur DinD (si applicable)
 * @returns {Promise<string>} - Chemin du répertoire stacks
 */
async function detectStacksDirectory(pi, executeCommand, containerName = null) {
  const possiblePaths = [
    '/root/stacks',
    '~/stacks',
    '$HOME/stacks',
    '/home/pi/stacks'
  ];

  for (const stackPath of possiblePaths) {
    try {
      let checkCommand = `test -d ${stackPath} && echo "exists" || echo "missing"`;

      // Adapter la commande si DinD
      if (containerName) {
        checkCommand = `docker exec ${containerName} bash -c "${checkCommand}"`;
      }

      const result = await executeCommand(checkCommand, pi.id);

      if (result.code === 0 && result.stdout.trim() === 'exists') {
        return stackPath;
      }
    } catch (error) {
      // Continuer avec le prochain chemin
      continue;
    }
  }

  // Fallback : utiliser ~/stacks par défaut
  return '~/stacks';
}

/**
 * Classe principale pour gérer le contexte Docker intelligent
 */
class DockerContextDetector {
  constructor(piManager) {
    this.piManager = piManager;
    this.containerCache = new Map(); // Cache des noms de conteneurs détectés
    this.stacksPathCache = new Map(); // Cache des chemins stacks
  }

  /**
   * Récupère les informations d'un Pi
   * @param {string} piId - ID du Pi
   * @returns {Object} - Objet Pi
   */
  getPi(piId) {
    const piConfig = this.piManager.getPiConfig(piId);
    if (!piConfig) {
      throw new Error(`Pi ${piId} not found`);
    }
    return piConfig;
  }

  /**
   * Détecte et met en cache le contexte Docker pour un Pi
   * @param {string} piId - ID du Pi
   * @returns {Promise<Object>} - Contexte Docker (isDinD, containerName, stacksPath)
   */
  async detectContext(piId) {
    const pi = this.getPi(piId);
    const isDinD = isDockerInDocker(pi);

    // Vérifier le cache
    const cacheKey = piId;
    if (this.containerCache.has(cacheKey) && this.stacksPathCache.has(cacheKey)) {
      return {
        isDinD,
        containerName: this.containerCache.get(cacheKey),
        stacksPath: this.stacksPathCache.get(cacheKey)
      };
    }

    // Détection initiale
    let containerName = null;
    if (isDinD) {
      containerName = await detectEmulatorContainerName(pi,
        (cmd, id) => this.piManager.executeCommand(cmd, id)
      );
      this.containerCache.set(cacheKey, containerName);
    }

    const stacksPath = await detectStacksDirectory(pi,
      (cmd, id) => this.piManager.executeCommand(cmd, id),
      containerName
    );
    this.stacksPathCache.set(cacheKey, stacksPath);

    return { isDinD, containerName, stacksPath };
  }

  /**
   * Adapte une commande Docker pour un Pi spécifique
   * @param {string} dockerCommand - Commande Docker à adapter
   * @param {string} piId - ID du Pi
   * @returns {Promise<string>} - Commande adaptée
   */
  async adaptCommand(dockerCommand, piId) {
    const context = await this.detectContext(piId);
    const pi = this.getPi(piId);
    return adaptDockerCommand(dockerCommand, pi, context.containerName);
  }

  /**
   * Adapte une commande shell (non-Docker) pour un Pi spécifique
   * Utilisé pour l'exécution de scripts dans les émulateurs
   * @param {string} shellCommand - Commande shell à adapter
   * @param {string} piId - ID du Pi
   * @returns {Promise<string>} - Commande adaptée
   */
  async adaptShellCommand(shellCommand, piId) {
    const context = await this.detectContext(piId);

    if (!context.isDinD || !context.containerName) {
      // Pi physique : commande normale
      return shellCommand;
    }

    // Émulateur DinD : enrober dans docker exec
    // Échapper les guillemets pour éviter les problèmes
    const escapedCommand = shellCommand.replace(/"/g, '\\"');
    return `docker exec ${context.containerName} bash -c "${escapedCommand}"`;
  }

  /**
   * Nettoie le cache pour un Pi (utile après reconnexion)
   * @param {string} piId - ID du Pi
   */
  clearCache(piId) {
    this.containerCache.delete(piId);
    this.stacksPathCache.delete(piId);
  }

  /**
   * Nettoie tout le cache
   */
  clearAllCache() {
    this.containerCache.clear();
    this.stacksPathCache.clear();
  }
}

module.exports = {
  isDockerInDocker,
  detectEmulatorContainerName,
  adaptDockerCommand,
  detectStacksDirectory,
  DockerContextDetector
};
