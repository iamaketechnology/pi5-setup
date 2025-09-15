#!/bin/bash

# DIAGNOSTIC PORTS 8000/8001 - Identification API Délices vs Supabase
# Pour résoudre la confusion entre l'API trouvée sur port 8000

set -euo pipefail

echo "🔍 DIAGNOSTIC PORTS 8000/8001 - $(date)"
echo "=========================================="

# 1. Lister tous les processus utilisant ports 8000 et 8001
echo ""
echo "=== PROCESSUS UTILISANT PORTS 8000/8001 ==="
echo "Port 8000:"
sudo lsof -i :8000 2>/dev/null || echo "Aucun processus sur port 8000"
echo ""
echo "Port 8001:"
sudo lsof -i :8001 2>/dev/null || echo "Aucun processus sur port 8001"

# 2. Vérifier conteneurs Docker sur ces ports
echo ""
echo "=== CONTENEURS DOCKER PORTS 8000/8001 ==="
echo "Mapping ports Docker:"
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "(8000|8001)" || echo "Aucun conteneur Docker sur ces ports"

# 3. Test API port 8000 (Délices & Pâtisseries)
echo ""
echo "=== TEST API PORT 8000 ==="
if curl -s -m 5 http://localhost:8000 2>/dev/null; then
    echo "Réponse port 8000:"
    curl -s -m 5 http://localhost:8000 | jq . 2>/dev/null || curl -s -m 5 http://localhost:8000
else
    echo "Port 8000 non accessible"
fi

# 4. Test API port 8001 (Supabase attendu)
echo ""
echo "=== TEST API PORT 8001 ==="
if curl -s -m 5 http://localhost:8001 2>/dev/null; then
    echo "Réponse port 8001:"
    curl -s -m 5 http://localhost:8001 | head -10
else
    echo "Port 8001 non accessible"
fi

# 5. Vérifier services systemd potentiels
echo ""
echo "=== SERVICES SYSTEMD ACTIFS ==="
systemctl list-units --type=service --state=active | grep -E "(delice|patisserie|bakery|food)" || echo "Aucun service Délices détecté"

# 6. Rechercher fichiers/projets contenant "délices" ou "pâtisseries"
echo ""
echo "=== RECHERCHE PROJETS DÉLICES ==="
echo "Recherche dans /home/*/:"
find /home/*/stacks /home/*/projects /home/*/www /home/*/docker* -type d -name "*delice*" -o -name "*patisserie*" 2>/dev/null || true
find /home/* -type f -name "*docker-compose*" -exec grep -l -i "délices\|patisserie\|bakery" {} \; 2>/dev/null || true

# 7. Vérifier configuration Supabase actuelle
echo ""
echo "=== CONFIGURATION SUPABASE ==="
if [[ -f "/home/${SUDO_USER:-pi}/stacks/supabase/.env" ]]; then
    echo "Port Supabase configuré:"
    grep "SUPABASE_PORT" "/home/${SUDO_USER:-pi}/stacks/supabase/.env" || echo "SUPABASE_PORT non trouvé dans .env"

    echo "Services Supabase:"
    cd "/home/${SUDO_USER:-pi}/stacks/supabase" && docker compose ps --format "table {{.Names}}\t{{.State}}\t{{.Ports}}" 2>/dev/null || echo "Supabase non démarré"
else
    echo "Configuration Supabase non trouvée"
fi

# 8. Netstat détaillé
echo ""
echo "=== ÉCOUTE RÉSEAU DÉTAILLÉE ==="
echo "Tous les ports en écoute 8000-8010:"
sudo netstat -tlnp | grep -E ":800[0-9]" | head -10

echo ""
echo "🎯 RECOMMANDATIONS:"
echo "1. Si API Délices sur 8000 = projet séparé à identifier"
echo "2. Si Supabase sur 8001 = configuration correcte"
echo "3. Vérifier que Kong route bien vers 8001, pas 8000"