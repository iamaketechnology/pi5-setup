#!/usr/bin/env bash
set -euo pipefail

# Script d'installation Portainer pour Raspberry Pi 5
# Gestion Docker via interface web

STACK_DIR="/home/pi/stacks/portainer"

echo "🎛️  Installation Portainer - Gestion Docker via Web UI"
echo ""

# Créer répertoire stack
mkdir -p "$STACK_DIR"

# Détecter scénario Traefik
TRAEFIK_SCENARIO="none"
TRAEFIK_ENV="/home/pi/stacks/traefik/.env"

if [[ -f "$TRAEFIK_ENV" ]]; then
    if grep -q "DUCKDNS_SUBDOMAIN" "$TRAEFIK_ENV"; then
        TRAEFIK_SCENARIO="duckdns"
        SUBDOMAIN=$(grep DUCKDNS_SUBDOMAIN "$TRAEFIK_ENV" | cut -d'=' -f2)
        PORTAINER_URL="https://${SUBDOMAIN}.duckdns.org/portainer"
    elif grep -q "CLOUDFLARE_API_TOKEN" "$TRAEFIK_ENV"; then
        TRAEFIK_SCENARIO="cloudflare"
        DOMAIN=$(grep DOMAIN "$TRAEFIK_ENV" | grep -v DUCKDNS | cut -d'=' -f2)
        PORTAINER_URL="https://portainer.${DOMAIN}"
    else
        TRAEFIK_SCENARIO="vpn"
        PORTAINER_URL="https://portainer.pi.local"
    fi
fi

# Générer docker-compose.yml
cat > "$STACK_DIR/docker-compose.yml" <<EOF
version: '3.8'

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    command: -H unix:///var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
EOF

if [[ "$TRAEFIK_SCENARIO" != "none" ]]; then
    cat >> "$STACK_DIR/docker-compose.yml" <<EOF
    labels:
      - "traefik.enable=true"
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"
EOF

    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]]; then
        cat >> "$STACK_DIR/docker-compose.yml" <<EOF
      - "traefik.http.routers.portainer.rule=PathPrefix(\`/portainer\`)"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"
      - "traefik.http.middlewares.portainer-stripprefix.stripprefix.prefixes=/portainer"
      - "traefik.http.routers.portainer.middlewares=portainer-stripprefix"
EOF
    elif [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        cat >> "$STACK_DIR/docker-compose.yml" <<EOF
      - "traefik.http.routers.portainer.rule=Host(\`portainer.${DOMAIN}\`)"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.tls.certresolver=cloudflare"
EOF
    else # VPN
        cat >> "$STACK_DIR/docker-compose.yml" <<EOF
      - "traefik.http.routers.portainer.rule=Host(\`portainer.pi.local\`)"
      - "traefik.http.routers.portainer.entrypoints=web"
EOF
    fi

    cat >> "$STACK_DIR/docker-compose.yml" <<EOF
    networks:
      - traefik-network
EOF
else
    # Sans Traefik, exposer port 9000
    cat >> "$STACK_DIR/docker-compose.yml" <<EOF
    ports:
      - "9000:9000"
EOF
fi

cat >> "$STACK_DIR/docker-compose.yml" <<EOF

volumes:
  portainer_data:
    driver: local
EOF

if [[ "$TRAEFIK_SCENARIO" != "none" ]]; then
    cat >> "$STACK_DIR/docker-compose.yml" <<EOF

networks:
  traefik-network:
    external: true
EOF
fi

# Démarrer Portainer
cd "$STACK_DIR"
docker compose up -d

echo ""
echo "✅ Portainer déployé avec succès !"
echo ""
echo "📊 Accès Portainer :"

if [[ "$TRAEFIK_SCENARIO" != "none" ]]; then
    echo "  URL : $PORTAINER_URL"
else
    IP=$(hostname -I | awk '{print $1}')
    echo "  URL : http://${IP}:9000"
fi

echo ""
echo "🔑 Première connexion :"
echo "  1. Ouvrir l'URL ci-dessus"
echo "  2. Créer compte admin (user + password)"
echo "  3. Sélectionner 'Docker' → 'Connect'"
echo ""
echo "🎛️  Fonctionnalités :"
echo "  - Start/Stop conteneurs en 1 clic"
echo "  - Voir RAM/CPU en temps réel"
echo "  - Gérer stacks Docker Compose"
echo "  - Logs intégrés"
echo "  - Terminal dans conteneurs"
echo ""
echo "💡 Astuce : Créer des stacks dans Portainer pour démarrer/arrêter"
echo "   plusieurs services ensemble (ex: stack 'Développement' avec Supabase + Gitea)"
echo ""
