#!/usr/bin/env bash
set -euo pipefail

# === PI 5 COMPLETE RESET - Remet le Pi 5 à zéro comme au premier démarrage ===

log()  { echo -e "\033[1;36m[RESET]  \033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]   \033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]     \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR] \033[0m $*"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Usage : sudo $0"
    exit 1
  fi
}

confirm_reset() {
  echo "==================== ⚠️  RESET COMPLET PI 5 ===================="
  echo ""
  echo "🚨 **ATTENTION : Cette action va SUPPRIMER COMPLÈTEMENT :**"
  echo ""
  echo "🐳 **Docker & Conteneurs :**"
  echo "   ❌ Tous les conteneurs (Supabase, Portainer, etc.)"
  echo "   ❌ Toutes les images Docker"
  echo "   ❌ Tous les volumes Docker"
  echo "   ❌ Tous les réseaux Docker"
  echo "   ❌ Docker Engine complet"
  echo ""
  echo "🔧 **Configurations système :**"
  echo "   ❌ Configuration Docker (/etc/docker/)"
  echo "   ❌ UFW (pare-feu) - retour défaut"
  echo "   ❌ Fail2ban configuration"
  echo "   ❌ Configuration SSH durcie"
  echo "   ❌ Optimisations sysctl personnalisées"
  echo "   ❌ Limites système personnalisées"
  echo ""
  echo "📁 **Projets & Données :**"
  echo "   ❌ Tous les projets dans /home/*/stacks/"
  echo "   ❌ Toutes les bases de données Supabase"
  echo "   ❌ Logs de setup (/var/log/pi5-setup-*)"
  echo ""
  echo "⚙️ **Paramètres Pi 5 :**"
  echo "   ❌ Modifications /boot/firmware/config.txt"
  echo "   ❌ Modules kernel activés (I2C, SPI)"
  echo "   🔄 Retour page size par défaut (16KB)"
  echo ""
  echo "✅ **PRÉSERVÉ (non supprimé) :**"
  echo "   ✅ Système d'exploitation de base"
  echo "   ✅ Utilisateurs et mots de passe"
  echo "   ✅ Clés SSH utilisateur personnelles"
  echo "   ✅ Configuration réseau de base"
  echo "   ✅ Paquets système essentiels (curl, git, etc.)"
  echo ""

  read -p "CONFIRMER le RESET COMPLET du Pi 5 ? (TAPER: reset-pi5): " -r
  if [[ "$REPLY" != "reset-pi5" ]]; then
    log "Reset annulé (phrase incorrecte)"
    exit 0
  fi

  echo ""
  read -p "CONFIRMATION FINALE - TOUT SUPPRIMER ? (oui/non): " -r
  if [[ ! $REPLY =~ ^(oui|OUI|yes|YES)$ ]]; then
    log "Reset annulé"
    exit 0
  fi

  echo ""
  log "🚀 Reset complet en cours..."
  sleep 3
}

stop_all_services() {
  log "⏹️ Arrêt de tous les services..."

  # Arrêter tous les containers Docker
  if command -v docker >/dev/null 2>&1; then
    log "   Arrêt containers Docker..."
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm -f $(docker ps -aq) 2>/dev/null || true
  fi

  # Arrêter services système liés
  local services=(
    "docker"
    "containerd"
    "fail2ban"
    "ufw"
  )

  for service in "${services[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
      systemctl stop "$service" 2>/dev/null || true
      systemctl disable "$service" 2>/dev/null || true
    fi
  done

  ok "✅ Services arrêtés"
}

clean_docker_complete() {
  log "🐳 Suppression complète Docker..."

  if command -v docker >/dev/null 2>&1; then
    log "   Nettoyage images et volumes..."
    docker system prune -af --volumes 2>/dev/null || true
    docker volume rm $(docker volume ls -q) 2>/dev/null || true
    docker network rm $(docker network ls -q --filter type=custom) 2>/dev/null || true
  fi

  log "   Désinstallation paquets Docker..."
  apt purge -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    docker-ce-rootless-extras 2>/dev/null || true

  log "   Suppression configurations..."
  rm -rf /etc/docker/
  rm -rf /var/lib/docker/
  rm -rf /var/lib/containerd/
  rm -rf /etc/systemd/system/docker.service.d/
  rm -rf /etc/systemd/system/multi-user.target.wants/docker.service

  log "   Suppression dépôts..."
  rm -f /etc/apt/sources.list.d/docker.list
  rm -f /etc/apt/keyrings/docker.gpg

  ok "✅ Docker complètement supprimé"
}

