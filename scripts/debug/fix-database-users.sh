#!/usr/bin/env bash
set -euo pipefail

# === FIX DATABASE USERS - Create missing Supabase PostgreSQL users ===

log()  { echo -e "\033[1;36m[DB-USERS]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-20
}

main() {
    log "🔧 Fix utilisateurs PostgreSQL manquants pour Supabase"

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -f "docker-compose.yml" ]] || [[ ! -f ".env" ]]; then
        error "❌ Pas dans le répertoire Supabase ou fichiers manquants"
        echo "Exécute : cd ~/stacks/supabase && ./fix-database-users.sh"
        exit 1
    fi

    log "📍 Répertoire : $(pwd)"

    echo ""
    echo "==================== DIAGNOSTIC POSTGRESQL ===================="

    # Vérifier que PostgreSQL fonctionne
    if ! docker compose ps db | grep -q "Up.*healthy"; then
        error "❌ PostgreSQL n'est pas en état healthy"
        log "État actuel :"
        docker compose ps db
        echo ""
        error "Corrigez d'abord PostgreSQL avant de continuer"
        exit 1
    fi

    ok "✅ PostgreSQL conteneur en état healthy"

    # Découvrir la configuration PostgreSQL
    log "🔍 Découverte de la configuration PostgreSQL..."

    log "Variables d'environnement PostgreSQL :"
    if docker compose exec db env | grep -E "(POSTGRES|SUPABASE)" | head -10; then
        ok "✅ Variables PostgreSQL trouvées"
    else
        warn "⚠️  Variables PostgreSQL non standard"
    fi

    echo ""
    log "📋 Tentative de connexion avec différents utilisateurs..."

    # Tester différents utilisateurs possibles
    DB_USERS=("postgres" "supabase_admin" "supabase" "root")
    WORKING_USER=""

    for user in "${DB_USERS[@]}"; do
        log "Test connexion avec utilisateur: $user"
        if docker compose exec -T db psql -U "$user" -d postgres -c "SELECT version();" >/dev/null 2>&1; then
            ok "✅ Connexion réussie avec utilisateur: $user"
            WORKING_USER="$user"
            break
        else
            warn "❌ Échec connexion avec: $user"
        fi
    done

    if [[ -z "$WORKING_USER" ]]; then
        error "❌ Impossible de se connecter à PostgreSQL avec aucun utilisateur"
        log "Essai de récupération..."

        # Essayer de voir les logs PostgreSQL
        log "📋 Logs PostgreSQL récents :"
        docker compose logs db --tail=10 | tail -5

        error "Consultez les logs ci-dessus et corrigez la configuration PostgreSQL"
        exit 1
    fi

    echo ""
    echo "==================== ANALYSE UTILISATEURS EXISTANTS ===================="

    log "👥 Utilisateurs existants dans PostgreSQL :"
    docker compose exec -T db psql -U "$WORKING_USER" -d postgres -c "\du" | head -20 || warn "Impossible de lister les utilisateurs"

    echo ""
    echo "==================== GÉNÉRATION MOTS DE PASSE SÉCURISÉS ===================="

    # Générer des mots de passe sécurisés
    AUTH_PASSWORD=$(generate_password)
    STORAGE_PASSWORD=$(generate_password)
    ANON_PASSWORD=$(generate_password)

    log "🔐 Mots de passe générés :"
    echo "  - authenticator: $AUTH_PASSWORD"
    echo "  - supabase_storage_admin: $STORAGE_PASSWORD"
    echo "  - anon: $ANON_PASSWORD"

    echo ""
    echo "==================== CRÉATION UTILISATEURS MANQUANTS ===================="

    # Sauvegarder .env
    cp .env .env.backup.users.$(date +%Y%m%d_%H%M%S)

    # Créer utilisateur authenticator
    log "👤 Création utilisateur 'authenticator'..."
    if docker compose exec -T db psql -U "$WORKING_USER" -d postgres -c "
        DROP USER IF EXISTS authenticator;
        CREATE USER authenticator WITH ENCRYPTED PASSWORD '$AUTH_PASSWORD';
        GRANT USAGE ON SCHEMA public TO authenticator;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO authenticator;
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO authenticator;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO authenticator;
    " >/dev/null 2>&1; then
        ok "✅ Utilisateur 'authenticator' créé avec succès"
    else
        warn "⚠️  Erreur lors de la création de 'authenticator'"
        docker compose exec -T db psql -U "$WORKING_USER" -d postgres -c "SELECT 1;" >/dev/null 2>&1 || error "Base de données inaccessible"
    fi

    # Créer utilisateur supabase_storage_admin
    log "👤 Création utilisateur 'supabase_storage_admin'..."
    if docker compose exec -T db psql -U "$WORKING_USER" -d postgres -c "
        DROP USER IF EXISTS supabase_storage_admin;
        CREATE USER supabase_storage_admin WITH ENCRYPTED PASSWORD '$STORAGE_PASSWORD';
        GRANT USAGE ON SCHEMA public TO supabase_storage_admin;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO supabase_storage_admin;
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO supabase_storage_admin;
        GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO supabase_storage_admin;
    " >/dev/null 2>&1; then
        ok "✅ Utilisateur 'supabase_storage_admin' créé avec succès"
    else
        warn "⚠️  Erreur lors de la création de 'supabase_storage_admin'"
    fi

    # Créer utilisateur anon (si nécessaire)
    log "👤 Création utilisateur 'anon'..."
    if docker compose exec -T db psql -U "$WORKING_USER" -d postgres -c "
        DROP USER IF EXISTS anon;
        CREATE USER anon WITH ENCRYPTED PASSWORD '$ANON_PASSWORD';
        GRANT USAGE ON SCHEMA public TO anon;
    " >/dev/null 2>&1; then
        ok "✅ Utilisateur 'anon' créé avec succès"
    else
        warn "⚠️  Erreur lors de la création de 'anon'"
    fi

    echo ""
    echo "==================== MISE À JOUR CONFIGURATION ===================="

    # Mettre à jour .env avec les mots de passe
    log "📝 Mise à jour fichier .env avec nouveaux mots de passe..."

    # Supprimer anciennes entrées
    sed -i '/AUTHENTICATOR_PASSWORD/d' .env || true
    sed -i '/SUPABASE_STORAGE_PASSWORD/d' .env || true
    sed -i '/ANON_PASSWORD/d' .env || true

    # Ajouter nouveaux mots de passe
    echo "AUTHENTICATOR_PASSWORD=$AUTH_PASSWORD" >> .env
    echo "SUPABASE_STORAGE_PASSWORD=$STORAGE_PASSWORD" >> .env
    echo "ANON_PASSWORD=$ANON_PASSWORD" >> .env

    ok "✅ Mots de passe ajoutés au fichier .env"

    # Vérifier que les variables API sont présentes
    log "🔍 Vérification variables API dans .env..."
    if grep -q "API_EXTERNAL_URL=" .env; then
        ok "✅ API_EXTERNAL_URL présente"
    else
        warn "❌ API_EXTERNAL_URL manquante - ajout..."
        LOCAL_IP=$(hostname -I | awk '{print $1}')
        echo "API_EXTERNAL_URL=http://$LOCAL_IP:8001" >> .env
        ok "✅ API_EXTERNAL_URL ajoutée"
    fi

    echo ""
    echo "==================== REDÉMARRAGE SERVICES ===================="

    log "🔄 Redémarrage des services dépendants de PostgreSQL..."

    # Redémarrer les services qui ont des erreurs d'authentification
    docker compose restart auth rest storage realtime

    log "⏳ Attente initialisation services (60s)..."
    sleep 60

    echo ""
    echo "==================== VÉRIFICATION FINALE ===================="

    log "👥 Utilisateurs PostgreSQL après création :"
    docker compose exec -T db psql -U "$WORKING_USER" -d postgres -c "SELECT usename, usecreatedb, usesuper FROM pg_user ORDER BY usename;" | head -10

    log "🧪 Test connexions avec nouveaux utilisateurs :"

    # Test authenticator
    if docker compose exec -T db psql -U authenticator -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        ok "  ✅ Connexion 'authenticator' : OK"
    else
        warn "  ❌ Connexion 'authenticator' : ÉCHEC"
    fi

    # Test supabase_storage_admin
    if docker compose exec -T db psql -U supabase_storage_admin -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        ok "  ✅ Connexion 'supabase_storage_admin' : OK"
    else
        warn "  ❌ Connexion 'supabase_storage_admin' : ÉCHEC"
    fi

    log "📊 État des services après redémarrage :"
    docker compose ps --format "table {{.Name}}\t{{.Status}}" | head -10

    echo ""
    echo "==================== RÉSULTATS ===================="
    echo "✅ Utilisateurs PostgreSQL créés avec succès"
    echo "✅ Mots de passe sécurisés générés et sauvegardés"
    echo "✅ Configuration .env mise à jour"
    echo "✅ Services redémarrés avec nouvelles credentials"
    echo ""
    echo "🔐 Mots de passe générés (sauvegardés dans .env) :"
    echo "   authenticator: $AUTH_PASSWORD"
    echo "   supabase_storage_admin: $STORAGE_PASSWORD"
    echo "   anon: $ANON_PASSWORD"
    echo ""
    echo "📋 Sauvegarde configuration : .env.backup.users.$(date +%Y%m%d_%H%M%S)"
    echo ""
    echo "🧪 Vérifications recommandées :"
    echo "   ./check-services-status.sh    # État services"
    echo "   ./test-api-connectivity.sh    # Test APIs"
    echo "   docker compose logs auth      # Logs Auth"
    echo "   docker compose logs storage   # Logs Storage"
    echo ""
    echo "🎯 Si services fonctionnent maintenant :"
    echo "   http://$(hostname -I | awk '{print $1}'):3000 (Studio)"
    echo "   http://$(hostname -I | awk '{print $1}'):8001 (API)"
    echo "=================================================="
}

main "$@"