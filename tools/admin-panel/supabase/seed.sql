-- =============================================================================
-- PI5 Control Center - Seed Data (Migration)
-- =============================================================================
-- Version: 4.0.0
-- Description: Migrate existing Pi from config.js to Supabase
-- Usage: Execute after schema.sql and policies.sql
-- =============================================================================

-- Insert current Pi (pi5) from existing config.js with monitoring metadata
INSERT INTO control_center.pis (
    id,
    name,
    hostname,
    description,
    -- Hardware
    model,
    ram_mb,
    storage_gb,
    cpu_cores,
    architecture,
    -- Network
    ip_address,
    ssh_port,
    -- Connection
    status,
    tags,
    color,
    -- OS
    os_name,
    os_version,
    -- Monitoring current state (will be updated by metrics collector)
    cpu_usage_percent,
    cpu_temperature_celsius,
    memory_total_mb,
    memory_usage_percent,
    disk_total_gb,
    disk_usage_percent,
    -- Metadata & Paths
    metadata,
    remote_paths,
    services_status,
    -- Timestamps
    last_seen,
    created_at,
    updated_at
) VALUES (
    gen_random_uuid(),
    'pi5', -- From config.js: name
    'pi5.local', -- From config.js: host
    'Production Raspberry Pi 5 - Main Server',
    -- Hardware
    'Raspberry Pi 5',
    8192, -- 8GB RAM
    500, -- 500GB NVMe
    4, -- 4 cores
    'aarch64',
    -- Network
    '192.168.1.118'::inet,
    22,
    -- Connection
    'active',
    ARRAY['production', 'main', 'supabase'],
    '#10b981',
    -- OS
    'Raspberry Pi OS',
    '12 (bookworm)',
    -- Monitoring (initial placeholders, will be updated)
    0.0, -- cpu_usage_percent
    45.0, -- cpu_temperature_celsius
    8192, -- memory_total_mb
    0.0, -- memory_usage_percent
    500, -- disk_total_gb
    0.0, -- disk_usage_percent
    -- Metadata
    jsonb_build_object(
        'username', 'pi',
        'migrated_from_config', true,
        'original_id', 'pi-prod',
        'location', 'Local Network',
        'primary_use', 'Development & Production'
    ),
    jsonb_build_object(
        'stacks', '/home/pi/stacks',
        'temp', '/tmp',
        'logs', '/var/log'
    ),
    jsonb_build_object(
        'docker', 'running',
        'supabase', 'running'
    ),
    -- Timestamps
    NOW(),
    NOW(),
    NOW()
) ON CONFLICT (hostname) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    model = EXCLUDED.model,
    ram_mb = EXCLUDED.ram_mb,
    storage_gb = EXCLUDED.storage_gb,
    ip_address = EXCLUDED.ip_address,
    status = EXCLUDED.status,
    tags = EXCLUDED.tags,
    os_name = EXCLUDED.os_name,
    os_version = EXCLUDED.os_version,
    last_seen = NOW(),
    updated_at = NOW();

-- Verify insertion
SELECT
    id,
    name,
    hostname,
    ip_address,
    status,
    tags,
    created_at
FROM control_center.pis
WHERE hostname = 'pi5.local';
