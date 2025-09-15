#!/usr/bin/env bash
set -euo pipefail

# === FIX REALTIME ENCRYPTION - Script automatique ===
# À intégrer dans setup-week2-supabase-final.sh

log()  { echo -e "\\033[1;36m[REALTIME-FIX]\\033[0m $*"; }
warn() { echo -e "\\033[1;33m[WARN]\\033[0m $*"; }
ok()   { echo -e "\\033[1;32m[OK]\\033[0m $*"; }
error() { echo -e "\\033[1;31m[ERROR]\\033[0m $*"; }

# Variables (à ajuster selon contexte)
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/$TARGET_USER/stacks/supabase"

detect_realtime_issue() {
  log "🔍 Détection problème Realtime..."

  if ! docker ps --format '{{.Names}}\t{{.Status}}' | grep realtime >/dev/null 2>&1; then
    warn "❌ Conteneur Realtime non trouvé"
    return 1
  fi

  if docker ps --format '{{.Names}}\t{{.Status}}' | grep realtime | grep -q "restarting"; then
    log "🚨 Realtime en boucle de redémarrage détectée"
    return 0
  fi

  if docker ps --format '{{.Names}}\t{{.Status}}' | grep realtime | grep -q "Up"; then
    log "✅ Realtime semble opérationnel"
    return 1
  fi

  log "⚠️ État Realtime incertain - tentative de correction"
  return 0
}

diagnose_realtime_detailed() {
  log "🔍 Diagnostic détaillé Realtime..."

  echo "📋 STATUS CONTENEUR:"
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep realtime || echo "  Aucun conteneur realtime trouvé"

  echo ""
  echo "📋 LOGS RÉCENTS (20 dernières lignes):"
  docker logs supabase-realtime --tail=20 2>&1 | sed 's/^/  /' || echo "  Logs non disponibles"

  echo ""
  echo "📋 VARIABLES ENCRYPTION:"
  docker exec supabase-realtime printenv 2>/dev/null | grep -E "(DB_ENC_KEY|SECRET_KEY_BASE|API_JWT_SECRET)" | sed 's/^/  /' || echo "  Variables non accessibles"

  echo ""
  echo "📋 SCHEMA MIGRATIONS STATUS:"
  docker exec -T supabase-db psql -U postgres -d postgres -c "
    SELECT schemaname, tablename,
           CASE WHEN schemaname='realtime' AND tablename='schema_migrations' THEN 'FOUND'
                WHEN schemaname='public' AND tablename='schema_migrations' THEN 'FOUND'
                ELSE 'OTHER' END as status
    FROM pg_tables
    WHERE tablename='schema_migrations';" 2>/dev/null | sed 's/^/  /' || echo "  Schema check failed"
}

fix_schema_migrations_structure() {
  log "🔧 Correction structure schema_migrations..."

  # Corriger structure dans realtime schema
  docker exec -T supabase-db psql -U postgres -d postgres -c "
    DROP TABLE IF EXISTS realtime.schema_migrations CASCADE;
    CREATE TABLE realtime.schema_migrations(
      version BIGINT PRIMARY KEY,
      inserted_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW()
    );" 2>/dev/null || warn "Échec correction realtime.schema_migrations"

  # Corriger structure dans public schema
  docker exec -T supabase-db psql -U postgres -d postgres -c "
    DROP TABLE IF EXISTS public.schema_migrations CASCADE;
    CREATE TABLE public.schema_migrations(
      version BIGINT PRIMARY KEY,
      inserted_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW()
    );" 2>/dev/null || warn "Échec correction public.schema_migrations"

  ok "✅ Structure schema_migrations corrigée"
}

