function registerSocketEvents(io, piManager) {
  io.on('connection', (socket) => {
    console.log('🔌 Client connected:', socket.id);

    socket.on('disconnect', () => {
      console.log('🔌 Client disconnected:', socket.id);
    });

    socket.on('test-connection', async () => {
      try {
        const currentPi = piManager.getCurrentPi();
        const piConfig = piManager.getCurrentPiConfig();
        const ssh = await piManager.getSSH();

        socket.emit('connection-status', {
          connected: ssh.isConnected(),
          host: piConfig.host,
          piId: currentPi,
          piName: piConfig.name
        });
      } catch (error) {
        socket.emit('connection-status', {
          connected: false,
          error: error.message
        });
      }
    });
  });
}

module.exports = {
  registerSocketEvents
};
