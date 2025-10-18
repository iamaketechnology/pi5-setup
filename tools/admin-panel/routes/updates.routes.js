// =============================================================================
// Updates Routes
// =============================================================================
// Handles checking and applying updates for Docker images, system packages, etc.
// =============================================================================

/**
 * Check if a Docker image MIGHT have updates available
 * FAST check - just based on tag naming, no network calls
 */
function checkUpdatePossible(currentTag) {
    // If using :latest or generic tags, updates might be available
    const genericTags = ['latest', 'stable', 'main', 'master', 'production', 'prod'];
    const isGeneric = genericTags.includes(currentTag.toLowerCase());

    // If using specific version (semver-like), probably pinned intentionally
    const hasVersion = /^\d+(\.\d+)*/.test(currentTag);

    return {
        tag: currentTag,
        digest: null,
        updateAvailable: isGeneric, // Only suggest update for generic tags
        isPinned: hasVersion
    };
}

/**
 * Check if a Docker image has updates available (ACCURATE but SLOW)
 * Uses docker pull to compare digests - can take several minutes
 */
async function checkDockerImageLatestAccurate(imageName, currentTag, piId, piManager) {
    try {
        // For images from Docker Hub
        if (!imageName.includes('/') || imageName.startsWith('library/')) {
            const cleanName = imageName.replace('library/', '');

            // Use docker CLI to check latest digest
            const cmd = `docker pull ${cleanName}:latest > /dev/null 2>&1 && docker inspect ${cleanName}:latest --format='{{.RepoDigests}}'`;
            const result = await piManager.executeCommand(cmd, piId);

            if (result.code === 0) {
                const latestDigest = result.stdout.match(/sha256:[a-f0-9]+/)?.[0];

                // Get current image digest
                const currentCmd = `docker inspect ${imageName}:${currentTag} --format='{{.RepoDigests}}'`;
                const currentResult = await piManager.executeCommand(currentCmd, piId);
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
            const result = await piManager.executeCommand(cmd, piId);

            if (result.code === 0) {
                const latestDigest = result.stdout.match(/sha256:[a-f0-9]+/)?.[0];
                const currentCmd = `docker inspect ${imageName}:${currentTag} --format='{{.RepoDigests}}'`;
                const currentResult = await piManager.executeCommand(currentCmd, piId);
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

function registerUpdatesRoutes({ app, piManager, middlewares }) {
    const { authOnly, adminOnly } = middlewares;

    // Check Docker image updates
    app.get('/api/updates/docker', ...authOnly, async (req, res) => {
        try {
            const { piId, mode = 'fast' } = req.query; // mode: 'fast' or 'accurate'

            // Get all running containers with their images
            const cmd = `docker ps --format '{{.Names}}|{{.Image}}'`;
            const result = await piManager.executeCommand(cmd, piId);

            if (result.code !== 0) {
                throw new Error(result.stderr || 'Failed to list containers');
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

                let updateInfo;
                if (mode === 'accurate') {
                    // ACCURATE mode: docker pull + digest comparison (SLOW)
                    updateInfo = await checkDockerImageLatestAccurate(imageName, currentTag, piId, piManager);
                } else {
                    // FAST mode: tag-based heuristic (instant)
                    updateInfo = checkUpdatePossible(currentTag);
                }

                services.push({
                    name: container,
                    container: container,
                    image: imageName,
                    currentVersion: currentTag,
                    latestVersion: mode === 'accurate' ? updateInfo.tag : 'latest',
                    updateAvailable: updateInfo.updateAvailable,
                    isPinned: updateInfo.isPinned || false,
                    digest: updateInfo.digest,
                    mode: mode // Return which mode was used
                });
            }

            res.json({ success: true, services, mode });

        } catch (error) {
            console.error('Failed to check Docker updates:', error);
            res.status(500).json({
                success: false,
                error: error.message
            });
        }
    });

    // Update a Docker container
    app.post('/api/updates/docker/update', ...adminOnly, async (req, res) => {
        try {
            const { container, image, piId } = req.body;

            if (!container || !image) {
                return res.status(400).json({
                    success: false,
                    error: 'Container and image are required'
                });
            }

            // Get container info
            const inspectCmd = `docker inspect ${container} --format='{{json .}}'`;
            const inspectResult = await piManager.executeCommand(inspectCmd, piId);

            if (inspectResult.code !== 0) {
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
                docker pull ${image} && \\
                docker stop ${container} && \\
                ${runCmd} && \\
                docker rm ${container} && \\
                docker rename ${container}_new ${container}
            `;

            const updateResult = await piManager.executeCommand(updateScript, piId);

            if (updateResult.code !== 0) {
                throw new Error(updateResult.stderr || 'Update failed');
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
    app.get('/api/updates/system', ...authOnly, async (req, res) => {
        try {
            const { piId } = req.query;

            // Update package list and check for upgradable packages
            const cmd = 'sudo apt update > /dev/null 2>&1 && apt list --upgradable 2>/dev/null | grep -v "Listing"';
            const result = await piManager.executeCommand(cmd, piId);

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
    app.post('/api/updates/system/upgrade', ...adminOnly, async (req, res) => {
        try {
            const { piId } = req.body;

            // Run apt upgrade
            const cmd = 'sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y';
            const result = await piManager.executeCommand(cmd, piId, { timeout: 600000 }); // 10 min timeout

            res.json({
                success: result.code === 0,
                output: result.stdout,
                error: result.stderr
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

module.exports = { registerUpdatesRoutes };
