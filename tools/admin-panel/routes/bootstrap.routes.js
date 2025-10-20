// =============================================================================
// Bootstrap Route - Auto-Pairing for New Pis
// =============================================================================
// Generates a self-registration script that Pis can curl and execute
// Version: 1.0.0
// =============================================================================

function registerBootstrapRoutes({ app, supabaseClient }) {
  const supabase = supabaseClient;

  // ===========================================================================
  // GET /bootstrap - Generate auto-pairing script
  // ===========================================================================
  app.get('/bootstrap', async (req, res) => {
    try {
      const protocol = req.protocol;
      const host = req.get('host');
      const controlCenterUrl = `${protocol}://${host}`;

      const script = generateBootstrapScript(controlCenterUrl);

      res.setHeader('Content-Type', 'text/plain');
      res.send(script);
    } catch (error) {
      console.error('Bootstrap error:', error);
      res.status(500).send('# Error generating bootstrap script\nexit 1');
    }
  });

  // ===========================================================================
  // POST /api/bootstrap/register - Register Pi from bootstrap script
  // ===========================================================================
  app.post('/api/bootstrap/register', async (req, res) => {
    try {
      const { name, hostname, ip, port, username, metadata } = req.body;

      if (!name || !hostname || !ip || !port || !username) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: name, hostname, ip, port, username'
        });
      }

      const { data: existingPis, error: checkError } = await supabase
        .from('pis')
        .select('*')
        .or(`hostname.eq.${hostname},ip.eq.${ip}`)
        .eq('active', true);

      if (checkError) {
        console.error('Error checking existing Pis:', checkError);
        return res.status(500).json({ success: false, error: 'Database error' });
      }

      if (existingPis && existingPis.length > 0) {
        const existingPi = existingPis[0];

        const { data: updatedPi, error: updateError } = await supabase
          .from('pis')
          .update({
            name,
            hostname,
            ip,
            port,
            username,
            metadata,
            updated_at: new Date().toISOString()
          })
          .eq('id', existingPi.id)
          .select()
          .single();

        if (updateError) {
          console.error('Error updating Pi:', updateError);
          return res.status(500).json({ success: false, error: 'Failed to update Pi' });
        }

        console.log(`✅ Pi updated via bootstrap: ${name} (${hostname})`);
        return res.json({
          success: true,
          message: 'Pi updated successfully',
          pi: updatedPi,
          action: 'updated'
        });
      }

      const { data: newPi, error: insertError } = await supabase
        .from('pis')
        .insert({
          name,
          hostname,
          ip,
          port,
          username,
          tags: ['bootstrap', 'auto-paired'],
          color: '#3b82f6',
          metadata,
          active: true,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .select()
        .single();

      if (insertError) {
        console.error('Error creating Pi:', insertError);
        return res.status(500).json({ success: false, error: 'Failed to create Pi' });
      }

      console.log(`✅ Pi registered via bootstrap: ${name} (${hostname})`);
      res.json({
        success: true,
        message: 'Pi registered successfully',
        pi: newPi,
        action: 'created'
      });

    } catch (error) {
      console.error('Bootstrap registration error:', error);
      res.status(500).json({ success: false, error: error.message });
    }
  });
};

function generateBootstrapScript(controlCenterUrl) {
  return `#!/bin/bash
set -euo pipefail

RED='\\033[0;31m'
GREEN='\\033[0;32m'
BLUE='\\033[0;34m'
NC='\\033[0m'

log_info() { echo -e "\${BLUE}[INFO]\${NC} \$*"; }
log_success() { echo -e "\${GREEN}[SUCCESS]\${NC} \$*"; }
log_error() { echo -e "\${RED}[ERROR]\${NC} \$*" >&2; }

log_info "Detecting Pi information..."

HOSTNAME=\$(hostname)
USERNAME="\${SUDO_USER:-\$(whoami)}"
SSH_PORT=\$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print \$2}' || echo "22")

PRIMARY_IP=""
if command -v ip &> /dev/null; then
  PRIMARY_IP=\$(ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}' | head -1 || echo "")
  
  if [[ -z "\${PRIMARY_IP}" ]]; then
    PRIMARY_IP=\$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}' | head -1 || echo "")
  fi
  
  if [[ -z "\${PRIMARY_IP}" ]]; then
    PRIMARY_IP=\$(ip -4 addr show | grep -oP '(?<=inet\\s)\\d+(\\.\\d+){3}' | grep -v "127.0.0.1" | head -1 || echo "")
  fi
fi

if [[ -z "\${PRIMARY_IP}" ]]; then
  log_error "Could not detect IP address"
  exit 1
fi

log_info "Hostname: \${HOSTNAME}"
log_info "Username: \${USERNAME}"
log_info "SSH Port: \${SSH_PORT}"
log_info "Primary IP: \${PRIMARY_IP}"

OS_VERSION=\$(cat /etc/os-release 2>/dev/null | grep "PRETTY_NAME" | cut -d'"' -f2 || echo "Unknown")
KERNEL_VERSION=\$(uname -r)
ARCHITECTURE=\$(uname -m)

PI_MODEL="Unknown"
if [[ -f /proc/device-tree/model ]]; then
  PI_MODEL=\$(cat /proc/device-tree/model | tr -d '\\0')
fi

PI_NAME="\${HOSTNAME}"

log_info "Registering with Control Center: ${controlCenterUrl}"

JSON_PAYLOAD=\$(cat <<JSONEOF
{
  "name": "\${PI_NAME}",
  "hostname": "\${HOSTNAME}",
  "ip": "\${PRIMARY_IP}",
  "port": \${SSH_PORT},
  "username": "\${USERNAME}",
  "metadata": {
    "os_version": "\${OS_VERSION}",
    "kernel_version": "\${KERNEL_VERSION}",
    "architecture": "\${ARCHITECTURE}",
    "model": "\${PI_MODEL}",
    "bootstrap_date": "\$(date -Iseconds)"
  }
}
JSONEOF
)

RESPONSE=\$(curl -s -X POST "${controlCenterUrl}/api/bootstrap/register" \\
  -H "Content-Type: application/json" \\
  -d "\${JSON_PAYLOAD}")

if echo "\${RESPONSE}" | grep -q '"success":true'; then
  ACTION=\$(echo "\${RESPONSE}" | grep -oP '(?<="action":")[^"]*' || echo "unknown")
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_success "Pi \${ACTION} successfully!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "📍 Name: \${PI_NAME}"
  echo "🌐 IP: \${PRIMARY_IP}:\${SSH_PORT}"
  echo "🎯 Control Center: ${controlCenterUrl}"
  echo ""
  log_info "Your Pi is now managed by the Control Center!"
  echo ""
  
  exit 0
else
  ERROR_MSG=\$(echo "\${RESPONSE}" | grep -oP '(?<="error":")[^"]*' || echo "Unknown error")
  log_error "Registration failed: \${ERROR_MSG}"
  log_error "Response: \${RESPONSE}"
  exit 1
fi
`;
}



module.exports = { registerBootstrapRoutes };
