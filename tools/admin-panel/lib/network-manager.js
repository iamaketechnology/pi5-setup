// =============================================================================
// Network Manager - Network monitoring and maintenance
// =============================================================================
// Version: 1.0.0
// Author: PI5-SETUP Project
// =============================================================================

const piManager = require('./pi-manager');

/**
 * Get network interfaces and their stats
 */
async function getNetworkInterfaces(piId = null) {
    try {
        const ssh = await piManager.getSSH(piId);

        // Get interface info with ifconfig or ip addr
        const result = await ssh.execCommand('ip -j addr show');

        if (result.code !== 0) {
            throw new Error(`Failed to get interfaces: ${result.stderr}`);
        }

        const interfaces = JSON.parse(result.stdout);

        return interfaces.map(iface => ({
            name: iface.ifname,
            state: iface.operstate || 'unknown',
            mac: iface.address,
            mtu: iface.mtu,
            addresses: iface.addr_info
                .filter(addr => addr.family === 'inet' || addr.family === 'inet6')
                .map(addr => ({
                    ip: addr.local,
                    prefix: addr.prefixlen,
                    family: addr.family,
                    scope: addr.scope
                }))
        }));
    } catch (error) {
        console.error('Error getting network interfaces:', error);
        throw error;
    }
}

/**
 * Get bandwidth usage statistics
 */
async function getBandwidthStats(piId = null, interface = 'eth0') {
    try {
        const ssh = await piManager.getSSH(piId);

        // Read /sys/class/net stats
        const commands = [
            `cat /sys/class/net/${interface}/statistics/rx_bytes`,
            `cat /sys/class/net/${interface}/statistics/tx_bytes`,
            `cat /sys/class/net/${interface}/statistics/rx_packets`,
            `cat /sys/class/net/${interface}/statistics/tx_packets`,
            `cat /sys/class/net/${interface}/statistics/rx_errors`,
            `cat /sys/class/net/${interface}/statistics/tx_errors`
        ];

        const results = await Promise.all(
            commands.map(cmd => ssh.execCommand(cmd))
        );

        return {
            interface,
            rx_bytes: parseInt(results[0].stdout.trim()),
            tx_bytes: parseInt(results[1].stdout.trim()),
            rx_packets: parseInt(results[2].stdout.trim()),
            tx_packets: parseInt(results[3].stdout.trim()),
            rx_errors: parseInt(results[4].stdout.trim()),
            tx_errors: parseInt(results[5].stdout.trim()),
            timestamp: Date.now()
        };
    } catch (error) {
        console.error('Error getting bandwidth stats:', error);
        return null;
    }
}

/**
 * Get active network connections
 */
async function getActiveConnections(piId = null) {
    try {
        const ssh = await piManager.getSSH(piId);

        // Use ss command (modern replacement for netstat)
        const result = await ssh.execCommand('ss -tuln');

        if (result.code !== 0) {
            throw new Error(`Failed to get connections: ${result.stderr}`);
        }

        const lines = result.stdout.split('\n').slice(1); // Skip header
        const connections = [];

        for (const line of lines) {
            const parts = line.trim().split(/\s+/);
            if (parts.length >= 5) {
                connections.push({
                    protocol: parts[0],
                    state: parts[1],
                    recvQ: parts[2],
                    sendQ: parts[3],
                    localAddr: parts[4],
                    peerAddr: parts[5] || '-'
                });
            }
        }

        return connections;
    } catch (error) {
        console.error('Error getting active connections:', error);
        return [];
    }
}

/**
 * Get firewall (UFW) status and rules
 */
async function getFirewallStatus(piId = null) {
    try {
        const ssh = await piManager.getSSH(piId);

        // Get UFW status
        const statusResult = await ssh.execCommand('sudo ufw status verbose');

        if (statusResult.code !== 0) {
            return {
                enabled: false,
                rules: [],
                error: 'UFW not available or not installed'
            };
        }

        const output = statusResult.stdout;
        const enabled = output.includes('Status: active');

        // Parse rules
        const rules = [];
        const ruleLines = output.split('\n').filter(line =>
            line.includes('ALLOW') || line.includes('DENY') || line.includes('REJECT')
        );

        for (const line of ruleLines) {
            const match = line.match(/^(\d+)\s+(.+?)\s+(ALLOW|DENY|REJECT)\s+(.+?)$/);
            if (match) {
                rules.push({
                    number: match[1],
                    to: match[2].trim(),
                    action: match[3],
                    from: match[4].trim()
                });
            }
        }

        return {
            enabled,
            rules,
            defaultIncoming: output.match(/Default: deny \(incoming\)/) ? 'deny' : 'allow',
            defaultOutgoing: output.match(/Default: allow \(outgoing\)/) ? 'allow' : 'deny'
        };
    } catch (error) {
        console.error('Error getting firewall status:', error);
        return { enabled: false, rules: [], error: error.message };
    }
}

