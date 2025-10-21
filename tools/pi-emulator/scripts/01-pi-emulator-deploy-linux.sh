#!/bin/bash
# =============================================================================
# Pi Emulator Deploy - Linux
# =============================================================================
# Version: 2.0.0
# Last updated: 2025-10-20
# Author: PI5-SETUP Project
# Usage: bash 01-pi-emulator-deploy-linux.sh
# =============================================================================

set -euo pipefail

# Logging inline
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# Variables
# Support SSH piping (BASH_SOURCE non disponible)
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
    EMULATOR_DIR="${PROJECT_ROOT}/tools/pi-emulator"
else
    # Mode SSH pipe - créer structure localement
    EMULATOR_DIR="${HOME}/pi-emulator-temp"
    mkdir -p "${EMULATOR_DIR}/compose"
fi
COMPOSE_FILE="${EMULATOR_DIR}/compose/docker-compose.yml"

log_info "Pi Emulator Deploy - Linux"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Vérifier et installer Docker si nécessaire
if ! command -v docker &> /dev/null; then
    log_warning "Docker non installé. Installation automatique..."

    # Installer Docker
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh

    # Ajouter user au groupe docker
    CURRENT_USER="${SUDO_USER:-$(whoami)}"
    usermod -aG docker "${CURRENT_USER}"

    log_success "Docker installé"
    log_warning "Redémarrer la session pour appliquer les permissions Docker"

    # Tester si docker fonctionne
    if ! docker ps &> /dev/null; then
        log_error "Docker installé mais permissions insuffisantes"
        log_info "Lance: newgrp docker"
        exit 1
    fi
else
    log_success "Docker déjà installé"
fi

# Vérifier Docker Compose
if ! docker compose version &> /dev/null; then
    log_error "Docker Compose V2 non disponible"
    log_info "Mise à jour de Docker recommandée"
    exit 1
fi

# Créer docker-compose.yml si mode SSH pipe
if [[ ! -f "${COMPOSE_FILE}" ]]; then
    log_info "Création du fichier docker-compose.yml..."
    cat > "${COMPOSE_FILE}" <<'COMPOSE_EOF'
services:
  pi-emulator:
    image: debian:bookworm-slim
    container_name: pi-emulator-test
    hostname: raspberrypi
    privileged: true
    restart: unless-stopped

    ports:
      - "2222:22"
      - "8080:80"
      - "8443:443"
      - "5432:5432"
      - "8000:8000"
      - "9000:9000"
      - "3000:3000"
      - "8001:8001"

    volumes:
      - pi-home:/home/pi
      - pi-docker:/var/lib/docker

    environment:
      - DEBIAN_FRONTEND=noninteractive
      - TZ=Europe/Paris

    command: >
      bash -c "
        apt-get update &&
        apt-get install -y openssh-server sudo docker.io docker-compose curl wget git nano gpg ufw ca-certificates gnupg lsb-release apt-transport-https software-properties-common openssl htop net-tools iputils-ping &&

        useradd -m -s /bin/bash -G sudo pi &&
        echo 'pi:raspberry' | chpasswd &&
        echo 'pi ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/pi &&

        mkdir -p /home/pi/stacks /home/pi/.ssh /root/stacks /root/backups /root/logs &&
        chown -R pi:pi /home/pi &&

        mkdir -p /run/sshd &&
        sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config &&
        sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config &&

        service ssh start &&
        service docker start &&

        mkdir -p /usr/local/lib/docker/cli-plugins &&
        curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose &&
        chmod +x /usr/local/lib/docker/cli-plugins/docker-compose &&

        echo '✅ Pi Emulator ready!' &&
        echo 'SSH: ssh pi@localhost -p 2222 (password: raspberry)' &&

        tail -f /dev/null
      "

    networks:
      - pi-network

networks:
  pi-network:
    driver: bridge
    name: pi-emulator-network

volumes:
  pi-home:
    name: pi-emulator-home
  pi-docker:
    name: pi-emulator-docker
COMPOSE_EOF
    log_success "docker-compose.yml créé"
fi

# Vérifier si déjà lancé
if docker ps --format '{{.Names}}' | grep -q "^pi-emulator-test$"; then
    log_info "Pi Emulator déjà en cours d'exécution"
    log_success "Émulateur actif"
    docker ps --filter "name=pi-emulator-test"
    exit 0
fi

# Lancer Docker Compose
log_info "Lancement de l'émulateur Pi..."
cd "${EMULATOR_DIR}"
docker compose -f "${COMPOSE_FILE}" up -d

# Attendre démarrage SSH
log_info "Attente démarrage SSH (30s)..."
sleep 30

# Vérifier SSH
if docker exec pi-emulator-test pgrep sshd > /dev/null; then
    log_success "SSH actif"
else
    log_error "SSH non démarré"
    docker logs pi-emulator-test --tail 50
    exit 1
fi

# Résumé
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 PI EMULATOR LANCÉ (LINUX)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 Connexion SSH:"
echo "   ssh pi@localhost -p 2222"
echo "   Password: raspberry"
echo ""
echo "📌 Depuis Admin Panel (tools/admin-panel/config.js):"
echo "   {"
echo "     hostname: 'localhost',"
echo "     port: 2222,"
echo "     username: 'pi',"
echo "     password: 'raspberry'"
echo "   }"
echo ""
echo "📌 Commandes utiles:"
echo "   docker logs pi-emulator-test -f"
echo "   docker exec -it pi-emulator-test bash"
echo "   docker compose -f compose/docker-compose.yml down"
echo ""
echo "📌 Installer services:"
echo "   ssh pi@localhost -p 2222"
echo "   cd /home/pi"
echo "   curl -fsSL https://raw.githubusercontent.com/.../script.sh | sudo bash"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
