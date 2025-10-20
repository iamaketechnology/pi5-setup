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

    // Capture all events to handle dynamic shell-input-* events
    socket.onAny((eventName, ...args) => {
      // Match shell-input-{executionId} events
      if (eventName.startsWith('shell-input-')) {
        const executionId = eventName.replace('shell-input-', '');
        const input = args[0] || '';
        console.log(`[WEBSOCKET] Received ${eventName}, dispatching to execution ${executionId}`);
        piManager.dispatchShellInput(executionId, input);
      }
    });
  });
}

module.exports = {
  registerSocketEvents
};