generate_proper_encryption_keys() {
  log "🔑 Génération clés encryption correctes..."

  # Générer clé AES 128-bit EXACTEMENT 16 caractères ASCII (8 octets → 16 hex)
  DB_ENC_KEY=$(openssl rand -hex 8)

  # Générer SECRET_KEY_BASE de 64 caractères (32 octets → 64 hex)
  SECRET_KEY_BASE=$(openssl rand -hex 32)

  # JWT_SECRET optimal: ~40 caractères (retour terrain 2024-2025)
  if [[ -f "$PROJECT_DIR/.env" ]]; then
    JWT_SECRET=$(grep "^JWT_SECRET=" "$PROJECT_DIR/.env" | cut -d'=' -f2- | tr -d '"')
    # Si JWT_SECRET trop long, le raccourcir à 40 caractères
    if [[ ${#JWT_SECRET} -gt 50 ]]; then
      log "   JWT_SECRET trop long (${#JWT_SECRET} chars), raccourci à 40"
      JWT_SECRET=$(echo "$JWT_SECRET" | head -c 40)
    fi
  else
    JWT_SECRET=$(openssl rand -base64 30 | head -c 40)
  fi

  ok "✅ Clés générées (format confirmé par recherche):"
  echo "  DB_ENC_KEY: ${DB_ENC_KEY} (16 chars exactement)"
  echo "  SECRET_KEY_BASE: ${SECRET_KEY_BASE:0:8}... (64 chars)"
  echo "  JWT_SECRET: ${JWT_SECRET:0:8}... (${#JWT_SECRET} chars - optimal)"

  export DB_ENC_KEY SECRET_KEY_BASE JWT_SECRET
}

update_environment_file() {
  log "📝 Mise à jour fichier .env..."

  cd "$PROJECT_DIR"

  # Backup .env
  cp .env ".env.backup.$(date +%Y%m%d_%H%M%S)"

  # Mettre à jour les clés
  sed -i "s/^DB_ENC_KEY=.*/DB_ENC_KEY=${DB_ENC_KEY}/" .env
  sed -i "s/^SECRET_KEY_BASE=.*/SECRET_KEY_BASE=${SECRET_KEY_BASE}/" .env

  # Ajouter clés si elles n'existent pas
  if ! grep -q "^DB_ENC_KEY=" .env; then
    echo "DB_ENC_KEY=${DB_ENC_KEY}" >> .env
  fi

  if ! grep -q "^SECRET_KEY_BASE=" .env; then
    echo "SECRET_KEY_BASE=${SECRET_KEY_BASE}" >> .env
  fi

  ok "✅ Fichier .env mis à jour (backup créé)"
}

update_docker_compose_safely() {
  log "📝 Mise à jour docker-compose.yml (méthode sécurisée)..."

  # Détecter indentation existante pour variables d'environnement
  local indent=$(grep -A1 "environment:" docker-compose.yml | tail -1 | sed 's/\([[:space:]]*\).*/\1/')

  # Ajouter DB_ENC_KEY dans section realtime si absent
  if ! grep -q "DB_ENC_KEY:" docker-compose.yml; then
    sed -i "/realtime:/,/environment:/{
      /environment:/a\\${indent}DB_ENC_KEY: \${DB_ENC_KEY}
    }" docker-compose.yml
    ok "   DB_ENC_KEY ajoutée avec indentation correcte"
  fi

  # Ajouter APP_NAME dans section realtime si absent
  if ! grep -q "APP_NAME:" docker-compose.yml; then
    sed -i "/realtime:/,/environment:/{
      /environment:/a\\${indent}APP_NAME: supabase_realtime
    }" docker-compose.yml
    ok "   APP_NAME ajoutée avec indentation correcte"
  fi

  # Mettre à jour SECRET_KEY_BASE
  if grep -q "SECRET_KEY_BASE:" docker-compose.yml; then
    sed -i "s/^${indent}SECRET_KEY_BASE:.*/${indent}SECRET_KEY_BASE: \${SECRET_KEY_BASE}/" docker-compose.yml
    ok "   SECRET_KEY_BASE mise à jour"
  else
    sed -i "/realtime:/,/environment:/{
      /environment:/a\\${indent}SECRET_KEY_BASE: \${SECRET_KEY_BASE}
    }" docker-compose.yml
    ok "   SECRET_KEY_BASE ajoutée"
  fi

  # VALIDATION CRITIQUE - Vérifier syntaxe YAML
  if docker compose config > /dev/null 2>&1; then
    ok "✅ Docker-compose.yml valide"
  else
    error "❌ YAML invalide après modification"
    log "Restauration fichier docker-compose.yml depuis backup..."
    return 1
  fi
}

