// =============================================================================
// Updates Routes
// =============================================================================
// Handles checking and applying updates for Docker images, system packages, etc.
// =============================================================================

const { executeSSHCommand } = require('../ssh');

/**
 * Setup updates routes
 */
function setupUpdatesRoutes(app) {
    // Check Docker image updates
    app.get('/api/updates/docker', async (req, res) => {
        try {
            const piId = req.query.piId;

            // Get all running containers with their images
            const cmd = `docker ps --format '{{.Names}}|{{.Image}}'`;
            const result = await executeSSHCommand(cmd, piId);

            if (!result.success) {
                throw new Error(result.error || 'Failed to list containers');
            }

            const lines = result.stdout.trim().split('\n').filter(Boolean);
            const services = [];

            for (const line of lines) {
                const [container, image] = line.split('|');

                // Parse image (format: image:tag or image@digest)
                const [imageName, currentTag] = image.includes('@')
                    ? [image.split('@')[0], 'digest']
                    : image.includes(':')
                        ? image.split(':')
                        : [image, 'latest'];

                // Check for latest version on Docker Hub
                const latestVersion = await checkDockerImageLatest(imageName, currentTag, piId);

                services.push({
                    name: container,
                    container: container,
                    image: imageName,
                    currentVersion: currentTag,
                    latestVersion: latestVersion.tag,
                    updateAvailable: latestVersion.updateAvailable,
                    digest: latestVersion.digest
                });
            }

            res.json({ success: true, services });

        } catch (error) {
            console.error('Failed to check Docker updates:', error);
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    });

    // Update a Docker container
    app.post('/api/updates/docker/update', async (req, res) => {
        try {
            const { container, image } = req.body;
            const piId = req.body.piId;

            if (!container || !image) {
                return res.status(400).json({
                    success: false,
                    error: 'Container and image are required'
                });
            }

            // Get container info
            const inspectCmd = `docker inspect ${container} --format='{{json .}}'`;
            const inspectResult = await executeSSHCommand(inspectCmd, piId);

            if (!inspectResult.success) {
                throw new Error('Failed to inspect container');
            }

            const containerInfo = JSON.parse(inspectResult.stdout);
            const mounts = containerInfo[0].Mounts || [];
            const ports = containerInfo[0].NetworkSettings.Ports || {};
            const env = containerInfo[0].Config.Env || [];
            const networks = Object.keys(containerInfo[0].NetworkSettings.Networks || {});

            // Build docker run command with same configuration
            let runCmd = `docker run -d --name ${container}_new`;

            // Add environment variables
            env.forEach(e => {
                if (!e.startsWith('PATH=') && !e.startsWith('HOME=')) {
                    runCmd += ` -e "${e}"`;
                }
            });

            // Add port mappings
            Object.entries(ports).forEach(([containerPort, hostBindings]) => {
                if (hostBindings) {
                    hostBindings.forEach(binding => {
                        const hostPort = binding.HostPort;
                        runCmd += ` -p ${hostPort}:${containerPort.replace('/tcp', '')}`;
                    });
                }
            });

            // Add volume mounts
            mounts.forEach(mount => {
                if (mount.Type === 'volume') {
                    runCmd += ` -v ${mount.Name}:${mount.Destination}`;
                } else if (mount.Type === 'bind') {
                    runCmd += ` -v ${mount.Source}:${mount.Destination}`;
                }
            });

            // Add networks
            if (networks.length > 0) {
                runCmd += ` --network ${networks[0]}`;
            }

            // Add image
            runCmd += ` ${image}`;

            // Execute update: pull, stop old, start new, remove old
            const updateScript = `
                docker pull ${image} && \
                docker stop ${container} && \
                ${runCmd} && \
                docker rm ${container} && \
                docker rename ${container}_new ${container}
            `;

            const updateResult = await executeSSHCommand(updateScript, piId);

            if (!updateResult.success) {
                throw new Error(updateResult.error || 'Update failed');
            }

            res.json({
                success: true,
                message: `${container} updated to ${image}`
            });

        } catch (error) {
            console.error('Failed to update container:', error);
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    });

    // Check system (APT) updates
    app.get('/api/updates/system', async (req, res) => {
        try {
            const piId = req.query.piId;

            // Update package list and check for upgradable packages
            const cmd = 'sudo apt update > /dev/null 2>&1 && apt list --upgradable 2>/dev/null | grep -v "Listing"';
            const result = await executeSSHCommand(cmd, piId);

            const updates = result.stdout
                .trim()
                .split('\n')
                .filter(line => line && !line.startsWith('Listing'))
                .map(line => line.split('/')[0]); // Extract package name

            res.json({
                success: true,
                updates: updates.filter(Boolean),
                count: updates.length
            });

        } catch (error) {
            console.error('Failed to check system updates:', error);
            res.json({
                success: true,
                updates: [],
                count: 0
            });
        }
    });

    // Upgrade system packages
    app.post('/api/updates/system/upgrade', async (req, res) => {
        try {
            const piId = req.body.piId;

            // Run apt upgrade
            const cmd = 'sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y';
            const result = await executeSSHCommand(cmd, piId, 600000); // 10 min timeout

            res.json({
                success: result.success,
                output: result.stdout,
                error: result.error
            });

        } catch (error) {
            console.error('Failed to upgrade system:', error);
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    });
}

/**
 * Check if a Docker image has updates available
 */
async function checkDockerImageLatest(imageName, currentTag, piId) {
    try {
        // For images from Docker Hub
        if (!imageName.includes('/') || imageName.startsWith('library/')) {
            const cleanName = imageName.replace('library/', '');

            // Use docker CLI to check latest digest
            const cmd = `docker pull ${cleanName}:latest > /dev/null 2>&1 && docker inspect ${cleanName}:latest --format='{{.RepoDigests}}'`;
            const result = await executeSSHCommand(cmd, piId);

            if (result.success) {
                const latestDigest = result.stdout.match(/sha256:[a-f0-9]+/)?.[0];

                // Get current image digest
                const currentCmd = `docker inspect ${imageName}:${currentTag} --format='{{.RepoDigests}}'`;
                const currentResult = await executeSSHCommand(currentCmd, piId);
                const currentDigest = currentResult.stdout.match(/sha256:[a-f0-9]+/)?.[0];

                return {
                    tag: 'latest',
                    digest: latestDigest,
                    updateAvailable: latestDigest && currentDigest && latestDigest !== currentDigest
                };
            }
        }

        // For GitHub Container Registry or other registries
        if (imageName.startsWith('ghcr.io/')) {
            // Try to get latest tag from registry
            const cmd = `docker pull ${imageName}:latest > /dev/null 2>&1 && docker inspect ${imageName}:latest --format='{{.RepoDigests}}'`;
            const result = await executeSSHCommand(cmd, piId);

            if (result.success) {
                const latestDigest = result.stdout.match(/sha256:[a-f0-9]+/)?.[0];
                const currentCmd = `docker inspect ${imageName}:${currentTag} --format='{{.RepoDigests}}'`;
                const currentResult = await executeSSHCommand(currentCmd, piId);
                const currentDigest = currentResult.stdout.match(/sha256:[a-f0-9]+/)?.[0];

                return {
                    tag: 'latest',
                    digest: latestDigest,
                    updateAvailable: latestDigest && currentDigest && latestDigest !== currentDigest
                };
            }
        }

        // Fallback: assume no update if we can't check
        return {
            tag: currentTag,
            digest: null,
            updateAvailable: false
        };

    } catch (error) {
        console.error(`Failed to check updates for ${imageName}:`, error);
        return {
            tag: currentTag,
            digest: null,
            updateAvailable: false
        };
    }
}

module.exports = { setupUpdatesRoutes };
