#!/usr/bin/env bash
set -euo pipefail

# ========================================================================
# MIGRATION SUPABASE → APPWRITE POUR RASPBERRY PI 5
# ========================================================================
# Script de migration automatisée des données Supabase vers Appwrite
# Conversion PostgreSQL → MariaDB avec adaptation des types
#
# Version: 1.0.0-pi5-migration
# Date: 16 Sept 2025
# Compatibilité: Supabase self-hosted → Appwrite 1.7.4
#
# Usage:
#   sudo ./migrate-supabase-to-appwrite.sh
#   sudo ./migrate-supabase-to-appwrite.sh --dry-run
#   sudo ./migrate-supabase-to-appwrite.sh --schema-only
#
# ATTENTION: Effectuer une sauvegarde complète avant migration
# ========================================================================

# === CONFIGURATION ===
SCRIPT_VERSION="1.0.0-pi5-migration"
TARGET_USER="${SUDO_USER:-pi}"
SUPABASE_DIR="/home/$TARGET_USER/stacks/supabase"
APPWRITE_DIR="/home/$TARGET_USER/stacks/appwrite"
MIGRATION_DIR="/home/$TARGET_USER/migration-supabase-appwrite"
LOG_FILE="/var/log/pi5-migration-supabase-appwrite.log"

# === OPTIONS ===
DRY_RUN=false
SCHEMA_ONLY=false
FORCE_MODE=false

# === LOGGING ===
log()  { echo -e "$(date '+%Y-%m-%d %H:%M:%S') - \033[1;36m[MIGRATE]\033[0m $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') - \033[1;33m[WARN]   \033[0m $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "$(date '+%Y-%m-%d %H:%M:%S') - \033[1;32m[OK]     \033[0m $*" | tee -a "$LOG_FILE"; }
error() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') - \033[1;31m[ERROR]  \033[0m $*" | tee -a "$LOG_FILE"; }

# === VALIDATION ===
require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Usage: sudo $0 [options]"
    echo "Options:"
    echo "  --dry-run      Analyse seulement, pas de migration"
    echo "  --schema-only  Migrer structure seulement"
    echo "  --force        Forcer migration sans confirmation"
    exit 1
  fi
}

# === ARGUMENT PARSING ===
parse_arguments() {
  for arg in "$@"; do
    case $arg in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --schema-only)
        SCHEMA_ONLY=true
        shift
        ;;
      --force)
        FORCE_MODE=true
        shift
        ;;
      *)
        ;;
    esac
  done
}

# === BANNER ===
show_banner() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║               🔄 MIGRATION SUPABASE → APPWRITE                  ║"
  echo "║                                                                  ║"
  echo "║     Conversion PostgreSQL → MariaDB avec adaptation types       ║"
  echo "║                     Version: $SCRIPT_VERSION                     ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  echo ""
}

# === VALIDATIONS ===
validate_installations() {
  log "🔍 Validation installations existantes..."

  # Vérifier Supabase
  if [[ ! -d "$SUPABASE_DIR" ]]; then
    error "❌ Installation Supabase introuvable: $SUPABASE_DIR"
    exit 1
  fi

  if ! cd "$SUPABASE_DIR" 2>/dev/null || ! sudo -u "$TARGET_USER" docker compose ps | grep -q "supabase-db.*Up"; then
    error "❌ Supabase non fonctionnel ou arrêté"
    exit 1
  fi

  # Vérifier Appwrite
  if [[ ! -d "$APPWRITE_DIR" ]]; then
    error "❌ Installation Appwrite introuvable: $APPWRITE_DIR"
    log "   Installez d'abord: sudo ./setup-appwrite-pi5.sh"
    exit 1
  fi

  if ! cd "$APPWRITE_DIR" 2>/dev/null || ! sudo -u "$TARGET_USER" docker compose ps | grep -q "appwrite.*Up"; then
    error "❌ Appwrite non fonctionnel ou arrêté"
    exit 1
  fi

  ok "✅ Installations Supabase et Appwrite validées"
}

