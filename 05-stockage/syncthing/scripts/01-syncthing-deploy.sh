#!/usr/bin/env bash
# Syncthing - Phase 18
# Synchronisation fichiers P2P
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "${SCRIPT_DIR}/../../.." && pwd)/common-scripts/lib.sh"

STACK_DIR="${HOME}/stacks/syncthing"
mkdir -p "${STACK_DIR}" "${HOME}/data/sync"

cat > "${STACK_DIR}/docker-compose.yml" <<'EOF'
version: '3.8'
services:
  syncthing:
    image: lscr.io/linuxserver/syncthing:latest
    container_name: syncthing
    hostname: raspberrypi
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Paris
    volumes:
      - ./config:/config
      - ~/data/sync:/data/sync
    ports:
      - "8384:8384"   # WebUI
      - "22000:22000/tcp"  # Sync
      - "22000:22000/udp"
      - "21027:21027/udp"  # Discovery
    restart: unless-stopped
EOF

docker-compose -f "${STACK_DIR}/docker-compose.yml" up -d
sleep 20
echo "✅ Syncthing: http://raspberrypi.local:8384"
echo "   Dossier sync: ${HOME}/data/sync"
