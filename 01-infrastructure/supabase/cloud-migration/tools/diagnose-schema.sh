#!/bin/bash

# ============================================================
# Script de diagnostic post-migration - Vérification schéma
# ============================================================
# Version: 1.0.0
# Usage: ./diagnose-schema.sh <PI_IP> <SCHEMA_NAME>
# ============================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC}  $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

# Paramètres
PI_IP="${1:-}"
SCHEMA_NAME="${2:-Certidoc}"

if [ -z "$PI_IP" ]; then
    echo "Usage: $0 <PI_IP> [SCHEMA_NAME]"
    echo "Exemple: $0 192.168.1.74 Certidoc"
    exit 1
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Diagnostic Migration Supabase            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

log_info "Connexion au Pi: $PI_IP"
log_info "Schéma cible: $SCHEMA_NAME"
echo ""

# Récupérer le mot de passe PostgreSQL
log_info "Récupération configuration PostgreSQL..."
PI_DB_PASSWORD=$(ssh pi@${PI_IP} "cat ~/stacks/supabase/.env 2>/dev/null | grep POSTGRES_PASSWORD | cut -d'=' -f2")

if [ -z "$PI_DB_PASSWORD" ]; then
    PI_DB_PASSWORD=$(ssh pi@${PI_IP} "cat ~/supabase/.env 2>/dev/null | grep POSTGRES_PASSWORD | cut -d'=' -f2")
fi

if [ -z "$PI_DB_PASSWORD" ]; then
    log_error "Impossible de récupérer le mot de passe PostgreSQL"
    exit 1
fi

log_success "Configuration récupérée"
echo ""

# ============================================================
# DIAGNOSTIC 1 : Schémas existants
# ============================================================

log_info "📋 Schémas PostgreSQL existants:"
echo ""

ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres -c '\dn+'" 2>/dev/null

echo ""

# ============================================================
# DIAGNOSTIC 2 : Tables par schéma
# ============================================================

log_info "📊 Nombre de tables par schéma:"
echo ""

ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres -t -c \"
SELECT
    schemaname,
    COUNT(*) as table_count
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
GROUP BY schemaname
ORDER BY schemaname;
\"" 2>/dev/null

echo ""

# ============================================================
# DIAGNOSTIC 3 : Tables dans le schéma cible
# ============================================================

log_info "📦 Tables dans le schéma '$SCHEMA_NAME':"
echo ""

TABLE_COUNT=$(ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres -t -c \"
SELECT COUNT(*)
FROM information_schema.tables
WHERE table_schema = '$SCHEMA_NAME';
\"" 2>/dev/null | xargs)

if [ "$TABLE_COUNT" -eq 0 ]; then
    log_warning "Aucune table trouvée dans le schéma '$SCHEMA_NAME'"
    echo ""
    log_info "Vérification dans le schéma 'public'..."
    echo ""

    PUBLIC_COUNT=$(ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres -t -c \"
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE';
    \"" 2>/dev/null | xargs)

    log_info "Tables dans 'public': $PUBLIC_COUNT"

    if [ "$PUBLIC_COUNT" -gt 0 ]; then
        log_warning "Les tables ont été créées dans 'public' au lieu de '$SCHEMA_NAME' !"
        echo ""
        log_info "Liste des tables dans 'public':"
        ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres -c \"
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public' AND tablename NOT LIKE 'pg_%'
        ORDER BY tablename;
        \"" 2>/dev/null
    fi
else
    log_success "$TABLE_COUNT tables trouvées dans '$SCHEMA_NAME'"
    echo ""
    ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres -c \"
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = '$SCHEMA_NAME'
    ORDER BY tablename;
    \"" 2>/dev/null
fi

echo ""

# ============================================================
# DIAGNOSTIC 4 : Dump SQL Analysis
# ============================================================

log_info "🔍 Analyse du dump sur le Pi (si présent):"
echo ""

if ssh pi@${PI_IP} "test -f ~/supabase_migration.sql" 2>/dev/null; then
    log_success "Dump trouvé sur le Pi"

    # Compter les occurrences de "CREATE TABLE"
    CREATE_COUNT=$(ssh pi@${PI_IP} "grep -c 'CREATE TABLE' ~/supabase_migration.sql || true")
    log_info "Commandes CREATE TABLE: $CREATE_COUNT"

    # Vérifier si le dump contient le schéma cible
    SCHEMA_COUNT=$(ssh pi@${PI_IP} "grep -c '$SCHEMA_NAME\\.' ~/supabase_migration.sql || true")
    log_info "Références à '$SCHEMA_NAME.': $SCHEMA_COUNT"

    # Vérifier si le dump contient encore 'public.'
    PUBLIC_REF=$(ssh pi@${PI_IP} "grep -c 'public\\.' ~/supabase_migration.sql || true")
    log_info "Références à 'public.': $PUBLIC_REF"

    if [ "$PUBLIC_REF" -gt 0 ] && [ "$SCHEMA_COUNT" -eq 0 ]; then
        log_error "Le dump contient encore des références à 'public.' !"
        log_warning "La substitution sed n'a pas fonctionné correctement"
    fi
else
    log_warning "Dump non trouvé sur le Pi (déjà supprimé)"
fi

echo ""

# ============================================================
# DIAGNOSTIC 5 : Auth Users
# ============================================================

log_info "👥 Utilisateurs Auth:"
echo ""

AUTH_COUNT=$(ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres -t -c 'SELECT COUNT(*) FROM auth.users;' 2>/dev/null" | xargs || echo "0")

log_info "Total utilisateurs: $AUTH_COUNT"

echo ""

# ============================================================
# RÉSUMÉ
# ============================================================

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}📋 RÉSUMÉ DIAGNOSTIC${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

if [ "$TABLE_COUNT" -gt 0 ]; then
    log_success "Migration réussie dans '$SCHEMA_NAME'"
    log_info "Prochaines étapes:"
    echo "  1. Configurer client Supabase: db: { schema: '$SCHEMA_NAME' }"
    echo "  2. Tester les requêtes dans Studio (sélectionner schéma '$SCHEMA_NAME')"
else
    log_error "Migration incomplète - Tables non trouvées dans '$SCHEMA_NAME'"
    log_info "Actions correctives possibles:"
    echo ""
    echo "  Option 1 - Migrer les tables de public → $SCHEMA_NAME:"
    echo "    ssh pi@$PI_IP"
    echo "    PGPASSWORD=\$PASSWORD psql -h localhost -U postgres -d postgres -c \"ALTER SCHEMA public RENAME TO ${SCHEMA_NAME}_temp;\""
    echo "    PGPASSWORD=\$PASSWORD psql -h localhost -U postgres -d postgres -c \"CREATE SCHEMA public;\""
    echo "    PGPASSWORD=\$PASSWORD psql -h localhost -U postgres -d postgres -c \"ALTER SCHEMA ${SCHEMA_NAME}_temp RENAME TO $SCHEMA_NAME;\""
    echo ""
    echo "  Option 2 - Relancer migration avec script amélioré:"
    echo "    ./migrate-cloud-to-pi.sh --schema $SCHEMA_NAME"
fi

echo ""
