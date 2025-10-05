#!/usr/bin/env bash
# Calibre-Web - Phase 19
# Bibliothèque ebooks
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "${SCRIPT_DIR}/../../.." && pwd)/common-scripts/lib.sh"

STACK_DIR="${HOME}/stacks/calibre-web"
mkdir -p "${STACK_DIR}" "${HOME}/data/books"

cat > "${STACK_DIR}/docker-compose.yml" <<'EOF'
version: '3.8'
services:
  calibre-web:
    image: lscr.io/linuxserver/calibre-web:latest
    container_name: calibre-web
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Paris
    volumes:
      - ./config:/config
      - ~/data/books:/books
    ports:
      - "8083:8083"
    restart: unless-stopped
EOF

docker-compose -f "${STACK_DIR}/docker-compose.yml" up -d
sleep 20
echo "✅ Calibre-Web: http://raspberrypi.local:8083"
echo "   User: admin | Pass: admin123"
echo "   Bibliothèque: ${HOME}/data/books"