/**
 * Get public IP and geolocation
 */
async function getPublicIP(piId = null) {
    try {
        const ssh = await piManager.getSSH(piId);

        // Get public IP
        const ipResult = await ssh.execCommand('curl -s https://api.ipify.org');

        if (ipResult.code !== 0) {
            throw new Error('Failed to get public IP');
        }

        const publicIP = ipResult.stdout.trim();

        // Get geolocation (optional - using ipapi.co)
        const geoResult = await ssh.execCommand(`curl -s https://ipapi.co/${publicIP}/json/`);

        let location = null;
        if (geoResult.code === 0) {
            try {
                location = JSON.parse(geoResult.stdout);
            } catch (e) {
                console.error('Failed to parse geolocation:', e);
            }
        }

        return {
            ip: publicIP,
            location: location ? {
                country: location.country_name,
                region: location.region,
                city: location.city,
                isp: location.org,
                timezone: location.timezone
            } : null
        };
    } catch (error) {
        console.error('Error getting public IP:', error);
        return null;
    }
}

/**
 * Test network connectivity (ping)
 */
async function testPing(piId = null, host = '8.8.8.8', count = 4) {
    try {
        const ssh = await piManager.getSSH(piId);

        const result = await ssh.execCommand(`ping -c ${count} -W 2 ${host}`);

        // Parse ping output
        const lines = result.stdout.split('\n');
        const statsLine = lines.find(l => l.includes('packets transmitted'));
        const rttLine = lines.find(l => l.includes('rtt min/avg/max'));

        let stats = null;
        if (statsLine) {
            const match = statsLine.match(/(\d+) packets transmitted, (\d+) received, ([\d.]+)% packet loss/);
            if (match) {
                stats = {
                    transmitted: parseInt(match[1]),
                    received: parseInt(match[2]),
                    loss: parseFloat(match[3])
                };
            }
        }

        let rtt = null;
        if (rttLine) {
            const match = rttLine.match(/rtt min\/avg\/max\/mdev = ([\d.]+)\/([\d.]+)\/([\d.]+)\/([\d.]+)/);
            if (match) {
                rtt = {
                    min: parseFloat(match[1]),
                    avg: parseFloat(match[2]),
                    max: parseFloat(match[3]),
                    mdev: parseFloat(match[4])
                };
            }
        }

        return {
            host,
            success: result.code === 0,
            stats,
            rtt,
            output: result.stdout
        };
    } catch (error) {
        console.error('Error testing ping:', error);
        return { host, success: false, error: error.message };
    }
}

/**
 * Get DNS resolution info
 */
async function testDNS(piId = null, domain = 'google.com') {
    try {
        const ssh = await piManager.getSSH(piId);

        const result = await ssh.execCommand(`nslookup ${domain}`);

        return {
            domain,
            success: result.code === 0,
            output: result.stdout,
            error: result.stderr
        };
    } catch (error) {
        console.error('Error testing DNS:', error);
        return { domain, success: false, error: error.message };
    }
}

/**
 * Get listening ports grouped by service
 */
async function getListeningPorts(piId = null) {
    try {
        const ssh = await piManager.getSSH(piId);

        // Get listening ports with process info
        const result = await ssh.execCommand('sudo ss -tulpn');

        if (result.code !== 0) {
            throw new Error('Failed to get listening ports');
        }

        const lines = result.stdout.split('\n').slice(1);
        const ports = [];

        for (const line of lines) {
            const match = line.match(/^(\w+)\s+\S+\s+\S+\s+\S+\s+([\d.:*]+):(\d+)\s+.*?users:\(\("([^"]+)"/);
            if (match) {
                ports.push({
                    protocol: match[1],
                    address: match[2],
                    port: parseInt(match[3]),
                    process: match[4]
                });
            }
        }

        // Group by process
        const grouped = {};
        for (const port of ports) {
            if (!grouped[port.process]) {
                grouped[port.process] = [];
            }
            grouped[port.process].push(port);
        }

        return grouped;
    } catch (error) {
        console.error('Error getting listening ports:', error);
        return {};
    }
}

module.exports = {
    getNetworkInterfaces,
    getBandwidthStats,
    getActiveConnections,
    getFirewallStatus,
    getPublicIP,
    testPing,
    testDNS,
    getListeningPorts
};
