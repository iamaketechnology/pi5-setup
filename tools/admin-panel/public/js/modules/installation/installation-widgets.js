/**
 * Installation Widgets Module
 * Manages the stats widgets at the top of the Installation tab
 */

export class InstallationWidgets {
    constructor(diagnostics, terminalModule) {
        this.diagnostics = diagnostics;
        this.terminalModule = terminalModule;
    }

    /**
     * Load and update all widgets
     */
    async load() {
        try {
            const piId = window.currentPiId || null;

            // If no Pi selected, show placeholder values
            if (!piId) {
                this.updateWidget('widget-docker-value', '—');
                this.updateWidget('widget-services-value', '—');
                this.updateWidget('widget-disk-value', '—');
                this.updateWidget('widget-updates-value', '0');
                return;
            }

            // Load Docker containers count
            const dockerResponse = await fetch(`/api/docker/containers?piId=${piId}`);
            if (!dockerResponse.ok) {
                throw new Error(`Docker API error: ${dockerResponse.status}`);
            }
            const dockerData = await dockerResponse.json();
            const runningContainers = dockerData.containers?.filter(c => c.State === 'running').length || 0;
            this.updateWidget('widget-docker-value', runningContainers);

            // Load installed services count (from Docker)
            const totalServices = dockerData.containers?.length || 0;
            this.updateWidget('widget-services-value', totalServices);

            // Load disk space
            const diskResponse = await fetch(`/api/system/stats?piId=${piId}`);
            if (diskResponse.ok) {
                const diskData = await diskResponse.json();
                const diskFree = diskData.disk?.available || '—';
                this.updateWidget('widget-disk-value', diskFree);

                // Send intelligent suggestions to terminal AI
                await this.sendDiagnostics(totalServices, diskFree);
            } else {
                this.updateWidget('widget-disk-value', '—');
            }

            // Load updates count
            await this.loadUpdatesCount(totalServices);

        } catch (error) {
            console.error('Failed to load installation widgets:', error);
        }
    }

    /**
     * Update a widget value
     */
    updateWidget(elementId, value) {
        const element = document.getElementById(elementId);
        if (element) {
            element.textContent = value;
        }
    }

    /**
     * Load updates count
     */
    async loadUpdatesCount(totalServices) {
        if (window.updatesManager && window.updatesManager.services) {
            const updatesAvailable = window.updatesManager.services.filter(s => s.updateAvailable).length;

            // Update widgets
            this.updateWidget('widget-updates-value', updatesAvailable);
            this.updateWidget('updates-count', updatesAvailable);
            this.updateWidget('updates-count-main', updatesAvailable);

            // Get disk space for diagnostics
            const diskFree = document.getElementById('widget-disk-value')?.textContent || '—';
            await this.sendDiagnostics(totalServices, diskFree, updatesAvailable);
        } else {
            this.updateWidget('widget-updates-value', '0');
        }
    }

    /**
     * Send diagnostics to terminal AI
     */
    async sendDiagnostics(totalServices, diskFree, updatesAvailable = 0) {
        const messages = this.diagnostics.analyze(updatesAvailable, totalServices, diskFree);
        if (messages && this.terminalModule) {
            this.terminalModule.displaySuggestions(messages);
        }
    }
}
