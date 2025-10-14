// =============================================================================
// PI5 Control Center - Scheduler Module
// =============================================================================
// Manages cron jobs for automated script execution
// Version: 3.0.0
// =============================================================================

const cron = require('node-cron');
const { getScheduledTasks, updateScheduledTask, createExecution } = require('./database');
const { sendNotification } = require('./notifications');

const activeTasks = new Map(); // Map of task ID -> cron job

// =============================================================================
// Initialize Scheduler
// =============================================================================

function initScheduler(executeScriptFn) {
  console.log('📅 Initializing scheduler...');

  // Load all enabled tasks from database
  const tasks = getScheduledTasks({ enabled: true });

  for (const task of tasks) {
    try {
      scheduleTask(task, executeScriptFn);
      console.log(`✅ Scheduled: ${task.name} (${task.cron_expression})`);
    } catch (error) {
      console.error(`❌ Failed to schedule ${task.name}:`, error.message);
    }
  }

  console.log(`📅 Scheduler initialized with ${tasks.length} active tasks`);
}

// =============================================================================
// Schedule a Task
// =============================================================================

function scheduleTask(task, executeScriptFn) {
  // Validate cron expression
  if (!cron.validate(task.cron_expression)) {
    throw new Error(`Invalid cron expression: ${task.cron_expression}`);
  }

  // Stop existing task if any
  if (activeTasks.has(task.id)) {
    stopTask(task.id);
  }

  // Create new cron job
  const job = cron.schedule(task.cron_expression, async () => {
    console.log(`🕐 Executing scheduled task: ${task.name}`);

    const startTime = Date.now();

    try {
      // Create execution record
      const executionId = createExecution({
        piId: task.pi_id,
        scriptPath: task.script_path,
        scriptName: task.name,
        scriptType: 'scheduled',
        startedAt: startTime,
        triggeredBy: 'scheduler'
      });

      // Execute script
      const result = await executeScriptFn(task.script_path, task.pi_id);

      // Update execution record
      updateExecution(executionId, {
        endedAt: Date.now(),
        duration: Date.now() - startTime,
        exitCode: result.exitCode || 0,
        status: result.success ? 'success' : 'failed',
        output: result.output,
        error: result.error
      });

      // Update task
      updateScheduledTask(task.id, {
        lastRun: Date.now(),
        runCount: true
      });

      // Send notification on failure
      if (!result.success) {
        sendNotification('execution.failed', {
          task: task.name,
          script: task.script_path,
          pi: task.pi_id,
          error: result.error
        });
      }

      console.log(`✅ Scheduled task completed: ${task.name}`);
    } catch (error) {
      console.error(`❌ Scheduled task failed: ${task.name}`, error);

      sendNotification('execution.failed', {
        task: task.name,
        script: task.script_path,
        pi: task.pi_id,
        error: error.message
      });
    }
  });

  activeTasks.set(task.id, job);
  return job;
}

// =============================================================================
// Stop a Task
// =============================================================================

function stopTask(taskId) {
  const job = activeTasks.get(taskId);
  if (job) {
    job.stop();
    activeTasks.delete(taskId);
    console.log(`⏹️ Stopped task: ${taskId}`);
    return true;
  }
  return false;
}

// =============================================================================
// Get Next Run Time
// =============================================================================

function getNextRunTime(cronExpression) {
  try {
    const schedule = cron.schedule(cronExpression, () => {}, {
      scheduled: false
    });

    // This is a workaround since node-cron doesn't expose next run directly
    // We'll estimate based on current time
    const now = new Date();
    const patterns = cronExpression.split(' ');

    // Simple estimation (not 100% accurate for complex patterns)
    // For production, consider using 'cron-parser' library
    return now.getTime() + 60000; // Placeholder: next minute
  } catch (error) {
    return null;
  }
}

// =============================================================================
// Stop All Tasks
// =============================================================================

function stopAll() {
  console.log('🛑 Stopping all scheduled tasks...');

  for (const [taskId, job] of activeTasks.entries()) {
    job.stop();
  }

  activeTasks.clear();
  console.log('✅ All scheduled tasks stopped');
}

// =============================================================================
// Export Functions
// =============================================================================

module.exports = {
  initScheduler,
  scheduleTask,
  stopTask,
  stopAll,
  getNextRunTime,
  getActiveTasks: () => Array.from(activeTasks.keys())
};
