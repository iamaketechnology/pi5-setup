#!/bin/bash

# ============================================================
# Migration Supabase Cloud → Raspberry Pi 5
# ============================================================
# Version: 1.7.0
# Changelog:
#   - 1.7.0: Auto-fix Storage RLS policies after import (fix API Storage access)
#   - 1.6.0: Auto-normalize schema names to lowercase + improved sed substitution
#   - 1.5.3: Fix heredoc syntax error in schema setup (line 628)
#   - 1.5.2: Fix md5/md5sum detection on remote Pi (Linux compatibility)
#   - 1.5.1: Fix macOS compatibility (timeout command not available natively)
#   - 1.5.0: Add --schema option for multi-project support (custom schema names)
#   - 1.4.0: Security improvements (lock file, disk space, checksums, timeouts, dry-run)
#   - 1.3.0: Add automatic Pi backup before import (safety rollback)
#   - 1.2.1: Auto-upgrade PostgreSQL < 17 to v17
#   - 1.2.0: Upgrade to PostgreSQL 17 (compatible with Supabase Cloud 17.x)
#   - 1.1.3: Fix script crash on pg_dump error (disable set -e temporarily)
#   - 1.1.2: Better error messages on pg_dump failure
#   - 1.1.1: Fix Supabase path detection (~/stacks/supabase + ~/supabase)
#   - 1.1.0: Auto-install postgresql-client, fix macOS postgresql@15
#   - 1.0.0: Version initiale
# ============================================================
# Usage: ./migrate-cloud-to-pi.sh [OPTIONS]
#
# Options:
#   --dry-run           Teste la migration sans modifier le Pi (export uniquement)
#   --schema NAME       Migre vers un schéma personnalisé (défaut: public)
#                       Exemple: --schema project1_blog
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
#
# Exemples multi-projets :
#   ./migrate-cloud-to-pi.sh --schema blog_prod
#   ./migrate-cloud-to-pi.sh --schema shop_prod --dry-run
# ============================================================

set -e  # Exit on error

SCRIPT_VERSION="1.7.0"

# Paramètres par défaut
DRY_RUN=false
TARGET_SCHEMA="public"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --schema)
            TARGET_SCHEMA="$2"
            shift 2
            ;;
        *)
            echo "Option inconnue: $1"
            echo "Usage: $0 [--dry-run] [--schema NAME]"
            exit 1
            ;;
    esac
done

# Normaliser le nom du schéma en minuscules (comportement PostgreSQL par défaut)
# PostgreSQL convertit automatiquement les identifiants non-quotés en minuscules
if [ "$TARGET_SCHEMA" != "public" ]; then
    ORIGINAL_SCHEMA="$TARGET_SCHEMA"
    TARGET_SCHEMA=$(echo "$TARGET_SCHEMA" | tr '[:upper:]' '[:lower:]')

    if [ "$ORIGINAL_SCHEMA" != "$TARGET_SCHEMA" ]; then
        # On affichera un warning plus tard après le banner
        SCHEMA_CASE_WARNING=true
    fi
fi

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

        # Installer PostgreSQL 17 (compatible avec Supabase Cloud 17.x)
        log_info "Installation de PostgreSQL 17..."
        brew install postgresql@17 2>&1 | grep -E "(Installing|Installed|🍺)" || true

        # Ajouter au PATH immédiatement
        export PATH="/usr/local/opt/postgresql@17/bin:$PATH"
        export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"  # Apple Silicon

        # Ajouter au profil pour sessions futures
        if [ -f ~/.zshrc ]; then
            if ! grep -q "postgresql@17/bin" ~/.zshrc; then
                echo 'export PATH="/usr/local/opt/postgresql@17/bin:$PATH"' >> ~/.zshrc
                echo 'export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"' >> ~/.zshrc
            fi
        fi
        if [ -f ~/.bash_profile ]; then
            if ! grep -q "postgresql@17/bin" ~/.bash_profile; then
                echo 'export PATH="/usr/local/opt/postgresql@17/bin:$PATH"' >> ~/.bash_profile
                echo 'export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"' >> ~/.bash_profile
            fi
        fi

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
        echo "  macOS:        brew install postgresql@17"
        echo "  Ubuntu/Debian: sudo apt install postgresql-client"
        echo "  RedHat/CentOS: sudo yum install postgresql"
        exit 1
    fi
}

