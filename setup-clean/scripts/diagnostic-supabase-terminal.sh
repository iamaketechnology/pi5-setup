#!/bin/bash

# =============================================================================
# DIAGNOSTIC COMPLET SUPABASE - AFFICHAGE TERMINAL DIRECT
# =============================================================================
# Génère un rapport détaillé directement dans le terminal pour Claude Code
# Usage: sudo ./diagnostic-supabase-terminal.sh

set -euo pipefail

# Configuration
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/$TARGET_USER/stacks/supabase"

# Couleurs pour terminal
warn()  { echo -e "\033[1;33m[WARN]   \033[0m $*" >&2; }
ok()    { echo -e "\033[1;32m[OK]     \033[0m $*" >&2; }
error() { echo -e "\033[1;31m[ERROR] \033[0m $*" >&2; }

ok "🔍 Génération rapport diagnostic Supabase dans le terminal..."
ok "📋 Copiez TOUT ce qui suit pour Claude Code..."

echo ""
echo "# ============================================================================="
echo "# RAPPORT DIAGNOSTIC SUPABASE - TERMINAL OUTPUT"
echo "# ============================================================================="
echo "# INSTRUCTIONS POUR CLAUDE :"
echo "# 1. Analysez ce rapport complet"
echo "# 2. Identifiez les problèmes critiques"
echo "# 3. Proposez corrections spécifiques"
echo "# 4. Générez commandes de correction"
echo "# ============================================================================="
echo ""

echo "🕐 TIMESTAMP: $(date)"
echo "🖥️  HOSTNAME: $(hostname)"
echo "👤 USER: $TARGET_USER"
echo "📁 PROJECT_DIR: $PROJECT_DIR"
echo ""

# =============================================================================
# SECTION 1: ÉTAT SYSTÈME
# =============================================================================
echo "## 1. ÉTAT SYSTÈME"
echo ""
echo "### Architecture et OS:"
echo "Architecture: $(uname -m)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo ""

# =============================================================================
# SECTION 2: DOCKER
# =============================================================================
echo "### Docker Status:"
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker compose version)"
echo ""
echo "### Services Docker Supabase:"
if cd "$PROJECT_DIR" 2>/dev/null; then
  docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Erreur: docker compose ps"
else
  echo "Erreur: Impossible d'accéder à $PROJECT_DIR"
fi
echo ""

# =============================================================================
# SECTION 3: FICHIER .ENV CRITIQUE
# =============================================================================
echo "## 2. ANALYSE FICHIER .ENV (CRITIQUE)"
echo ""
echo "### État fichier .env:"

if [[ -f "$PROJECT_DIR/.env" ]]; then
  echo "✅ Fichier .env EXISTE"
  echo "Taille: $(stat -f%z "$PROJECT_DIR/.env" 2>/dev/null || stat -c%s "$PROJECT_DIR/.env" 2>/dev/null || echo "inconnue") bytes"
  echo "Permissions: $(ls -la "$PROJECT_DIR/.env" | awk '{print $1,$3,$4}')"
  echo "Dernière modification: $(ls -la "$PROJECT_DIR/.env" | awk '{print $6,$7,$8}')"
  echo ""

  echo "### Variables critiques présentes:"
  local critical_vars=("SUPABASE_PORT" "POSTGRES_PASSWORD" "JWT_SECRET" "SUPABASE_ANON_KEY" "SUPABASE_SERVICE_KEY" "LOCAL_IP")
  for var in "${critical_vars[@]}"; do
    if grep -q "^${var}=" "$PROJECT_DIR/.env" 2>/dev/null; then
      local value=$(grep "^${var}=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | cut -c1-20)
      echo "✅ $var=${value}..."
    else
      echo "❌ $var=MANQUANT"
    fi
  done
  echo ""

  echo "### Contenu complet .env (masqué pour sécurité):"
  sed 's/=.*/=***MASKED***/' "$PROJECT_DIR/.env" 2>/dev/null || echo "Erreur lecture .env"
  echo ""

  echo "### Backups .env disponibles:"
  ls -la "$PROJECT_DIR"/.env.bak.* 2>/dev/null | head -5 || echo "Aucune sauvegarde trouvée"

else
  echo "❌ FICHIER .ENV MANQUANT - PROBLÈME CRITIQUE"
  echo ""
  echo "### Recherche sauvegardes .env:"
  find "$PROJECT_DIR" -name ".env.bak.*" -type f 2>/dev/null | head -5 || echo "Aucune sauvegarde trouvée"
fi
echo ""

# =============================================================================
# SECTION 4: PORTS ET CONNECTIVITÉ
# =============================================================================
echo "## 3. PORTS ET CONNECTIVITÉ"
echo ""
echo "### Ports Docker mappés:"
echo "Kong (attendu 8001): $(docker port supabase-kong 2>/dev/null || echo "Service non accessible")"
echo "PostgreSQL (attendu 5432): $(docker port supabase-db 2>/dev/null || echo "Service non accessible")"
echo "Studio (attendu 3000): $(docker port supabase-studio 2>/dev/null || echo "Service non accessible")"
echo ""

echo "### Tests connectivité locale:"
for port in 8001 3000 5432; do
  if timeout 3 bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
    echo "✅ localhost:$port - ACCESSIBLE"
  else
    echo "❌ localhost:$port - NON ACCESSIBLE"
  fi
done
echo ""

echo "### Test API Supabase:"
if curl -sf --max-time 5 "http://localhost:8001" >/dev/null 2>&1; then
  local api_response=$(curl -s --max-time 5 "http://localhost:8001" 2>/dev/null | head -c 200)
  echo "✅ API Supabase accessible"
  echo "Response sample: $api_response"
else
  echo "❌ API Supabase NON ACCESSIBLE"
fi
echo ""

# =============================================================================
# SECTION 5: LOGS SERVICES PROBLÉMATIQUES
# =============================================================================
echo "## 4. LOGS SERVICES (10 DERNIÈRES LIGNES)"
echo ""

if cd "$PROJECT_DIR" 2>/dev/null; then
  for service in realtime kong auth studio; do
    echo "### Logs $service:"
    docker compose logs --tail=10 "$service" 2>/dev/null || echo "Service $service non accessible"
    echo ""
  done
else
  echo "Impossible d'accéder aux logs (PROJECT_DIR inaccessible)"
fi

# =============================================================================
# SECTION 6: BASE DE DONNÉES
# =============================================================================
echo "## 5. BASE DE DONNÉES POSTGRESQL"
echo ""
echo "### Connectivité PostgreSQL:"

if docker exec supabase-db pg_isready -U postgres 2>/dev/null; then
  echo "✅ PostgreSQL accessible"
  echo ""

  echo "### Schémas présents:"
  docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('auth','realtime','storage','public');" 2>/dev/null || echo "Erreur requête schémas"
  echo ""

  echo "### Table Realtime schema_migrations (problème fréquent):"
  if docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'realtime' AND table_name = 'schema_migrations');" 2>/dev/null | grep -q "t"; then
    echo "✅ Table realtime.schema_migrations existe"

    # Vérifier structure
    echo "Structure de la table:"
    docker exec supabase-db psql -U postgres -d postgres -c "\d realtime.schema_migrations;" 2>/dev/null || echo "Erreur description table"

    # Vérifier si colonne inserted_at existe
    if docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT EXISTS (SELECT FROM information_schema.columns WHERE table_schema = 'realtime' AND table_name = 'schema_migrations' AND column_name = 'inserted_at');" 2>/dev/null | grep -q "t"; then
      echo "✅ Colonne inserted_at présente (structure Ecto correcte)"
    else
      echo "❌ Colonne inserted_at MANQUANTE - Structure incorrecte pour Realtime"
    fi
  else
    echo "❌ Table realtime.schema_migrations MANQUANTE"
  fi

