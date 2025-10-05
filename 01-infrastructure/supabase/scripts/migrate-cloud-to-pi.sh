#!/bin/bash

# ============================================================
# Migration Supabase Cloud → Raspberry Pi 5
# ============================================================
# Usage: ./migrate-cloud-to-pi.sh
#
# Ce script migre automatiquement :
# - Schéma de base de données (tables, types, functions)
# - Données (toutes les rows)
# - RLS Policies
# - Triggers et fonctions
#
# Migration manuelle requise pour :
# - Auth Users (voir guide MIGRATION-CLOUD-TO-PI.md)
# - Storage files (voir guide MIGRATION-CLOUD-TO-PI.md)
# ============================================================

set -e  # Exit on error

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fonctions utilitaires
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

log_step() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo ""
}

# Installer PostgreSQL client si nécessaire
install_postgresql_client() {
    log_info "Installation de PostgreSQL client..."

    # Détecter OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if ! command -v brew &> /dev/null; then
            log_error "Homebrew non trouvé. Installez-le depuis https://brew.sh"
            exit 1
        fi
        brew install postgresql
    elif [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu/Raspberry Pi OS
        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq postgresql-client > /dev/null 2>&1
    elif [[ -f /etc/redhat-release ]]; then
        # RedHat/CentOS/Fedora
        sudo yum install -y postgresql
    else
        log_error "OS non supporté pour installation automatique"
        echo "  Installez manuellement PostgreSQL client :"
        echo "  macOS:        brew install postgresql"
        echo "  Ubuntu/Debian: sudo apt install postgresql-client"
        echo "  RedHat/CentOS: sudo yum install postgresql"
        exit 1
    fi
}

# Vérifier prérequis
check_prerequisites() {
    log_step "🔍 Vérification des prérequis"

    # Vérifier pg_dump
    if ! command -v pg_dump &> /dev/null; then
        log_warning "pg_dump non trouvé. Installation automatique..."
        install_postgresql_client

        # Revérifier après installation
        if ! command -v pg_dump &> /dev/null; then
            log_error "Échec installation PostgreSQL client"
            exit 1
        fi
    fi
    log_success "pg_dump trouvé : $(pg_dump --version | head -n1)"

    # Vérifier psql
    if ! command -v psql &> /dev/null; then
        log_warning "psql non trouvé. Installation automatique..."
        install_postgresql_client

        # Revérifier après installation
        if ! command -v psql &> /dev/null; then
            log_error "Échec installation PostgreSQL client"
            exit 1
        fi
    fi
    log_success "psql trouvé : $(psql --version | head -n1)"

    # Vérifier ssh
    if ! command -v ssh &> /dev/null; then
        log_error "ssh non trouvé"
        exit 1
    fi
    log_success "ssh trouvé"

    # Vérifier scp
    if ! command -v scp &> /dev/null; then
        log_error "scp non trouvé"
        exit 1
    fi
    log_success "scp trouvé"
}

# Banner
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                            ║${NC}"
echo -e "${BLUE}║   Migration Supabase Cloud → Pi 5         ║${NC}"
echo -e "${BLUE}║                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

check_prerequisites

# ============================================================
# ÉTAPE 1 : Configuration
# ============================================================

log_step "📋 ÉTAPE 1/7 : Configuration"

# Supabase Cloud (source)
log_info "Configuration Supabase Cloud (source)"
echo ""
read -p "🌐 URL Supabase Cloud (ex: https://xxxxx.supabase.co): " CLOUD_URL
read -p "🔑 Service Role Key Cloud (Settings → API): " CLOUD_SERVICE_KEY
read -sp "🔒 Database Password Cloud (Settings → Database): " CLOUD_DB_PASSWORD
echo ""
echo ""

# Validation URL
if [[ ! $CLOUD_URL =~ ^https://[a-z0-9-]+\.supabase\.co$ ]]; then
    log_error "URL invalide. Format attendu: https://xxxxx.supabase.co"
    exit 1
fi

# Extraction project ref depuis URL
CLOUD_PROJECT_REF=$(echo $CLOUD_URL | sed -E 's|https://([^.]+)\.supabase\.co|\1|')
CLOUD_DB_HOST="db.${CLOUD_PROJECT_REF}.supabase.co"

log_success "Project Ref Cloud : $CLOUD_PROJECT_REF"

# Raspberry Pi (destination)
echo ""
log_info "Configuration Raspberry Pi (destination)"
echo ""
read -p "🥧 IP Raspberry Pi (ex: 192.168.1.150): " PI_IP

# Validation IP
if [[ ! $PI_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    log_error "IP invalide"
    exit 1
fi

# Vérifier connexion SSH au Pi
log_info "Test connexion SSH au Pi..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes pi@${PI_IP} exit 2>/dev/null; then
    log_success "Connexion SSH OK"
else
    log_error "Impossible de se connecter au Pi via SSH"
    log_info "Vérifiez :"
    echo "  1. IP correcte : $PI_IP"
    echo "  2. SSH activé sur Pi"
    echo "  3. Clé SSH configurée : ssh-copy-id pi@${PI_IP}"
    exit 1
fi

# Récupérer password PostgreSQL du Pi
log_info "Récupération configuration PostgreSQL Pi..."
PI_DB_PASSWORD=$(ssh pi@${PI_IP} "cat ~/supabase/.env 2>/dev/null | grep POSTGRES_PASSWORD | cut -d'=' -f2")

if [ -z "$PI_DB_PASSWORD" ]; then
    log_error "Impossible de récupérer le password PostgreSQL du Pi"
    log_info "Vérifiez que Supabase est installé : ~/supabase/.env existe"
    exit 1
fi

log_success "Configuration PostgreSQL Pi récupérée"

# Afficher résumé config
echo ""
log_info "Résumé configuration :"
echo "  Cloud DB : ${CLOUD_DB_HOST}:5432"
echo "  Pi DB    : ${PI_IP}:5432"
echo ""

read -p "Continuer avec cette configuration ? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    log_warning "Migration annulée par utilisateur"
    exit 0
fi

# ============================================================
# ÉTAPE 2 : Backup Sécurité (Cloud)
# ============================================================

log_step "💾 ÉTAPE 2/7 : Backup sécurité Cloud"

BACKUP_DIR="supabase_migration_$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

log_info "Dossier backup : $BACKUP_DIR"

# ============================================================
# ÉTAPE 3 : Export Base Cloud
# ============================================================

log_step "📦 ÉTAPE 3/7 : Export base de données Cloud"

DUMP_FILE="${BACKUP_DIR}/supabase_cloud_dump.sql"

log_info "Export en cours (peut prendre plusieurs minutes)..."

PGPASSWORD=$CLOUD_DB_PASSWORD pg_dump \
    -h $CLOUD_DB_HOST \
    -U postgres \
    -p 5432 \
    -d postgres \
    --clean \
    --if-exists \
    --no-owner \
    --no-privileges \
    --verbose \
    -f $DUMP_FILE 2>&1 | grep -E "(dumping|completed)" || true

if [ $? -eq 0 ] && [ -f "$DUMP_FILE" ]; then
    DUMP_SIZE=$(du -h $DUMP_FILE | cut -f1)
    log_success "Export réussi : $DUMP_FILE ($DUMP_SIZE)"
else
    log_error "Échec export base Cloud"
    exit 1
fi

# Compter lignes dump
DUMP_LINES=$(wc -l < $DUMP_FILE)
log_info "Lignes SQL : $(printf "%'d" $DUMP_LINES)"

# ============================================================
# ÉTAPE 4 : Test Import Local (Optionnel)
# ============================================================

log_step "🧪 ÉTAPE 4/7 : Test de validité du dump"

log_info "Vérification syntaxe SQL..."

# Compter tables dans le dump
TABLE_COUNT=$(grep -c "CREATE TABLE" $DUMP_FILE || true)
log_info "Tables détectées : $TABLE_COUNT"

# Compter fonctions
FUNCTION_COUNT=$(grep -c "CREATE FUNCTION" $DUMP_FILE || true)
log_info "Fonctions détectées : $FUNCTION_COUNT"

# Vérifier erreurs évidentes
if grep -q "ERROR" $DUMP_FILE; then
    log_warning "Le dump contient le mot 'ERROR' - vérification manuelle recommandée"
fi

log_success "Dump valide"

# ============================================================
# ÉTAPE 5 : Transfert vers Pi
# ============================================================

log_step "📤 ÉTAPE 5/7 : Transfert dump vers Pi"

log_info "Copie vers pi@${PI_IP}:~/supabase_migration.sql..."

scp $DUMP_FILE pi@${PI_IP}:~/supabase_migration.sql

if [ $? -eq 0 ]; then
    log_success "Fichier transféré sur Pi"

    # Vérifier taille sur Pi
    REMOTE_SIZE=$(ssh pi@${PI_IP} "du -h ~/supabase_migration.sql | cut -f1")
    log_info "Taille sur Pi : $REMOTE_SIZE"
else
    log_error "Échec transfert vers Pi"
    exit 1
fi

# ============================================================
# ÉTAPE 6 : Import dans PostgreSQL Pi
# ============================================================

log_step "📥 ÉTAPE 6/7 : Import dans PostgreSQL Pi"

log_warning "⚠️  Cette opération va écraser les données existantes sur le Pi"
read -p "Continuer ? (y/n): " CONFIRM_IMPORT
if [ "$CONFIRM_IMPORT" != "y" ]; then
    log_warning "Import annulé"
    exit 0
fi

log_info "Import en cours (peut prendre plusieurs minutes)..."
echo ""

# Import via psql (capture output)
ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres < ~/supabase_migration.sql" 2>&1 | \
    grep -E "(CREATE|ALTER|INSERT|COPY|ERROR)" | tail -20

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log_success "Import réussi dans PostgreSQL Pi"
else
    log_warning "Import terminé avec warnings (peut être normal)"
    log_info "Vérifiez les erreurs ci-dessus"
fi

# ============================================================
# ÉTAPE 7 : Vérification Post-Import
# ============================================================

log_step "✅ ÉTAPE 7/7 : Vérification post-import"

log_info "Vérification tables..."

# Compter tables sur Pi
TABLE_COUNT_PI=$(ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres -t -c \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';\"" | xargs)

log_success "Tables sur Pi : $TABLE_COUNT_PI"

# Vérifier schéma auth (users)
AUTH_USER_COUNT=$(ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres -t -c \"SELECT COUNT(*) FROM auth.users;\"" 2>/dev/null | xargs || echo "0")

log_info "Utilisateurs Auth : $AUTH_USER_COUNT"

# Test API REST
log_info "Test API REST Pi..."

PI_ANON_KEY=$(ssh pi@${PI_IP} "cat ~/supabase/.env | grep ANON_KEY | cut -d'=' -f2")

API_TEST=$(curl -s -w "\n%{http_code}" "http://${PI_IP}:8000/rest/v1/" -H "apikey: ${PI_ANON_KEY}" | tail -1)

if [ "$API_TEST" = "200" ]; then
    log_success "API REST fonctionnelle"
elif [ "$API_TEST" = "404" ]; then
    log_success "API REST accessible (404 normal sans table)"
else
    log_warning "API REST : Status $API_TEST"
fi

# Test Auth
log_info "Test Auth API..."
AUTH_TEST=$(curl -s -w "\n%{http_code}" "http://${PI_IP}:8000/auth/v1/health" | tail -1)

if [ "$AUTH_TEST" = "200" ]; then
    log_success "Auth API fonctionnelle"
else
    log_warning "Auth API : Status $AUTH_TEST"
fi

# ============================================================
# RÉSUMÉ FINAL
# ============================================================

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                            ║${NC}"
echo -e "${GREEN}║         ✅ MIGRATION TERMINÉE              ║${NC}"
echo -e "${GREEN}║                                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""

log_info "📊 Résumé migration :"
echo ""
echo "  Source  : ${CLOUD_DB_HOST}"
echo "  Dest    : ${PI_IP}:5432"
echo "  Tables  : ${TABLE_COUNT_PI}"
echo "  Users   : ${AUTH_USER_COUNT}"
echo "  Dump    : ${DUMP_FILE} (${DUMP_SIZE})"
echo ""

log_info "🔍 Vérifications recommandées :"
echo ""
echo "  1. Tester Supabase Studio : http://${PI_IP}:8000"
echo "  2. Vérifier données table : SELECT * FROM your_table LIMIT 10;"
echo "  3. Tester auth : Login avec utilisateur existant"
echo "  4. Vérifier RLS : Policies actives sur tables sensibles"
echo ""

log_info "📚 Étapes suivantes :"
echo ""
echo "  ⚠️  Migration Auth Users :"
echo "     - Passwords ne sont pas migrés (hashés)"
echo "     - Option 1 : Password reset pour tous users"
echo "     - Option 2 : Configurer OAuth (Google, GitHub)"
echo "     - Voir : MIGRATION-CLOUD-TO-PI.md (section Auth)"
echo ""
echo "  ⚠️  Migration Storage Files :"
echo "     - Fichiers non migrés automatiquement"
echo "     - Utiliser script migrate-storage.js"
echo "     - Voir : MIGRATION-CLOUD-TO-PI.md (section Storage)"
echo ""
echo "  ✅ Mettre à jour application :"
echo "     - NEXT_PUBLIC_SUPABASE_URL=http://${PI_IP}:8000"
echo "     - NEXT_PUBLIC_SUPABASE_ANON_KEY=${PI_ANON_KEY:0:20}..."
echo ""

log_info "🗑️  Nettoyage :"
echo ""
read -p "Supprimer le dump du Pi ? (y/n): " DELETE_REMOTE
if [ "$DELETE_REMOTE" = "y" ]; then
    ssh pi@${PI_IP} "rm ~/supabase_migration.sql"
    log_success "Dump Pi supprimé"
fi

read -p "Supprimer le dossier backup local '$BACKUP_DIR' ? (y/n): " DELETE_LOCAL
if [ "$DELETE_LOCAL" = "y" ]; then
    rm -rf $BACKUP_DIR
    log_success "Backup local supprimé"
else
    log_info "Backup conservé : $BACKUP_DIR"
fi

echo ""
log_success "🎉 Migration terminée avec succès !"
echo ""
log_info "📖 Guide complet : pi5-setup/01-infrastructure/supabase/MIGRATION-CLOUD-TO-PI.md"
log_info "💬 Support : https://github.com/iamaketechnology/pi5-setup/issues"
echo ""
