#!/usr/bin/env bash
set -euo pipefail

# === CLEANUP WEEK1 COMPLETE - Nettoyage complet pour recommencer Week1 ===

log()  { echo -e "\033[1;36m[CLEANUP]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo ./cleanup-week1-complete.sh"
    exit 1
  fi
}

confirm_cleanup() {
  echo "==================== ⚠️  NETTOYAGE COMPLET WEEK1 ===================="
  echo ""
  echo "🗑️  **Cette action va SUPPRIMER COMPLÈTEMENT :**"
  echo ""
  echo "🐳 **Docker & Conteneurs :**"
  echo "   ❌ Tous les conteneurs (Portainer, etc.)"
  echo "   ❌ Toutes les images Docker"
  echo "   ❌ Tous les volumes Docker"
  echo "   ❌ Tous les réseaux Docker"
  echo "   ❌ Docker Engine complet"
  echo ""
  echo "🔧 **Configurations système :**"
  echo "   ❌ Configuration Docker (/etc/docker/)"
  echo "   ❌ UFW (pare-feu) - retour par défaut"
  echo "   ❌ Fail2ban configuration"
  echo "   ❌ Configuration SSH durcie"
  echo "   ❌ Optimisations sysctl Pi 5"
  echo "   ❌ Limites système personnalisées"
  echo ""
  echo "📁 **Fichiers & Logs :**"
  echo "   ❌ Logs Week1 (/var/log/pi5-setup-*)"
  echo "   ❌ Clés GPG Docker"
  echo "   ❌ Dépôts APT Docker"
  echo ""
  echo "⚙️  **Paramètres Pi 5 :**"
  echo "   ❌ Modifications /boot/firmware/config.txt"
  echo "   ❌ Modules kernel activés (I2C, SPI)"
  echo ""
  echo "✅ **PRÉSERVÉ (non supprimé) :**"
  echo "   ✅ Paquets système de base (curl, git, htop, etc.)"
  echo "   ✅ Utilisateurs et mots de passe"
  echo "   ✅ Clés SSH utilisateur"
  echo "   ✅ Configuration réseau de base"
  echo ""

  read -p "Veux-tu VRAIMENT supprimer TOUTE la configuration Week1 ? (oui/non): " -r
  if [[ ! $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
    log "Nettoyage annulé"
    exit 0
  fi

  echo ""
  read -p "CONFIRMATION FINALE - Supprimer Docker et toutes les données ? (oui/non): " -r
  if [[ ! $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
    log "Nettoyage annulé"
    exit 0
  fi

  echo ""
  log "🚀 Nettoyage complet en cours..."
  sleep 2
}

cleanup_docker_complete() {
  log "🐳 Suppression complète Docker..."

  # Arrêter tous les conteneurs
  if command -v docker >/dev/null; then
    log "   Arrêt de tous les conteneurs..."
    docker stop $(docker ps -aq) 2>/dev/null || true

    # Supprimer tous les conteneurs
    log "   Suppression de tous les conteneurs..."
    docker rm -f $(docker ps -aq) 2>/dev/null || true

    # Supprimer toutes les images
    log "   Suppression de toutes les images..."
    docker rmi -f $(docker images -q) 2>/dev/null || true

    # Supprimer tous les volumes
    log "   Suppression de tous les volumes..."
    docker volume prune -f 2>/dev/null || true
    docker volume rm $(docker volume ls -q) 2>/dev/null || true

    # Supprimer tous les réseaux
    log "   Suppression des réseaux..."
    docker network prune -f 2>/dev/null || true

    # Nettoyage système complet
    log "   Nettoyage système Docker..."
    docker system prune -af --volumes 2>/dev/null || true
  fi

  # Arrêter service Docker
  if systemctl is-active docker >/dev/null 2>&1; then
    log "   Arrêt service Docker..."
    systemctl stop docker
    systemctl disable docker
  fi

  # Arrêter containerd
  if systemctl is-active containerd >/dev/null 2>&1; then
    log "   Arrêt containerd..."
    systemctl stop containerd
    systemctl disable containerd
  fi

  # Supprimer paquets Docker
  log "   Désinstallation paquets Docker..."
  apt purge -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    docker-ce-rootless-extras 2>/dev/null || true

  # Supprimer configuration Docker
  log "   Suppression configuration Docker..."
  rm -rf /etc/docker/
  rm -rf /var/lib/docker/
  rm -rf /var/lib/containerd/
  rm -rf /etc/systemd/system/docker.service.d/
  rm -rf /etc/systemd/system/multi-user.target.wants/docker.service

  # Supprimer dépôts et clés
  log "   Suppression dépôts Docker..."
  rm -f /etc/apt/sources.list.d/docker.list
  rm -f /etc/apt/keyrings/docker.gpg

  # Recharger systemd
  systemctl daemon-reload

  ok "✅ Docker complètement supprimé"
}

cleanup_ufw() {
  log "🔥 Réinitialisation UFW..."

  if command -v ufw >/dev/null; then
    # Désactiver UFW
    ufw --force disable 2>/dev/null || true

    # Reset complet
    ufw --force reset 2>/dev/null || true

    ok "✅ UFW réinitialisé"
  fi
}

cleanup_fail2ban() {
  log "🛡️ Suppression configuration Fail2ban..."

  # Arrêter service
  if systemctl is-active fail2ban >/dev/null 2>&1; then
    systemctl stop fail2ban
    systemctl disable fail2ban
  fi

  # Supprimer configuration personnalisée
  rm -f /etc/fail2ban/jail.local
  rm -f /etc/fail2ban/jail.d/*

  # Réinstaller configuration par défaut si nécessaire
  if command -v fail2ban-server >/dev/null; then
    log "   Restauration configuration Fail2ban par défaut..."
    systemctl enable fail2ban
    systemctl start fail2ban
  fi

  ok "✅ Fail2ban réinitialisé"
}

cleanup_ssh_hardening() {
  log "🔐 Suppression durcissement SSH..."

  # Supprimer configuration SSH durcie
  rm -f /etc/ssh/sshd_config.d/10-hardening.conf

  # Redémarrer SSH pour appliquer config par défaut
  systemctl restart ssh || systemctl restart sshd

  ok "✅ SSH remis en configuration par défaut"
}

cleanup_system_optimizations() {
  log "⚙️ Suppression optimisations système..."

  # Supprimer optimisations sysctl
  rm -f /etc/sysctl.d/99-pi5-server.conf
  rm -f /etc/sysctl.d/99-postgresql-supabase.conf

  # Restaurer limites par défaut
  log "   Restauration /etc/security/limits.conf..."

  # Backup puis nettoyage des ajouts
  cp /etc/security/limits.conf /etc/security/limits.conf.backup.$(date +%Y%m%d_%H%M%S)

  # Supprimer lignes ajoutées par nos scripts
  sed -i '/# Pi5 Server limits/,$d' /etc/security/limits.conf
  sed -i '/# PostgreSQL limits/,$d' /etc/security/limits.conf
  sed -i '/# Supabase optimizations/,$d' /etc/security/limits.conf

  # Recharger paramètres
  sysctl --system >/dev/null 2>&1 || true

  ok "✅ Optimisations système supprimées"
}

cleanup_pi5_config() {
  log "🥧 Nettoyage configuration Pi 5..."

  local config_file="/boot/firmware/config.txt"

  if [[ -f "$config_file" ]]; then
    # Backup
    cp "$config_file" "${config_file}.backup.cleanup.$(date +%Y%m%d_%H%M%S)"

    log "   Nettoyage $config_file..."

    # Supprimer ajouts Week1
    sed -i '/# Kernel 4KB pour compatibilité/d' "$config_file"
    sed -i '/kernel=kernel8.img/d' "$config_file"
    sed -i '/# Pi 5 optimizations/d' "$config_file"
    sed -i '/gpu_mem=/d' "$config_file"
    sed -i '/dtparam=i2c_arm=on/d' "$config_file"
    sed -i '/dtparam=spi=on/d' "$config_file"

    # Supprimer lignes vides multiples
    sed -i '/^$/N;/^\n$/d' "$config_file"

    ok "✅ Configuration Pi 5 nettoyée"
  fi

  # Supprimer modules ajoutés
  if [[ -f /etc/modules ]]; then
    log "   Nettoyage /etc/modules..."
    sed -i '/i2c-dev/d' /etc/modules
  fi
}

cleanup_logs() {
  log "📋 Suppression logs Week1..."

  # Supprimer logs de setup
  rm -f /var/log/pi5-setup-week1*.log
  rm -f /var/log/pi5-setup-week2*.log

  # Nettoyer logs système liés
  journalctl --vacuum-time=1d >/dev/null 2>&1 || true

  ok "✅ Logs supprimés"
}

cleanup_haveged() {
  log "🎲 Suppression haveged..."

  if command -v haveged >/dev/null; then
    systemctl stop haveged 2>/dev/null || true
    systemctl disable haveged 2>/dev/null || true
    apt purge -y haveged 2>/dev/null || true
    ok "✅ haveged supprimé"
  else
    ok "✅ haveged n'était pas installé"
  fi
}

cleanup_user_docker_group() {
  log "👥 Nettoyage groupe docker utilisateurs..."

  # Identifier utilisateur cible
  local target_user="${SUDO_USER:-$USER}"

  if [[ "$target_user" != "root" ]]; then
    # Supprimer utilisateur du groupe docker
    if getent group docker >/dev/null; then
      gpasswd -d "$target_user" docker 2>/dev/null || true
      log "   Utilisateur $target_user retiré du groupe docker"
    fi
  fi

  # Supprimer groupe docker s'il existe encore
  if getent group docker >/dev/null; then
    groupdel docker 2>/dev/null || true
  fi

  ok "✅ Groupe docker nettoyé"
}

cleanup_apt_cache() {
  log "🧹 Nettoyage cache APT..."

  # Mettre à jour la liste des paquets
  apt update -qq

  # Supprimer paquets orphelins
  apt autoremove -y

  # Nettoyer cache
  apt autoclean

  ok "✅ Cache APT nettoyé"
}

verify_cleanup() {
  log "🔍 Vérification du nettoyage..."

  local issues=0

  # Vérifier Docker
  if command -v docker >/dev/null; then
    warn "⚠️ Docker encore présent"
    ((issues++))
  else
    ok "✅ Docker supprimé"
  fi

  # Vérifier service Docker
  if systemctl is-enabled docker >/dev/null 2>&1; then
    warn "⚠️ Service Docker encore activé"
    ((issues++))
  else
    ok "✅ Service Docker désactivé"
  fi

  # Vérifier configuration Docker
  if [[ -d /etc/docker ]]; then
    warn "⚠️ Configuration Docker encore présente"
    ((issues++))
  else
    ok "✅ Configuration Docker supprimée"
  fi

  # Vérifier données Docker
  if [[ -d /var/lib/docker ]]; then
    warn "⚠️ Données Docker encore présentes"
    ((issues++))
  else
    ok "✅ Données Docker supprimées"
  fi

  # Vérifier UFW
  if ufw status 2>/dev/null | grep -q "Status: active"; then
    ok "✅ UFW réinitialisé mais actif"
  else
    ok "✅ UFW désactivé"
  fi

  # Vérifier configuration SSH durcie
  if [[ -f /etc/ssh/sshd_config.d/10-hardening.conf ]]; then
    warn "⚠️ Configuration SSH durcie encore présente"
    ((issues++))
  else
    ok "✅ Configuration SSH par défaut restaurée"
  fi

  echo ""
  if [[ $issues -eq 0 ]]; then
    ok "🎉 Nettoyage complet réussi !"
    echo ""
    echo "🚀 **Système prêt pour nouvelle installation Week1**"
    echo "   Utilise : setup-week1-enhanced.sh"
  else
    warn "⚠️ $issues problème(s) détecté(s) lors du nettoyage"
    echo ""
    echo "🔄 **Actions suggérées** :"
    echo "   1. Redémarrer le système : sudo reboot"
    echo "   2. Relancer ce script si nécessaire"
  fi
}

show_next_steps() {
  echo ""
  echo "==================== 🚀 PROCHAINES ÉTAPES ===================="
  echo ""
  echo "⚠️ **REDÉMARRAGE OBLIGATOIRE pour finaliser le nettoyage**"
  echo ""
  echo "1️⃣ **Redémarrer maintenant :**"
  echo "   sudo reboot"
  echo ""
  echo "2️⃣ **Après redémarrage - Vérifications (optionnel) :**"
  echo "   # Vérifier que Docker est supprimé"
  echo "   command -v docker && echo '❌ Docker encore présent' || echo '✅ Docker supprimé'"
  echo ""
  echo "   # Vérifier ports libres pour Supabase"
  echo "   netstat -tuln | grep -E ':(3000|8000|8001|5432|54321) ' && echo '⚠️ Ports occupés' || echo '✅ Ports libres'"
  echo ""
  echo "   # Vérifier page size et entropie"
  echo "   echo \"📏 Page size: \$(getconf PAGESIZE) bytes\""
  echo "   echo \"🎲 Entropie: \$(cat /proc/sys/kernel/random/entropy_avail) bits\""
  echo ""
  echo "3️⃣ **Installation Week1 Enhanced :**"
  echo "   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week1/setup-week1-enhanced.sh -o setup.sh"
  echo "   chmod +x setup.sh"
  echo "   sudo MODE=beginner ./setup.sh"
  echo ""
  echo "4️⃣ **Puis directement Week2 Supabase :**"
  echo "   sudo ./setup-week2-improved.sh"
  echo ""
  echo "📊 **Script de validation (si besoin) :**"
  echo "   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week2/validate-pre-week2.sh -o validate.sh && chmod +x validate.sh && ./validate.sh"
  echo ""
  echo "=============================================================="

  # Demander redémarrage
  echo ""
  log "🔄 Le redémarrage est OBLIGATOIRE pour finaliser le nettoyage complet"
  read -p "Redémarrer maintenant ? (oui/non): " -r
  if [[ $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
    log "🔄 Redémarrage en cours pour finaliser le nettoyage..."
    echo ""
    echo "⏳ Après redémarrage, reconnecte-toi et lance l'installation Week1 Enhanced"
    sleep 3
    reboot
  else
    warn "⚠️ ATTENTION: Redémarrage reporté"
    echo ""
    echo "🚨 **IMPORTANT** : Le nettoyage ne sera PAS complet sans redémarrage"
    echo "   Redémarre manuellement : sudo reboot"
    echo ""
    echo "✅ **Après redémarrage** : Système prêt pour installation Week1 Enhanced"
  fi
}

main() {
  require_root

  echo "==================== 🗑️ NETTOYAGE COMPLET WEEK1 ===================="
  log "🧹 Suppression complète installation Week1 pour recommencer"

  confirm_cleanup

  echo ""
  log "🚀 Début du nettoyage complet..."

  cleanup_docker_complete
  echo ""

  cleanup_ufw
  echo ""

  cleanup_fail2ban
  echo ""

  cleanup_ssh_hardening
  echo ""

  cleanup_system_optimizations
  echo ""

  cleanup_pi5_config
  echo ""

  cleanup_haveged
  echo ""

  cleanup_user_docker_group
  echo ""

  cleanup_logs
  echo ""

  cleanup_apt_cache
  echo ""

  verify_cleanup

  show_next_steps
}

main "$@"