else
  echo "❌ PostgreSQL NON ACCESSIBLE"
fi
echo ""

# =============================================================================
# SECTION 7: RESSOURCES SYSTÈME
# =============================================================================
echo "## 6. RESSOURCES SYSTÈME"
echo ""
echo "### Utilisation mémoire:"
echo "RAM totale: $(free -h | grep Mem | awk '{print $2}')"
echo "RAM utilisée: $(free -h | grep Mem | awk '{print $3}')"
echo "RAM libre: $(free -h | grep Mem | awk '{print $4}')"
echo ""

echo "### Top conteneurs par mémoire:"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}" 2>/dev/null | head -8
echo ""

# =============================================================================
# SECTION 8: RÉSUMÉ ET ACTIONS SUGGÉRÉES
# =============================================================================
echo "## 7. RÉSUMÉ AUTOMATIQUE ET ACTIONS SUGGÉRÉES"
echo ""
echo "### Problèmes détectés automatiquement:"

local issues=()

# Vérification .env
if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  issues+=("CRITIQUE: Fichier .env manquant")
fi

# Vérification services restart
local restarting=$(docker ps --filter "status=restarting" --format "{{.Names}}" | grep "supabase-" 2>/dev/null || true)
if [[ -n "$restarting" ]]; then
  issues+=("BLOQUANT: Services en restart loop: $restarting")
fi

# Vérification Kong port
local kong_port=$(docker port supabase-kong 2>/dev/null | grep "8000/tcp" | cut -d: -f2)
if [[ -n "$kong_port" && "$kong_port" != "8001" ]]; then
  issues+=("MAJEUR: Kong sur mauvais port: $kong_port (attendu: 8001)")
fi

# Afficher problèmes
if [[ ${#issues[@]} -eq 0 ]]; then
  echo "✅ Aucun problème critique détecté automatiquement"
else
  echo "❌ Problèmes détectés:"
  for issue in "${issues[@]}"; do
    echo "   - $issue"
  done
fi
echo ""

echo "### Actions recommandées pour Claude Code:"
echo "1. Analyser section .env pour problèmes de variables"
echo "2. Vérifier logs Realtime si restart loop"
echo "3. Examiner connectivité et ports mappés"
echo "4. Proposer corrections spécifiques basées sur ce rapport"
echo ""

echo "### Commandes de correction rapides:"
echo "# Restaurer .env si manquant:"
echo "cd $PROJECT_DIR && ls -la .env.bak.* | head -1 | awk '{print \$9}' | xargs -I {} cp {} .env"
echo ""
echo "# Redémarrer services problématiques:"
echo "cd $PROJECT_DIR && docker compose restart kong realtime"
echo ""
echo "# Diagnostic complet:"
echo "cd $PROJECT_DIR && docker compose logs --tail=50"
echo ""

echo "# ============================================================================="
echo "# FIN RAPPORT DIAGNOSTIC"
echo "# ============================================================================="
echo "#"
echo "# COPIEZ TOUT CE QUI PRÉCÈDE ET COLLEZ DANS CLAUDE CODE"
echo "# PUIS DITES: \"Analyse ce rapport et donne-moi les corrections\""
echo "#"
echo "# ============================================================================="

ok "✅ Diagnostic terminé - Copiez tout le texte ci-dessus pour Claude Code !"