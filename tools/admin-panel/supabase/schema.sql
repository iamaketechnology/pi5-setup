-- =============================================================================
-- PI5 Control Center - Supabase Schema
-- =============================================================================
-- Version: 4.0.0
-- Description: Multi-Pi management database schema
-- Usage: Execute in Supabase SQL Editor or via psql
-- =============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create dedicated schema
CREATE SCHEMA IF NOT EXISTS control_center;

-- Grant usage to authenticated users
GRANT USAGE ON SCHEMA control_center TO authenticated;
GRANT USAGE ON SCHEMA control_center TO service_role;

-- =============================================================================
-- Table: pis
-- Description: Raspberry Pi inventory and connection info
-- =============================================================================

CREATE TABLE IF NOT EXISTS control_center.pis (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Identity
    name TEXT NOT NULL,
    hostname TEXT UNIQUE NOT NULL,

    -- Network
    ip_address INET,
    ssh_port INTEGER DEFAULT 22,
    mac_address MACADDR,

    -- Connection
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'offline', 'error')),
    token TEXT UNIQUE, -- Bootstrap pairing token (one-time use)
    ssh_key_fingerprint TEXT,

    -- Configuration
    tags TEXT[] DEFAULT '{}',
    color TEXT DEFAULT '#10b981', -- Tailwind green-500

    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb, -- {os_version, arch, model, etc}
    remote_paths JSONB DEFAULT '{"stacks": "/home/pi/stacks", "temp": "/tmp"}'::jsonb,

    -- Monitoring
    last_seen TIMESTAMPTZ,
    last_boot TIMESTAMPTZ,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_pis_hostname ON control_center.pis(hostname);
CREATE INDEX IF NOT EXISTS idx_pis_status ON control_center.pis(status);
CREATE INDEX IF NOT EXISTS idx_pis_token ON control_center.pis(token) WHERE token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_pis_last_seen ON control_center.pis(last_seen DESC);

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_pis_updated_at
    BEFORE UPDATE ON control_center.pis
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- Table: installations
-- Description: Installation history and logs
-- =============================================================================

CREATE TABLE IF NOT EXISTS control_center.installations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Relations
    pi_id UUID NOT NULL REFERENCES control_center.pis(id) ON DELETE CASCADE,

    -- Script info
    script_name TEXT NOT NULL,
    script_path TEXT,
    script_category TEXT, -- infrastructure, security, monitoring, etc.

    -- Execution
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'running', 'success', 'failed', 'cancelled')),
    exit_code INTEGER,

    -- Output
    output TEXT, -- Full stdout/stderr
    error_message TEXT,

    -- Timing
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER GENERATED ALWAYS AS (
        CASE
            WHEN completed_at IS NOT NULL AND started_at IS NOT NULL
            THEN EXTRACT(EPOCH FROM (completed_at - started_at))::INTEGER
            ELSE NULL
        END
    ) STORED,

    -- Context
    triggered_by TEXT DEFAULT 'manual', -- manual, scheduled, auto
    metadata JSONB DEFAULT '{}'::jsonb,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_installations_pi_id ON control_center.installations(pi_id);
CREATE INDEX IF NOT EXISTS idx_installations_status ON control_center.installations(status);
CREATE INDEX IF NOT EXISTS idx_installations_created_at ON control_center.installations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_installations_pi_status ON control_center.installations(pi_id, status);

-- =============================================================================
-- Table: system_stats
-- Description: Real-time system metrics history
-- =============================================================================

CREATE TABLE IF NOT EXISTS control_center.system_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Relations
    pi_id UUID NOT NULL REFERENCES control_center.pis(id) ON DELETE CASCADE,

    -- Metrics
    cpu_percent NUMERIC(5,2),
    ram_percent NUMERIC(5,2),
    ram_used_mb INTEGER,
    ram_total_mb INTEGER,
    disk_percent NUMERIC(5,2),
    disk_used_gb NUMERIC(10,2),
    disk_total_gb NUMERIC(10,2),
    temperature_celsius NUMERIC(5,2),
    uptime_seconds INTEGER,

    -- Network
    network_rx_bytes BIGINT,
    network_tx_bytes BIGINT,

    -- Docker
    docker_containers_running INTEGER,
    docker_containers_total INTEGER,

    -- Timestamp
    collected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Partition by time for performance (optional, for high-frequency data)
