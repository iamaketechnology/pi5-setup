#!/usr/bin/env bash
# =============================================================================
# SCRIPT DE CRÉATION - BASE DE CONNAISSANCES SUPABASE RASPBERRY PI 5
# =============================================================================
# Version: 1.0.0
# Description: Crée la structure complète de la Base de Connaissances
# Usage: chmod +x create-knowledge-base.sh && ./create-knowledge-base.sh
# =============================================================================

set -euo pipefail

# Couleurs pour output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   📚 CRÉATION BASE DE CONNAISSANCES SUPABASE PI 5    ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Déterminer répertoire de base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KB_ROOT="$BASE_DIR"

echo -e "\n${YELLOW}📁 Répertoire Base:${NC} $KB_ROOT\n"

# =============================================================================
# PHASE 1 : CRÉATION STRUCTURE DE DOSSIERS
# =============================================================================
echo -e "${GREEN}[1/4]${NC} Création de la structure de dossiers..."

mkdir -p "$KB_ROOT/01-GETTING-STARTED"
mkdir -p "$KB_ROOT/02-INSTALLATION"
mkdir -p "$KB_ROOT/03-PI5-SPECIFIC"
mkdir -p "$KB_ROOT/04-TROUBLESHOOTING"
mkdir -p "$KB_ROOT/05-CONFIGURATION"
mkdir -p "$KB_ROOT/06-MAINTENANCE"
mkdir -p "$KB_ROOT/07-ADVANCED"
mkdir -p "$KB_ROOT/08-REFERENCE"
mkdir -p "$KB_ROOT/99-ARCHIVE/DEBUG-SESSIONS"

echo -e "  ✓ Structure créée"

# =============================================================================
# PHASE 2 : CRÉATION FICHIERS GETTING-STARTED
# =============================================================================
echo -e "\n${GREEN}[2/4]${NC} Création fichiers Getting Started..."

touch "$KB_ROOT/01-GETTING-STARTED/00-Prerequisites.md"
touch "$KB_ROOT/01-GETTING-STARTED/01-Quick-Start.md"
touch "$KB_ROOT/01-GETTING-STARTED/02-Architecture-Overview.md"

echo -e "  ✓ 3 fichiers créés dans 01-GETTING-STARTED/"

# =============================================================================
# PHASE 3 : CRÉATION FICHIERS INSTALLATION
# =============================================================================
echo -e "\n${GREEN}[2/4]${NC} Création fichiers Installation..."

touch "$KB_ROOT/02-INSTALLATION/Week1-Docker-Setup.md"
touch "$KB_ROOT/02-INSTALLATION/Week2-Supabase-Stack.md"
touch "$KB_ROOT/02-INSTALLATION/Installation-Commands.sh"
touch "$KB_ROOT/02-INSTALLATION/Post-Install-Checklist.md"

chmod +x "$KB_ROOT/02-INSTALLATION/Installation-Commands.sh"

echo -e "  ✓ 4 fichiers créés dans 02-INSTALLATION/"

# =============================================================================
# PHASE 4 : CRÉATION FICHIERS PI5-SPECIFIC
# =============================================================================
echo -e "\n${GREEN}[2/4]${NC} Création fichiers Pi 5 Spécifiques..."

touch "$KB_ROOT/03-PI5-SPECIFIC/ARM64-Compatibility.md"
touch "$KB_ROOT/03-PI5-SPECIFIC/Page-Size-Fix.md"
touch "$KB_ROOT/03-PI5-SPECIFIC/Memory-Optimization.md"
touch "$KB_ROOT/03-PI5-SPECIFIC/Known-Issues-2025.md"

echo -e "  ✓ 4 fichiers créés dans 03-PI5-SPECIFIC/"

# =============================================================================
# PHASE 5 : CRÉATION FICHIERS TROUBLESHOOTING
# =============================================================================
echo -e "\n${GREEN}[2/4]${NC} Création fichiers Troubleshooting..."

touch "$KB_ROOT/04-TROUBLESHOOTING/Auth-Issues.md"
touch "$KB_ROOT/04-TROUBLESHOOTING/Realtime-Issues.md"
touch "$KB_ROOT/04-TROUBLESHOOTING/Docker-Issues.md"
touch "$KB_ROOT/04-TROUBLESHOOTING/Database-Issues.md"
touch "$KB_ROOT/04-TROUBLESHOOTING/Quick-Fixes.md"

