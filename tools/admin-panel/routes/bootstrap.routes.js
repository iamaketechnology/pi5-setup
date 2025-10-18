const fs = require('fs');
const os = require('os');
const path = require('path');

function registerBootstrapRoutes({ app, supabaseClient }) {
  app.get('/api/bootstrap/pubkey', (req, res) => {
    try {
      const pubkeyPath = path.join(os.homedir(), '.ssh', 'id_rsa.pub');

      if (fs.existsSync(pubkeyPath)) {
        const pubkey = fs.readFileSync(pubkeyPath, 'utf8');
        res.type('text/plain').send(pubkey);
      } else {
        res.status(404).json({
          success: false,
          error: 'SSH public key not found. Generate one with: ssh-keygen -t rsa'
        });
      }
    } catch (error) {
      console.error('Error reading public key:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });

  app.post('/api/bootstrap/register', async (req, res) => {
    try {
      const { token, hostname, ip_address, mac_address, metadata } = req.body;

      if (!token || !hostname) {
        return res.status(400).json({
          success: false,
          error: 'Token and hostname are required'
        });
      }

      console.log('📝 Pi registration received:', {
        token,
        hostname,
        ip: ip_address,
        mac: mac_address
      });

      if (supabaseClient.isEnabled()) {
        try {
          const existingPi = await supabaseClient.getPiByHostname(hostname);

          if (existingPi) {
            await supabaseClient.updatePi(existingPi.id, {
              token,
              ip_address,
              mac_address,
              status: 'pending',
              metadata: metadata || {},
              last_seen: new Date().toISOString()
            });

            console.log(`✅ Updated existing Pi: ${hostname}`);
          } else {
            const piData = {
              name: hostname,
              hostname,
              ip_address,
              mac_address,
              token,
              status: 'pending',
              tags: ['bootstrap', 'pending-pairing'],
              metadata: metadata || {},
              last_seen: new Date().toISOString()
            };

            await supabaseClient.createPi(piData);
            console.log(`✅ Registered new Pi: ${hostname}`);
          }

          res.json({
            success: true,
            message: 'Pi registered successfully in Supabase. Use token to pair.',
            token
          });
        } catch (dbError) {
          console.error('Supabase error:', dbError);
          res.json({
            success: true,
            message: 'Pi registration acknowledged (database unavailable). Use token to pair manually.',
            token,
            warning: 'Database storage failed'
          });
        }
      } else {
        res.json({
          success: true,
          message: 'Pi registered. Use token to pair in Control Center (manual pairing required).',
          token,
          warning: 'Supabase not configured'
        });
      }
    } catch (error) {
      console.error('Error registering Pi:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });
}

module.exports = {
  registerBootstrapRoutes
};
