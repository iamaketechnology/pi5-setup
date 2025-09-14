#!/usr/bin/env bash
set -euo pipefail

# === PREPARE WEEK2 - Préparer le Pi 5 pour Supabase après Week1 ===

log()  { echo -e "\033[1;36m[PREPARE]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo ./prepare-week2.sh"
    exit 1
  fi
}

check_week1_installation() {
  log "🔍 Vérification installation Week1..."

  # Vérifier Docker
  if ! command -v docker >/dev/null; then
    error "❌ Docker non installé - Exécute d'abord Week1"
    exit 1
  fi

  # Vérifier Docker Compose v2
  if ! docker compose version >/dev/null 2>&1; then
    error "❌ Docker Compose v2 non installé"
    exit 1
  fi

  # Vérifier si Portainer existe
  if docker ps -a --format "{{.Names}}" | grep -q "^portainer$"; then
    warn "⚠️ Portainer détecté - Vérification du port..."
    PORTAINER_PORT=$(docker port portainer 2>/dev/null | grep "9000/tcp" | cut -d: -f2 || echo "unknown")
    echo "   Portainer utilise le port : $PORTAINER_PORT"
  fi

  ok "✅ Installation Week1 détectée"
}

fix_portainer_port_conflict() {
  log "🔧 Résolution conflit de port Portainer..."

  # Vérifier si Portainer utilise le port 8000 (conflit avec Supabase)
  if docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -q "portainer.*8000"; then
    error "❌ Portainer utilise le port 8000 - Conflit avec Supabase!"

    log "   Migration Portainer vers port 8080..."

    # Arrêter Portainer
    docker stop portainer >/dev/null 2>&1 || true
    docker rm portainer >/dev/null 2>&1 || true

    # Relancer sur port différent
    docker run -d \
      -p 8080:9000 \
      --name portainer \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce:latest >/dev/null 2>&1

    # Mettre à jour UFW si nécessaire
    if ufw status | grep -q "9000"; then
      ufw delete allow 9000/tcp >/dev/null 2>&1 || true
      ufw allow 8080/tcp >/dev/null 2>&1 || true
    fi

    ok "✅ Portainer migré vers port 8080"
    echo "   🌐 Nouvelle URL : http://$(hostname -I | awk '{print $1}'):8080"

  elif docker ps --format "{{.Names}}" | grep -q "^portainer$"; then
    ok "✅ Portainer n'utilise pas le port 8000"
  else
    ok "✅ Portainer non détecté ou arrêté"
  fi
}

