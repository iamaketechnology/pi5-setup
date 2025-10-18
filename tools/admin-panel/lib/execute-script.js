const fs = require('fs');
const path = require('path');

function createExecuteScript({ config, db, piManager, notifications, io, getScriptType }) {
  return async function executeScript(scriptPath, piId = null, triggeredBy = 'manual') {
    const targetPi = piId || piManager.getCurrentPi();
    const piConfig = piManager.getPiConfig(targetPi);
    const startTime = Date.now();

    const localPath = path.join(config.paths.projectRoot, scriptPath);

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
      await piManager.uploadFile(localPath, remotePath, targetPi);

      const result = await piManager.executeCommand(`sudo bash ${remotePath}`, targetPi, {
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
