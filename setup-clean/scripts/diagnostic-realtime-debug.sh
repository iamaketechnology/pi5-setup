#!/bin/bash

# =============================================================================
# DIAGNOSTIC REALTIME SPÉCIFIQUE - DEBUG RESTART LOOPS
# =============================================================================
# Script de diagnostic avancé pour problèmes Realtime Supabase sur Pi 5
# Analyse en profondeur les causes de restart loops et erreurs Elixir/Ecto
# Usage: sudo ./diagnostic-realtime-debug.sh

set -euo pipefail

# Configuration
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/$TARGET_USER/stacks/supabase"

# Couleurs pour terminal
warn()  { echo -e "\033[1;33m[WARN]   \033[0m $*" >&2; }
ok()    { echo -e "\033[1;32m[OK]     \033[0m $*" >&2; }
error() { echo -e "\033[1;31m[ERROR] \033[0m $*" >&2; }

ok "🔍 Diagnostic Realtime avancé - Supabase Pi 5"
ok "📋 Analyse spécifique restart loops et erreurs Ecto"
echo ""
echo "# ============================================================================="
echo "# RAPPORT DIAGNOSTIC REALTIME - $(date)"
echo "# ============================================================================="
echo "# INSTRUCTIONS: Copiez TOUT ce qui suit pour Claude Code"
echo "# ============================================================================="
echo ""

echo "🕐 TIMESTAMP: $(date)"
echo "🖥️  HOSTNAME: $(hostname)"
echo "👤 USER: $TARGET_USER"
echo "📁 PROJECT_DIR: $PROJECT_DIR"
echo ""

# =============================================================================
# SECTION 1: ÉTAT CONTENEUR REALTIME
# =============================================================================
echo "## 1. ÉTAT CONTENEUR REALTIME"
echo ""

if cd "$PROJECT_DIR" 2>/dev/null; then
  echo "### Status conteneur:"
  docker ps --filter "name=supabase-realtime" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Conteneur non trouvé"
  echo ""

  echo "### Restart count et uptime:"
  docker inspect supabase-realtime --format "Restart count: {{.RestartCount}}" 2>/dev/null || echo "Impossible d'inspecter"
  docker inspect supabase-realtime --format "Started: {{.State.StartedAt}}" 2>/dev/null || echo "Impossible d'inspecter"
  echo ""

  echo "### Health status:"
  docker inspect supabase-realtime --format "Health: {{.State.Health.Status}}" 2>/dev/null || echo "Pas de health check configuré"
  echo ""

else
  echo "❌ ERREUR: Impossible d'accéder à $PROJECT_DIR"
fi

# =============================================================================
# SECTION 2: LOGS REALTIME DÉTAILLÉS
# =============================================================================
echo "## 2. LOGS REALTIME DÉTAILLÉS (30 dernières lignes)"
echo ""

if cd "$PROJECT_DIR" 2>/dev/null; then
  echo "### Logs actuels (avec timestamps):"
  docker compose logs --tail=30 --timestamps realtime 2>/dev/null || echo "Logs non accessibles"
  echo ""

  echo "### Erreurs Elixir/Ecto spécifiques:"
  docker compose logs realtime 2>/dev/null | grep -E "(ERROR|error|Error|CRASH|crash|Crash|GenServer|DBConnection|Ecto)" | tail -10 || echo "Aucune erreur Elixir détectée"
  echo ""

  echo "### Variables d'environnement Realtime:"
  docker exec supabase-realtime env 2>/dev/null | grep -E "(DB_|SECRET_|JWT_|APP_|ERL_)" | sort || echo "Variables non accessibles"
  echo ""
fi

# =============================================================================
# SECTION 3: ANALYSE BASE DE DONNÉES REALTIME
# =============================================================================
echo "## 3. ANALYSE BASE DE DONNÉES REALTIME"
echo ""

