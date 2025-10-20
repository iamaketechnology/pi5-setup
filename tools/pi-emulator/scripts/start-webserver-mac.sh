#!/bin/bash
# =============================================================================
# Start Web Server - Mac (Share scripts with Linux)
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-20
# Author: PI5-SETUP Project
# Usage: bash start-webserver-mac.sh
# =============================================================================

set -euo pipefail

# Logging inline
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $*"; }

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUESTED_PORT="${1:-}"

log_info "Serveur Web Temporaire - Partage Scripts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Fonction pour vérifier si un port est libre
is_port_free() {
    ! lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1
}

# Fonction pour trouver un port libre
find_free_port() {
    # Liste de ports candidats (évite les ports système et services Pi communs)
    # Évite: 22(SSH), 80(HTTP), 443(HTTPS), 3000(apps), 5432(Postgres),
    #        8000(common), 8080(HTTP-alt), 8443(HTTPS-alt), 9000(Minio)
    local CANDIDATE_PORTS=(8765 9876 7654 6789 8123 9123 7777 6666 8888 9999)

    for port in "${CANDIDATE_PORTS[@]}"; do
        if is_port_free $port; then
            echo $port
            return 0
        fi
    done

    # Si aucun port candidat libre, chercher dans une plage haute
    for port in {10000..10100}; do
        if is_port_free $port; then
            echo $port
            return 0
        fi
    done

    return 1
}

# Détection intelligente du port
if [[ -n "$REQUESTED_PORT" ]]; then
    # Port spécifié par l'utilisateur
    if is_port_free $REQUESTED_PORT; then
        PORT=$REQUESTED_PORT
        log_info "Utilisation du port demandé: ${PORT}"
    else
        log_warning "Port ${REQUESTED_PORT} déjà utilisé"
        EXISTING_PID=$(lsof -Pi :${REQUESTED_PORT} -sTCP:LISTEN -t)
        EXISTING_CMD=$(ps -p ${EXISTING_PID} -o comm= 2>/dev/null || echo "inconnu")
        log_info "Occupé par: ${EXISTING_CMD} (PID ${EXISTING_PID})"

        log_info "Recherche d'un port libre..."
        PORT=$(find_free_port)
        if [[ -z "$PORT" ]]; then
            log_error "Aucun port libre trouvé"
            exit 1
        fi
        log_success "Port libre trouvé: ${PORT}"
    fi
else
    # Auto-détection
    log_info "Recherche d'un port libre..."
    PORT=$(find_free_port)
    if [[ -z "$PORT" ]]; then
        log_error "Aucun port libre trouvé"
        exit 1
    fi
    log_success "Port libre trouvé: ${PORT}"
fi

echo ""

# Obtenir IP du Mac
log_info "Détection IP du Mac..."

MAC_IP=$(ifconfig en0 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}')

if [[ -z "$MAC_IP" ]]; then
    MAC_IP=$(ifconfig en1 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}')
fi

if [[ -z "$MAC_IP" ]]; then
    log_error "Impossible de détecter l'IP du Mac"
    log_info "Vérifier connexion réseau"
    exit 1
fi

log_success "IP détectée: ${MAC_IP}"
echo ""

# Lancer serveur web
log_info "Démarrage serveur web sur port ${PORT}..."

cd "${SCRIPT_DIR}"