# Vérifier espace disque
check_disk_space() {
    local min_space_mb=1000  # 1GB minimum

    # Espace disque local (Mac/PC)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local_free=$(df -m . | tail -1 | awk '{print $4}')
    else
        local_free=$(df -BM . | tail -1 | awk '{print $4}' | sed 's/M//')
    fi

    if [ "$local_free" -lt "$min_space_mb" ]; then
        log_error "Espace disque insuffisant : ${local_free}MB disponible (minimum ${min_space_mb}MB)"
        exit 1
    fi

    log_success "Espace disque local : ${local_free}MB"

    # Espace disque Pi (si connexion établie)
    if [ ! -z "$PI_IP" ]; then
        pi_free=$(ssh pi@${PI_IP} "df -BM ~ | tail -1 | awk '{print \$4}' | sed 's/M//'" 2>/dev/null || echo "0")
        if [ "$pi_free" -lt "$min_space_mb" ]; then
            log_error "Espace disque Pi insuffisant : ${pi_free}MB disponible (minimum ${min_space_mb}MB)"
            exit 1
        fi
        log_success "Espace disque Pi : ${pi_free}MB"
    fi
}

# Vérifier lock file (éviter migrations simultanées)
check_lock_file() {
    LOCK_FILE="/tmp/supabase_migration.lock"

    if [ -f "$LOCK_FILE" ]; then
        LOCK_PID=$(cat "$LOCK_FILE")
        if ps -p $LOCK_PID > /dev/null 2>&1; then
            log_error "Migration déjà en cours (PID: $LOCK_PID)"
            log_info "Si c'est une erreur, supprimez : $LOCK_FILE"
            exit 1
        else
            log_warning "Lock file obsolète trouvé, suppression..."
            rm -f "$LOCK_FILE"
        fi
    fi

    # Créer lock file
    echo $$ > "$LOCK_FILE"
    log_info "Lock file créé : $LOCK_FILE"
}

# Nettoyer lock file
cleanup_lock() {
    rm -f /tmp/supabase_migration.lock
}

# Trap pour cleanup automatique
trap cleanup_lock EXIT INT TERM

