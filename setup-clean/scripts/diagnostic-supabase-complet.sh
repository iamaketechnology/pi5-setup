#!/bin/bash

# =============================================================================
# DIAGNOSTIC COMPLET SUPABASE PI 5 - RAPPORT AUTOMATIQUE
# =============================================================================
# Génère un rapport détaillé sur Desktop pour debugging avec Claude Code
# Usage: sudo ./diagnostic-supabase-complet.sh

set -euo pipefail

# Configuration
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/$TARGET_USER/stacks/supabase"
DESKTOP_DIR="/home/$TARGET_USER/Desktop"
RAPPORT_FILE="$DESKTOP_DIR/DIAGNOSTIC-SUPABASE-$(date +%Y%m%d_%H%M%S).txt"

# Couleurs pour terminal
warn()  { echo -e "\033[1;33m[WARN]   \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]     \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR] \033[0m $*"; }

echo "🔍 Génération rapport diagnostic Supabase..."
echo "📄 Rapport sera sauvé sur: $RAPPORT_FILE"

# Créer le rapport
cat > "$RAPPORT_FILE" << 'RAPPORT_HEADER'
# =============================================================================
# RAPPORT DIAGNOSTIC SUPABASE AUTOMATIQUE
# =============================================================================
# Généré automatiquement pour debugging avec Claude Code
#
# INSTRUCTIONS POUR CLAUDE :
# 1. Analysez ce rapport complet
# 2. Identifiez les problèmes critiques
# 3. Proposez corrections spécifiques
# 4. Générez commandes de correction
# =============================================================================

RAPPORT_HEADER

# Ajouter timestamp et environnement
cat >> "$RAPPORT_FILE" << EOF
🕐 TIMESTAMP: $(date)
🖥️  HOSTNAME: $(hostname)
👤 USER: $TARGET_USER
📁 PROJECT_DIR: $PROJECT_DIR

EOF

# =============================================================================
# SECTION 1: ÉTAT SYSTÈME
# =============================================================================
echo "📊 Collecte état système..." >&2

cat >> "$RAPPORT_FILE" << 'SECTION1'
## 1. ÉTAT SYSTÈME

### Architecture et OS:
EOF

{
  echo "Architecture: $(uname -m)"
  echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')"
  echo "Kernel: $(uname -r)"
  echo "Uptime: $(uptime -p)"
  echo ""
} >> "$RAPPORT_FILE" 2>/dev/null

# =============================================================================
# SECTION 2: DOCKER
# =============================================================================
echo "🐳 Collecte état Docker..." >&2

cat >> "$RAPPORT_FILE" << 'SECTION2'
### Docker Status:
EOF

{
  echo "Docker version: $(docker --version)"
  echo "Docker Compose version: $(docker compose version)"
  echo ""
  echo "### Services Docker Supabase:"
  if cd "$PROJECT_DIR" 2>/dev/null; then
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" || echo "Erreur: docker compose ps"
  else
    echo "Erreur: Impossible d'accéder à $PROJECT_DIR"
  fi
  echo ""
} >> "$RAPPORT_FILE" 2>&1

# =============================================================================
# SECTION 3: FICHIER .ENV CRITIQUE
# =============================================================================
echo "📄 Analyse fichier .env..." >&2

cat >> "$RAPPORT_FILE" << 'SECTION3'
## 2. ANALYSE FICHIER .ENV (CRITIQUE)

### État fichier .env:
EOF

{
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
} >> "$RAPPORT_FILE" 2>&1

# =============================================================================
# SECTION 4: PORTS ET CONNECTIVITÉ
# =============================================================================
echo "🌐 Test connectivité services..." >&2

cat >> "$RAPPORT_FILE" << 'SECTION4'
## 3. PORTS ET CONNECTIVITÉ

### Ports Docker mappés:
EOF

{
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
} >> "$RAPPORT_FILE" 2>&1

# =============================================================================
# SECTION 5: LOGS SERVICES PROBLÉMATIQUES
# =============================================================================
echo "📋 Collecte logs services..." >&2

cat >> "$RAPPORT_FILE" << 'SECTION5'
## 4. LOGS SERVICES (20 DERNIÈRES LIGNES)

EOF

if cd "$PROJECT_DIR" 2>/dev/null; then
  for service in realtime kong auth studio; do
    {
      echo "### Logs $service:"
      docker compose logs --tail=20 "$service" 2>/dev/null || echo "Service $service non accessible"
      echo ""
    } >> "$RAPPORT_FILE" 2>&1
  done
else
  echo "Impossible d'accéder aux logs (PROJECT_DIR inaccessible)" >> "$RAPPORT_FILE"
fi

# =============================================================================
# SECTION 6: BASE DE DONNÉES
# =============================================================================
echo "🗄️ Vérification base de données..." >&2

cat >> "$RAPPORT_FILE" << 'SECTION6'
## 5. BASE DE DONNÉES POSTGRESQL

### Connectivité PostgreSQL:
EOF

{
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
} >> "$RAPPORT_FILE" 2>&1

