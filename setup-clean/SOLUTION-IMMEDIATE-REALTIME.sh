#!/usr/bin/env bash
set -euo pipefail

# === SOLUTION IMMÉDIATE REALTIME - Fix rapide basé sur sugestionia.md ===

log()  { echo -e "\\033[1;36m[FIX]\\033[0m $*"; }
warn() { echo -e "\\033[1;33m[WARN]\\033[0m $*"; }
ok()   { echo -e "\\033[1;32m[OK]\\033[0m $*"; }
error() { echo -e "\\033[1;31m[ERROR]\\033[0m $*"; }

# Variables
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/$TARGET_USER/stacks/supabase"

fix_immediate() {
  log "🚀 Fix immédiat Realtime basé sur recherche confirmée..."

  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "❌ Répertoire Supabase non trouvé: $PROJECT_DIR"
    exit 1
  fi

  cd "$PROJECT_DIR"

  # 1) Générer clé d'encryption EXACTEMENT 16 caractères ASCII
  log "🔑 Génération DB_ENC_KEY (16 chars)..."
  DB_ENC_KEY=$(openssl rand -hex 8)   # 8 octets -> 16 hexdigits
  echo "DB_ENC_KEY=$DB_ENC_KEY" | tee -a .env
  ok "   DB_ENC_KEY: $DB_ENC_KEY"

  # 2) Forcer SECRET_KEY_BASE à 64 chars
  log "🔑 Génération SECRET_KEY_BASE (64 chars)..."
  SECRET_KEY_BASE=$(openssl rand -hex 32)  # 64 hexdigits
  echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" | tee -a .env
  ok "   SECRET_KEY_BASE: ${SECRET_KEY_BASE:0:16}..."

  # 3) Ajouter variables au docker-compose.yml
  log "📝 Mise à jour docker-compose.yml..."

  # Ajouter DB_ENC_KEY
  if ! grep -q "DB_ENC_KEY" docker-compose.yml; then
    sed -i '/realtime:/,/environment:/{
      /environment:/a\
      DB_ENC_KEY: ${DB_ENC_KEY}
    }' docker-compose.yml
    ok "   DB_ENC_KEY ajoutée au docker-compose.yml"
  fi

  # Mettre à jour SECRET_KEY_BASE
  if grep -q "SECRET_KEY_BASE:" docker-compose.yml; then
    sed -i 's/^\(\s*SECRET_KEY_BASE:\).*/\1 ${SECRET_KEY_BASE}/' docker-compose.yml
    ok "   SECRET_KEY_BASE mise à jour"
  else
    sed -i '/realtime:/,/environment:/{
      /environment:/a\
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
    }' docker-compose.yml
    ok "   SECRET_KEY_BASE ajoutée"
  fi

  # 4) Ajouter variables ARM64 supplémentaires
  log "🔧 Ajout variables ARM64..."
  sed -i '/realtime:/,/environment:/{
    /environment:/a\
      APP_NAME: supabase_realtime\
      ERL_AFLAGS: -proto_dist inet_tcp\
      DNS_NODES: ""\
      DB_IP_VERSION: ipv4\
      SEED_SELF_HOST: "true"
  }' docker-compose.yml

  # 5) Nettoyer tenant corrompu
  log "🧹 Nettoyage tenant corrompu..."
  docker exec -T supabase-db psql -U postgres -d postgres -c "DELETE FROM _realtime.tenants WHERE external_id = 'realtime-dev';" 2>/dev/null || warn "Table _realtime.tenants pas encore créée"

  # 6) Recréer uniquement Realtime
  log "🔄 Redémarrage Realtime..."
  su "$TARGET_USER" -c "docker compose stop realtime" || true
  su "$TARGET_USER" -c "docker compose rm -f realtime" || true
  su "$TARGET_USER" -c "docker compose up -d realtime"

  # 7) Vérification
  log "✅ Vérification status..."
  sleep 10

  if docker ps --format '{{.Names}}\t{{.Status}}' | grep realtime | grep -q "Up"; then
    ok "🎉 REALTIME CORRIGÉ ET OPÉRATIONNEL !"

    # Vérifications bonus
    echo ""
    echo "📋 VÉRIFICATIONS FINALES:"
    echo ""

    echo "🔍 Variables reçues par Realtime:"
    docker exec supabase-realtime env 2>/dev/null | egrep 'DB_ENC_KEY|SECRET_KEY_BASE|API_JWT_SECRET' | sed 's/^/  /' || echo "  Variables non accessibles (normal si restart en cours)"

    echo ""
    echo "🔍 Table tenants:"
    docker exec -T supabase-db psql -U postgres -d postgres -c "SELECT COUNT(*) as tenant_count FROM _realtime.tenants;" 2>/dev/null | sed 's/^/  /' || echo "  Table pas encore créée"

    echo ""
    echo "🔍 Status conteneurs:"
    docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E "(realtime|auth|rest)" | sed 's/^/  /'

  else
    error "❌ Realtime toujours en problème"
    echo ""
    echo "📋 LOGS RÉCENTS:"
    docker logs supabase-realtime --tail=20 2>&1 | sed 's/^/  /'
    echo ""
    echo "Essaye d'attendre 30 secondes de plus puis vérifie:"
    echo "  docker ps | grep realtime"
    echo "  docker logs supabase-realtime --tail=50"
  fi
}

# Vérification root
if [[ "$EUID" -ne 0 ]]; then
  echo "Usage: sudo $0"
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║            🚀 SOLUTION IMMÉDIATE REALTIME                       ║"
echo "║                                                                  ║"
echo "║  Fix rapide basé sur recherche confirmée sugestionia.md         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

fix_immediate