if docker exec supabase-db pg_isready -U postgres 2>/dev/null; then
  echo "✅ PostgreSQL accessible"
  echo ""

  echo "### Schéma realtime existant:"
  docker exec supabase-db psql -U postgres -d postgres -c "\dn realtime" 2>/dev/null || echo "Schéma realtime non trouvé"
  echo ""

  echo "### Table schema_migrations - Structure détaillée:"
  if docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'realtime' AND table_name = 'schema_migrations');" 2>/dev/null | grep -q "t"; then
    echo "✅ Table schema_migrations existe"
    echo ""

    echo "Structure complète:"
    docker exec supabase-db psql -U postgres -d postgres -c "\d realtime.schema_migrations;" 2>/dev/null || echo "Erreur description table"
    echo ""

    echo "Contenu actuel:"
    docker exec supabase-db psql -U postgres -d postgres -c "SELECT * FROM realtime.schema_migrations ORDER BY version;" 2>/dev/null || echo "Erreur lecture contenu"
    echo ""

    echo "Permissions sur la table:"
    docker exec supabase-db psql -U postgres -d postgres -c "SELECT grantee, privilege_type FROM information_schema.table_privileges WHERE table_schema = 'realtime' AND table_name = 'schema_migrations';" 2>/dev/null || echo "Erreur lecture permissions"
    echo ""

  else
    echo "❌ Table realtime.schema_migrations MANQUANTE"
    echo ""

    echo "Tables dans schéma realtime:"
    docker exec supabase-db psql -U postgres -d postgres -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'realtime';" 2>/dev/null || echo "Erreur liste tables"
    echo ""
  fi

  echo "### Vérification autres tables schema_migrations (conflits potentiels):"
  docker exec supabase-db psql -U postgres -d postgres -c "SELECT table_schema, table_name FROM information_schema.tables WHERE table_name = 'schema_migrations';" 2>/dev/null || echo "Erreur recherche conflits"
  echo ""

  echo "### Rôles PostgreSQL pour Realtime:"
  docker exec supabase-db psql -U postgres -d postgres -c "SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role');" 2>/dev/null || echo "Erreur lecture rôles"
  echo ""

else
  echo "❌ PostgreSQL NON ACCESSIBLE"
fi

# =============================================================================
# SECTION 4: FICHIER .ENV - VARIABLES REALTIME
# =============================================================================
echo "## 4. FICHIER .ENV - VARIABLES REALTIME"
echo ""