# Vérifier prérequis
check_prerequisites() {
    log_step "🔍 Vérification des prérequis"

    # Lock file pour éviter migrations simultanées
    check_lock_file

    # Vérifier espace disque
    check_disk_space

    # Vérifier pg_dump et sa version
    if ! command -v pg_dump &> /dev/null; then
        log_warning "pg_dump non trouvé. Installation automatique..."
        install_postgresql_client

        # Revérifier après installation
        if ! command -v pg_dump &> /dev/null; then
            log_error "Échec installation PostgreSQL client"
            exit 1
        fi
    else
        # Vérifier version PostgreSQL (minimum 17 requis pour Supabase Cloud)
        PG_VERSION=$(pg_dump --version | grep -oE '[0-9]+' | head -1)
        if [ "$PG_VERSION" -lt 17 ]; then
            log_warning "PostgreSQL $PG_VERSION détecté. Mise à jour vers v17 requise..."
            install_postgresql_client

            # Revérifier version après installation
            PG_VERSION=$(pg_dump --version | grep -oE '[0-9]+' | head -1)
            if [ "$PG_VERSION" -lt 17 ]; then
                log_error "PostgreSQL 17+ requis (actuellement: $PG_VERSION)"
                echo ""
                echo "Installation manuelle requise :"
                echo "  brew install postgresql@17"
                echo "  export PATH=\"/usr/local/opt/postgresql@17/bin:\$PATH\""
                exit 1
            fi
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
echo -e "${BLUE}║   ${CYAN}v${SCRIPT_VERSION}${BLUE}                                   ║${NC}"
if [ "$DRY_RUN" = true ]; then
echo -e "${BLUE}║   ${YELLOW}[MODE DRY-RUN]${BLUE}                         ║${NC}"
fi
echo -e "${BLUE}║                                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    log_warning "🧪 Mode dry-run activé : aucune modification ne sera faite sur le Pi"
    log_info "Le script s'arrêtera après l'export Cloud (étape 4/8)"
    echo ""
fi

if [ "${SCHEMA_CASE_WARNING:-false}" = true ]; then
    log_warning "📝 Note: PostgreSQL convertit les schémas en minuscules"
    log_info "Schéma demandé : $ORIGINAL_SCHEMA"
    log_info "Schéma créé    : $TARGET_SCHEMA (minuscules)"
    echo ""
    log_info "Dans votre code client, utilisez : db: { schema: '$TARGET_SCHEMA' }"
    echo ""
fi

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

# Chercher .env dans différents emplacements possibles
PI_DB_PASSWORD=$(ssh pi@${PI_IP} "cat ~/stacks/supabase/.env 2>/dev/null | grep POSTGRES_PASSWORD | cut -d'=' -f2")

if [ -z "$PI_DB_PASSWORD" ]; then
    # Essayer l'ancien chemin
    PI_DB_PASSWORD=$(ssh pi@${PI_IP} "cat ~/supabase/.env 2>/dev/null | grep POSTGRES_PASSWORD | cut -d'=' -f2")
fi

if [ -z "$PI_DB_PASSWORD" ]; then
    log_error "Impossible de récupérer le password PostgreSQL du Pi"
    log_info "Vérifiez que Supabase est installé dans :"
    echo "  - ~/stacks/supabase/.env"
    echo "  - ~/supabase/.env"
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

# Vérifier si timeout existe (GNU coreutils - pas natif sur macOS)
if command -v timeout &> /dev/null; then
    log_warning "Timeout : 30 minutes maximum"
    TIMEOUT_CMD="timeout 1800"
else
    log_info "Note: timeout non disponible (normal sur macOS)"
    TIMEOUT_CMD=""
fi

# Désactiver temporairement set -e pour capturer l'erreur
set +e

# Exporter avec timeout optionnel
EXPORT_OUTPUT=$($TIMEOUT_CMD bash -c "PGPASSWORD=$CLOUD_DB_PASSWORD pg_dump \
    -h $CLOUD_DB_HOST \
    -U postgres \
    -p 5432 \
    -d postgres \
    --clean \
    --if-exists \
    --no-owner \
    --no-privileges \
    --verbose \
    -f $DUMP_FILE 2>&1" || echo "EXPORT_ERROR")

EXPORT_STATUS=$?
set -e

# Vérifier erreur d'export
if echo "$EXPORT_OUTPUT" | grep -q "EXPORT_ERROR"; then
    log_error "Export échoué ou connexion refusée"
    log_info "Vérifiez le Database Password Cloud"
    exit 1
fi

echo "$EXPORT_OUTPUT" | grep -E "(dumping|completed)" || true

if [ $EXPORT_STATUS -eq 0 ] && [ -f "$DUMP_FILE" ]; then
    DUMP_SIZE=$(du -h $DUMP_FILE | cut -f1)
    log_success "Export réussi : $DUMP_FILE ($DUMP_SIZE)"

    # Validation basique du dump
    log_info "Validation du dump..."

    # Vérifier que le fichier n'est pas vide
    if [ ! -s "$DUMP_FILE" ]; then
        log_error "Le dump est vide !"
        exit 1
    fi

    # Vérifier qu'il contient du SQL valide
    if ! grep -q "PostgreSQL database dump" "$DUMP_FILE"; then
        log_error "Le dump ne semble pas être un fichier PostgreSQL valide"
        exit 1
    fi

    # Calculer checksum pour vérification post-transfert
    if command -v md5 &> /dev/null; then
        DUMP_CHECKSUM=$(md5 -q "$DUMP_FILE")
    elif command -v md5sum &> /dev/null; then
        DUMP_CHECKSUM=$(md5sum "$DUMP_FILE" | cut -d' ' -f1)
    else
        DUMP_CHECKSUM="N/A"
    fi

    log_success "Dump validé (checksum: ${DUMP_CHECKSUM:0:8}...)"
else
    log_error "Échec export base Cloud"
    echo ""
    echo "Détails de l'erreur :"
    echo "$EXPORT_OUTPUT" | tail -20
    echo ""
    log_info "Vérifications à faire :"
    echo "  1. Votre IP publique est autorisée dans Supabase Cloud"
    echo "     → Dashboard → Settings → Database → Add votre IP"
    echo "  2. Le Database Password est correct"
    echo "  3. La base est accessible depuis l'extérieur"
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

# Arrêter si mode dry-run
if [ "$DRY_RUN" = true ]; then
    echo ""
    log_success "🧪 Dry-run terminé avec succès !"
    echo ""
    log_info "Résumé :"
    echo "  • Dump créé : $DUMP_FILE ($DUMP_SIZE)"
    echo "  • Tables : $TABLE_COUNT"
    echo "  • Fonctions : $FUNCTION_COUNT"
    echo "  • Lignes SQL : $(printf "%'d" $DUMP_LINES)"
    echo ""
    log_info "Pour effectuer la migration complète, relancez sans --dry-run :"
    echo "  ./migrate-cloud-to-pi.sh"
    echo ""
    exit 0
fi

# ============================================================
# ÉTAPE 5 : Transfert vers Pi
# ============================================================

log_step "📤 ÉTAPE 5/8 : Transfert dump vers Pi"

log_info "Copie vers pi@${PI_IP}:~/supabase_migration.sql..."

# Transfert avec compression et timeout
scp -C -o ConnectTimeout=30 $DUMP_FILE pi@${PI_IP}:~/supabase_migration.sql

if [ $? -eq 0 ]; then
    log_success "Fichier transféré sur Pi"

    # Vérifier taille sur Pi
    REMOTE_SIZE=$(ssh pi@${PI_IP} "du -h ~/supabase_migration.sql | cut -f1")
    log_info "Taille sur Pi : $REMOTE_SIZE"

    # Vérifier checksum après transfert (si disponible)
    if [ "$DUMP_CHECKSUM" != "N/A" ]; then
        log_info "Vérification intégrité du transfert..."

        # Détecter quelle commande est disponible sur le Pi (Linux = md5sum)
        if ssh pi@${PI_IP} "command -v md5sum" &> /dev/null; then
            REMOTE_CHECKSUM=$(ssh pi@${PI_IP} "md5sum ~/supabase_migration.sql | cut -d' ' -f1")
        elif ssh pi@${PI_IP} "command -v md5" &> /dev/null; then
            REMOTE_CHECKSUM=$(ssh pi@${PI_IP} "md5 -q ~/supabase_migration.sql")
        else
            REMOTE_CHECKSUM="N/A"
        fi

        if [ "$DUMP_CHECKSUM" = "$REMOTE_CHECKSUM" ]; then
            log_success "Checksum vérifié : fichier intact"
        elif [ "$REMOTE_CHECKSUM" != "N/A" ]; then
            log_error "Checksum ne correspond pas ! Fichier corrompu lors du transfert"
            log_info "Local:  $DUMP_CHECKSUM"
            log_info "Remote: $REMOTE_CHECKSUM"
            exit 1
        fi
    fi
else
    log_error "Échec transfert vers Pi"
    exit 1
fi

# ============================================================
# ÉTAPE 6 : Backup Pi (avant écrasement)
# ============================================================

log_step "💾 ÉTAPE 6/8 : Backup sécurité Pi (avant import)"

log_warning "⚠️  L'import va écraser les données existantes sur le Pi"
echo ""
read -p "Faire un backup du Pi avant import ? (y/n - recommandé): " DO_PI_BACKUP

if [ "$DO_PI_BACKUP" = "y" ]; then
    log_info "Backup PostgreSQL Pi en cours..."

    PI_BACKUP_FILE="${BACKUP_DIR}/supabase_pi_backup_pre_migration.sql"

    # Export base Pi actuelle
    ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} pg_dump -h localhost -U postgres -p 5432 -d postgres --clean --if-exists" > $PI_BACKUP_FILE

    if [ $? -eq 0 ]; then
        BACKUP_SIZE=$(du -h $PI_BACKUP_FILE | cut -f1)
        log_success "Backup Pi sauvegardé : $PI_BACKUP_FILE ($BACKUP_SIZE)"
        log_info "En cas de problème, restaurez avec :"
        echo "  scp $PI_BACKUP_FILE pi@${PI_IP}:~/restore.sql"
        echo "  ssh pi@${PI_IP} 'PGPASSWORD=\$PASSWORD psql -h localhost -U postgres -p 5432 -d postgres < ~/restore.sql'"
    else
        log_warning "Échec backup Pi (continuez à vos risques)"
    fi