CREATE INDEX IF NOT EXISTS idx_system_stats_pi_time ON control_center.system_stats(pi_id, collected_at DESC);

-- Auto-cleanup old stats (keep last 7 days)
CREATE OR REPLACE FUNCTION control_center.cleanup_old_system_stats()
RETURNS void AS $$
BEGIN
    DELETE FROM control_center.system_stats
    WHERE collected_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Table: scheduled_tasks
-- Description: Cron-like task scheduler
-- =============================================================================

CREATE TABLE IF NOT EXISTS control_center.scheduled_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Relations
    pi_id UUID NOT NULL REFERENCES control_center.pis(id) ON DELETE CASCADE,

    -- Task info
    name TEXT NOT NULL,
    script_path TEXT NOT NULL,
    cron_expression TEXT NOT NULL, -- e.g., "0 2 * * *"

    -- State
    enabled BOOLEAN NOT NULL DEFAULT true,

    -- Execution tracking
    last_run_at TIMESTAMPTZ,
    last_run_status TEXT CHECK (last_run_status IN ('success', 'failed', NULL)),
    next_run_at TIMESTAMPTZ,

    -- Metadata
    description TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_pi_id ON control_center.scheduled_tasks(pi_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_enabled ON control_center.scheduled_tasks(enabled);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_next_run ON control_center.scheduled_tasks(next_run_at) WHERE enabled = true;

CREATE TRIGGER update_scheduled_tasks_updated_at
    BEFORE UPDATE ON control_center.scheduled_tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- Views: Useful aggregations
-- =============================================================================

-- View: Pi summary with latest stats
CREATE OR REPLACE VIEW control_center.pis_with_stats AS
SELECT
    p.*,
    s.cpu_percent,
    s.ram_percent,
    s.disk_percent,
    s.temperature_celsius,
    s.docker_containers_running,
    s.collected_at AS stats_updated_at
FROM control_center.pis p
LEFT JOIN LATERAL (
    SELECT * FROM control_center.system_stats
    WHERE pi_id = p.id
    ORDER BY collected_at DESC
    LIMIT 1
) s ON true;

-- View: Installation summary by Pi
CREATE OR REPLACE VIEW control_center.installation_summary AS
SELECT
    pi_id,
    COUNT(*) AS total_installations,
    COUNT(*) FILTER (WHERE status = 'success') AS successful,
    COUNT(*) FILTER (WHERE status = 'failed') AS failed,
    COUNT(*) FILTER (WHERE status = 'running') AS running,
    MAX(completed_at) AS last_installation_at,
    AVG(duration_seconds) FILTER (WHERE status = 'success') AS avg_duration_seconds
FROM control_center.installations
GROUP BY pi_id;

-- =============================================================================
-- Comments
-- =============================================================================

COMMENT ON TABLE control_center.pis IS 'Raspberry Pi inventory and connection info';
COMMENT ON TABLE control_center.installations IS 'Installation execution history and logs';
COMMENT ON TABLE control_center.system_stats IS 'Real-time system metrics (CPU, RAM, disk, temp)';
COMMENT ON TABLE control_center.scheduled_tasks IS 'Cron-like scheduled tasks per Pi';

COMMENT ON COLUMN control_center.pis.token IS 'One-time bootstrap pairing token (nullified after pairing)';
COMMENT ON COLUMN control_center.pis.status IS 'pending: awaiting pairing, active: connected, offline: unreachable, error: connection issue';
COMMENT ON COLUMN control_center.installations.triggered_by IS 'manual: user-triggered, scheduled: cron task, auto: dependency/hook';