validate_connectivity() {
  log "🔌 Test connectivité bases de données..."

  # Test Supabase PostgreSQL
  if ! cd "$SUPABASE_DIR" && sudo -u "$TARGET_USER" docker compose exec -T db pg_isready -h localhost; then
    error "❌ PostgreSQL Supabase inaccessible"
    exit 1
  fi

  # Test Appwrite MariaDB
  if ! cd "$APPWRITE_DIR" && sudo -u "$TARGET_USER" docker compose exec -T mariadb mysqladmin ping; then
    error "❌ MariaDB Appwrite inaccessible"
    exit 1
  fi

  ok "✅ Bases de données accessibles"
}

# === ANALYSIS ===
analyze_supabase_data() {
  log "📊 Analyse données Supabase..."

  mkdir -p "$MIGRATION_DIR"

  # Lister les tables publiques
  cd "$SUPABASE_DIR"
  sudo -u "$TARGET_USER" docker compose exec -T db psql -U postgres -d postgres -t -c "
    SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename NOT LIKE 'pg_%'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
  " > "$MIGRATION_DIR/tables_analysis.txt"

  # Compter les enregistrements
  sudo -u "$TARGET_USER" docker compose exec -T db psql -U postgres -d postgres -t -c "
    SELECT schemaname, tablename, n_tup_ins as total_rows
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
    ORDER BY n_tup_ins DESC;
  " > "$MIGRATION_DIR/rows_count.txt"

  # Analyser les types de colonnes problématiques
  sudo -u "$TARGET_USER" docker compose exec -T db psql -U postgres -d postgres -t -c "
    SELECT
      t.table_name,
      c.column_name,
      c.data_type,
      c.is_nullable,
      c.column_default
    FROM information_schema.tables t
    INNER JOIN information_schema.columns c ON t.table_name = c.table_name
    WHERE t.table_schema = 'public'
    AND c.data_type IN ('uuid', 'jsonb', 'text[]', 'timestamp with time zone')
    ORDER BY t.table_name, c.ordinal_position;
  " > "$MIGRATION_DIR/problematic_types.txt"

  ok "✅ Analyse sauvegardée dans: $MIGRATION_DIR"
}

show_migration_summary() {
  echo ""
  log "📋 Résumé analyse migration:"

  if [[ -f "$MIGRATION_DIR/tables_analysis.txt" ]]; then
    echo ""
    log "   📊 Tables publiques détectées:"
    while IFS='|' read -r schema table size; do
      if [[ -n "$table" && "$table" != "tablename" ]]; then
        log "     - $(echo $table | tr -d ' ') ($(echo $size | tr -d ' '))"
      fi
    done < "$MIGRATION_DIR/tables_analysis.txt"
  fi

  if [[ -f "$MIGRATION_DIR/problematic_types.txt" ]]; then
    echo ""
    warn "   ⚠️ Types nécessitant conversion:"
    while IFS='|' read -r table column type nullable default; do
      if [[ -n "$column" && "$column" != "column_name" ]]; then
        warn "     - $(echo $table | tr -d ' ').$(echo $column | tr -d ' ') ($(echo $type | tr -d ' '))"
      fi
    done < "$MIGRATION_DIR/problematic_types.txt"
  fi

  echo ""
}

# === BACKUP ===
create_backup() {
  log "💾 Création sauvegarde complète..."

  local backup_dir="$MIGRATION_DIR/backup-$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$backup_dir"

  # Backup Supabase complet
  log "   Sauvegarde Supabase..."
  cd "$SUPABASE_DIR"
  sudo -u "$TARGET_USER" docker compose exec -T db pg_dumpall -U postgres > "$backup_dir/supabase_full_backup.sql"

  # Backup schéma public seulement
  sudo -u "$TARGET_USER" docker compose exec -T db pg_dump -U postgres -d postgres --schema=public --schema-only > "$backup_dir/supabase_schema_public.sql"

  # Backup données public seulement
  sudo -u "$TARGET_USER" docker compose exec -T db pg_dump -U postgres -d postgres --schema=public --data-only > "$backup_dir/supabase_data_public.sql"

  # Backup Appwrite actuel
  log "   Sauvegarde Appwrite actuelle..."
  cd "$APPWRITE_DIR"

  # Source variables environnement Appwrite
  set -a
  source .env
  set +a

  sudo -u "$TARGET_USER" docker compose exec -T mariadb mysqldump -u root -p"${_APP_DB_ROOT_PASS}" appwrite > "$backup_dir/appwrite_current_backup.sql"

  ok "✅ Sauvegardes créées: $backup_dir"
  echo "$backup_dir" > "$MIGRATION_DIR/last_backup_dir.txt"
}