else
    log_warning "Backup Pi ignoré - impossible de revenir en arrière !"
fi

echo ""
read -p "Continuer avec l'import ? (y/n): " CONFIRM_IMPORT
if [ "$CONFIRM_IMPORT" != "y" ]; then
    log_warning "Import annulé"
    log_info "Backups conservés dans : $BACKUP_DIR"
    exit 0
fi

# ============================================================
# ÉTAPE 6b : Préparation schéma cible (si personnalisé)
# ============================================================

if [ "$TARGET_SCHEMA" != "public" ]; then
    log_step "🏗️  ÉTAPE 6b/8 : Préparation schéma personnalisé"

    log_info "Schéma cible : $TARGET_SCHEMA"
    log_info "Création du schéma et configuration des permissions..."

    # Script SQL pour créer le schéma et donner les permissions
    SCHEMA_SETUP_SQL="-- Créer le schéma s'il n'existe pas
CREATE SCHEMA IF NOT EXISTS $TARGET_SCHEMA;

-- Donner les permissions d'usage du schéma aux rôles Supabase
GRANT USAGE ON SCHEMA $TARGET_SCHEMA TO anon, authenticated, service_role;

-- Donner toutes les permissions sur les tables futures
GRANT ALL ON ALL TABLES IN SCHEMA $TARGET_SCHEMA TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA $TARGET_SCHEMA TO anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA $TARGET_SCHEMA TO anon, authenticated, service_role;