clean_user_projects() {
  log "📁 Suppression projets utilisateurs..."

  # Identifier utilisateur cible
  local target_user="${SUDO_USER:-$USER}"

  if [[ "$target_user" != "root" ]]; then
    local user_home="/home/$target_user"

    # Supprimer projets stacks
    if [[ -d "$user_home/stacks" ]]; then
      rm -rf "$user_home/stacks"
      log "   Supprimé : $user_home/stacks/"
    fi

    # Supprimer autres projets de développement courants
    local project_dirs=(
      "pi5-setup"
      "supabase"
      "docker-projects"
      "containers"
    )

    for dir in "${project_dirs[@]}"; do
      if [[ -d "$user_home/$dir" ]]; then
        rm -rf "$user_home/$dir"
        log "   Supprimé : $user_home/$dir/"
      fi
    done

    # Nettoyer groupe docker
    if getent group docker >/dev/null 2>&1; then
      gpasswd -d "$target_user" docker 2>/dev/null || true
    fi
  fi

  # Supprimer groupe docker
  groupdel docker 2>/dev/null || true

  ok "✅ Projets utilisateurs supprimés"
}

reset_firewall() {
  log "🔥 Reset pare-feu UFW..."

  if command -v ufw >/dev/null 2>&1; then
    ufw --force disable 2>/dev/null || true
    ufw --force reset 2>/dev/null || true
    ok "✅ UFW réinitialisé"
  fi
}