# =============================================================================
# SECTION 7: FICHIERS CONFIGURATION
# =============================================================================
echo "⚙️ Vérification fichiers config..." >&2

cat >> "$RAPPORT_FILE" << 'SECTION7'
## 6. FICHIERS CONFIGURATION

### Fichier docker-compose.yml:
EOF

{
  if [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    echo "✅ docker-compose.yml présent"
    echo "Taille: $(stat -f%z "$PROJECT_DIR/docker-compose.yml" 2>/dev/null || stat -c%s "$PROJECT_DIR/docker-compose.yml" 2>/dev/null) bytes"

    echo ""
    echo "### Validation YAML:"
    if cd "$PROJECT_DIR" && docker compose config >/dev/null 2>&1; then
      echo "✅ YAML valide"
    else
      echo "❌ YAML INVALIDE - Erreurs:"
      cd "$PROJECT_DIR" && docker compose config 2>&1 | head -10
    fi

    echo ""
    echo "### Variables utilisées dans compose:"
    grep -E '\$\{[^}]+\}' "$PROJECT_DIR/docker-compose.yml" | sort | uniq -c | head -10

  else
    echo "❌ docker-compose.yml MANQUANT"
  fi
  echo ""
} >> "$RAPPORT_FILE" 2>&1

# =============================================================================
# SECTION 8: RESSOURCES SYSTÈME
# =============================================================================
echo "💾 Vérification ressources..." >&2

cat >> "$RAPPORT_FILE" << 'SECTION8'
## 7. RESSOURCES SYSTÈME

### Utilisation mémoire:
EOF

{
  echo "RAM totale: $(free -h | grep Mem | awk '{print $2}')"
  echo "RAM utilisée: $(free -h | grep Mem | awk '{print $3}')"
  echo "RAM libre: $(free -h | grep Mem | awk '{print $4}')"
  echo ""

  echo "### Top conteneurs par mémoire:"
  docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}" | head -10
  echo ""

  echo "### Espace disque projet:"
  du -sh "$PROJECT_DIR" 2>/dev/null || echo "Impossible de calculer taille projet"
  echo ""
} >> "$RAPPORT_FILE" 2>&1

# =============================================================================
# SECTION 9: HISTORIQUE ET LOGS INSTALLATION
# =============================================================================
echo "📜 Recherche logs installation..." >&2

cat >> "$RAPPORT_FILE" << 'SECTION9'
## 8. LOGS INSTALLATION

### Logs Week2 récents:
EOF

{
  echo "Logs d'installation trouvés:"
  ls -la /var/log/pi5-setup-week2-supabase-* 2>/dev/null | tail -3 || echo "Aucun log d'installation trouvé"

  echo ""
  echo "### Dernières erreurs dans logs système:"
  journalctl --since "1 hour ago" -p err --no-pager | tail -10 2>/dev/null || echo "Impossible d'accéder aux journaux système"
  echo ""
} >> "$RAPPORT_FILE" 2>&1

# =============================================================================
# SECTION 10: RÉSUMÉ ET ACTIONS SUGGÉRÉES
# =============================================================================
echo "📋 Génération résumé..." >&2

cat >> "$RAPPORT_FILE" << 'SECTION10'
## 9. RÉSUMÉ AUTOMATIQUE ET ACTIONS SUGGÉRÉES

### Problèmes détectés automatiquement:
EOF

{
  local issues=()

  # Vérification .env
  if [[ ! -f "$PROJECT_DIR/.env" ]]; then
    issues+=("CRITIQUE: Fichier .env manquant")
  fi

  # Vérification services restart
  local restarting=$(docker ps --filter "status=restarting" --format "{{.Names}}" | grep "supabase-" || true)
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
} >> "$RAPPORT_FILE" 2>&1

# =============================================================================
# FINALISATION
# =============================================================================

cat >> "$RAPPORT_FILE" << 'FOOTER'
# =============================================================================
# FIN RAPPORT DIAGNOSTIC AUTOMATIQUE
# =============================================================================
#
# INSTRUCTIONS POUR L'UTILISATEUR:
# 1. Copiez TOUT le contenu de ce fichier
# 2. Collez-le dans Claude Code
# 3. Demandez: "Analyse ce rapport et donne-moi les corrections"
#
# NEXT: Claude analysera et proposera corrections spécifiques
# =============================================================================
FOOTER

# Permissions et finalisation
chown "$TARGET_USER:$TARGET_USER" "$RAPPORT_FILE" 2>/dev/null || true
chmod 644 "$RAPPORT_FILE"

echo ""
ok "✅ Rapport diagnostic généré avec succès!"
echo "📍 Emplacement: $RAPPORT_FILE"
echo ""
echo "🔥 PROCHAINES ÉTAPES:"
echo "1. Ouvrez le fichier sur votre bureau: $(basename "$RAPPORT_FILE")"
echo "2. Copiez TOUT le contenu (Ctrl+A puis Ctrl+C)"
echo "3. Collez dans Claude Code et dites: 'Analyse ce rapport et donne corrections'"
echo ""
echo "💡 Le rapport contient TOUT ce dont Claude a besoin pour diagnostiquer!"