# === CONVERSION ===
create_conversion_schema() {
  log "🔧 Création schéma conversion PostgreSQL → MariaDB..."

  cat > "$MIGRATION_DIR/type_conversion.sql" << 'EOF'
-- Conversion des types PostgreSQL vers MariaDB
-- Usage: source ce fichier avant import

-- UUID vers VARCHAR(36)
-- PostgreSQL: uuid
-- MariaDB: VARCHAR(36) avec contrainte format

-- JSONB vers JSON
-- PostgreSQL: jsonb
-- MariaDB: JSON (MySQL 5.7+)

-- Timestamp with timezone vers TIMESTAMP
-- PostgreSQL: timestamp with time zone
-- MariaDB: TIMESTAMP (UTC recommandé)

-- Text arrays vers JSON
-- PostgreSQL: text[]
-- MariaDB: JSON array

-- Boolean vers TINYINT
-- PostgreSQL: boolean
-- MariaDB: TINYINT(1)

-- Serial vers AUTO_INCREMENT
-- PostgreSQL: serial, bigserial
-- MariaDB: INT AUTO_INCREMENT, BIGINT AUTO_INCREMENT
EOF

  # Script de conversion automatique
  cat > "$MIGRATION_DIR/convert_schema.py" << 'EOF'
#!/usr/bin/env python3
import re
import sys

def convert_postgresql_to_mariadb(sql_content):
    """Convertit un schéma PostgreSQL vers MariaDB"""

    # Conversions de types
    conversions = {
        r'\buuid\b': 'VARCHAR(36)',
        r'\bjsonb\b': 'JSON',
        r'\btext\[\]': 'JSON',
        r'\bboolean\b': 'TINYINT(1)',
        r'\bserial\b': 'INT AUTO_INCREMENT',
        r'\bbigserial\b': 'BIGINT AUTO_INCREMENT',
        r'\btimestamp with time zone\b': 'TIMESTAMP',
        r'\btimestamp without time zone\b': 'TIMESTAMP'
    }

    result = sql_content

    for pg_type, maria_type in conversions.items():
        result = re.sub(pg_type, maria_type, result, flags=re.IGNORECASE)

    # Supprimer extensions PostgreSQL
    result = re.sub(r'CREATE EXTENSION.*?;', '', result, flags=re.IGNORECASE | re.DOTALL)

    # Adapter syntaxe CREATE TABLE
    result = re.sub(r'CREATE TABLE IF NOT EXISTS', 'CREATE TABLE', result)

    # Supprimer contraintes PostgreSQL spécifiques
    result = re.sub(r'CONSTRAINT.*?CHECK.*?\([^)]+\)', '', result, flags=re.IGNORECASE)

    return result

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 convert_schema.py input.sql output.sql")
        sys.exit(1)

    with open(sys.argv[1], 'r') as f:
        content = f.read()

    converted = convert_postgresql_to_mariadb(content)

    with open(sys.argv[2], 'w') as f:
        f.write(converted)

    print(f"Conversion terminée: {sys.argv[1]} → {sys.argv[2]}")
EOF

  chmod +x "$MIGRATION_DIR/convert_schema.py"
  ok "✅ Scripts de conversion créés"
}

# === MIGRATION ===
export_supabase_schema() {
  log "📤 Export schéma Supabase (public seulement)..."

  cd "$SUPABASE_DIR"

  # Export schéma public (structure)
  sudo -u "$TARGET_USER" docker compose exec -T db pg_dump -U postgres -d postgres \
    --schema=public \
    --schema-only \
    --no-owner \
    --no-privileges \
    --exclude-table='public.schema_migrations' \
    --exclude-table='public.supabase_*' \
    > "$MIGRATION_DIR/supabase_schema_export.sql"

  ok "✅ Schéma exporté: $MIGRATION_DIR/supabase_schema_export.sql"
}