echo -e "  ✓ 5 fichiers créés dans 04-TROUBLESHOOTING/"

# =============================================================================
# PHASE 6 : CRÉATION FICHIERS CONFIGURATION
# =============================================================================
echo -e "\n${GREEN}[2/4]${NC} Création fichiers Configuration..."

touch "$KB_ROOT/05-CONFIGURATION/Environment-Variables.md"
touch "$KB_ROOT/05-CONFIGURATION/Docker-Compose-Explained.md"
touch "$KB_ROOT/05-CONFIGURATION/Security-Hardening.md"
touch "$KB_ROOT/05-CONFIGURATION/Performance-Tuning.md"

echo -e "  ✓ 4 fichiers créés dans 05-CONFIGURATION/"

# =============================================================================
# PHASE 7 : CRÉATION FICHIERS MAINTENANCE
# =============================================================================
echo -e "\n${GREEN}[2/4]${NC} Création fichiers Maintenance..."

touch "$KB_ROOT/06-MAINTENANCE/Backup-Strategies.md"
touch "$KB_ROOT/06-MAINTENANCE/Update-Procedures.md"
touch "$KB_ROOT/06-MAINTENANCE/Monitoring.md"
touch "$KB_ROOT/06-MAINTENANCE/Reset-Procedures.md"

echo -e "  ✓ 4 fichiers créés dans 06-MAINTENANCE/"

# =============================================================================
# PHASE 8 : CRÉATION FICHIERS ADVANCED
# =============================================================================
echo -e "\n${GREEN}[2/4]${NC} Création fichiers Advanced..."

touch "$KB_ROOT/07-ADVANCED/Custom-Extensions.md"
touch "$KB_ROOT/07-ADVANCED/SSL-Reverse-Proxy.md"
touch "$KB_ROOT/07-ADVANCED/Multi-Environment.md"
touch "$KB_ROOT/07-ADVANCED/Migration-Strategies.md"

echo -e "  ✓ 4 fichiers créés dans 07-ADVANCED/"

# =============================================================================
# PHASE 9 : CRÉATION FICHIERS REFERENCE
# =============================================================================
echo -e "\n${GREEN}[3/4]${NC} Création fichiers Reference..."

touch "$KB_ROOT/08-REFERENCE/All-Commands-Reference.md"
touch "$KB_ROOT/08-REFERENCE/All-Ports-Reference.md"
touch "$KB_ROOT/08-REFERENCE/Service-Dependencies.md"
touch "$KB_ROOT/08-REFERENCE/Glossary.md"

echo -e "  ✓ 4 fichiers créés dans 08-REFERENCE/"

# =============================================================================
# PHASE 10 : CRÉATION README PRINCIPAL
# =============================================================================
echo -e "\n${GREEN}[4/4]${NC} Création README principal..."

touch "$KB_ROOT/README.md"

echo -e "  ✓ README.md créé"

# =============================================================================
# RÉSUMÉ FINAL
# =============================================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ CRÉATION TERMINÉE AVEC SUCCÈS !${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Comptage fichiers créés
total_files=$(find "$KB_ROOT" -type f | wc -l | xargs)
echo -e "\n📊 ${YELLOW}Statistiques:${NC}"
echo -e "  • Dossiers créés: 10"
echo -e "  • Fichiers créés: $total_files"
echo -e "  • Emplacement: $KB_ROOT"

echo -e "\n📋 ${YELLOW}Prochaines étapes:${NC}"
echo -e "  1. Remplir le contenu avec: knowledge-base-content.md"
echo -e "  2. Lire README.md pour navigation"
echo -e "  3. Commencer par 01-Quick-Start.md pour installation rapide"

echo -e "\n${GREEN}🎉 Base de Connaissances prête à être remplie !${NC}\n"

# Afficher arborescence
echo -e "${YELLOW}📂 Structure créée:${NC}"
tree -L 2 "$KB_ROOT" 2>/dev/null || find "$KB_ROOT" -type d -print | sed 's|[^/]*/| |g'
