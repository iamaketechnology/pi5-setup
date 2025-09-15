#!/bin/bash

# Debug YAML - tester les variables Docker
POSTGRES_VERSION="15-alpine"
GOTRUE_VERSION="v2.177.0"
POSTGREST_VERSION="v12.2.0"

echo "Testing YAML generation..."

cat > test-compose.yml << COMPOSE
services:
  db:
    container_name: supabase-db
    image: postgres:${POSTGRES_VERSION}
    platform: linux/arm64
    restart: unless-stopped
    command:
      - "postgres"
      - "-c"
      - "config_file=/etc/postgresql/postgresql.conf"
COMPOSE

echo "Generated YAML:"
cat test-compose.yml

echo ""
echo "YAML validation:"
docker-compose -f test-compose.yml config || echo "YAML Error detected"