if [[ -f "$PROJECT_DIR/.env" ]]; then
  echo "✅ Fichier .env existe"
  echo ""

  echo "### Variables critiques Realtime:"
  local realtime_vars=("DB_ENC_KEY" "SECRET_KEY_BASE" "JWT_SECRET" "LOCAL_IP" "SUPABASE_PORT" "POSTGRES_PASSWORD")
  for var in "${realtime_vars[@]}"; do
    if grep -q "^${var}=" "$PROJECT_DIR/.env" 2>/dev/null; then
      local value=$(grep "^${var}=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | cut -c1-20)
      local length=$(grep "^${var}=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | wc -c)
      echo "✅ $var=${value}... (longueur: $((length-1)) chars)"
    else
      echo "❌ $var=MANQUANT"
    fi
  done
  echo ""

  echo "### Validation longueurs clés encryption:"
  if grep -q "^DB_ENC_KEY=" "$PROJECT_DIR/.env" 2>/dev/null; then
    local db_enc_key_len=$(grep "^DB_ENC_KEY=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | wc -c)
    if [[ $((db_enc_key_len-1)) -eq 16 ]]; then
      echo "✅ DB_ENC_KEY: $((db_enc_key_len-1)) chars (correct pour AES-128)"
    else
      echo "❌ DB_ENC_KEY: $((db_enc_key_len-1)) chars (attendu: 16 pour AES-128)"
    fi
  fi

  if grep -q "^SECRET_KEY_BASE=" "$PROJECT_DIR/.env" 2>/dev/null; then
    local secret_key_len=$(grep "^SECRET_KEY_BASE=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | wc -c)
    if [[ $((secret_key_len-1)) -eq 64 ]]; then
      echo "✅ SECRET_KEY_BASE: $((secret_key_len-1)) chars (correct pour Elixir)"
    else
      echo "❌ SECRET_KEY_BASE: $((secret_key_len-1)) chars (attendu: 64 pour Elixir)"
    fi
  fi
  echo ""

else
  echo "❌ FICHIER .ENV MANQUANT"
fi

# =============================================================================
# SECTION 5: DOCKER COMPOSE - CONFIGURATION REALTIME
# =============================================================================
echo "## 5. DOCKER COMPOSE - CONFIGURATION REALTIME"
echo ""

if cd "$PROJECT_DIR" 2>/dev/null; then
  echo "### Configuration service Realtime:"
  docker compose config 2>/dev/null | grep -A 20 "realtime:" || echo "Configuration non accessible"
  echo ""

  echo "### Variables d'environnement substituées:"
  docker compose config 2>/dev/null | grep -A 10 "environment:" | grep -E "(DB_|SECRET_|JWT_)" || echo "Variables non visibles"
  echo ""

  echo "### Réseaux et dépendances:"
  docker compose config 2>/dev/null | grep -A 5 "depends_on:" || echo "Dépendances non visibles"
  echo ""
fi

# =============================================================================
# SECTION 6: TESTS CONNECTIVITÉ INTERNE
# =============================================================================
echo "## 6. TESTS CONNECTIVITÉ INTERNE"
echo ""

if cd "$PROJECT_DIR" 2>/dev/null; then
  echo "### Test connexion PostgreSQL depuis Realtime:"
  if docker exec supabase-realtime sh -c 'nc -z supabase-db 5432' 2>/dev/null; then
    echo "✅ Connectivité réseau Realtime -> PostgreSQL OK"
  else
    echo "❌ Connectivité réseau Realtime -> PostgreSQL ÉCHEC"
  fi
  echo ""

  echo "### Test résolution DNS interne:"
  docker exec supabase-realtime nslookup supabase-db 2>/dev/null | head -5 || echo "DNS non résolu"
  echo ""

  echo "### Variables réseau dans Realtime:"
  docker exec supabase-realtime env 2>/dev/null | grep -E "(DATABASE_URL|DB_HOST|DB_PORT)" || echo "Variables réseau non trouvées"
  echo ""
fi

# =============================================================================
# SECTION 7: ANALYSE PROCESSUS ELIXIR
# =============================================================================
echo "## 7. ANALYSE PROCESSUS ELIXIR"
echo ""

if cd "$PROJECT_DIR" 2>/dev/null; then
  echo "### Processus Erlang/Elixir dans le conteneur:"
  docker exec supabase-realtime ps aux 2>/dev/null | grep -E "(beam|elixir|erl)" || echo "Processus Elixir non trouvés"
  echo ""

  echo "### Version Elixir/Erlang:"
  docker exec supabase-realtime elixir --version 2>/dev/null || echo "Version Elixir non accessible"
  echo ""

  echo "### Ports écoutés dans Realtime:"
  docker exec supabase-realtime netstat -tlnp 2>/dev/null | head -10 || echo "Ports non accessibles"
  echo ""
fi

# =============================================================================
# SECTION 8: DIAGNOSTIC AUTOMATIQUE ET RECOMMANDATIONS
# =============================================================================
echo "## 8. DIAGNOSTIC AUTOMATIQUE ET RECOMMANDATIONS"
echo ""

local issues=()
local warnings=()

# Vérification service status
if cd "$PROJECT_DIR" 2>/dev/null; then
  local status=$(docker ps --filter "name=supabase-realtime" --format "{{.Status}}" | head -1)
  if [[ "$status" == *"Restarting"* ]]; then
    issues+=("CRITIQUE: Service Realtime en restart loop")
  elif [[ "$status" == *"Exited"* ]]; then
    issues+=("CRITIQUE: Service Realtime arrêté/crashed")
  fi
fi

# Vérification table schema_migrations
if docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'realtime' AND table_name = 'schema_migrations');" 2>/dev/null | grep -q "f"; then
  issues+=("CRITIQUE: Table realtime.schema_migrations manquante")
fi

# Vérification clés encryption
if [[ -f "$PROJECT_DIR/.env" ]]; then
  if ! grep -q "^DB_ENC_KEY=" "$PROJECT_DIR/.env" 2>/dev/null; then
    issues+=("MAJEUR: DB_ENC_KEY manquant")
  fi
  if ! grep -q "^SECRET_KEY_BASE=" "$PROJECT_DIR/.env" 2>/dev/null; then
    issues+=("MAJEUR: SECRET_KEY_BASE manquant")
  fi
fi

# Afficher diagnostic
if [[ ${#issues[@]} -eq 0 ]]; then
  echo "✅ Aucun problème critique détecté automatiquement"
else
  echo "❌ Problèmes détectés:"
  for issue in "${issues[@]}"; do
    echo "   - $issue"
  done
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
  echo ""
  echo "⚠️  Avertissements:"
  for warning in "${warnings[@]}"; do
    echo "   - $warning"
  done
fi

echo ""
echo "### Commandes de correction suggérées:"
echo ""
echo "# Si table schema_migrations manquante:"
echo "docker exec supabase-db psql -U postgres -d postgres -c \"CREATE SCHEMA IF NOT EXISTS realtime; CREATE TABLE realtime.schema_migrations(version BIGINT PRIMARY KEY, inserted_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW());\""
echo ""
echo "# Si restart loop persistant:"
echo "cd $PROJECT_DIR && docker compose stop realtime && docker compose start realtime"
echo ""
echo "# Si problèmes variables encryption:"
echo "# Vérifier et corriger .env avec clés correctes (16 chars pour DB_ENC_KEY, 64 pour SECRET_KEY_BASE)"
echo ""

echo "# ============================================================================="
echo "# FIN DIAGNOSTIC REALTIME AVANCÉ"
echo "# ============================================================================="
echo "#"
echo "# COPIEZ TOUT LE CONTENU CI-DESSUS"
echo "# COLLEZ DANS CLAUDE CODE POUR ANALYSE ET CORRECTIONS"
echo "#"
echo "# ============================================================================="

ok "✅ Diagnostic Realtime terminé - Copiez tout pour Claude Code !"