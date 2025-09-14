#!/usr/bin/env bash
set -euo pipefail

# === SCRIPT DEBUG: Conflit Port 8000 ===
# Résout le conflit de port pour Kong API Gateway

log() { echo -e "\033[1;36m[DEBUG]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }
ok() { echo -e "\033[1;32m[OK]\033[0m $*"; }

log "🔍 Diagnostic conflit port 8000..."

# 1. Identifier qui utilise le port 8000
log "Vérification port 8000 en cours d'utilisation :"
sudo netstat -tlnp | grep :8000 || log "Port 8000 libre"

# 2. Vérifier les conteneurs actifs
log "Conteneurs Docker actifs :"
sudo docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"

# 3. Arrêter tous les conteneurs Supabase
log "Arrêt des conteneurs Supabase..."
cd ~/stacks/supabase
sudo docker compose down 2>/dev/null || log "Aucun docker-compose à arrêter"

# 4. Arrêter tous les autres conteneurs si nécessaire
log "Arrêt de tous les conteneurs actifs..."
sudo docker stop $(sudo docker ps -q) 2>/dev/null || log "Aucun conteneur à arrêter"

# 5. Nettoyer les réseaux
log "Nettoyage des réseaux Docker..."
sudo docker network prune -f

ok "✅ Nettoyage terminé"

# 6. Modifier les ports dans la configuration
log "Modification ports Kong: 8000 → 8001..."

# Modifier .env
if [[ -f .env ]]; then
    sudo sed -i 's/API_PORT=8000/API_PORT=8001/g' .env
    ok "Port modifié dans .env"
else
    error "Fichier .env non trouvé"
fi

# Modifier docker-compose.yml
if [[ -f docker-compose.yml ]]; then
    sudo sed -i 's/8000:8000/8001:8000/g' docker-compose.yml
    ok "Port modifié dans docker-compose.yml"
else
    error "Fichier docker-compose.yml non trouvé"
fi

# 7. Vérifier les modifications
log "Vérification des modifications :"
grep -n "8001" .env || log "Pas de modification dans .env"
grep -n "8001" docker-compose.yml || log "Pas de modification dans docker-compose.yml"

log "🚀 Prêt pour redémarrage sur port 8001"
echo ""
echo "Prochaine étape : ./restart-supabase.sh"