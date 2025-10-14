// =============================================================================
// PI5 Control Center - Database Module (SQLite)
// =============================================================================
// Manages execution history, scheduled tasks, system stats history
// Version: 3.0.0
// =============================================================================

const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

let db = null;

// =============================================================================
// Initialize Database
// =============================================================================

function initDatabase(dbPath) {
  // Ensure data directory exists
  const dataDir = path.dirname(dbPath);
  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
  }

  db = new Database(dbPath);
  db.pragma('journal_mode = WAL');

  // Create tables
  createTables();

  console.log(`✅ Database initialized: ${dbPath}`);
  return db;
}

function createTables() {
  // Execution history table
  db.exec(`
    CREATE TABLE IF NOT EXISTS executions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pi_id TEXT NOT NULL,
      script_path TEXT NOT NULL,
      script_name TEXT NOT NULL,
      script_type TEXT,
      started_at INTEGER NOT NULL,
      ended_at INTEGER,
      duration INTEGER,
      exit_code INTEGER,
      status TEXT NOT NULL DEFAULT 'running',
      output TEXT,
      error TEXT,
      triggered_by TEXT DEFAULT 'manual',
      created_at INTEGER DEFAULT (strftime('%s', 'now'))
    )
  `);

  // Scheduled tasks table
  db.exec(`
    CREATE TABLE IF NOT EXISTS scheduled_tasks (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      pi_id TEXT NOT NULL,
      script_path TEXT NOT NULL,
      cron_expression TEXT NOT NULL,
      enabled INTEGER DEFAULT 1,
      last_run INTEGER,
      next_run INTEGER,
      run_count INTEGER DEFAULT 0,
      created_at INTEGER DEFAULT (strftime('%s', 'now')),
      updated_at INTEGER DEFAULT (strftime('%s', 'now'))
    )
  `);

  // System stats history table (for graphs)
  db.exec(`
    CREATE TABLE IF NOT EXISTS stats_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pi_id TEXT NOT NULL,
      cpu REAL,
      memory_percent REAL,
      memory_used INTEGER,
      memory_total INTEGER,
      temperature REAL,
      disk_percent REAL,
      timestamp INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    )
  `);

  // Create indexes
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_executions_pi_id ON executions(pi_id);
    CREATE INDEX IF NOT EXISTS idx_executions_started_at ON executions(started_at DESC);
    CREATE INDEX IF NOT EXISTS idx_executions_status ON executions(status);
    CREATE INDEX IF NOT EXISTS idx_stats_history_pi_timestamp ON stats_history(pi_id, timestamp DESC);
  `);
}

// =============================================================================
// Execution History Functions
// =============================================================================

function createExecution(data) {
  const stmt = db.prepare(`
    INSERT INTO executions (pi_id, script_path, script_name, script_type, started_at, triggered_by, status)
    VALUES (?, ?, ?, ?, ?, ?, 'running')
  `);

  const result = stmt.run(
    data.piId,
    data.scriptPath,
    data.scriptName,
    data.scriptType || null,
    data.startedAt || Date.now(),
    data.triggeredBy || 'manual'
  );

  return result.lastInsertRowid;
}

function updateExecution(id, data) {
  const fields = [];
  const values = [];

  if (data.endedAt !== undefined) {
    fields.push('ended_at = ?');
    values.push(data.endedAt);
  }

  if (data.duration !== undefined) {
    fields.push('duration = ?');
    values.push(data.duration);
  }

  if (data.exitCode !== undefined) {
    fields.push('exit_code = ?');
    values.push(data.exitCode);
  }

  if (data.status !== undefined) {
    fields.push('status = ?');
    values.push(data.status);
  }

  if (data.output !== undefined) {
    fields.push('output = ?');
    values.push(data.output);
  }

  if (data.error !== undefined) {
    fields.push('error = ?');
    values.push(data.error);
  }

  if (fields.length === 0) return;

  const stmt = db.prepare(`
    UPDATE executions
    SET ${fields.join(', ')}
    WHERE id = ?
  `);

  stmt.run(...values, id);
}

function getExecutions(filters = {}) {
  let query = 'SELECT * FROM executions WHERE 1=1';
  const params = [];

  if (filters.piId) {
    query += ' AND pi_id = ?';
    params.push(filters.piId);
  }

  if (filters.status) {
    query += ' AND status = ?';
    params.push(filters.status);
  }

  if (filters.scriptType) {
    query += ' AND script_type = ?';
    params.push(filters.scriptType);
  }

  if (filters.search) {
    query += ' AND (script_name LIKE ? OR script_path LIKE ?)';
    params.push(`%${filters.search}%`, `%${filters.search}%`);
  }

  query += ' ORDER BY started_at DESC';

  if (filters.limit) {
    query += ' LIMIT ?';
    params.push(filters.limit);
  }

  const stmt = db.prepare(query);
  return stmt.all(...params);
}

function getExecutionById(id) {
  const stmt = db.prepare('SELECT * FROM executions WHERE id = ?');
  return stmt.get(id);
}

function getExecutionStats(piId = null) {
  let query = `
    SELECT
      COUNT(*) as total,
      SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) as success,
      SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed,
      SUM(CASE WHEN status = 'running' THEN 1 ELSE 0 END) as running,
      AVG(duration) as avg_duration
    FROM executions
  `;

  if (piId) {
    query += ' WHERE pi_id = ?';
  }

  const stmt = db.prepare(query);
  return piId ? stmt.get(piId) : stmt.get();
}

// =============================================================================
// Scheduled Tasks Functions
// =============================================================================

function createScheduledTask(data) {
  const stmt = db.prepare(`
    INSERT INTO scheduled_tasks (id, name, pi_id, script_path, cron_expression, enabled)
    VALUES (?, ?, ?, ?, ?, ?)
  `);

  stmt.run(
    data.id,
    data.name,
    data.piId,
    data.scriptPath,
    data.cronExpression,
    data.enabled ? 1 : 0
  );
}

function updateScheduledTask(id, data) {
  const fields = [];
  const values = [];

  if (data.name !== undefined) {
    fields.push('name = ?');
    values.push(data.name);
  }

  if (data.cronExpression !== undefined) {
    fields.push('cron_expression = ?');
    values.push(data.cronExpression);
  }

  if (data.enabled !== undefined) {
    fields.push('enabled = ?');
    values.push(data.enabled ? 1 : 0);
  }

  if (data.lastRun !== undefined) {
    fields.push('last_run = ?');
    values.push(data.lastRun);
  }

  if (data.nextRun !== undefined) {
    fields.push('next_run = ?');
    values.push(data.nextRun);
  }

  if (data.runCount !== undefined) {
    fields.push('run_count = run_count + 1');
  }

  fields.push('updated_at = strftime(\'%s\', \'now\')');

  if (fields.length === 0) return;

  const stmt = db.prepare(`
    UPDATE scheduled_tasks
    SET ${fields.join(', ')}
    WHERE id = ?
  `);

  stmt.run(...values, id);
}

function deleteScheduledTask(id) {
  const stmt = db.prepare('DELETE FROM scheduled_tasks WHERE id = ?');
  stmt.run(id);
}

function getScheduledTasks(filters = {}) {
  let query = 'SELECT * FROM scheduled_tasks WHERE 1=1';
  const params = [];

  if (filters.piId) {
    query += ' AND pi_id = ?';
    params.push(filters.piId);
  }

  if (filters.enabled !== undefined) {
    query += ' AND enabled = ?';
    params.push(filters.enabled ? 1 : 0);
  }

  query += ' ORDER BY name ASC';

  const stmt = db.prepare(query);
  return stmt.all(...params);
}

function getScheduledTaskById(id) {
  const stmt = db.prepare('SELECT * FROM scheduled_tasks WHERE id = ?');
  return stmt.get(id);
}

// =============================================================================
// System Stats History Functions
// =============================================================================

function saveStatsHistory(piId, stats) {
  const stmt = db.prepare(`
    INSERT INTO stats_history (pi_id, cpu, memory_percent, memory_used, memory_total, temperature, disk_percent)
    VALUES (?, ?, ?, ?, ?, ?, ?)
  `);

  stmt.run(
    piId,
    stats.cpu,
    stats.memory?.percent || null,
    stats.memory?.used || null,
    stats.memory?.total || null,
    stats.temperature || null,
    stats.disk?.percent || null
  );
}

function getStatsHistory(piId, options = {}) {
  const { hours = 24, interval = 300 } = options; // Default: 24h, 5min interval

  const stmt = db.prepare(`
    SELECT
      timestamp,
      cpu,
      memory_percent,
      temperature,
      disk_percent
    FROM stats_history
    WHERE pi_id = ?
    AND timestamp >= strftime('%s', 'now', '-${hours} hours')
    ORDER BY timestamp ASC
  `);

  let results = stmt.all(piId);

  // Downsample if needed (keep 1 point every 'interval' seconds)
  if (interval > 0 && results.length > 0) {
    const downsampled = [];
    let lastTimestamp = 0;

    for (const row of results) {
      if (row.timestamp - lastTimestamp >= interval) {
        downsampled.push(row);
        lastTimestamp = row.timestamp;
      }
    }

    results = downsampled;
  }

  return results;
}

function cleanOldStats(daysToKeep = 7) {
  const stmt = db.prepare(`
    DELETE FROM stats_history
    WHERE timestamp < strftime('%s', 'now', '-${daysToKeep} days')
  `);

  const result = stmt.run();
  return result.changes;
}

// =============================================================================
// Export Functions
// =============================================================================

module.exports = {
  initDatabase,
  getDatabase: () => db,

  // Executions
  createExecution,
  updateExecution,
  getExecutions,
  getExecutionById,
  getExecutionStats,

  // Scheduled Tasks
  createScheduledTask,
  updateScheduledTask,
  deleteScheduledTask,
  getScheduledTasks,
  getScheduledTaskById,

  // Stats History
  saveStatsHistory,
  getStatsHistory,
  cleanOldStats
};