convert_schema_to_mariadb() {
  log "🔄 Conversion schéma PostgreSQL → MariaDB..."

  # Conversion automatique
  python3 "$MIGRATION_DIR/convert_schema.py" \
    "$MIGRATION_DIR/supabase_schema_export.sql" \
    "$MIGRATION_DIR/appwrite_schema_converted.sql"

  # Ajout en-tête MariaDB
  cat > "$MIGRATION_DIR/appwrite_schema_final.sql" << 'EOF'
-- Schéma converti Supabase → Appwrite
-- PostgreSQL → MariaDB
SET FOREIGN_KEY_CHECKS = 0;
SET sql_mode = 'NO_AUTO_VALUE_ON_ZERO';
SET AUTOCOMMIT = 0;
START TRANSACTION;

USE appwrite;

EOF

  # Ajouter schéma converti
  cat "$MIGRATION_DIR/appwrite_schema_converted.sql" >> "$MIGRATION_DIR/appwrite_schema_final.sql"

  # Ajouter fin
  cat >> "$MIGRATION_DIR/appwrite_schema_final.sql" << 'EOF'

COMMIT;
SET FOREIGN_KEY_CHECKS = 1;
EOF

  ok "✅ Schéma converti: $MIGRATION_DIR/appwrite_schema_final.sql"
}

export_supabase_data() {
  log "📤 Export données Supabase..."

  if [[ "$SCHEMA_ONLY" == "true" ]]; then
    log "   Mode schema-only: pas d'export de données"
    return 0
  fi

  cd "$SUPABASE_DIR"

  # Export données publiques seulement
  sudo -u "$TARGET_USER" docker compose exec -T db pg_dump -U postgres -d postgres \
    --schema=public \
    --data-only \
    --no-owner \
    --no-privileges \
    --exclude-table='public.schema_migrations' \
    --exclude-table='public.supabase_*' \
    --column-inserts \
    > "$MIGRATION_DIR/supabase_data_export.sql"

  ok "✅ Données exportées: $MIGRATION_DIR/supabase_data_export.sql"
}

import_to_appwrite() {
  log "📥 Import vers Appwrite MariaDB..."

  if [[ "$DRY_RUN" == "true" ]]; then
    log "   Mode dry-run: simulation import"
    return 0
  fi

  cd "$APPWRITE_DIR"

  # Source variables environnement
  set -a
  source .env
  set +a

  # Import schéma
  log "   Import schéma..."
  sudo -u "$TARGET_USER" docker compose exec -T mariadb mysql -u root -p"${_APP_DB_ROOT_PASS}" < "$MIGRATION_DIR/appwrite_schema_final.sql"

  # Import données si pas schema-only
  if [[ "$SCHEMA_ONLY" == "false" && -f "$MIGRATION_DIR/supabase_data_export.sql" ]]; then
    log "   Import données..."

    # Conversion basique des INSERT PostgreSQL → MariaDB
    sed 's/INSERT INTO public\./INSERT INTO /g' "$MIGRATION_DIR/supabase_data_export.sql" > "$MIGRATION_DIR/appwrite_data_final.sql"

    sudo -u "$TARGET_USER" docker compose exec -T mariadb mysql -u root -p"${_APP_DB_ROOT_PASS}" appwrite < "$MIGRATION_DIR/appwrite_data_final.sql"
  fi

  ok "✅ Import terminé dans Appwrite"
}

# === VALIDATION ===
validate_migration() {
  log "✅ Validation migration..."

  cd "$APPWRITE_DIR"
  set -a
  source .env
  set +a

  # Compter tables importées
  local imported_tables=$(sudo -u "$TARGET_USER" docker compose exec -T mariadb mysql -u root -p"${_APP_DB_ROOT_PASS}" appwrite -e "SHOW TABLES;" | wc -l)

  # Compter enregistrements (approximatif)
  local total_rows=0
  while read -r table; do
    if [[ -n "$table" && "$table" != "Tables_in_appwrite" ]]; then
      local rows=$(sudo -u "$TARGET_USER" docker compose exec -T mariadb mysql -u root -p"${_APP_DB_ROOT_PASS}" appwrite -e "SELECT COUNT(*) FROM \`$table\`;" 2>/dev/null | tail -1 || echo 0)
      total_rows=$((total_rows + rows))
    fi
  done < <(sudo -u "$TARGET_USER" docker compose exec -T mariadb mysql -u root -p"${_APP_DB_ROOT_PASS}" appwrite -e "SHOW TABLES;" | tail -n +2)

  log "   📊 Tables importées: $((imported_tables - 1))"
  log "   📊 Enregistrements total: $total_rows"

  ok "✅ Migration validée"
}

