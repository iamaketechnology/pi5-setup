-- =============================================================================
-- PI5 Control Center - Seed Data (Migration)
-- =============================================================================
-- Version: 4.0.0
-- Description: Migrate existing Pi from config.js to Supabase
-- Usage: Execute after schema.sql and policies.sql
-- =============================================================================

-- Insert current Pi (pi5) from existing config.js
INSERT INTO control_center.pis (
    id,
    name,
    hostname,
    ip_address,
    ssh_port,
    status,
    tags,
    color,
    metadata,
    remote_paths,
    last_seen,
    created_at,
    updated_at
) VALUES (
    gen_random_uuid(),
    'pi5', -- From config.js: name
    'pi5.local', -- From config.js: host
    '192.168.1.118'::inet, -- Backup IP
    22, -- From config.js: port
    'active', -- Status (connected)
    ARRAY['production', 'main'], -- From config.js: tags
    '#10b981', -- From config.js: color (green)
    jsonb_build_object(
        'username', 'pi',
        'migrated_from_config', true,
        'original_id', 'pi-prod'
    ),
    jsonb_build_object(
        'stacks', '/home/pi/stacks',
        'temp', '/tmp'
    ),
    NOW(), -- Mark as seen now
    NOW(),
    NOW()
) ON CONFLICT (hostname) DO UPDATE SET
    name = EXCLUDED.name,
    ip_address = EXCLUDED.ip_address,
    status = EXCLUDED.status,
    tags = EXCLUDED.tags,
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
