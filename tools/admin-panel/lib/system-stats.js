function createSystemStats(piManager, db) {
  return async function getSystemStats(piId = null) {
    try {
      const targetPi = piId || piManager.getCurrentPi();
      const piConfig = piManager.getPiConfig(targetPi);

      const [cpu, mem, temp, disk, uptime, dockerStats] = await Promise.all([
        piManager.executeCommand("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1", targetPi),
        piManager.executeCommand("free -m | awk 'NR==2{printf \"%.0f/%.0f/%.0f\", $3,$2,($3/$2)*100}'", targetPi),
        piManager.executeCommand("vcgencmd measure_temp | cut -d'=' -f2 | cut -d\"'\" -f1", targetPi),
        piManager.executeCommand("df -h / | awk 'NR==2{printf \"%s/%s/%s\", $3,$2,$5}'", targetPi),
        piManager.executeCommand("uptime -p", targetPi),
        piManager.executeCommand("docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}' 2>/dev/null || echo ''", targetPi)
      ]);

      const memParts = mem.stdout.split('/');
      const memUsed = parseInt(memParts[0]) || 0;
      const memTotal = parseInt(memParts[1]) || 0;
      const memPercent = parseInt(memParts[2]) || 0;

      const diskParts = disk.stdout.split('/');
      const diskUsed = diskParts[0] || '0G';
      const diskTotal = diskParts[1] || '0G';
      const diskPercent = parseInt(diskParts[2]) || 0;

      const dockerContainers = dockerStats.stdout
        .split('\n')
        .filter(Boolean)
        .map(line => {
          const [name, cpu, mem] = line.split('\t');
          return { name, cpu, mem };
        });

      const stats = {
        cpu: parseFloat(cpu.stdout) || 0,
        memory: {
          used: memUsed,
          total: memTotal,
          percent: memPercent
        },
        temperature: parseFloat(temp.stdout) || 0,
        disk: {
          used: diskUsed,
          total: diskTotal,
          percent: diskPercent
        },
        uptime: uptime.stdout.replace('up ', ''),
        docker: dockerContainers,
        piId: targetPi,
        piName: piConfig.name
      };

      db.saveStatsHistory(targetPi, stats);

      return stats;
    } catch (error) {
      console.error('Error fetching system stats:', error.message);
      return {
        cpu: 0,
        memory: { used: 0, total: 0, percent: 0 },
        temperature: 0,
        disk: { used: '0G', total: '0G', percent: 0 },
        uptime: 'unknown',
        docker: [],
        error: error.message
      };
    }
  };
}

module.exports = {
  createSystemStats
};