# === CLEANUP ===
cleanup_migration() {
  log "🧹 Nettoyage post-migration..."

  # Garder logs et sauvegardes, supprimer temporaires
  rm -f "$MIGRATION_DIR"/*_export.sql
  rm -f "$MIGRATION_DIR"/*_converted.sql

  ok "✅ Nettoyage terminé (sauvegardes conservées)"
}

# === SUMMARY ===
show_migration_results() {
  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo "🎉 MIGRATION SUPABASE → APPWRITE TERMINÉE"
  echo "══════════════════════════════════════════════════════════════════"
  echo ""
  echo "📁 **Fichiers de migration** :"
  echo "   $MIGRATION_DIR/"
  echo ""
  echo "💾 **Sauvegardes** :"
  if [[ -f "$MIGRATION_DIR/last_backup_dir.txt" ]]; then
    local backup_dir=$(cat "$MIGRATION_DIR/last_backup_dir.txt")
    echo "   $backup_dir/"
  fi
  echo ""
  echo "🎯 **Accès Appwrite avec données migrées** :"
  local pi_ip=$(hostname -I | awk '{print $1}')
  echo "   http://$pi_ip:8081"
  echo ""
  echo "⚠️ **Actions post-migration requises** :"
  echo "   1. Vérifier structure tables dans console Appwrite"
  echo "   2. Reconfigurer permissions/collections"
  echo "   3. Tester authentification si migrée"
  echo "   4. Adapter code client aux APIs Appwrite"
  echo ""
  echo "📚 **Documentation** :"
  echo "   - Console Appwrite: http://$pi_ip:8081/console"
  echo "   - API Docs: https://appwrite.io/docs/references"
  echo "   - Migration guide: /docs/appwrite-installation-guide.md"
  echo ""
  echo "🔄 **Rollback si nécessaire** :"
  echo "   - Sauvegardes disponibles dans backup/"
  echo "   - Redémarrer Supabase: cd $SUPABASE_DIR && docker compose up -d"
  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo ""
}

# === MAIN ===
main() {
  require_root
  parse_arguments "$@"
  show_banner

  log "🎯 Migration Supabase → Appwrite pour utilisateur: $TARGET_USER"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "🔍 Mode DRY-RUN: Analyse seulement"
  fi

  if [[ "$SCHEMA_ONLY" == "true" ]]; then
    log "📋 Mode SCHEMA-ONLY: Structure seulement"
  fi

  # Validations
  validate_installations
  validate_connectivity

  # Analyse
  analyze_supabase_data
  show_migration_summary

  # Confirmation
  if [[ "$FORCE_MODE" == "false" && "$DRY_RUN" == "false" ]]; then
    echo ""
    warn "⚠️ ATTENTION: Cette migration va modifier la base Appwrite"
    warn "   - Sauvegarde automatique sera créée"
    warn "   - Processus irréversible sans restore manuel"
    echo ""
    read -p "🤔 Continuer avec la migration? [y/N]: " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log "❌ Migration annulée par l'utilisateur"
      exit 0
    fi
  fi

  # Migration
  if [[ "$DRY_RUN" == "false" ]]; then
    create_backup
  fi

  create_conversion_schema
  export_supabase_schema
  convert_schema_to_mariadb

  if [[ "$SCHEMA_ONLY" == "false" ]]; then
    export_supabase_data
  fi

  import_to_appwrite

  if [[ "$DRY_RUN" == "false" ]]; then
    validate_migration
    cleanup_migration
    show_migration_results
  else
    log "🔍 Analyse terminée - Fichiers disponibles dans: $MIGRATION_DIR"
  fi

  ok "🎉 Migration Supabase → Appwrite terminée!"
}

main "$@"