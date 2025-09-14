#!/usr/bin/env bash
set -euo pipefail

# === SCRIPT DEBUG: Redémarrage Supabase ===
# Redémarre Supabase après correction du port

log() { echo -e "\033[1;36m[RESTART]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }
ok() { echo -e "\033[1;32m[OK]\033[0m $*"; }

log "🚀 Redémarrage Supabase avec port corrigé..."

cd ~/stacks/supabase

# 1. Vérifier que nous sommes dans le bon répertoire
if [[ ! -f docker-compose.yml ]]; then
    error "docker-compose.yml non trouvé dans $(pwd)"
    exit 1
fi

# 2. Démarrer les services
log "Démarrage des services Supabase..."
sudo docker compose up -d

# 3. Attendre que les services démarrent
log "Attente démarrage des services (30 secondes)..."
sleep 30

# 4. Vérifier l'état des services
log "État des services :"
sudo docker compose ps

# 5. Test de connectivité
log "Test de connectivité API Gateway..."
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Test port 8001 (nouveau port)
if curl -s -I http://localhost:8001 >/dev/null 2>&1; then
    ok "✅ API Gateway accessible sur port 8001"
else
    error "❌ API Gateway non accessible sur port 8001"
fi

# Test Studio (port 3000)
if curl -s -I http://localhost:3000 >/dev/null 2>&1; then
    ok "✅ Studio accessible sur port 3000"
else
    error "❌ Studio non accessible sur port 3000"
fi

echo ""
echo "==================== 🎉 SUPABASE DÉMARRÉ ===================="
echo ""
echo "📍 Accès aux services :"
echo "   🎨 Studio      : http://$LOCAL_IP:3000"
echo "   🔌 API Gateway : http://$LOCAL_IP:8001"
echo "   ⚡ Edge Funcs  : http://$LOCAL_IP:54321/functions/v1/"
echo ""
echo "🛠️ Scripts de diagnostic :"
echo "   ./check-supabase-health.sh"
echo "   ./test-supabase-api.sh"
echo "================================================================"