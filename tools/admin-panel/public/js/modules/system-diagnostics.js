/**
 * System Diagnostics Module
 * Intelligent analysis of Pi system health
 */

class SystemDiagnostics {
    constructor() {
        this.lastDiagnosticHash = null;
        this.thresholds = {
            disk: {
                critical: 5,  // GB
                warning: 10,
                low: 20
            },
            updates: {
                critical: 5,
                warning: 3
            },
            services: {
                good: 5
            }
        };
    }

    /**
     * Generate intelligent diagnostic messages
     * @param {number} updatesCount - Number of available updates
     * @param {number} servicesCount - Number of running services
     * @param {string} diskFree - Free disk space (e.g., "45.2 GB")
     * @returns {Array|null} Array of diagnostic messages or null if unchanged
     */
    analyze(updatesCount, servicesCount, diskFree) {
        // Create hash to detect state changes
        const currentHash = `${updatesCount}-${servicesCount}-${diskFree}`;

        // Skip if state hasn't changed
        if (this.lastDiagnosticHash === currentHash) {
            console.log('📊 System state unchanged, keeping current diagnostics');
            return null;
        }

        this.lastDiagnosticHash = currentHash;

        const messages = [];

        // 1. Overall health diagnostic (always first)
        messages.push(this.generateHealthDiagnostic(updatesCount, servicesCount, diskFree));

        // 2. Critical updates warning
        if (updatesCount >= this.thresholds.updates.critical) {
            messages.push({
                type: 'warning',
                icon: 'alert-triangle',
                title: `${updatesCount} mises à jour disponibles`,
                text: 'Des mises à jour importantes sont disponibles. Je recommande de les installer pour maintenir votre système sécurisé.',
                actions: [{
                    label: 'Voir les détails',
                    category: 'updates-docker'
                }]
            });
        } else if (updatesCount > 0) {
            messages.push({
                type: 'info',
                icon: 'info',
                title: `${updatesCount} mise${updatesCount > 1 ? 's' : ''} à jour`,
                text: 'Quelques mises à jour sont disponibles. Vous pouvez les appliquer quand vous le souhaitez.',
                actions: [{
                    label: 'Voir',
                    category: 'updates-docker'
                }]
            });
        } else if (servicesCount > 0) {
            // Only show "up to date" if there are services
            messages.push({
                type: 'success',
                icon: 'check-circle',
                title: 'Système à jour',
                text: `Tous vos ${servicesCount} services sont à jour ! 🎉`,
                actions: []
            });
        }

        // 3. Disk space warnings
        const diskWarning = this.analyzeDiskSpace(diskFree);
        if (diskWarning) {
            messages.push(diskWarning);
        }

        // 4. No services warning
        if (servicesCount === 0) {
            messages.push({
                type: 'info',
                icon: 'package-plus',
                title: 'Aucun service installé',
                text: 'Commencez par installer des services depuis les catégories à gauche.',
                actions: [{
                    label: 'Infrastructure',
                    category: 'infrastructure'
                }]
            });
        }

        return messages;
    }

    /**
     * Generate overall health diagnostic message
     */
    generateHealthDiagnostic(updatesCount, servicesCount, diskFree) {
        const diagnostics = [];
        let healthScore = 100;

        // Analyze services
        const servicesAnalysis = this.analyzeServices(servicesCount);
        diagnostics.push(servicesAnalysis.text);
        healthScore += servicesAnalysis.scoreImpact;

        // Analyze updates
        const updatesAnalysis = this.analyzeUpdates(updatesCount);
        diagnostics.push(updatesAnalysis.text);
        healthScore += updatesAnalysis.scoreImpact;

        // Analyze disk space
        const diskAnalysis = this.analyzeDisk(diskFree);
        diagnostics.push(diskAnalysis.text);
        healthScore += diskAnalysis.scoreImpact;

        // Calculate final health score
        healthScore = Math.max(0, Math.min(100, healthScore));
        const health = this.getHealthLevel(healthScore);

        return {
            type: 'info',
            icon: 'activity',
            title: '🤖 Diagnostic du système',
            text: `**Santé : ${health.emoji} ${healthScore}/100 (${health.text})**\n\n${diagnostics.join(' • ')}`,
            actions: []
        };
    }

