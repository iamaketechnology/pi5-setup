#!/bin/bash

# =============================================================================
# DIAGNOSTIC SUPABASE PI 5 VIA SSH - RAPPORT POUR CLAUDE CODE
# =============================================================================
# Usage: Copiez ce script sur votre Pi et exécutez: sudo ./diagnostic-supabase-ssh.sh
# Le rapport s'affichera dans le terminal pour copier-coller dans Claude Code

set -euo pipefail

# Configuration
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/$TARGET_USER/stacks/supabase"

# Couleurs pour terminal
warn()  { echo -e "\033[1;33m[WARN]   \033[0m $*" >&2; }
ok()    { echo -e "\033[1;32m[OK]     \033[0m $*" >&2; }
error() { echo -e "\033[1;31m[ERROR] \033[0m $*" >&2; }

# Début du rapport
clear
ok "🔍 Diagnostic Supabase Pi 5 - Rapport pour Claude Code"
ok "📋 Sélectionnez et copiez TOUT ce qui suit :"
echo ""
echo "# ============================================================================="
echo "# RAPPORT DIAGNOSTIC SUPABASE PI 5 - $(date)"
echo "# ============================================================================="
echo "# INSTRUCTIONS POUR CLAUDE CODE :"
echo "# 1. Copiez TOUT le contenu suivant (jusqu'à la fin)"
echo "# 2. Collez dans Claude Code"
echo "# 3. Dites: \"Analyse ce rapport et donne-moi les corrections\""
echo "# ============================================================================="
echo ""

echo "🕐 TIMESTAMP: $(date)"
echo "🖥️  HOSTNAME: $(hostname)"
echo "👤 USER: $TARGET_USER"
echo "📁 PROJECT_DIR: $PROJECT_DIR"
echo "🔗 SSH Session depuis Mac détectée"
echo ""

# =============================================================================
# SYSTÈME ET DOCKER
# =============================================================================
echo "## 1. SYSTÈME ET DOCKER"
echo ""
echo "### Environnement:"
echo "Architecture: $(uname -m)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')"
echo "Kernel: $(uname -r)"
echo "Docker: $(docker --version)"
echo "Compose: $(docker compose version)"
echo ""

echo "### Services Supabase:"
if cd "$PROJECT_DIR" 2>/dev/null; then
  docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "❌ Impossible d'obtenir statut services"
else
  echo "❌ ERREUR: Impossible d'accéder à $PROJECT_DIR"
fi
echo ""

# =============================================================================
# ANALYSE FICHIER .ENV (CRITIQUE)
# =============================================================================
echo "## 2. FICHIER .ENV (ANALYSE CRITIQUE)"
echo ""

