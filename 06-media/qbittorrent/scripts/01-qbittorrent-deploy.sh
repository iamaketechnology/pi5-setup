#!/usr/bin/env bash
# qBittorrent - Phase 16
# Client torrent avec WebUI
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "${SCRIPT_DIR}/../../.." && pwd)/common-scripts/lib.sh"

STACK_DIR="${HOME}/stacks/qbittorrent"
mkdir -p "${STACK_DIR}" "${HOME}/data/torrents"/{downloads,watch}

cat > "${STACK_DIR}/docker-compose.yml" <<'EOF'
version: '3.8'
services:
  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Paris
      - WEBUI_PORT=8080
    volumes:
      - ./config:/config
      - ~/data/torrents:/data/torrents
    ports:
      - "8080:8080"
      - "6881:6881"
      - "6881:6881/udp"
    restart: unless-stopped
EOF

docker-compose -f "${STACK_DIR}/docker-compose.yml" up -d
sleep 20
echo "✅ qBittorrent: http://raspberrypi.local:8080"
echo "   User: admin | Pass: adminadmin (changer!)"
