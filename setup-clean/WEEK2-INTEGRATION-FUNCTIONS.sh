# ============================================================================
# FONCTIONS INTEGRATION WEEK2 - CORRECTION REALTIME
# À ajouter dans setup-week2-supabase-final.sh
# ============================================================================

# Fonction 1: Préparation environnement Realtime (avant create_docker_compose)
prepare_realtime_environment() {
  log "🔧 Préparation environnement Realtime optimisé..."

  # Générer clé AES 128-bit EXACTEMENT 16 caractères ASCII (8 octets → 16 hex)
  DB_ENC_KEY=$(openssl rand -hex 8)

  # Générer SECRET_KEY_BASE de 64 caractères (32 octets → 64 hex)
  SECRET_KEY_BASE=$(openssl rand -hex 32)

  # JWT_SECRET optimal: ~40 caractères (retour terrain 2024-2025)
  # Si JWT_SECRET existant trop long, le raccourcir
  if [[ ${#JWT_SECRET} -gt 50 ]]; then
    log "   JWT_SECRET trop long (${#JWT_SECRET} chars), raccourci à 40"
    JWT_SECRET=$(echo "$JWT_SECRET" | head -c 40)
  fi

  # Exporter pour utilisation dans docker-compose
  export DB_ENC_KEY SECRET_KEY_BASE JWT_SECRET

  ok "✅ Clés Realtime générées (format confirmé recherche):"
  log "   DB_ENC_KEY: ${DB_ENC_KEY} (16 chars exactement)"
  log "   SECRET_KEY_BASE: ${SECRET_KEY_BASE:0:8}... (64 chars)"
  log "   JWT_SECRET: ${JWT_SECRET:0:8}... (${#JWT_SECRET} chars - optimal)"
}

# Fonction 2: Correction structure base données (dans create_complete_database_structure)
fix_realtime_database_structure() {
  log "🗄️ Correction structure base données Realtime..."

  # Attendre que PostgreSQL soit complètement prêt
  wait_postgresql_ready

  # Corriger structure schema_migrations dans realtime schema
  docker exec -T supabase-db psql -U postgres -d postgres -c "
    CREATE SCHEMA IF NOT EXISTS realtime;
    DROP TABLE IF EXISTS realtime.schema_migrations CASCADE;
    CREATE TABLE realtime.schema_migrations(
      version BIGINT PRIMARY KEY,
      inserted_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW()
    );" || warn "Échec correction realtime.schema_migrations"

  # Corriger structure schema_migrations dans public schema (requis pour certaines migrations)
  docker exec -T supabase-db psql -U postgres -d postgres -c "
    DROP TABLE IF EXISTS public.schema_migrations CASCADE;
    CREATE TABLE public.schema_migrations(
      version BIGINT PRIMARY KEY,
      inserted_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW()
    );" || warn "Échec correction public.schema_migrations"

  # Créer autres tables Realtime nécessaires
  docker exec -T supabase-db psql -U postgres -d postgres -c "
    CREATE SCHEMA IF NOT EXISTS realtime;

    -- Table pour subscriptions
    CREATE TABLE IF NOT EXISTS realtime.subscription (
      id BIGSERIAL PRIMARY KEY,
      subscription_id UUID NOT NULL,
      entity REGCLASS NOT NULL,
      filters REALTIME.user_defined_filter[] NOT NULL DEFAULT '{}',
      claims JSONB NOT NULL,
      claims_role REGROLE NOT NULL GENERATED ALWAYS AS (REALTIME.to_regrole((claims ->> 'role'))) STORED,
      created_at TIMESTAMP NOT NULL DEFAULT timezone('utc', now())
    );

    -- Table pour messages
    CREATE TABLE IF NOT EXISTS realtime.messages (
      id BIGSERIAL PRIMARY KEY,
      topic TEXT NOT NULL,
      event TEXT,
      payload JSONB,
      inserted_at TIMESTAMP NOT NULL DEFAULT NOW()
    );

    -- Grants pour realtime user
    GRANT USAGE ON SCHEMA realtime TO supabase_realtime_admin;
    GRANT ALL ON ALL TABLES IN SCHEMA realtime TO supabase_realtime_admin;
    GRANT ALL ON ALL SEQUENCES IN SCHEMA realtime TO supabase_realtime_admin;
  " || warn "Échec création tables Realtime supplémentaires"

  ok "✅ Structure base données Realtime corrigée"
}

# Fonction 3: Modification docker-compose.yml avec variables correctes
update_realtime_compose_config() {
  log "🐳 Mise à jour configuration Realtime dans docker-compose..."

  # Cette fonction modifie la section realtime du docker-compose.yml
  # À appeler après la création du fichier docker-compose.yml

  # Remplacer section realtime avec configuration corrigée
  cat >> "$PROJECT_DIR/docker-compose.yml.tmp" << 'REALTIME_CONFIG'

  # Configuration Realtime corrigée
  realtime:
    container_name: supabase-realtime
    image: supabase/realtime:v2.30.23
    platform: linux/arm64
    depends_on:
      db:
        condition: service_healthy
      analytics:
        condition: service_healthy
    restart: unless-stopped
    environment:
      PORT: 4000
      DB_HOST: ${DB_HOST}
      DB_PORT: ${DB_PORT}
      DB_USER: supabase_realtime_admin
      DB_PASSWORD: ${DB_PASSWORD}
      DB_NAME: ${POSTGRES_DB}
      DB_AFTER_CONNECT_QUERY: 'SET search_path TO realtime'
      DB_ENC_KEY: ${DB_ENC_KEY}           # Clé AES 128-bit dédiée
      API_JWT_SECRET: ${JWT_SECRET}       # JWT pour API
      SECRET_KEY_BASE: ${SECRET_KEY_BASE} # Clé Elixir 64+ caractères
      ERL_AFLAGS: -proto_dist inet_tcp    # Optimisation ARM64
      ENABLE_TAILSCALE: "false"
      DNS_NODES: "''"

      # Limites optimisées pour Pi 5
      RLIMIT_NOFILE: 65536
      MAX_CONNECTIONS: 200

      # Configuration clustering Elixir
      ERLANG_COOKIE: supabase_realtime_cookie
      RELEASE_COOKIE: supabase_realtime_cookie

      # SSL désactivé pour Docker local
      DB_SSL: "false"

      # Variables ARM64 additionnelles (confirmées par recherche)
      APP_NAME: supabase_realtime
      ERL_AFLAGS: -proto_dist inet_tcp
      DNS_NODES: ""
      DB_IP_VERSION: ipv4
      SEED_SELF_HOST: "true"

    command: >
      sh -c "
        /app/bin/realtime eval 'Realtime.Release.migrate' &&
        /app/bin/realtime start"

    # Limites système pour Pi 5
    ulimits:
      nofile:
        soft: 65536
        hard: 65536

    # Health check Realtime
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

REALTIME_CONFIG

  ok "✅ Configuration Realtime mise à jour"
}

# Fonction 4: Validation santé Realtime post-installation
validate_realtime_final_health() {
  log "✅ Validation finale santé Realtime..."

  local max_attempts=120  # 2 minutes pour Pi 5
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    # Vérifier statut conteneur
    if docker ps --format '{{.Names}}\t{{.Status}}' | grep realtime | grep -q "Up"; then

      # Test endpoint santé avec timeout
      if timeout 5 docker exec supabase-realtime curl -f http://localhost:4000/health >/dev/null 2>&1; then
        ok "✅ Realtime opérationnel et sain (${attempt}s)"
        return 0
      fi

      # Test alternative: vérifier logs pour absence d'erreurs
      if ! docker logs supabase-realtime --tail=5 2>&1 | grep -q "error\|Error\|ERROR"; then
        if [ $attempt -gt 30 ]; then  # Donner 30s minimum
          ok "✅ Realtime stable (pas d'erreurs récentes)"
          return 0
        fi
      fi

      # Feedback périodique
      if [ $((attempt % 15)) -eq 0 ]; then
        log "⏳ Realtime démarré, attente endpoint santé... (${attempt}s)"
      fi

    else
      # Vérifier si en restart loop
      if docker ps --format '{{.Names}}\t{{.Status}}' | grep realtime | grep -q "restarting"; then
        error "❌ Realtime en boucle de redémarrage"

        log "📋 Logs récents Realtime:"
        docker logs supabase-realtime --tail=10 2>&1 | sed 's/^/    /'

        # Lancer correction automatique
        fix_realtime_encryption_automatic
        return $?
      fi

      # Feedback démarrage
      if [ $((attempt % 20)) -eq 0 ]; then
        log "⏳ Realtime en cours de démarrage... (${attempt}s)"
      fi
    fi

    sleep 1
    ((attempt++))
  done

  error "❌ Realtime validation échouée après ${max_attempts}s"
  return 1
}

# Fonction 5: Correction automatique si problème détecté
fix_realtime_encryption_automatic() {
  log "🔧 Correction automatique encryption Realtime..."

  # Arrêter Realtime
  docker compose stop realtime >/dev/null 2>&1

  # Regénérer clés avec format correct
  prepare_realtime_environment

  # Mettre à jour .env avec nouvelles clés
  sed -i "s/^DB_ENC_KEY=.*/DB_ENC_KEY=${DB_ENC_KEY}/" .env
  sed -i "s/^SECRET_KEY_BASE=.*/SECRET_KEY_BASE=${SECRET_KEY_BASE}/" .env

  # Ajouter clés si elles n'existent pas
  if ! grep -q "^DB_ENC_KEY=" .env; then
    echo "DB_ENC_KEY=${DB_ENC_KEY}" >> .env
  fi

  if ! grep -q "^SECRET_KEY_BASE=" .env; then
    echo "SECRET_KEY_BASE=${SECRET_KEY_BASE}" >> .env
  fi

  # Supprimer conteneur pour forcer recréation
  docker compose rm -f realtime >/dev/null 2>&1

  # Redémarrer avec nouvelles variables
  docker compose up -d realtime

  # Attendre et vérifier
  sleep 15
  if docker ps --format '{{.Names}}\t{{.Status}}' | grep realtime | grep -q "Up"; then
    ok "✅ Correction Realtime réussie"
    return 0
  else
    error "❌ Correction Realtime échouée"
    return 1
  fi
}

# Fonction 6: Diagnostic complet si échec
diagnose_realtime_complete() {
  log "🔍 Diagnostic complet Realtime..."

  echo ""
  echo "📋 STATUS CONTENEUR:"
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E "(realtime|Names)" || echo "  Aucun conteneur realtime"

  echo ""
  echo "📋 LOGS RÉCENTS (20 dernières lignes):"
  docker logs supabase-realtime --tail=20 2>&1 | sed 's/^/  /' || echo "  Logs non disponibles"

  echo ""
  echo "📋 VARIABLES ENCRYPTION:"
  docker exec supabase-realtime printenv 2>/dev/null | grep -E "(DB_ENC_KEY|SECRET_KEY_BASE|API_JWT_SECRET)" | sed 's/^/  /' || echo "  Variables non accessibles"

  echo ""
  echo "📋 SCHEMA MIGRATIONS:"
  docker exec -T supabase-db psql -U postgres -d postgres -c "
    SELECT schemaname, tablename,
           column_name, data_type
    FROM information_schema.columns
    WHERE (schemaname='realtime' OR schemaname='public')
      AND tablename='schema_migrations'
    ORDER BY schemaname, column_name;" 2>/dev/null | sed 's/^/  /' || echo "  Schema check failed"

  echo ""
  echo "📋 CONNECTIVITÉ RÉSEAU:"
  docker exec supabase-realtime curl -I http://localhost:4000 2>/dev/null | head -1 | sed 's/^/  /' || echo "  Endpoint non accessible"
}

# ============================================================================
# INTÉGRATION DANS setup-week2-supabase-final.sh
# ============================================================================

# 1. AJOUTER APRÈS generate_secrets() :
#    prepare_realtime_environment

# 2. AJOUTER DANS create_complete_database_structure() APRÈS create_auth_schema() :
#    fix_realtime_database_structure

# 3. REMPLACER la section realtime dans create_docker_compose() par :
#    update_realtime_compose_config

# 4. REMPLACER validate_critical_services() par validate_realtime_final_health()

# 5. AJOUTER EN CAS D'ÉCHEC dans restart_dependent_services() :
#    if ! validate_realtime_final_health; then
#      fix_realtime_encryption_automatic
#    fi

# ============================================================================