if [[ -f "$PROJECT_DIR/.env" ]]; then
  echo "✅ FICHIER .ENV EXISTE"
  echo "📊 Taille: $(stat -c%s "$PROJECT_DIR/.env" 2>/dev/null || echo "inconnue") bytes"
  echo "🔐 Permissions: $(ls -la "$PROJECT_DIR/.env" | awk '{print $1,$3,$4}')"
  echo "📅 Modifié: $(ls -la "$PROJECT_DIR/.env" | awk '{print $6,$7,$8}')"
  echo ""

  echo "### Variables critiques:"
  local critical_vars=("SUPABASE_PORT" "POSTGRES_PASSWORD" "JWT_SECRET" "SUPABASE_ANON_KEY" "SUPABASE_SERVICE_KEY" "LOCAL_IP")
  for var in "${critical_vars[@]}"; do
    if grep -q "^${var}=" "$PROJECT_DIR/.env" 2>/dev/null; then
      local value=$(grep "^${var}=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | cut -c1-15)
      echo "✅ $var=${value}..."
    else
      echo "❌ $var=MANQUANT"
    fi
  done

  echo ""
  echo "### Sauvegardes disponibles:"
  ls -la "$PROJECT_DIR"/.env.bak.* 2>/dev/null | head -3 || echo "Aucune sauvegarde trouvée"

else
  echo "❌ FICHIER .ENV MANQUANT - PROBLÈME CRITIQUE !"
  echo ""
  echo "### Recherche sauvegardes:"
  find "$PROJECT_DIR" -name ".env.bak.*" -type f 2>/dev/null | head -3 || echo "Aucune sauvegarde trouvée"
fi
echo ""

# =============================================================================
# PORTS ET CONNECTIVITÉ
# =============================================================================
echo "## 3. PORTS ET CONNECTIVITÉ"
echo ""
echo "### Mappings Docker:"
echo "🌐 Kong (8001): $(docker port supabase-kong 2>/dev/null | grep "8000/tcp" || echo "NON ACCESSIBLE")"
echo "🗄️  PostgreSQL (5432): $(docker port supabase-db 2>/dev/null | grep "5432/tcp" || echo "NON ACCESSIBLE")"
echo "🎨 Studio (3000): $(docker port supabase-studio 2>/dev/null | grep "3000/tcp" || echo "NON ACCESSIBLE")"
echo ""

echo "### Tests connectivité:"
for port in 8001 3000 5432; do
  if timeout 2 bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
    echo "✅ localhost:$port - OK"
  else
    echo "❌ localhost:$port - ÉCHEC"
  fi
done
echo ""

echo "### Test API Supabase:"
if timeout 5 curl -sf "http://localhost:8001" >/dev/null 2>&1; then
  local api_test=$(timeout 5 curl -s "http://localhost:8001" 2>/dev/null | head -c 150 | tr -d '\n')
  echo "✅ API accessible - Response: $api_test"
else
  echo "❌ API Supabase NON ACCESSIBLE"
fi
echo ""

# =============================================================================
# LOGS SERVICES PROBLÉMATIQUES
# =============================================================================
echo "## 4. LOGS SERVICES PROBLÉMATIQUES"
echo ""

if cd "$PROJECT_DIR" 2>/dev/null; then
  # Identifier services en problème
  local problematic_services=$(docker ps --filter "status=restarting" --format "{{.Names}}" | grep "supabase-" || true)

  if [[ -n "$problematic_services" ]]; then
    echo "🚨 SERVICES EN RESTART LOOP: $problematic_services"
    echo ""
  fi

  # Logs des services critiques
  for service in realtime kong auth; do
    local status=$(docker ps --filter "name=supabase-$service" --format "{{.Status}}" | head -1)
    echo "### $service ($status):"

    if [[ "$status" == *"Restart"* ]] || [[ "$status" == *"Exited"* ]]; then
      echo "⚠️  Service problématique - Derniers logs:"
      docker compose logs --tail=8 "$service" 2>/dev/null | tail -8 || echo "Logs non accessibles"
    else
      echo "✅ Service stable"
      docker compose logs --tail=3 "$service" 2>/dev/null | tail -3 || echo "Logs non accessibles"
    fi
    echo ""
  done
fi

# =============================================================================
# BASE DE DONNÉES
# =============================================================================
echo "## 5. BASE DE DONNÉES POSTGRESQL"
echo ""

if timeout 5 docker exec supabase-db pg_isready -U postgres 2>/dev/null; then
  echo "✅ PostgreSQL accessible"
  echo ""

  echo "### Schémas critiques:"
  local schemas=$(docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT string_agg(schema_name, ', ') FROM information_schema.schemata WHERE schema_name IN ('auth','realtime','storage','public');" 2>/dev/null)
  echo "Présents: $schemas"
  echo ""

  echo "### Table Realtime schema_migrations (problème fréquent):"
  if docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'realtime' AND table_name = 'schema_migrations');" 2>/dev/null | grep -q "t"; then
    echo "✅ Table existe"

    if docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT EXISTS (SELECT FROM information_schema.columns WHERE table_schema = 'realtime' AND table_name = 'schema_migrations' AND column_name = 'inserted_at');" 2>/dev/null | grep -q "t"; then
      echo "✅ Structure Ecto correcte (colonne inserted_at présente)"
    else
      echo "❌ PROBLÈME: Colonne inserted_at manquante - Structure incompatible Realtime"
    fi
  else
    echo "❌ Table realtime.schema_migrations MANQUANTE"
  fi

else
  echo "❌ PostgreSQL NON ACCESSIBLE"
fi
echo ""

# =============================================================================
# RESSOURCES
# =============================================================================
echo "## 6. RESSOURCES SYSTÈME"
echo ""
echo "### Mémoire:"
echo "Total: $(free -h | grep Mem | awk '{print $2}') | Utilisée: $(free -h | grep Mem | awk '{print $3}') | Libre: $(free -h | grep Mem | awk '{print $4}')"
echo ""

echo "### Conteneurs les plus gourmands:"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}" 2>/dev/null | head -6
echo ""