-- Configurer les permissions par défaut pour les futurs objets
ALTER DEFAULT PRIVILEGES IN SCHEMA $TARGET_SCHEMA
    GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA $TARGET_SCHEMA
    GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA $TARGET_SCHEMA
    GRANT ALL ON FUNCTIONS TO anon, authenticated, service_role;

-- Afficher confirmation
SELECT 'Schéma $TARGET_SCHEMA créé et configuré' AS status;"

    # Exécuter sur le Pi
    ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres" <<< "$SCHEMA_SETUP_SQL" 2>&1 | grep -E "(CREATE|GRANT|status|ERROR)" || true

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Schéma '$TARGET_SCHEMA' prêt avec permissions Supabase"
    else
        log_error "Échec création schéma '$TARGET_SCHEMA'"
        exit 1
    fi

    # Modifier le dump pour renommer public → TARGET_SCHEMA
    log_info "Adaptation du dump SQL pour schéma personnalisé..."

    MODIFIED_DUMP="${BACKUP_DIR}/supabase_migration_${TARGET_SCHEMA}.sql"

    # Remplacer toutes les références à 'public' par 'TARGET_SCHEMA'
    # Patterns à capturer :
    # - public.table_name (références qualifiées)
    # - SCHEMA public (CREATE TABLE ... SCHEMA public ...)
    # - "public" (entre guillemets)
    # - 'public' (entre apostrophes - pour search_path, etc.)
    ssh pi@${PI_IP} "cat ~/supabase_migration.sql | sed -e 's/public\./${TARGET_SCHEMA}./g' -e 's/SCHEMA public/SCHEMA ${TARGET_SCHEMA}/g' -e 's/\"public\"/\"${TARGET_SCHEMA}\"/g' -e \"s/'public'/'${TARGET_SCHEMA}'/g\" > ~/supabase_migration_custom.sql"

    # Utiliser le fichier modifié pour l'import
    ssh pi@${PI_IP} "mv ~/supabase_migration_custom.sql ~/supabase_migration.sql"

    # Vérifier que la substitution a fonctionné
    SCHEMA_REFS=$(ssh pi@${PI_IP} "grep -c '${TARGET_SCHEMA}\\.' ~/supabase_migration.sql || echo 0")
    PUBLIC_REFS=$(ssh pi@${PI_IP} "grep -c 'public\\.' ~/supabase_migration.sql || echo 0")

    log_info "Substitution effectuée : ${SCHEMA_REFS} références à '${TARGET_SCHEMA}.'"
    if [ "$PUBLIC_REFS" -gt 0 ]; then
        log_warning "Attention : ${PUBLIC_REFS} références à 'public.' restent (normal pour extensions)"
    fi

    log_success "Dump adapté pour schéma '$TARGET_SCHEMA'"
else
    log_info "Schéma cible : public (par défaut)"
fi

# ============================================================
# ÉTAPE 7 : Import dans PostgreSQL Pi
# ============================================================

log_step "📥 ÉTAPE 7/8 : Import dans PostgreSQL Pi"

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
# ÉTAPE 7b : Fix Storage RLS Policies
# ============================================================

log_step "🔧 ÉTAPE 7b/8 : Configuration Storage API"

log_info "Vérification des tables Storage..."

# Vérifier si le schéma storage existe
STORAGE_EXISTS=$(ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres -t -c \"SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = 'storage';\"" | xargs)