reset_fail2ban() {
  log "🛡️ Reset Fail2ban..."

  if command -v fail2ban-server >/dev/null 2>&1; then
    systemctl stop fail2ban 2>/dev/null || true
    systemctl disable fail2ban 2>/dev/null || true

    # Supprimer configurations personnalisées
    rm -f /etc/fail2ban/jail.local
    rm -rf /etc/fail2ban/jail.d/*

    # Réinstaller config par défaut
    systemctl enable fail2ban 2>/dev/null || true
    systemctl start fail2ban 2>/dev/null || true

    ok "✅ Fail2ban réinitialisé"
  fi
}

reset_ssh_config() {
  log "🔐 Reset configuration SSH..."

  # Supprimer durcissement SSH
  rm -f /etc/ssh/sshd_config.d/10-hardening.conf
  rm -f /etc/ssh/sshd_config.d/99-pi5-hardening.conf

  # Redémarrer SSH
  systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true

  ok "✅ SSH remis en configuration par défaut"
}

reset_system_optimizations() {
  log "⚙️ Suppression optimisations système..."

  # Supprimer optimisations sysctl
  rm -f /etc/sysctl.d/99-pi5-server.conf
  rm -f /etc/sysctl.d/99-postgresql-supabase.conf
  rm -f /etc/sysctl.d/99-docker-optimizations.conf

  # Restaurer limites par défaut
  if [[ -f /etc/security/limits.conf ]]; then
    cp /etc/security/limits.conf /etc/security/limits.conf.backup.$(date +%Y%m%d_%H%M%S)

    # Supprimer ajouts personnalisés
    sed -i '/# Pi5 Server limits/,$d' /etc/security/limits.conf
    sed -i '/# PostgreSQL limits/,$d' /etc/security/limits.conf
    sed -i '/# Docker optimizations/,$d' /etc/security/limits.conf
  fi

  # Recharger paramètres
  sysctl --system >/dev/null 2>&1 || true

  ok "✅ Optimisations système supprimées"
}

reset_pi5_config() {
  log "🥧 Reset configuration Pi 5..."

  local config_file="/boot/firmware/config.txt"

  if [[ -f "$config_file" ]]; then
    # Backup de sécurité
    cp "$config_file" "${config_file}.backup.reset.$(date +%Y%m%d_%H%M%S)"

    log "   Nettoyage $config_file..."

    # Supprimer modifications spécifiques
    sed -i '/# Kernel 4KB pour compatibilité/d' "$config_file"
    sed -i '/kernel=kernel8.img/d' "$config_file"
    sed -i '/# Pi 5 optimizations/d' "$config_file"
    sed -i '/gpu_mem=/d' "$config_file"
    sed -i '/dtparam=i2c_arm=on/d' "$config_file"
    sed -i '/dtparam=spi=on/d' "$config_file"
    sed -i '/# Week1 Enhanced/d' "$config_file"
    sed -i '/# Supabase optimizations/d' "$config_file"

    # Supprimer lignes vides multiples
    sed -i '/^$/N;/^\n$/d' "$config_file"

    ok "✅ Configuration Pi 5 nettoyée"
  fi

  # Supprimer modules ajoutés
  if [[ -f /etc/modules ]]; then
    sed -i '/i2c-dev/d' /etc/modules
    sed -i '/spi-dev/d' /etc/modules
  fi
}

clean_logs() {
  log "📋 Suppression logs de setup..."

  # Logs spécifiques
  rm -f /var/log/pi5-setup-*.log
  rm -f /var/log/supabase-*.log
  rm -f /var/log/docker-*.log

  # Nettoyer journalctl
  journalctl --vacuum-time=1h >/dev/null 2>&1 || true

  ok "✅ Logs supprimés"
}

remove_added_packages() {
  log "📦 Suppression paquets ajoutés..."

  # Paquets installés par les scripts Week1/Week2
  local packages_to_remove=(
    "haveged"
    "python3-yaml"
    "netcat-openbsd"
    "iotop"
    "ncdu"
  )

  for package in "${packages_to_remove[@]}"; do
    if dpkg -l | grep -q "^ii.*$package"; then
      apt purge -y "$package" 2>/dev/null || true
      log "   Supprimé : $package"
    fi
  done

  # Nettoyer les orphelins
  apt autoremove -y 2>/dev/null || true
  apt autoclean 2>/dev/null || true

  ok "✅ Paquets supprimés"
}

final_cleanup() {
  log "🧹 Nettoyage final..."

  # Nettoyer systemd
  systemctl daemon-reload

  # Nettoyer cache
  apt update -qq 2>/dev/null || true

  # Nettoyer /tmp
  find /tmp -type f -mtime +1 -delete 2>/dev/null || true

  ok "✅ Nettoyage final terminé"
}

show_reboot_info() {
  echo ""
  echo "==================== 🎉 RESET TERMINÉ ===================="
  echo ""
  echo "✅ **Pi 5 remis à zéro avec succès**"
  echo ""
  echo "🔄 **REDÉMARRAGE OBLIGATOIRE** pour finaliser :"
  echo "   - Page size retournera à 16KB (défaut Pi 5)"
  echo "   - Configuration kernel par défaut"
  echo "   - Services système par défaut"
  echo ""
  echo "⚡ **État après redémarrage** :"
  echo "   - Système Pi 5 comme au premier démarrage"
  echo "   - Docker : ❌ Non installé"
  echo "   - Supabase : ❌ Non installé"
  echo "   - Projets : ❌ Supprimés"
  echo "   - Page size : 16KB (défaut Pi 5)"
  echo ""
  echo "🚀 **Prochaines étapes** :"
  echo "   1. Redémarrer : sudo reboot"
  echo "   2. Week 1 : setup-week1-enhanced-final.sh"
  echo "   3. Week 2 : setup-week2-supabase-final.sh"
  echo ""
  echo "📚 **Documentation** : docs/PI5-SUPABASE-ISSUES-COMPLETE.md"
  echo "=============================================================="
  echo ""

  read -p "Redémarrer maintenant ? (oui/non): " -r
  if [[ $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
    log "🔄 Redémarrage en cours..."
    sleep 3
    reboot
  else
    warn "⚠️ Redémarrage reporté - À faire manuellement : sudo reboot"
  fi
}

main() {
  require_root
  confirm_reset

  echo ""
  log "🚀 Début du reset complet Pi 5..."

  stop_all_services
  echo ""

  clean_docker_complete
  echo ""

  clean_user_projects
  echo ""

  reset_firewall
  echo ""

  reset_fail2ban
  echo ""

  reset_ssh_config
  echo ""

  reset_system_optimizations
  echo ""

  reset_pi5_config
  echo ""

  clean_logs
  echo ""

  remove_added_packages
  echo ""

  final_cleanup

  show_reboot_info
}

main "$@"