check_and_fix_page_size() {
  log "📏 Vérification page size du kernel..."

  local current_page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
  echo "   Page size actuelle : $current_page_size bytes"

  if [[ "$current_page_size" == "16384" ]]; then
    error "❌ Page size 16KB - Incompatible avec PostgreSQL/Supabase"

    log "   Configuration kernel 4KB..."

    # Backup config.txt
    local config_file="/boot/firmware/config.txt"
    if [[ -f "$config_file" ]]; then
      cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"

      # Ajouter kernel=kernel8.img si pas présent
      if ! grep -q "^kernel=kernel8.img" "$config_file"; then
        echo "" >> "$config_file"
        echo "# Kernel 4KB pour compatibilité PostgreSQL/Supabase" >> "$config_file"
        echo "kernel=kernel8.img" >> "$config_file"

        warn "⚠️ Kernel 4KB configuré - REDÉMARRAGE REQUIS"
        echo ""
        echo "🔄 **REDÉMARRAGE NÉCESSAIRE** :"
        echo "   sudo reboot"
        echo ""
        echo "💡 Après redémarrage, relance ce script pour vérifier"
        echo "   le page size sera 4096 bytes au lieu de 16384"
        echo ""

        # Demander confirmation redémarrage
        read -p "Redémarrer maintenant ? (oui/non): " -r
        if [[ $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
          log "Redémarrage en cours..."
          reboot
        else
          warn "Redémarrage reporté - À faire manuellement avant Week2"
          exit 1
        fi
      else
        warn "⚠️ Kernel 4KB déjà configuré mais pas effectif - Redémarrage nécessaire"
        exit 1
      fi
    else
      error "❌ Fichier $config_file non trouvé"
      exit 1
    fi

  elif [[ "$current_page_size" == "4096" ]]; then
    ok "✅ Page size 4KB - Compatible avec PostgreSQL"
  else
    warn "⚠️ Page size non standard ($current_page_size) - À surveiller"
  fi
}

install_missing_tools() {
  log "🛠️ Installation outils manquants pour Week2..."

  # Mettre à jour les paquets
  apt update -qq

  local tools_needed=()

  # Vérifier haveged (entropie)
  if ! command -v haveged >/dev/null; then
    tools_needed+=("haveged")
  fi

  # Vérifier python3-yaml
  if ! python3 -c "import yaml" >/dev/null 2>&1; then
    tools_needed+=("python3-yaml")
  fi

  # Vérifier netcat
  if ! command -v nc >/dev/null; then
    tools_needed+=("netcat-openbsd")
  fi

  # Vérifier curl (devrait être installé par Week1)
  if ! command -v curl >/dev/null; then
    tools_needed+=("curl")
  fi

  if [[ ${#tools_needed[@]} -gt 0 ]]; then
    log "   Installation : ${tools_needed[*]}"
    apt install -y "${tools_needed[@]}"

    # Démarrer haveged si installé
    if [[ " ${tools_needed[*]} " =~ " haveged " ]]; then
      systemctl enable haveged >/dev/null 2>&1
      systemctl start haveged >/dev/null 2>&1
      ok "   ✅ haveged démarré pour améliorer l'entropie"
    fi

    ok "✅ Outils installés"
  else
    ok "✅ Tous les outils nécessaires déjà présents"
  fi
}

optimize_docker_for_supabase() {
  log "🐳 Optimisation Docker pour Supabase..."

  local docker_config="/etc/docker/daemon.json"
  local backup_config="${docker_config}.backup.$(date +%Y%m%d_%H%M%S)"

  # Backup configuration existante
  if [[ -f "$docker_config" ]]; then
    cp "$docker_config" "$backup_config"
  fi

  # Configuration optimisée pour Supabase
  cat > "$docker_config" << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "dns": ["8.8.8.8", "8.8.4.4"],
  "ipv6": true,
  "fixed-cidr-v6": "2001:db8:1::/64",
  "ip6tables": true
}
EOF

  # Valider la configuration JSON
  if python3 -c "import json; json.load(open('$docker_config'))" 2>/dev/null; then
    ok "✅ Configuration Docker optimisée"

    # Redémarrer Docker
    log "   Redémarrage Docker..."
    systemctl restart docker

    # Attendre que Docker soit prêt
    local retry_count=0
    while ! docker info >/dev/null 2>&1 && [[ $retry_count -lt 30 ]]; do
      sleep 1
      ((retry_count++))
    done

    if docker info >/dev/null 2>&1; then
      ok "✅ Docker redémarré avec succès"
    else
      error "❌ Erreur redémarrage Docker - Restauration backup"
      cp "$backup_config" "$docker_config"
      systemctl restart docker
      return 1
    fi
  else
    error "❌ Configuration JSON invalide - Pas de modification"
    rm -f "$docker_config"
    [[ -f "$backup_config" ]] && mv "$backup_config" "$docker_config"
    return 1
  fi
}

configure_system_for_postgresql() {
  log "🗄️ Optimisation système pour PostgreSQL..."

  # Configuration sysctl pour PostgreSQL
  local sysctl_config="/etc/sysctl.d/99-postgresql-supabase.conf"

  cat > "$sysctl_config" << 'EOF'
# PostgreSQL/Supabase optimizations

# Mémoire partagée (augmentée pour PostgreSQL)
kernel.shmmax=68719476736
kernel.shmall=4294967296

# Limites fichiers pour PostgreSQL
fs.file-max=2097152

# Optimisations réseau pour connexions DB
net.core.somaxconn=65535
net.core.netdev_max_backlog=5000

# Gestion mémoire optimisée pour bases de données
vm.swappiness=1
vm.dirty_ratio=15
vm.dirty_background_ratio=5
vm.overcommit_memory=2
vm.overcommit_ratio=80
EOF

  # Appliquer les paramètres
  sysctl -p "$sysctl_config" >/dev/null 2>&1
  ok "✅ Paramètres système optimisés pour PostgreSQL"

  # Configuration limites utilisateurs
  local limits_config="/etc/security/limits.conf"

  # Ajouter limites PostgreSQL si pas déjà présentes
  if ! grep -q "# PostgreSQL limits" "$limits_config"; then
    cat >> "$limits_config" << 'EOF'

# PostgreSQL limits for Supabase
postgres soft nofile 65536
postgres hard nofile 65536
postgres soft nproc 32768
postgres hard nproc 32768
EOF
    ok "✅ Limites utilisateur configurées pour PostgreSQL"
  fi
}

check_system_resources() {
  log "💾 Vérification ressources système..."

  # RAM
  local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
  echo "   RAM disponible : ${ram_gb}GB"

  if [[ $ram_gb -ge 16 ]]; then
    ok "   ✅ RAM excellente pour Supabase (${ram_gb}GB)"
  elif [[ $ram_gb -ge 8 ]]; then
    ok "   ✅ RAM suffisante pour Supabase (${ram_gb}GB)"
  elif [[ $ram_gb -ge 4 ]]; then
    warn "   ⚠️ RAM limitée (${ram_gb}GB) - Supabase fonctionnera mais sera plus lent"
  else
    error "   ❌ RAM insuffisante (${ram_gb}GB) - Minimum 4GB recommandé"
  fi

  # Espace disque
  local disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
  echo "   Espace disque libre : ${disk_gb}GB"

  if [[ $disk_gb -ge 20 ]]; then
    ok "   ✅ Espace disque suffisant"
  else
    warn "   ⚠️ Espace disque limité (${disk_gb}GB) - Minimum 20GB recommandé"
  fi

  # Entropie
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  echo "   Entropie système : $entropy bits"

  if [[ $entropy -ge 2000 ]]; then
    ok "   ✅ Entropie excellente"
  elif [[ $entropy -ge 1000 ]]; then
    ok "   ✅ Entropie suffisante"
  else
    warn "   ⚠️ Entropie faible - haveged installé pour amélioration"
  fi
}

check_port_availability() {
  log "🔌 Vérification disponibilité des ports Supabase..."

  local supabase_ports=(3000 8000 8001 5432 54321)
  local blocked_ports=()

  for port in "${supabase_ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
      blocked_ports+=("$port")
      warn "   ❌ Port $port occupé"
    else
      ok "   ✅ Port $port libre"
    fi
  done

  if [[ ${#blocked_ports[@]} -gt 0 ]]; then
    warn "⚠️ Ports bloqués : ${blocked_ports[*]}"
    echo "   💡 Solutions :"
    echo "   - Port 3000 : Arrêter autres services web"
    echo "   - Port 8000 : Portainer déjà migré vers 8080"
    echo "   - Port 8001 : Port API Supabase (à libérer)"
    echo "   - Port 5432 : PostgreSQL (ne pas utiliser d'autre instance)"
    echo "   - Port 54321 : Edge Functions"
  else
    ok "✅ Tous les ports Supabase libres"
  fi
}

main() {
  require_root

  echo "==================== 🛠️ PRÉPARATION WEEK2 ===================="
  log "🚀 Préparation du Pi 5 pour Supabase après installation Week1"
  echo ""

  check_week1_installation
  echo ""

  fix_portainer_port_conflict
  echo ""

  check_and_fix_page_size
  echo ""

  install_missing_tools
  echo ""

  optimize_docker_for_supabase
  echo ""

  configure_system_for_postgresql
  echo ""

  check_system_resources
  echo ""

  check_port_availability

  echo ""
  echo "==================== 📊 RÉSUMÉ PRÉPARATION ===================="

  ok "🎉 Pi 5 préparé pour Supabase Week2 !"
  echo ""
  echo "🚀 **Prochaines étapes** :"
  echo "   1. Si pas de redémarrage requis : Installer Supabase immédiatement"
  echo "   2. Script recommandé : ./reset-and-fix.sh (installation propre)"
  echo "   3. Ou setup-week2-improved.sh (installation standard)"
  echo ""
  echo "🔍 **Pour diagnostic complet** :"
  echo "   ./diagnose-deep.sh"
  echo ""
  echo "📊 **Monitoring Pi 5** :"
  echo "   Installer pi5-optimizations.sh pour script de monitoring"
  echo "=============================================================="
}

main "$@"