# =============================================================================
# DIAGNOSTIC AUTOMATIQUE
# =============================================================================
echo "## 7. DIAGNOSTIC AUTOMATIQUE"
echo ""

local critical_issues=()
local major_issues=()
local warnings=()

# Vérifications critiques
if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  critical_issues+=("Fichier .env manquant")
fi

local restarting=$(docker ps --filter "status=restarting" --format "{{.Names}}" | grep "supabase-" 2>/dev/null || true)
if [[ -n "$restarting" ]]; then
  major_issues+=("Services en restart loop: $restarting")
fi

local kong_port=$(docker port supabase-kong 2>/dev/null | grep "8000/tcp" | cut -d: -f2)
if [[ -n "$kong_port" && "$kong_port" != "8001" ]]; then
  major_issues+=("Kong sur mauvais port: $kong_port (attendu: 8001)")
fi

local unhealthy=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" | grep "supabase-" 2>/dev/null || true)
if [[ -n "$unhealthy" ]]; then
  warnings+=("Services unhealthy: $unhealthy")
fi

# Rapport diagnostic
if [[ ${#critical_issues[@]} -gt 0 ]]; then
  echo "🚨 PROBLÈMES CRITIQUES:"
  for issue in "${critical_issues[@]}"; do
    echo "   ❌ $issue"
  done
  echo ""
fi

if [[ ${#major_issues[@]} -gt 0 ]]; then
  echo "⚠️  PROBLÈMES MAJEURS:"
  for issue in "${major_issues[@]}"; do
    echo "   ⚠️  $issue"
  done
  echo ""
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
  echo "ℹ️  AVERTISSEMENTS:"
  for warn in "${warnings[@]}"; do
    echo "   ℹ️  $warn"
  done
  echo ""
fi

if [[ ${#critical_issues[@]} -eq 0 && ${#major_issues[@]} -eq 0 ]]; then
  echo "✅ Diagnostic automatique: Aucun problème critique détecté"
  echo ""
fi

# =============================================================================
# COMMANDES DE CORRECTION
# =============================================================================
echo "## 8. COMMANDES DE CORRECTION SUGGÉRÉES"
echo ""
echo "### Si .env manquant:"
echo "cd $PROJECT_DIR"
echo "ls -la .env.bak.* | head -1 | awk '{print \$9}' | xargs -I {} cp {} .env"
echo "chmod 600 .env && chown $TARGET_USER:$TARGET_USER .env"
echo ""

echo "### Si services en restart loop:"
echo "cd $PROJECT_DIR"
echo "docker compose stop realtime"
echo "docker compose start realtime"
echo ""

echo "### Si Kong sur mauvais port:"
echo "cd $PROJECT_DIR"
echo "grep SUPABASE_PORT .env"
echo "docker compose restart kong"
echo ""

echo "### Diagnostic complet:"
echo "cd $PROJECT_DIR && docker compose logs --tail=30"
echo ""

# =============================================================================
# FIN
# =============================================================================
echo "# ============================================================================="
echo "# FIN RAPPORT DIAGNOSTIC"
echo "# ============================================================================="
echo "# "
echo "# 📋 COPIEZ TOUT LE CONTENU CI-DESSUS"
echo "# 🔄 COLLEZ DANS CLAUDE CODE"
echo "# 💬 DITES: \"Analyse ce rapport et donne-moi les corrections\""
echo "# "
echo "# ============================================================================="
echo ""

ok "✅ Rapport diagnostic terminé !"
ok "📋 Sélectionnez tout le texte ci-dessus (Ctrl+A) puis copiez (Ctrl+C)"
ok "🔄 Collez dans Claude Code pour analyse et corrections"