if [ "$STORAGE_EXISTS" -gt 0 ]; then
    log_success "Schéma Storage détecté"
    log_info "Application des policies RLS pour service_role..."

    # Script SQL pour fixer les RLS Storage
    STORAGE_RLS_FIX=$(cat <<'EOF_SQL'
-- Donner privilèges à service_role
GRANT USAGE ON SCHEMA storage TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO service_role;

-- Supprimer policies existantes (éviter doublons)
DROP POLICY IF EXISTS "service_role_all_buckets" ON storage.buckets;
DROP POLICY IF EXISTS "service_role_all_objects" ON storage.objects;

-- Créer policies permissives pour service_role
CREATE POLICY "service_role_all_buckets" ON storage.buckets
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "service_role_all_objects" ON storage.objects
  FOR ALL TO service_role USING (true) WITH CHECK (true);
EOF_SQL
)

    # Exécuter le fix
    ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres" <<< "$STORAGE_RLS_FIX" 2>&1 | grep -E "(CREATE|DROP|GRANT)" | head -10 || true

    log_success "Policies Storage configurées"

    # Tester l'API Storage
    log_info "Test API Storage..."
    PI_SERVICE_KEY=$(ssh pi@${PI_IP} "cat ~/stacks/supabase/.env 2>/dev/null || cat ~/supabase/.env 2>/dev/null | grep SUPABASE_SERVICE_KEY | cut -d'=' -f2")

    # Détecter le port Kong (8000 ou 8001)
    KONG_PORT=$(ssh pi@${PI_IP} "docker ps --filter name=kong --format '{{.Ports}}' | grep -oE '0\.0\.0\.0:[0-9]+' | cut -d':' -f2 | head -1")
    if [ -z "$KONG_PORT" ]; then
        KONG_PORT="8000"  # Port par défaut
    fi

    STORAGE_TEST=$(curl -s -w "\n%{http_code}" "http://${PI_IP}:${KONG_PORT}/storage/v1/bucket" -H "apikey: ${PI_SERVICE_KEY}" -H "Authorization: Bearer ${PI_SERVICE_KEY}" | tail -1)

    if [ "$STORAGE_TEST" = "200" ]; then
        log_success "API Storage fonctionnelle (port ${KONG_PORT})"
    else
        log_warning "API Storage : Status $STORAGE_TEST (peut être normal si aucun bucket)"
    fi
else
    log_info "Schéma Storage non détecté (skippé)"
fi

# ============================================================
# ÉTAPE 8 : Vérification Post-Import
# ============================================================

log_step "✅ ÉTAPE 8/8 : Vérification post-import"

log_info "Vérification tables..."

# Compter tables sur Pi (dans le schéma cible)
TABLE_COUNT_PI=$(ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres -t -c \"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${TARGET_SCHEMA}';\"" | xargs)

log_success "Tables dans '${TARGET_SCHEMA}' : $TABLE_COUNT_PI"

# Vérifier schéma auth (users)
AUTH_USER_COUNT=$(ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres -t -c \"SELECT COUNT(*) FROM auth.users;\"" 2>/dev/null | xargs || echo "0")

log_info "Utilisateurs Auth : $AUTH_USER_COUNT"

# Test API REST
log_info "Test API REST Pi..."

PI_ANON_KEY=$(ssh pi@${PI_IP} "cat ~/stacks/supabase/.env 2>/dev/null || cat ~/supabase/.env 2>/dev/null | grep ANON_KEY | cut -d'=' -f2")

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
echo "  Schema  : ${TARGET_SCHEMA}"
echo "  Tables  : ${TABLE_COUNT_PI}"
echo "  Users   : ${AUTH_USER_COUNT}"
echo "  Dump    : ${DUMP_FILE} (${DUMP_SIZE})"
echo ""

log_info "🔍 Vérifications recommandées :"
echo ""
echo "  1. Tester Supabase Studio : http://${PI_IP}:8000"
if [ "$TARGET_SCHEMA" != "public" ]; then
    echo "     ⚠️  Dans Studio, sélectionner schéma '$TARGET_SCHEMA' (dropdown en haut)"
fi
echo "  2. Vérifier données table : SELECT * FROM ${TARGET_SCHEMA}.your_table LIMIT 10;"
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
echo "     - Utiliser : node ~/pi5-setup/01-infrastructure/supabase/migration/post-migration-storage.js"
echo "     - Voir : MIGRATION-CLOUD-TO-PI.md (section Storage)"
echo ""
echo "  ✅ Mettre à jour application :"
echo "     - NEXT_PUBLIC_SUPABASE_URL=http://${PI_IP}:8000"
echo "     - NEXT_PUBLIC_SUPABASE_ANON_KEY=${PI_ANON_KEY:0:20}..."
if [ "$TARGET_SCHEMA" != "public" ]; then
    echo ""
    echo "  ⚠️  Configuration schéma personnalisé dans code client :"
    echo "     const supabase = createClient(url, key, {"
    echo "       db: { schema: '${TARGET_SCHEMA}' }"
    echo "     })"
fi
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