clean_corrupted_tenant() {
  log "🧹 Nettoyage tenant corrompu..."

  # Supprimer tenant "realtime-dev" corrompu qui cause les erreurs de seeding
  docker exec -T supabase-db psql -U postgres -d postgres -c "DELETE FROM _realtime.tenants WHERE external_id = 'realtime-dev';" 2>/dev/null || warn "Table _realtime.tenants pas encore créée"

  ok "✅ Tenant corrompu nettoyé"
}

restart_realtime_service() {
  log "🔄 Redémarrage service Realtime..."

  cd "$PROJECT_DIR"

  # Arrêt propre du service
  if docker compose ps realtime | grep -q "Up"; then
    su "$TARGET_USER" -c "docker compose stop realtime"
    sleep 3
  fi

  # Supprimer conteneur pour forcer recréation avec nouvelles variables
  if docker ps -a --format '{{.Names}}' | grep -q "supabase-realtime"; then
    su "$TARGET_USER" -c "docker compose rm -f realtime"
  fi

  # Nettoyer tenant corrompu avant redémarrage
  clean_corrupted_tenant

  # Redémarrage avec nouvelles variables
  su "$TARGET_USER" -c "docker compose up -d realtime"

  ok "✅ Service Realtime redémarré"
}

validate_realtime_health() {
  log "✅ Validation santé Realtime..."

  local max_attempts=60
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    # Vérifier si conteneur est Up
    if docker ps --format '{{.Names}}\t{{.Status}}' | grep realtime | grep -q "Up"; then

      # Test endpoint santé
      if docker exec supabase-realtime curl -f http://localhost:4000/health >/dev/null 2>&1; then
        ok "✅ Realtime opérationnel et sain (${attempt}s)"
        return 0
      fi

      # Si Up mais pas healthy, continuer à attendre
      if [ $((attempt % 10)) -eq 0 ]; then
        log "⏳ Realtime démarré mais endpoint santé pas encore ready... (${attempt}s)"
      fi

    else
      # Vérifier si en restart loop
      if docker ps --format '{{.Names}}\t{{.Status}}' | grep realtime | grep -q "restarting"; then
        error "❌ Realtime toujours en boucle de redémarrage après correction"
        diagnose_realtime_detailed
        return 1
      fi

      # Autre statut
      if [ $((attempt % 15)) -eq 0 ]; then
        log "⏳ Realtime en cours de démarrage... (${attempt}s)"
      fi
    fi

    sleep 1
    ((attempt++))
  done

  error "❌ Realtime failed to become healthy after ${max_attempts}s"
  diagnose_realtime_detailed
  return 1
}

main() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                🔧 REALTIME ENCRYPTION FIX                       ║"
  echo "║                                                                  ║"
  echo "║  Correction automatique des problèmes d'encryption Realtime     ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  echo ""

  # Vérifier si correction nécessaire
  if ! detect_realtime_issue; then
    log "✅ Aucune correction Realtime nécessaire"
    return 0
  fi

  log "🎯 Début correction automatique Realtime..."

  # Diagnostic initial
  diagnose_realtime_detailed

  # Étapes de correction
  fix_schema_migrations_structure
  generate_proper_encryption_keys
  update_environment_file
  update_docker_compose_safely
  restart_realtime_service

  # Validation
  if validate_realtime_health; then
    echo ""
    ok "🎉 CORRECTION REALTIME RÉUSSIE"
    echo "   Realtime est maintenant opérationnel avec encryption corrigée"
  else
    echo ""
    error "❌ CORRECTION ÉCHOUÉE - Investigation manuelle requise"
    echo "   Voir diagnostic ci-dessus pour détails"
    return 1
  fi
}

# Exécution si script appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "$EUID" -ne 0 ]]; then
    echo "Usage: sudo $0"
    exit 1
  fi

  main "$@"
fi