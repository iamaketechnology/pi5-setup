#!/usr/bin/env bash
set -euo pipefail

# === VALIDATE PRE-WEEK2 - Validation complète avant installation Supabase ===

log()  { echo -e "\033[1;36m[VALIDATE]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Variables globales pour tracking des problèmes
CRITICAL_ISSUES=0
MINOR_ISSUES=0
RECOMMENDATIONS=()

add_critical() {
  ((CRITICAL_ISSUES++))
  error "$1"
}

add_minor() {
  ((MINOR_ISSUES++))
  warn "$1"
}

add_recommendation() {
  RECOMMENDATIONS+=("$1")
}

validate_system_architecture() {
  log "🔍 Validation architecture système..."

  local arch=$(uname -m)
  echo "   Architecture : $arch"

  if [[ "$arch" == "aarch64" ]]; then
    ok "✅ Architecture ARM64 compatible"
  else
    add_critical "❌ Architecture $arch non testée avec Supabase Pi 5"
  fi

  # Modèle Pi
  if [[ -f /proc/device-tree/model ]]; then
    local model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')
    echo "   Modèle : $model"

    if [[ "$model" == *"Raspberry Pi 5"* ]]; then
      ok "✅ Raspberry Pi 5 confirmé"
    else
      add_minor "⚠️ Modèle différent du Pi 5 - Optimisations peuvent différer"
    fi
  fi
}

validate_memory_resources() {
  log "💾 Validation ressources mémoire..."

  local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
  echo "   RAM totale : ${ram_gb}GB"

  if [[ $ram_gb -ge 16 ]]; then
    ok "✅ RAM excellente pour Supabase (${ram_gb}GB)"
  elif [[ $ram_gb -ge 8 ]]; then
    ok "✅ RAM très bien pour Supabase (${ram_gb}GB)"
  elif [[ $ram_gb -ge 4 ]]; then
    add_minor "⚠️ RAM limitée (${ram_gb}GB) - Performance réduite possible"
    add_recommendation "Considérer upgrade vers Pi 5 16GB pour meilleures performances"
  else
    add_critical "❌ RAM insuffisante (${ram_gb}GB) - Minimum 4GB requis"
  fi

  # Swap
  local swap_gb=$(free -g | awk '/^Swap:/{print $2}')
  echo "   Swap configuré : ${swap_gb}GB"

  if [[ $swap_gb -ge 1 ]]; then
    ok "✅ Swap configuré"
  else
    add_minor "⚠️ Pas de swap - Recommandé pour stabilité PostgreSQL"
  fi
}

validate_disk_space() {
  log "💽 Validation espace disque..."

  local disk_total=$(df / | awk 'NR==2 {print int($2/1024/1024)}')
  local disk_used=$(df / | awk 'NR==2 {print int($3/1024/1024)}')
  local disk_avail=$(df / | awk 'NR==2 {print int($4/1024/1024)}')

  echo "   Disque / : ${disk_used}GB utilisés / ${disk_total}GB total (${disk_avail}GB libres)"

  if [[ $disk_avail -ge 30 ]]; then
    ok "✅ Espace disque excellent (${disk_avail}GB libres)"
  elif [[ $disk_avail -ge 20 ]]; then
    ok "✅ Espace disque suffisant (${disk_avail}GB libres)"
  elif [[ $disk_avail -ge 10 ]]; then
    add_minor "⚠️ Espace disque limité (${disk_avail}GB) - Surveiller utilisation"
    add_recommendation "Nettoyer espace disque ou étendre partition"
  else
    add_critical "❌ Espace disque insuffisant (${disk_avail}GB) - Minimum 10GB requis"
  fi

  # Vérifier inodes
  local inodes_used=$(df -i / | awk 'NR==2 {print int($3/1000)}')
  local inodes_total=$(df -i / | awk 'NR==2 {print int($2/1000)}')
  local inodes_avail=$(df -i / | awk 'NR==2 {print int($4/1000)}')

  echo "   Inodes : ${inodes_used}K utilisés / ${inodes_total}K total"

  if [[ $inodes_avail -lt 100 ]]; then
    add_critical "❌ Inodes insuffisants (${inodes_avail}K libres)"
  fi
}

validate_page_size() {
  log "📏 Validation page size kernel..."

  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
  echo "   Page size actuelle : $page_size bytes"

  if [[ "$page_size" == "4096" ]]; then
    ok "✅ Page size 4KB - Compatible PostgreSQL/Supabase"
  elif [[ "$page_size" == "16384" ]]; then
    add_critical "❌ Page size 16KB - Incompatible PostgreSQL/Supabase"
    add_recommendation "Ajouter 'kernel=kernel8.img' dans /boot/firmware/config.txt et redémarrer"
  else
    add_minor "⚠️ Page size non standard ($page_size) - Compatibilité incertaine"
  fi
}

validate_entropy() {
  log "🎲 Validation entropie système..."

  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  echo "   Entropie actuelle : $entropy bits"

  if [[ $entropy -ge 2000 ]]; then
    ok "✅ Entropie excellente"
  elif [[ $entropy -ge 1000 ]]; then
    ok "✅ Entropie suffisante"
  elif [[ $entropy -ge 500 ]]; then
    add_minor "⚠️ Entropie modérée ($entropy) - Peut causer lenteurs Docker"
    add_recommendation "Installer haveged : sudo apt install haveged"
  else
    add_critical "❌ Entropie faible ($entropy) - Causera des blocages Docker"
    add_recommendation "URGENT: Installer haveged : sudo apt install haveged"
  fi

  # Vérifier si haveged est installé
  if command -v haveged >/dev/null; then
    ok "   ✅ haveged installé"
    if systemctl is-active haveged >/dev/null 2>&1; then
      ok "   ✅ haveged actif"
    else
      add_minor "   ⚠️ haveged installé mais pas actif"
      add_recommendation "Démarrer haveged : sudo systemctl start haveged"
    fi
  fi
}

validate_docker() {
  log "🐳 Validation Docker..."

  # Installation Docker
  if command -v docker >/dev/null; then
    ok "✅ Docker installé"
    echo "   Version : $(docker --version)"
  else
    add_critical "❌ Docker non installé"
    add_recommendation "Installer Docker avec setup-week1.sh"
    return
  fi

  # Service Docker
  if systemctl is-active docker >/dev/null 2>&1; then
    ok "✅ Service Docker actif"
  else
    add_critical "❌ Service Docker inactif"
    add_recommendation "Démarrer Docker : sudo systemctl start docker"
    return
  fi

  # Docker Compose v2
  if docker compose version >/dev/null 2>&1; then
    ok "✅ Docker Compose v2 disponible"
    echo "   Version : $(docker compose version --short 2>/dev/null || echo 'Plugin installé')"
  else
    add_critical "❌ Docker Compose v2 non disponible"
    add_recommendation "Installer docker-compose-plugin"
    return
  fi

  # Test fonctionnalité Docker
  if timeout 10 docker run --rm hello-world >/dev/null 2>&1; then
    ok "✅ Docker fonctionnel"
  else
    add_critical "❌ Docker non fonctionnel - Test hello-world échoué"
  fi

  # Configuration daemon.json
  if [[ -f /etc/docker/daemon.json ]]; then
    ok "✅ Configuration daemon.json présente"

    # Vérifier optimisations importantes
    local daemon_config="/etc/docker/daemon.json"

    if grep -q "max-concurrent-downloads" "$daemon_config"; then
      local downloads=$(grep "max-concurrent-downloads" "$daemon_config" | grep -o '[0-9]\+')
      if [[ $downloads -ge 5 ]]; then
        ok "   ✅ max-concurrent-downloads optimisé ($downloads)"
      else
        add_minor "   ⚠️ max-concurrent-downloads faible ($downloads)"
        add_recommendation "Augmenter max-concurrent-downloads à 10 pour Supabase"
      fi
    fi

    if grep -q "nofile" "$daemon_config"; then
      ok "   ✅ Limites fichiers configurées"
    else
      add_minor "   ⚠️ Limites fichiers non configurées"
    fi
  else
    add_minor "⚠️ Configuration daemon.json manquante"
    add_recommendation "Optimiser Docker avec prepare-week2.sh"
  fi
}

validate_network_ports() {
  log "🔌 Validation ports réseau..."

  local supabase_ports=(
    "3000:Studio"
    "8000:Kong API"
    "8001:API Alt"
    "5432:PostgreSQL"
    "54321:Edge Functions"
    "9000:Portainer"
    "8080:Portainer Alt"
  )

  local blocked_ports=()
  local available_ports=()

  for port_info in "${supabase_ports[@]}"; do
    local port=$(echo "$port_info" | cut -d: -f1)
    local service=$(echo "$port_info" | cut -d: -f2)

    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
      blocked_ports+=("$port:$service")
    else
      available_ports+=("$port:$service")
    fi
  done

  echo "   Ports libres : ${#available_ports[@]}"
  echo "   Ports occupés : ${#blocked_ports[@]}"

  if [[ ${#blocked_ports[@]} -eq 0 ]]; then
    ok "✅ Tous les ports Supabase libres"
  else
    echo ""
    warn "⚠️ Ports occupés :"
    for port_info in "${blocked_ports[@]}"; do
      echo "   - $port_info"
    done

    # Vérifier conflit critique (8000)
    if printf '%s\n' "${blocked_ports[@]}" | grep -q "8000:"; then
      add_critical "❌ Port 8000 occupé - Conflit direct avec Supabase Kong"
    else
      add_minor "⚠️ Certains ports occupés mais pas critiques"
    fi
  fi

  # Vérifier specifically Portainer
  if netstat -tuln 2>/dev/null | grep -q ":8000 "; then
    add_recommendation "Migrer Portainer du port 8000 vers 8080"
  fi
}

validate_system_limits() {
  log "⚙️ Validation limites système..."

  # File limits
  local nofile_limit=$(ulimit -n)
  echo "   Limite fichiers ouverts : $nofile_limit"

  if [[ $nofile_limit -ge 65536 ]]; then
    ok "✅ Limite fichiers ouverts suffisante"
  elif [[ $nofile_limit -ge 32768 ]]; then
    add_minor "⚠️ Limite fichiers modérée ($nofile_limit)"
  else
    add_critical "❌ Limite fichiers faible ($nofile_limit) - PostgreSQL nécessite ≥32768"
    add_recommendation "Configurer /etc/security/limits.conf pour augmenter nofile"
  fi

  # Process limits
  local nproc_limit=$(ulimit -u)
  echo "   Limite processus : $nproc_limit"

  if [[ $nproc_limit -ge 16384 ]]; then
    ok "✅ Limite processus suffisante"
  else
    add_minor "⚠️ Limite processus potentiellement faible ($nproc_limit)"
  fi

  # Shared memory (important pour PostgreSQL)
  local shmmax=$(cat /proc/sys/kernel/shmmax 2>/dev/null || echo "0")
  local shmmax_gb=$((shmmax / 1024 / 1024 / 1024))

  if [[ $shmmax_gb -ge 1 ]]; then
    ok "✅ Mémoire partagée configurée (${shmmax_gb}GB)"
  else
    add_minor "⚠️ Mémoire partagée faible - PostgreSQL peut être limité"
    add_recommendation "Configurer kernel.shmmax dans sysctl.conf"
  fi
}

validate_required_tools() {
  log "🛠️ Validation outils requis..."

  local required_tools=(
    "curl:Téléchargement scripts"
    "python3:Validation YAML"
    "nc:Tests connectivité"
    "git:Gestion version"
  )

  local missing_tools=()

  for tool_info in "${required_tools[@]}"; do
    local tool=$(echo "$tool_info" | cut -d: -f1)
    local desc=$(echo "$tool_info" | cut -d: -f2)

    if command -v "$tool" >/dev/null; then
      ok "   ✅ $tool disponible"
    else
      missing_tools+=("$tool:$desc")
    fi
  done

  # Vérifier Python YAML
  if command -v python3 >/dev/null; then
    if python3 -c "import yaml" >/dev/null 2>&1; then
      ok "   ✅ python3-yaml disponible"
    else
      missing_tools+=("python3-yaml:Validation fichiers YAML")
    fi
  fi

  if [[ ${#missing_tools[@]} -eq 0 ]]; then
    ok "✅ Tous les outils requis disponibles"
  else
    add_minor "⚠️ Outils manquants : ${#missing_tools[@]}"
    for tool_info in "${missing_tools[@]}"; do
      echo "   - $tool_info"
    done
    add_recommendation "Installer outils manquants avec prepare-week2.sh"
  fi
}

generate_compatibility_report() {
  echo ""
  echo "==================== 📊 RAPPORT DE COMPATIBILITÉ ===================="

  local total_issues=$((CRITICAL_ISSUES + MINOR_ISSUES))

  if [[ $CRITICAL_ISSUES -eq 0 && $MINOR_ISSUES -eq 0 ]]; then
    ok "🟢 SYSTÈME PARFAITEMENT COMPATIBLE"
    echo ""
    echo "✨ **Statut** : Prêt pour installation Supabase immédiate"
    echo "🚀 **Action** : Procéder avec setup-week2-improved.sh"

  elif [[ $CRITICAL_ISSUES -eq 0 ]]; then
    warn "🟡 SYSTÈME COMPATIBLE AVEC OPTIMISATIONS MINEURES"
    echo ""
    echo "⚠️ **Statut** : $MINOR_ISSUES problème(s) mineur(s)"
    echo "🛠️ **Action** : Optionnel - Exécuter prepare-week2.sh pour optimisations"
    echo "🚀 **Alternative** : Installation Supabase possible directement"

  else
    error "🔴 SYSTÈME NON COMPATIBLE - CORRECTIONS REQUISES"
    echo ""
    echo "❌ **Statut** : $CRITICAL_ISSUES problème(s) critique(s), $MINOR_ISSUES mineur(s)"
    echo "🛑 **Action** : OBLIGATOIRE - Corriger problèmes critiques avant Supabase"
  fi

  echo ""
  echo "📋 **Résumé des problèmes** :"
  echo "   🔴 Critiques : $CRITICAL_ISSUES"
  echo "   🟡 Mineurs   : $MINOR_ISSUES"
  echo "   📋 Total     : $total_issues"

  if [[ ${#RECOMMENDATIONS[@]} -gt 0 ]]; then
    echo ""
    echo "🛠️ **Recommandations** :"
    local i=1
    for rec in "${RECOMMENDATIONS[@]}"; do
      echo "   $i. $rec"
      ((i++))
    done
  fi

  echo ""
  echo "🚀 **Scripts recommandés selon statut** :"
  if [[ $CRITICAL_ISSUES -eq 0 ]]; then
    echo "   ✅ setup-week2-improved.sh     # Installation Supabase standard"
    echo "   🛠️ prepare-week2.sh            # Optimisations et vérifications"
    echo "   🔄 reset-and-fix.sh           # Installation complète propre"
  else
    echo "   🛑 prepare-week2.sh            # Corriger problèmes critiques AVANT"
    echo "   📊 diagnose-deep.sh           # Diagnostic approfondi"
    echo "   ⚙️ setup-week1-enhanced.sh    # Réinstallation base améliorée"
  fi

  echo "=========================================================================="

  # Code de retour selon sévérité
  if [[ $CRITICAL_ISSUES -gt 0 ]]; then
    return 2  # Erreur critique
  elif [[ $MINOR_ISSUES -gt 0 ]]; then
    return 1  # Avertissements
  else
    return 0  # Tout OK
  fi
}

main() {
  echo "==================== 🔍 VALIDATION PRE-WEEK2 ===================="
  log "🏥 Validation complète avant installation Supabase"
  echo ""

  validate_system_architecture
  echo ""

  validate_memory_resources
  echo ""

  validate_disk_space
  echo ""

  validate_page_size
  echo ""

  validate_entropy
  echo ""

  validate_docker
  echo ""

  validate_network_ports
  echo ""

  validate_system_limits
  echo ""

  validate_required_tools

  generate_compatibility_report
  return $?
}

main "$@"