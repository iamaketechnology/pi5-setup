// =============================================================================
// SSH Emulator Routes - API Endpoints
// =============================================================================
// API routes for managing SSH configs and Pi emulators
// Version: 1.0.0
// =============================================================================

function registerSshEmulatorRoutes({ app, sshEmulatorManager, supabaseClient, middlewares = {} }) {
  const { authOnly = [], adminOnly = [] } = middlewares;
  // Get the actual Supabase client from the wrapper
  const supabase = supabaseClient.client;
  const isSupabaseEnabled = supabaseClient.isEnabled();

  // ===========================================================================
  // SSH Configuration Routes
  // ===========================================================================

  // GET /api/ssh/config - Get SSH configuration
  app.get('/api/ssh/config', ...authOnly, async (req, res) => {
    try {
      const config = await sshEmulatorManager.getSSHConfig();
      res.json({ success: true, ...config });
    } catch (error) {
      console.error('Error getting SSH config:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // POST /api/ssh/hosts - Add SSH host
  app.post('/api/ssh/hosts', ...authOnly, async (req, res) => {
    try {
      const { alias, hostname, port, username, identityFile, password } = req.body;

      if (!alias || !hostname || !username) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: alias, hostname, username'
        });
      }

      // Add to SSH config
      const result = await sshEmulatorManager.addSSHHost({
        alias,
        hostname,
        port: port || 22,
        username,
        identityFile,
        password
      });

      if (!result.success) {
        return res.json(result);
      }

      // Sync to Supabase for Pi Selector
      if (isSupabaseEnabled && supabase) {
        try {
          // Check if Pi already exists
          const { data: existingPis, error: checkError } = await supabase
            .schema('control_center')
            .from('pis')
            .select('*')
            .eq('hostname', alias)
            .eq('status', 'active');

          if (checkError) {
            console.error('Warning: Could not check Supabase for existing Pi:', checkError);
          }

          if (!existingPis || existingPis.length === 0) {
            // Create Pi in Supabase
            const { data: newPi, error: insertError } = await supabase
              .schema('control_center')
              .from('pis')
              .insert({
                name: alias,
                hostname: alias,
                ip_address: hostname,
                ssh_port: port || 22,
                tags: ['ssh-config', 'manual'],
                color: '#8b5cf6', // Purple for SSH-added
                metadata: {
                  source: 'ssh-config',
                  ssh_user: username || 'pi',
                  identityFile: identityFile || null,
                  added_date: new Date().toISOString()
                },
                status: 'active',
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
              })
              .select()
              .single();

            if (insertError) {
              console.error('Warning: Could not sync Pi to Supabase:', insertError);
            } else {
              console.log(`✅ Pi synced to Supabase: ${alias}`);
              result.supabaseSync = { success: true, pi: newPi };
            }
          } else {
            console.log(`ℹ️  Pi already exists in Supabase: ${alias}`);
            result.supabaseSync = { success: true, existed: true };
          }
        } catch (syncError) {
          console.error('Warning: Supabase sync error:', syncError);
          result.supabaseSync = { success: false, error: syncError.message };
        }
      }

      res.json(result);
    } catch (error) {
      console.error('Error adding SSH host:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // DELETE /api/ssh/hosts/:alias - Remove SSH host
  app.delete('/api/ssh/hosts/:alias', ...authOnly, async (req, res) => {
    try {
      const { alias } = req.params;

      // Remove from SSH config
      const result = await sshEmulatorManager.removeSSHHost(alias);

      // Remove from Supabase
      if (result.success && isSupabaseEnabled && supabase) {
        try {
          const { error: deleteError } = await supabase
            .schema('control_center')
            .from('pis')
            .delete()
            .eq('hostname', alias)
            .eq('status', 'active');

          if (deleteError) {
            console.error('Warning: Could not remove Pi from Supabase:', deleteError);
            result.supabaseSync = { success: false, error: deleteError.message };
          } else {
            console.log(`✅ Pi removed from Supabase: ${alias}`);
            result.supabaseSync = { success: true };
          }
        } catch (syncError) {
          console.error('Warning: Supabase sync error:', syncError);
          result.supabaseSync = { success: false, error: syncError.message };
        }
      }

      res.json(result);
    } catch (error) {
      console.error('Error removing SSH host:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // POST /api/ssh/test/:alias - Test SSH connection
  app.post('/api/ssh/test/:alias', ...authOnly, async (req, res) => {
    try {
      const { alias } = req.params;
      const result = await sshEmulatorManager.testSSHConnection(alias);
      res.json(result);
    } catch (error) {
      console.error('Error testing SSH connection:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // ===========================================================================
  // Pi Emulator Routes
  // ===========================================================================

  // GET /api/emulator/status - Get emulator status
  app.get('/api/emulator/status', ...authOnly, async (req, res) => {
    try {
      const status = await sshEmulatorManager.getEmulatorStatus();
      res.json({ success: true, ...status });
    } catch (error) {
      console.error('Error getting emulator status:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // POST /api/emulator/deploy - Deploy emulator on remote host
  app.post('/api/emulator/deploy', ...authOnly, async (req, res) => {
    try {
      const { targetHost, targetUser, targetPassword } = req.body;

      if (!targetHost || !targetUser) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: targetHost, targetUser'
        });
      }

      const result = await sshEmulatorManager.deployEmulator({
        targetHost,
        targetUser,
        targetPassword
      });

      res.json(result);
    } catch (error) {
      console.error('Error deploying emulator:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // POST /api/emulator/start - Start emulator
  app.post('/api/emulator/start', ...authOnly, async (req, res) => {
    try {
      const { remote = false, remoteHost } = req.body;

      const result = await sshEmulatorManager.startEmulator({
        remote,
        remoteHost
      });

      res.json(result);
    } catch (error) {
      console.error('Error starting emulator:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // POST /api/emulator/stop - Stop emulator
  app.post('/api/emulator/stop', ...authOnly, async (req, res) => {
    try {
      const { remote = false, remoteHost } = req.body;

      const result = await sshEmulatorManager.stopEmulator({
        remote,
        remoteHost
      });

      res.json(result);
    } catch (error) {
      console.error('Error stopping emulator:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // GET /api/emulator/info - Get emulator connection info
  app.get('/api/emulator/info', ...authOnly, async (req, res) => {
    try {
      const { remoteHost } = req.query;

      const result = await sshEmulatorManager.getEmulatorInfo({
        remoteHost
      });

      res.json(result);
    } catch (error) {
      console.error('Error getting emulator info:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // ===========================================================================
  // Network Utilities Routes
  // ===========================================================================

  // GET /api/network/scan - Scan local network
  app.get('/api/network/scan', ...authOnly, async (req, res) => {
    try {
      const result = await sshEmulatorManager.scanNetwork();
      res.json(result);
    } catch (error) {
      console.error('Error scanning network:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });

  // ===========================================================================
  // Sync Route - Synchronize SSH config to Supabase
  // ===========================================================================

  // POST /api/ssh/sync - Sync all SSH hosts to Supabase
  app.post('/api/ssh/sync', ...authOnly, async (req, res) => {
    try {
      if (!isSupabaseEnabled || !supabase) {
        return res.status(503).json({
          success: false,
          error: 'Supabase not configured'
        });
      }

      const config = await sshEmulatorManager.getSSHConfig();
      const hosts = config.hosts || [];

      const results = {
        total: hosts.length,
        created: 0,
        updated: 0,
        skipped: 0,
        errors: []
      };

      for (const host of hosts) {
        try {
          // Check if Pi already exists
          const { data: existingPis, error: checkError } = await supabase
            .schema('control_center')
            .from('pis')
            .select('*')
            .eq('hostname', host.alias)
            .eq('status', 'active');

          if (checkError) {
            results.errors.push({ host: host.alias, error: checkError.message });
            continue;
          }

          if (existingPis && existingPis.length > 0) {
            // Update existing
            const existingMetadata = existingPis[0].metadata || {};
            const { error: updateError } = await supabase
              .schema('control_center')
              .from('pis')
              .update({
                ip_address: host.hostname,
                ssh_port: parseInt(host.port) || 22,
                metadata: {
                  ...existingMetadata,
                  source: 'ssh-config-sync',
                  ssh_user: host.username || 'pi',
                  identityFile: host.identityFile || null,
                  synced_date: new Date().toISOString()
                },
                updated_at: new Date().toISOString()
              })
              .eq('hostname', host.alias);

            if (updateError) {
              results.errors.push({ host: host.alias, error: updateError.message });
            } else {
              results.updated++;
            }
          } else {
            // Create new
            const { error: insertError } = await supabase
              .schema('control_center')
              .from('pis')
              .insert({
                name: host.alias,
                hostname: host.alias,
                ip_address: host.hostname,
                ssh_port: parseInt(host.port) || 22,
                tags: ['ssh-config', 'synced'],
                color: '#8b5cf6', // Purple for SSH-synced
                metadata: {
                  source: 'ssh-config-sync',
                  ssh_user: host.username || 'pi',
                  identityFile: host.identityFile || null,
                  synced_date: new Date().toISOString()
                },
                status: 'active',
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
              });

            if (insertError) {
              results.errors.push({ host: host.alias, error: insertError.message });
            } else {
              results.created++;
            }
          }
        } catch (syncError) {
          results.errors.push({ host: host.alias, error: syncError.message });
        }
      }

      results.skipped = results.total - (results.created + results.updated + results.errors.length);

      console.log('✅ SSH config synced to Supabase:', results);
      res.json({ success: true, results });
    } catch (error) {
      console.error('Error syncing SSH config:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });
}

module.exports = { registerSshEmulatorRoutes };