# Créer fichier index HTML pour faciliter navigation
cat > index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Pi Emulator Scripts</title>
    <style>
        body { font-family: monospace; margin: 40px; background: #1e1e1e; color: #00ff00; }
        h1 { color: #00ff00; }
        ul { list-style: none; padding: 0; }
        li { margin: 10px 0; }
        a { color: #00ffff; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .command { background: #333; padding: 10px; margin: 10px 0; border-left: 3px solid #00ff00; }
    </style>
</head>
<body>
    <h1>🚀 Pi Emulator Scripts</h1>
    <p>Serveur temporaire pour transfert de scripts vers Linux Mint</p>

    <h2>📥 Télécharger sur Linux:</h2>
    <div class="command">
        curl -O http://${MAC_IP}:${PORT}/linux-setup-ssh.sh<br>
        sudo bash linux-setup-ssh.sh
    </div>

    <h2>📂 Scripts disponibles:</h2>
    <ul>
        <li><a href="linux-setup-ssh.sh">linux-setup-ssh.sh</a> - Installation SSH sur Linux</li>
        <li><a href="00-setup-ssh-access.sh">00-setup-ssh-access.sh</a> - Configuration SSH Mac→Linux</li>
        <li><a href="01-pi-emulator-deploy-linux.sh">01-pi-emulator-deploy-linux.sh</a> - Déploiement émulateur</li>
        <li><a href="01-pi-emulator-deploy-mac.sh">01-pi-emulator-deploy-mac.sh</a> - Déploiement Mac</li>
        <li><a href="02-pi-init-services.sh">02-pi-init-services.sh</a> - Init services de base</li>
        <li><a href="test-ssh.sh">test-ssh.sh</a> - Test connexion SSH</li>
    </ul>
</body>
</html>
EOF

# Lancer serveur en arrière-plan
python3 -m http.server ${PORT} > /tmp/webserver-pi-emulator.log 2>&1 &
SERVER_PID=$!

sleep 2

# Vérifier si le serveur tourne
if ! ps -p ${SERVER_PID} > /dev/null 2>&1; then
    log_error "Échec démarrage serveur"
    cat /tmp/webserver-pi-emulator.log
    exit 1
fi

# Sauvegarder PID pour pouvoir arrêter plus tard
echo ${SERVER_PID} > /tmp/webserver-pi-emulator.pid

log_success "Serveur web démarré (PID: ${SERVER_PID})"
echo ""

# Résumé
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 SERVEUR WEB ACTIF"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ CONFIGURATION:"
echo "   IP Mac    : ${MAC_IP}"
echo "   Port      : ${PORT}"
echo "   PID       : ${SERVER_PID}"
echo "   Répertoire: ${SCRIPT_DIR}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📥 ÉTAPE 1/3 - SUR TON LINUX MINT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Ouvre un terminal sur ton Linux Mint et COPIE-COLLE:"
echo ""
echo "┌────────────────────────────────────────────────────┐"
echo "│ curl -O http://${MAC_IP}:${PORT}/linux-setup-ssh.sh │"
echo "│ sudo bash linux-setup-ssh.sh                       │"
echo "└────────────────────────────────────────────────────┘"
echo ""
echo "Le script va:"
echo "  ✅ Installer SSH server"
echo "  ✅ Configurer SSH automatiquement"
echo "  ✅ T'afficher l'IP de ton Linux"
echo "  ✅ Te dire la prochaine étape"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 ÉTAPE 2/3 - RETOUR SUR TON MAC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Une fois le script Linux terminé, lance sur ton Mac:"
echo ""
echo "┌────────────────────────────────────────────────────┐"
echo "│ cd tools/pi-emulator                               │"
echo "│ bash scripts/00-setup-ssh-access.sh                │"
echo "└────────────────────────────────────────────────────┘"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🛑 ÉTAPE 3/3 - ARRÊTER CE SERVEUR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Après avoir téléchargé le script sur Linux:"
echo ""
echo "┌────────────────────────────────────────────────────┐"
echo "│ bash scripts/stop-webserver-mac.sh                 │"
echo "└────────────────────────────────────────────────────┘"
echo ""
echo "OU manuellement:"
echo "  kill ${SERVER_PID}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 INTERFACE WEB (OPTIONNEL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Accès depuis ton Mac: http://${MAC_IP}:${PORT}"
echo ""

# Option: Ouvrir dans navigateur
read -p "Ouvrir l'interface web dans le navigateur? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "http://${MAC_IP}:${PORT}" 2>/dev/null || true
    log_success "Interface web ouverte"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Serveur prêt ! Va sur ton Linux Mint maintenant"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "Logs en temps réel: tail -f /tmp/webserver-pi-emulator.log"
log_warning "Laisse ce terminal ouvert pendant le téléchargement"
echo ""