    /**
     * Analyze services count
     */
    analyzeServices(count) {
        if (count === 0) {
            return {
                text: '⚠️ Aucun service détecté',
                scoreImpact: -30
            };
        } else if (count < this.thresholds.services.good) {
            return {
                text: `✅ ${count} service${count > 1 ? 's' : ''} actif${count > 1 ? 's' : ''}`,
                scoreImpact: 0
            };
        } else {
            return {
                text: `✅ ${count} services actifs (bon déploiement)`,
                scoreImpact: 10
            };
        }
    }

    /**
     * Analyze updates count
     */
    analyzeUpdates(count) {
        if (count === 0) {
            return {
                text: '✅ Système à jour',
                scoreImpact: 10
            };
        } else if (count < this.thresholds.updates.warning) {
            return {
                text: `⚠️ ${count} mise${count > 1 ? 's' : ''} à jour`,
                scoreImpact: -5
            };
        } else if (count < this.thresholds.updates.critical) {
            return {
                text: `⚠️ ${count} mises à jour (à planifier)`,
                scoreImpact: -15
            };
        } else {
            return {
                text: `🚨 ${count} mises à jour critiques`,
                scoreImpact: -30
            };
        }
    }

    /**
     * Analyze disk space
     */
    analyzeDisk(diskFree) {
        if (!diskFree || diskFree === '—') {
            return {
                text: '⚠️ Espace disque inconnu',
                scoreImpact: 0
            };
        }

        const diskValue = parseFloat(diskFree);

        if (diskValue < this.thresholds.disk.critical) {
            return {
                text: '🚨 Espace disque critique',
                scoreImpact: -40
            };
        } else if (diskValue < this.thresholds.disk.warning) {
            return {
                text: '⚠️ Espace disque faible',
                scoreImpact: -20
            };
        } else if (diskValue < this.thresholds.disk.low) {
            return {
                text: `✅ ${diskFree} disponible`,
                scoreImpact: 0
            };
        } else {
            return {
                text: `✅ ${diskFree} disponible (excellent)`,
                scoreImpact: 10
            };
        }
    }

    /**
     * Analyze disk space for warning message
     */
    analyzeDiskSpace(diskFree) {
        if (!diskFree || diskFree === '—') {
            return null;
        }

        const diskValue = parseFloat(diskFree);

        if (diskValue < this.thresholds.disk.critical) {
            return {
                type: 'warning',
                icon: 'hard-drive',
                title: 'Espace disque critique',
                text: `Seulement ${diskFree} disponible ! Nettoyage urgent requis avec \`docker system prune\`.`,
                actions: [{
                    label: 'Nettoyer Docker',
                    command: 'docker system prune -a'
                }]
            };
        } else if (diskValue < this.thresholds.disk.warning) {
            return {
                type: 'warning',
                icon: 'hard-drive',
                title: 'Espace disque faible',
                text: `Il ne reste que ${diskFree} disponible. Pensez à nettoyer Docker avec \`docker system prune\`.`,
                actions: [{
                    label: 'Nettoyer Docker',
                    command: 'docker system prune -a'
                }]
            };
        }

        return null;
    }

    /**
     * Get health level based on score
     */
    getHealthLevel(score) {
        if (score < 50) {
            return { emoji: '🔴', text: 'Critique' };
        } else if (score < 70) {
            return { emoji: '🟠', text: 'Attention requise' };
        } else if (score < 85) {
            return { emoji: '🟡', text: 'Bon' };
        } else {
            return { emoji: '🟢', text: 'Excellent' };
        }
    }

    /**
     * Update thresholds dynamically
     */
    updateThresholds(newThresholds) {
        this.thresholds = { ...this.thresholds, ...newThresholds };
    }

    /**
     * Reset diagnostic cache (force re-analysis)
     */
    reset() {
        this.lastDiagnosticHash = null;
    }
}

// Export for use in other modules
if (typeof window !== 'undefined') {
    window.SystemDiagnostics = SystemDiagnostics;
}
