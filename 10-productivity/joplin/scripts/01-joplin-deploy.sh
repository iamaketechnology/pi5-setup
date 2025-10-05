#!/usr/bin/env bash
# Joplin Server - Phase 17
# Serveur de notes synchronisées
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "${SCRIPT_DIR}/../../.." && pwd)/common-scripts/lib.sh"

STACK_DIR="${HOME}/stacks/joplin"
mkdir -p "${STACK_DIR}"

cat > "${STACK_DIR}/docker-compose.yml" <<'EOF'
version: '3.8'
services:
  db:
    image: postgres:15-alpine
    container_name: joplin-db
    environment:
      POSTGRES_DB: joplin
      POSTGRES_USER: joplin
      POSTGRES_PASSWORD: joplin
    volumes:
      - ./data:/var/lib/postgresql/data
    restart: unless-stopped

  joplin:
    image: joplin/server:latest
    container_name: joplin-server
    depends_on:
      - db
    ports:
      - "22300:22300"
    environment:
      APP_PORT: 22300
      APP_BASE_URL: http://raspberrypi.local:22300
      DB_CLIENT: pg
      POSTGRES_HOST: db
      POSTGRES_PORT: 5432
      POSTGRES_DATABASE: joplin
      POSTGRES_USER: joplin
      POSTGRES_PASSWORD: joplin
    restart: unless-stopped
EOF

docker-compose -f "${STACK_DIR}/docker-compose.yml" up -d
sleep 30
echo "✅ Joplin Server: http://raspberrypi.local:22300"
echo "   Email: admin@localhost | Pass: admin (changer!)"
