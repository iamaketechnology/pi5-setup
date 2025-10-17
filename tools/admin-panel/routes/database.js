// =============================================================================
// Database Routes - Supabase Schema Installation
// =============================================================================

const express = require('express');
const router = express.Router();
const fs = require('fs').promises;
const path = require('path');

/**
 * GET /api/database/status
 * Check if control_center schema is installed
 */
router.get('/status', async (req, res) => {
    try {
        const piManager = req.app.get('piManager');
        const currentPi = piManager.getCurrentPi();

        if (!currentPi || !currentPi.ssh) {
            return res.json({
                success: false,
                error: 'No Pi connected',
                schema_exists: false
            });
        }

        // Check if schema exists
        const checkSchemaCmd = `
            docker exec supabase-db psql -U postgres -d postgres -t -c "
                SELECT EXISTS(
                    SELECT 1 FROM information_schema.schemata
                    WHERE schema_name = 'control_center'
                );
            "
        `;

        const schemaResult = await currentPi.ssh.execCommand(checkSchemaCmd);
        const schemaExists = schemaResult.stdout.trim() === 't';

        let tableCount = 0;
        let piCount = 0;
        let piNames = '';

        if (schemaExists) {
            // Count tables
            const countTablesCmd = `
                docker exec supabase-db psql -U postgres -d postgres -t -c "
                    SELECT COUNT(*)
                    FROM information_schema.tables
                    WHERE table_schema = 'control_center';
                "
            `;

            const tablesResult = await currentPi.ssh.execCommand(countTablesCmd);
            tableCount = parseInt(tablesResult.stdout.trim()) || 0;

            // Count Pis
            const countPisCmd = `
                docker exec supabase-db psql -U postgres -d postgres -t -c "
                    SELECT COUNT(*) FROM control_center.pis;
                "
            `;

            const pisResult = await currentPi.ssh.execCommand(countPisCmd);
            piCount = parseInt(pisResult.stdout.trim()) || 0;

            // Get Pi names
            const getPiNamesCmd = `
                docker exec supabase-db psql -U postgres -d postgres -t -c "
                    SELECT string_agg(name, ', ') FROM control_center.pis;
                "
            `;

            const namesResult = await currentPi.ssh.execCommand(getPiNamesCmd);
            piNames = namesResult.stdout.trim() || 'Aucun';
        }

        res.json({
            success: true,
            schema_exists: schemaExists,
            table_count: tableCount,
            pi_count: piCount,
            pi_names: piNames
        });

    } catch (error) {
        console.error('Error checking database status:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

/**
 * POST /api/database/install
 * Install control_center schema on Supabase
 */
router.post('/install', async (req, res) => {
    try {
        const piManager = req.app.get('piManager');
        const currentPi = piManager.getCurrentPi();

        if (!currentPi || !currentPi.ssh) {
            return res.json({
                success: false,
                error: 'No Pi connected'
            });
        }

        const supabaseDir = path.join(__dirname, '../supabase');

        // Read SQL files
        const schemaSQL = await fs.readFile(path.join(supabaseDir, 'schema.sql'), 'utf8');
        const policiesSQL = await fs.readFile(path.join(supabaseDir, 'policies.sql'), 'utf8');
        const seedSQL = await fs.readFile(path.join(supabaseDir, 'seed.sql'), 'utf8');

        // Upload SQL files to Pi
        await currentPi.ssh.putFile(
            path.join(supabaseDir, 'schema.sql'),
            '/tmp/control_center_schema.sql'
        );
        await currentPi.ssh.putFile(
            path.join(supabaseDir, 'policies.sql'),
            '/tmp/control_center_policies.sql'
        );
        await currentPi.ssh.putFile(
            path.join(supabaseDir, 'seed.sql'),
            '/tmp/control_center_seed.sql'
        );

        // Execute schema.sql
        console.log('Executing schema.sql...');
        const schemaResult = await currentPi.ssh.execCommand(
            'docker exec -i supabase-db psql -U postgres -d postgres < /tmp/control_center_schema.sql'
        );

        if (schemaResult.code !== 0) {
            throw new Error(`Schema installation failed: ${schemaResult.stderr}`);
        }

        // Execute policies.sql
        console.log('Executing policies.sql...');
        const policiesResult = await currentPi.ssh.execCommand(
            'docker exec -i supabase-db psql -U postgres -d postgres < /tmp/control_center_policies.sql'
        );

        if (policiesResult.code !== 0) {
            throw new Error(`Policies installation failed: ${policiesResult.stderr}`);
        }

        // Execute seed.sql
        console.log('Executing seed.sql...');
        const seedResult = await currentPi.ssh.execCommand(
            'docker exec -i supabase-db psql -U postgres -d postgres < /tmp/control_center_seed.sql'
        );

        if (seedResult.code !== 0) {
            throw new Error(`Seed installation failed: ${seedResult.stderr}`);
        }

        // Cleanup temp files
        await currentPi.ssh.execCommand('rm -f /tmp/control_center_*.sql');

        // Count installed Pis
        const countPisCmd = `
            docker exec supabase-db psql -U postgres -d postgres -t -c "
                SELECT COUNT(*) FROM control_center.pis;
            "
        `;

        const pisResult = await currentPi.ssh.execCommand(countPisCmd);
        const piCount = parseInt(pisResult.stdout.trim()) || 0;

        res.json({
            success: true,
            message: 'Schema installed successfully',
            pi_count: piCount
        });

    } catch (error) {
        console.error('Error installing database schema:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

module.exports = router;
