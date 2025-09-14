#!/usr/bin/env bash
set -euo pipefail

# === SCRIPT DEBUG: Test API Supabase ===
# Teste toutes les APIs Supabase

log() { echo -e "\033[1;36m[API-TEST]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }
ok() { echo -e "\033[1;32m[OK]\033[0m $*"; }

log "🧪 Test complet des APIs Supabase..."

cd ~/stacks/supabase || {
    error "Répertoire ~/stacks/supabase non trouvé"
    exit 1
}

# Récupérer les clés depuis .env
if [[ -f .env ]]; then
    source .env
    ANON_KEY="${SUPABASE_ANON_KEY:-}"
    SERVICE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"
else
    error "Fichier .env non trouvé"
    exit 1
fi

LOCAL_IP="localhost"
API_PORT="8001"

echo ""
echo "==================== TESTS API REST ===================="

# 1. Test API REST de base
log "Test API REST de base..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$LOCAL_IP:$API_PORT/rest/v1/" \
    -H "apikey: $ANON_KEY" 2>/dev/null || echo "000")

if [[ "$RESPONSE" == "200" ]]; then
    ok "✅ API REST accessible"
else
    error "❌ API REST non accessible (HTTP $RESPONSE)"
fi

# 2. Test création table simple
log "Test création table de test..."
CREATE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "http://$LOCAL_IP:$API_PORT/rest/v1/rpc/exec_sql" \
    -H "apikey: $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -d '{"sql": "CREATE TABLE IF NOT EXISTS test_pi5 (id SERIAL PRIMARY KEY, name TEXT, created_at TIMESTAMP DEFAULT NOW())"}' \
    2>/dev/null || echo "000")

if [[ "$CREATE_RESPONSE" == "200" ]] || [[ "$CREATE_RESPONSE" == "201" ]]; then
    ok "✅ Création table test réussie"
else
    warn "⚠️ Création table (HTTP $CREATE_RESPONSE) - peut-être déjà existante"
fi

echo ""
echo "==================== TESTS AUTHENTIFICATION ===================="

# 3. Test service Auth
log "Test service authentification..."
AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$LOCAL_IP:$API_PORT/auth/v1/settings" \
    -H "apikey: $ANON_KEY" 2>/dev/null || echo "000")

if [[ "$AUTH_RESPONSE" == "200" ]]; then
    ok "✅ Service Auth accessible"
else
    error "❌ Service Auth non accessible (HTTP $AUTH_RESPONSE)"
fi

echo ""
echo "==================== TESTS STORAGE ===================="

# 4. Test service Storage
log "Test service stockage..."
STORAGE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$LOCAL_IP:$API_PORT/storage/v1/buckets" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $ANON_KEY" 2>/dev/null || echo "000")

if [[ "$STORAGE_RESPONSE" == "200" ]]; then
    ok "✅ Service Storage accessible"
else
    error "❌ Service Storage non accessible (HTTP $STORAGE_RESPONSE)"
fi

echo ""
echo "==================== TESTS REALTIME ===================="

# 5. Test service Realtime
log "Test service temps réel..."
REALTIME_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://$LOCAL_IP:$API_PORT/realtime/v1/" \
    -H "apikey: $ANON_KEY" 2>/dev/null || echo "000")

if [[ "$REALTIME_RESPONSE" == "426" ]] || [[ "$REALTIME_RESPONSE" == "200" ]]; then
    ok "✅ Service Realtime accessible (WebSocket upgrade attendu)"
else
    error "❌ Service Realtime non accessible (HTTP $REALTIME_RESPONSE)"
fi

echo ""
echo "==================== TESTS EDGE FUNCTIONS ===================="

# 6. Test Edge Functions
log "Test fonctions serverless..."
if curl -s "http://$LOCAL_IP:54321/functions/v1/hello" \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "Content-Type: application/json" \
    -d '{"name": "Pi5-Test"}' >/dev/null 2>&1; then
    ok "✅ Edge Functions accessibles"
else
    warn "⚠️ Edge Functions peuvent ne pas être configurées"
fi

echo ""
echo "==================== TEST BASE DE DONNÉES ===================="

# 7. Test direct PostgreSQL
log "Test connexion directe PostgreSQL..."
if sudo docker compose exec -T db psql -U supabase_admin -d postgres -c "\l" >/dev/null 2>&1; then
    ok "✅ PostgreSQL accessible via Docker"

    # Test insertion données
    sudo docker compose exec -T db psql -U supabase_admin -d postgres -c \
        "INSERT INTO test_pi5 (name) VALUES ('API Test $(date)');" >/dev/null 2>&1 && \
    ok "✅ Insertion données réussie" || warn "⚠️ Insertion données échouée"

    # Compter enregistrements
    COUNT=$(sudo docker compose exec -T db psql -U supabase_admin -d postgres -t -c \
        "SELECT COUNT(*) FROM test_pi5;" 2>/dev/null | tr -d ' \n' || echo "0")
    log "Enregistrements dans test_pi5: $COUNT"
else
    error "❌ PostgreSQL non accessible"
fi

echo ""
echo "==================== RÉSUMÉ TESTS ===================="

LOCAL_IP_EXTERNAL=$(hostname -I | awk '{print $1}')
echo "🌐 Interface web : http://$LOCAL_IP_EXTERNAL:3000"
echo "🔌 API REST     : http://$LOCAL_IP_EXTERNAL:$API_PORT/rest/v1/"
echo "🔐 API Auth     : http://$LOCAL_IP_EXTERNAL:$API_PORT/auth/v1/"
echo "📁 API Storage  : http://$LOCAL_IP_EXTERNAL:$API_PORT/storage/v1/"
echo "⚡ Edge Func    : http://$LOCAL_IP_EXTERNAL:54321/functions/v1/"
echo ""
echo "🔑 Clés API (depuis .env) :"
echo "   ANON_KEY: ${ANON_KEY:0:20}..."
echo "   SERVICE_KEY: ${SERVICE_KEY:0:20}..."
echo "================================================================"