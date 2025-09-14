#!/usr/bin/env bash
set -euo pipefail

# === SCRIPT DEBUG: Vérification Santé Supabase ===
# Vérifie que tous les services Supabase fonctionnent

log() { echo -e "\033[1;36m[HEALTH]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }
ok() { echo -e "\033[1;32m[OK]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }

log "🏥 Vérification santé Supabase..."

cd ~/stacks/supabase || {
    error "Répertoire ~/stacks/supabase non trouvé"
    exit 1
}

LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "==================== DIAGNOSTIC SYSTÈME ===================="

# 1. Page size
CURRENT_PAGE_SIZE=$(getconf PAGE_SIZE)
log "Page size: $CURRENT_PAGE_SIZE"
if [[ "$CURRENT_PAGE_SIZE" == "16384" ]]; then
    ok "✅ Page size 16KB - Configuration compatible utilisée"
elif [[ "$CURRENT_PAGE_SIZE" == "4096" ]]; then
    ok "✅ Page size 4KB - Configuration standard"
else
    warn "⚠️ Page size inattendu: $CURRENT_PAGE_SIZE"
fi

# 2. RAM disponible
RAM_TOTAL=$(free -h | grep Mem | awk '{print $2}')
RAM_USED=$(free -h | grep Mem | awk '{print $3}')
log "RAM: $RAM_USED utilisé / $RAM_TOTAL total"

# 3. Espace disque
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
log "Disque: $DISK_USAGE utilisé, $DISK_AVAIL disponible"

echo ""
echo "==================== ÉTAT CONTENEURS ===================="

# 4. État des conteneurs
log "État des services Docker :"
sudo docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "==================== TESTS CONNECTIVITÉ ===================="

# 5. Tests de connectivité
services=(
    "Studio:3000:/:Interface web Supabase"
    "API Gateway:8001:/rest/v1/:API REST"
    "Edge Functions:54321/functions/v1/hello:Fonctions serverless"
    "Auth:8001/auth/v1/:Service authentification"
    "Realtime:8001/realtime/v1/:Service temps réel"
    "Storage:8001/storage/v1/:Service stockage"
)

for service in "${services[@]}"; do
    IFS=':' read -r name port path desc <<< "$service"

    if curl -s -I "http://localhost:$port$path" >/dev/null 2>&1; then
        ok "✅ $name ($desc)"
    else
        error "❌ $name non accessible sur port $port"
    fi
done

echo ""
echo "==================== BASE DE DONNÉES ===================="

# 6. Test base de données
log "Test connexion PostgreSQL..."
if sudo docker compose exec -T db pg_isready -U supabase_admin >/dev/null 2>&1; then
    ok "✅ PostgreSQL opérationnel"

    # Test simple requête
    if sudo docker compose exec -T db psql -U supabase_admin -d postgres -c "SELECT version();" >/dev/null 2>&1; then
        ok "✅ Requêtes PostgreSQL fonctionnelles"
    else
        error "❌ Requêtes PostgreSQL échouent"
    fi
else
    error "❌ PostgreSQL non accessible"
fi

echo ""
echo "==================== UTILISATION RESSOURCES ===================="

# 7. Utilisation des ressources
log "Utilisation mémoire par conteneur :"
sudo docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}" 2>/dev/null || warn "Statistiques non disponibles"

echo ""
echo "==================== RÉSUMÉ ===================="
echo "🌐 Accès web : http://$LOCAL_IP:3000 (Studio)"
echo "🔌 API REST  : http://$LOCAL_IP:8001/rest/v1/"
echo "📁 Logs     : sudo docker compose logs [service]"
echo ""
echo "🛠️ Scripts disponibles :"
echo "   ./debug-port-conflict.sh    # Résoudre conflits ports"
echo "   ./restart-supabase.sh       # Redémarrer services"
echo "   ./test-supabase-api.sh      # Tester API"
echo "================================================================"