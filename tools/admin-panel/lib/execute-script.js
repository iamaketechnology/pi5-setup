const fs = require('fs');
const path = require('path');
const { DockerContextDetector } = require('./docker-context-detector');

function createExecuteScript({ config, db, piManager, notifications, io, getScriptType }) {
  // Initialiser le détecteur de contexte Docker
  const dockerDetector = new DockerContextDetector(piManager);

  return async function executeScript(scriptPath, piId = null, triggeredBy = 'manual') {
    if (!scriptPath) {
      throw new Error('Script path is required');
    }

    const targetPi = piId || piManager.getCurrentPi();
    const piConfig = piManager.getPiConfig(targetPi);
    const startTime = Date.now();

    // FIX: projectRoot is in config.paths.projectRoot, not config.projectRoot
    const projectRoot = config.paths?.projectRoot || config.projectRoot;

    if (!projectRoot) {
      throw new Error('Project root path is not configured');
    }

    const localPath = path.join(projectRoot, scriptPath);

    if (!fs.existsSync(localPath)) {
      throw new Error('Script not found');
    }

    const remotePath = `${piConfig.remoteTempDir}/${path.basename(scriptPath)}`;

    const executionId = db.createExecution({
      piId: targetPi,
      scriptPath,
      scriptName: path.basename(scriptPath),
      scriptType: getScriptType(scriptPath),
      startedAt: startTime,
      triggeredBy
    });

    let output = '';
    let error = '';

    try {
      // Détecter le contexte (Pi physique ou Émulateur DinD)
      const context = await dockerDetector.detectContext(targetPi);

      // Upload lib.sh si le script en dépend (scripts dans catégories, pas common-scripts)
      const needsLibSh = !scriptPath.startsWith('common-scripts/') && !scriptPath.startsWith('tools/');
      if (needsLibSh) {
        const libShLocal = path.join(projectRoot, 'common-scripts/lib.sh');
        const libShRemote = '/tmp/common-scripts-lib.sh';

        if (fs.existsSync(libShLocal)) {
          await piManager.uploadFile(libShLocal, libShRemote, targetPi);

          if (context.isDinD && context.containerName) {
            // Créer le répertoire common-scripts dans le conteneur
            await piManager.executeCommand(
              `docker exec ${context.containerName} mkdir -p /tmp/common-scripts`,
              targetPi
            );
            // Copier lib.sh dans le conteneur
            await piManager.executeCommand(
              `docker cp ${libShRemote} ${context.containerName}:/tmp/common-scripts/lib.sh`,
              targetPi
            );
          } else {
            // Pi physique : créer le répertoire et copier
            await piManager.executeCommand(
              `mkdir -p /tmp/common-scripts && cp ${libShRemote} /tmp/common-scripts/lib.sh`,
              targetPi
            );
          }
        }
      }

      // Upload du fichier sur l'hôte SSH
      await piManager.uploadFile(localPath, remotePath, targetPi);

      // Si c'est un émulateur, copier le fichier dans le conteneur
      if (context.isDinD && context.containerName) {
        await piManager.executeCommand(
          `docker cp ${remotePath} ${context.containerName}:${remotePath}`,
          targetPi
        );
      }

      // Adapter la commande d'exécution selon le contexte (Pi physique vs Émulateur)
      const baseCommand = `sudo bash ${remotePath}`;
      const adaptedCommand = await dockerDetector.adaptShellCommand(baseCommand, targetPi);

      const result = await piManager.executeCommand(adaptedCommand, targetPi, {
        onStdout: (chunk) => {
          const data = chunk.toString('utf8');
          output += data;
          io.emit('log', { type: 'stdout', data, executionId });
        },
        onStderr: (chunk) => {
          const data = chunk.toString('utf8');
          error += data;
          io.emit('log', { type: 'stderr', data, executionId });
        }
      });

      const endTime = Date.now();
      const success = result.code === 0;

      db.updateExecution(executionId, {
        endedAt: endTime,
        duration: endTime - startTime,
        exitCode: result.code,
        status: success ? 'success' : 'failed',
        output: output || result.stdout,
        error: error || result.stderr
      });

      if (!success) {
        notifications.sendNotification('execution.failed', {
          script: scriptPath,
          pi: piConfig.name,
          error: error || result.stderr,
          duration: endTime - startTime,
          exitCode: result.code
        });
      } else {
        notifications.sendNotification('execution.success', {
          script: scriptPath,
          pi: piConfig.name,
          duration: endTime - startTime,
          exitCode: result.code
        });
      }

      return {
        success,
        exitCode: result.code,
        output: output || result.stdout,
        error: error || result.stderr,
        duration: endTime - startTime,
        executionId
      };
    } catch (err) {
      const endTime = Date.now();

      db.updateExecution(executionId, {
        endedAt: endTime,
        duration: endTime - startTime,
        exitCode: -1,
        status: 'failed',
        error: err.message
      });

      notifications.sendNotification('execution.failed', {
        script: scriptPath,
        pi: piConfig.name,
        error: err.message,
        duration: endTime - startTime
      });

      throw err;
    }
  };
}

module.exports = {
  createExecuteScript
};
