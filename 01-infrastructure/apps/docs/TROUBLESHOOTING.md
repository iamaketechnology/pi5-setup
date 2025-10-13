# Guide de Dépannage - Déploiement d'Applications React/Vite/Next.js

> **Basé sur les problèmes réels rencontrés lors de déploiements**
> Source: certidoc-proof/deployment-pi/CHANGELOG-AND-FIXES.md

---

## 📋 Table des Matières

1. [Problèmes CSS/Tailwind](#problèmes-csstailwind)
2. [Content Security Policy (CSP)](#content-security-policy-csp)
3. [Cache Nginx Trop Agressif](#cache-nginx-trop-agressif)
4. [Conflits de Ports](#conflits-de-ports)
5. [Réseaux Docker](#réseaux-docker)
6. [Fichiers .env](#fichiers-env)
7. [Checklist Post-Déploiement](#checklist-post-déploiement)

---

## 1. Problèmes CSS/Tailwind

### 🔴 CRITIQUE: CSS Non Compilé (Fichier de 5 kB au lieu de 90 kB)

#### Symptômes

- Page s'affiche mais **tout en texte noir sur blanc**
- Aucune couleur, aucune mise en page
- CSS de seulement **5-10 kB** au lieu de 90-100 kB attendu
- Fichier CSS contient `@tailwind base`, `@tailwind components` **non compilés**
- Directives `@apply` non transformées

#### Cause Racine

**Les fichiers de configuration Tailwind et PostCSS ne sont PAS copiés sur le serveur avant le build Docker.**

Fichiers manquants critiques:
- `tailwind.config.ts` ou `tailwind.config.js`
- `postcss.config.js` ou `postcss.config.cjs`
- `components.json` (optionnel mais recommandé pour shadcn/ui)

Sans ces fichiers, **Vite ne peut pas exécuter PostCSS** qui lui-même **ne peut pas exécuter Tailwind**, donc le CSS reste non-compilé.

#### Solution

**Avant le build Docker**, assurez-vous que ces fichiers sont copiés:

```bash
# Vérifier localement
ls -la tailwind.config.ts postcss.config.js

# Copier vers le serveur distant
scp tailwind.config.ts postcss.config.js user@server:/path/to/app/

# Ou utiliser la fonction smart_copy_file du common-scripts/lib.sh
smart_copy_file "tailwind.config.ts" "user@host" "/remote/app/dir"
smart_copy_file "postcss.config.js" "user@host" "/remote/app/dir"
```

**Vérification post-build:**

```bash
# Sur le serveur
docker exec <container> ls -lh /usr/share/nginx/html/assets/*.css

# Le CSS doit faire ~90-100 kB, pas 5 kB
# -rw-r--r-- 1 root root 92K index-abc123.css  ← BON
# -rw-r--r-- 1 root root 5.2K index-abc123.css ← MAUVAIS (non compilé)
```

**Dockerfile correct:**

```dockerfile
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copier TOUS les fichiers de configuration avant npm install
COPY package*.json ./
COPY tsconfig*.json ./
COPY vite.config.ts ./
COPY tailwind.config.ts ./     # ← CRITIQUE
COPY postcss.config.js ./      # ← CRITIQUE
COPY components.json ./        # ← Si shadcn/ui

RUN npm ci --only=production

COPY src ./src
COPY public ./public
COPY index.html ./

# Build avec les configs Tailwind
RUN npm run build
```

#### Prévention

Utilisez la fonction `detect_build_config_files()` de `common-scripts/lib.sh`:

```bash
# Détecter automatiquement les fichiers de configuration
source /opt/pi5-setup/common-scripts/lib.sh

detect_build_config_files "$LOCAL_PROJECT_DIR" | while read -r file; do
    smart_copy_file "$LOCAL_PROJECT_DIR/$file" "user@host" "/remote/app/dir"
done
```

---

## 2. Content Security Policy (CSP)

### 🔴 CRITIQUE: CSP Bloque les Requêtes API Supabase

#### Symptômes

```
Refused to connect to 'http://192.168.1.74:8001/auth/v1/token?grant_type=password'
because it violates the following Content Security Policy directive:
"default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: https:".
Note that 'connect-src' was not explicitly set, so 'default-src' is used as a fallback.
```

- Impossible de se connecter à l'application
- Toutes les requêtes à l'API Supabase sont bloquées
- Erreur **"TypeError: Failed to fetch"** dans la console
- Console browser affiche violations CSP

#### Cause Racine

La CSP par défaut permet seulement **`https:`** mais pas **`http://`** pour les connexions locales.

```nginx
# MAUVAIS - Bloque HTTP local
add_header Content-Security-Policy "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: https:; ...";
```

Problèmes:
1. **`default-src` ne permet pas HTTP local** - Seulement HTTPS
2. **`connect-src` non défini** - Donc `default-src` est utilisé comme fallback
3. **Supabase local est en HTTP** - `http://192.168.1.74:8001`

#### Solution

**Pour environnement de développement avec Supabase auto-hébergé:**

```nginx
# nginx.conf
add_header Content-Security-Policy "
    default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob: https: http://{{SUPABASE_IP}}:* http://{{HOSTNAME}}:*;
    connect-src 'self' http://{{SUPABASE_IP}}:* http://{{HOSTNAME}}:* https:;
    img-src 'self' data: https: http://{{SUPABASE_IP}}:*;
    font-src 'self' data:;
" always;
```

Remplacez:
- `{{SUPABASE_IP}}`: IP du serveur Supabase (ex: `192.168.1.74`)
- `{{HOSTNAME}}`: Hostname local (ex: `pi5.local`)

**Pour environnement de production avec Supabase Cloud:**

```nginx
# nginx.conf
add_header Content-Security-Policy "
    default-src 'self';
    script-src 'self' 'unsafe-inline' 'unsafe-eval';
    style-src 'self' 'unsafe-inline';
    connect-src 'self' https://*.supabase.co https://*.supabase.in;
    img-src 'self' data: https:;
    font-src 'self' data:;
" always;
```

#### Vérification

```bash
# Tester avec curl
curl -I http://192.168.1.74:9000 | grep Content-Security-Policy

# Devrait afficher:
# Content-Security-Policy: default-src 'self' ... http://192.168.1.74:* ...
```

**Ouvrir la console browser (F12) et chercher:**
- ❌ `Refused to connect` → CSP trop restrictive
- ✅ Pas d'erreurs CSP → Configuration correcte

---

## 3. Cache Nginx Trop Agressif

### 🟡 MOYEN: Mises à Jour CSS/JS Non Visibles Après Redéploiement

#### Symptômes

- Après rebuild, les navigateurs continuent à utiliser l'ancien CSS
- Cache de **1 an** avec **`immutable`**
- Impossible de forcer un rechargement sans vider le cache manuellement
- Cmd+Shift+R (hard refresh) ne fonctionne pas

#### Cause Racine

Configuration initiale trop agressive:

```nginx
# MAUVAIS pour développement actif
location ~* \.(js|css|...)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

Le header `immutable` indique au navigateur de **JAMAIS revalider le fichier**, même avec F5.

#### Solution

**Pour développement/staging:**

```nginx
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 30d;                                    # ← 30 jours au lieu de 1 an
    add_header Cache-Control "public, must-revalidate";  # ← Permet revalidation
    add_header X-Content-Type-Options "nosniff" always;

    # Ensure correct MIME types
    types {
        text/css css;
        application/javascript js mjs;
        image/svg+xml svg svgz;
    }
}
```

**Pour production stable avec versioning (hashes dans les noms de fichiers):**

```nginx
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";  # OK si fichiers ont hash
}
```

#### Stratégie Recommandée

| Environnement | Cache Assets | Cache index.html | Raison |
|---------------|-------------|------------------|--------|
| **Développement** | `max-age=0, must-revalidate` | `no-cache, no-store` | Mises à jour immédiates |
| **Staging** | `max-age=2592000, must-revalidate` (30j) | `no-cache` | Balance perf/updates |
| **Production** | `max-age=31536000, immutable` (1 an) | `no-cache` | Max perf (avec hashes) |

#### Forcer le Rechargement Client

```bash
# Utilisateurs: Hard refresh
# Chrome/Firefox: Cmd+Shift+R (Mac) ou Ctrl+Shift+R (Windows/Linux)

# Développeurs: Vider le cache
# Chrome DevTools: Network tab → "Disable cache" (avec DevTools ouvert)
```

---

## 4. Conflits de Ports

### 🔴 BLOQUANT: Port Déjà Utilisé

#### Symptômes

```
Error: Bind for 0.0.0.0:3000 failed: port is already allocated
Error: Bind for 0.0.0.0:8080 failed: port is already allocated
```

#### Cause Racine

Un service existant (Supabase, Traefik, autre app) utilise déjà le port choisi.

Ports couramment utilisés par Supabase:
- **3000**: Supabase Studio
- **3001**: Service interne Supabase
- **8001**: Supabase REST API
- **8080**: Service interne Supabase
- **54321**: PostgreSQL
- **54323-54329**: Services Supabase divers

#### Solution

**Vérifier les ports utilisés avant déploiement:**

```bash
# Sur le serveur
sudo netstat -tlnp | grep LISTEN | grep -E ":(80|30|54|31)"

# Ou avec ss (plus moderne)
sudo ss -tlnp | grep LISTEN
```

**Utiliser la fonction `find_available_port()` de `common-scripts/lib.sh`:**

```bash
source /opt/pi5-setup/common-scripts/lib.sh

# Trouver un port libre entre 9000 et 9100
APP_PORT=$(find_available_port "user@host" 9000 9100)

echo "Port disponible: $APP_PORT"
# Met à jour docker-compose.yml avec $APP_PORT
```

**Ports recommandés pour applications:**

- **9000-9099**: Applications React/Vite/Next.js
- **4000-4099**: APIs Node.js/Express
- **5000-5099**: APIs Python/Flask
- **7000-7099**: Dashboards/monitoring

#### Prévention

Utilisez `check_port_available()` dans vos scripts de déploiement:

```bash
source /opt/pi5-setup/common-scripts/lib.sh

# Vérifier le port avant docker compose up
if ! check_port_available "user@host" "$APP_PORT"; then
    error "Port $APP_PORT non disponible, choisissez un autre port"
fi
```

---

## 5. Réseaux Docker

### 🔴 BLOQUANT: Réseau Docker Introuvable

#### Symptômes

```
Error: network supabase_network_default declared as external, but could not be found
```

#### Cause Racine

Le nom du réseau Docker dans `docker-compose.yml` ne correspond pas au réseau réel créé par Supabase.

```bash
# Vérification
docker network ls | grep supabase

# Exemple de sortie:
# abc123def456  supabase_network  bridge  local  ← Nom réel
```

#### Solution

**Vérifier le nom exact du réseau:**

```bash
# Lister les réseaux
docker network ls

# Inspecter un réseau
docker network inspect supabase_network
```

**Corriger `docker-compose.yml`:**

```yaml
# docker-compose.yml
services:
  app:
    image: myapp:latest
    networks:
      - app-network

networks:
  app-network:
    external: true
    name: supabase_network  # ← Nom EXACT du réseau Docker réel
```

**Utiliser la fonction `check_docker_network()` avant déploiement:**

```bash
source /opt/pi5-setup/common-scripts/lib.sh

# Vérifier que le réseau existe
if ! check_docker_network "user@host" "supabase_network"; then
    error "Réseau Docker 'supabase_network' introuvable"
fi
```

#### Noms de Réseaux Communs

| Stack | Nom du Réseau |
|-------|---------------|
| Supabase | `supabase_network` |
| Traefik | `traefik-proxy` ou `traefik_default` |
| Homepage | `homepage_default` |
| Gitea | `gitea_default` |

---

## 6. Fichiers .env

### 🔴 BLOQUANT: Variables d'Environnement Non Injectées

#### Symptômes

- Build Docker échoue avec erreurs de variables manquantes
- L'application ne peut pas se connecter à Supabase
- Le fichier `.env` n'existe pas sur le serveur distant
- Variables visibles localement mais pas dans le conteneur

#### Cause Racine

**Heredoc SSH mal échappé:**

```bash
# MAUVAIS (variables interprétées localement)
ssh "$PI_HOST" "cat > $PI_APP_DIR/.env << EOF
VITE_SUPABASE_URL=$SUPABASE_URL
EOF"
```

Problème: Les variables sont interprétées **avant** l'envoi SSH, pas sur le serveur distant.

#### Solution

**Méthode robuste pour créer .env via SSH:**

```bash
# Utiliser bash heredoc avec quote 'ENVEOF'
ssh "$PI_HOST" bash <<ENVSCRIPT
set -e
cd $PI_APP_DIR
cat > .env.tmp <<'ENVEOF'
VITE_SUPABASE_URL=$SUPABASE_URL
VITE_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
VITE_SUPABASE_PROJECT_ID=$SUPABASE_PROJECT_ID
ENVEOF
chmod 600 .env.tmp
mv .env.tmp .env
ENVSCRIPT
```

**Ou utiliser `create_remote_env_file()` de `common-scripts/lib.sh`:**

```bash
source /opt/pi5-setup/common-scripts/lib.sh

# Créer .env avec variables (idempotent)
create_remote_env_file "user@host" "/remote/app/dir" \
    "VITE_SUPABASE_URL=$SUPABASE_URL" \
    "VITE_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
    "VITE_SUPABASE_PROJECT_ID=$SUPABASE_PROJECT_ID"
```

#### Vérification

```bash
# Vérifier que le .env existe sur le serveur
ssh user@host "[ -f /path/to/app/.env ] && echo 'OK' || echo 'MANQUANT'"

# Vérifier le contenu (sans afficher les secrets)
ssh user@host "wc -l /path/to/app/.env"
# Devrait afficher: 3 /path/to/app/.env

# Vérifier les permissions (doit être 600)
ssh user@host "stat -c '%a %n' /path/to/app/.env"
# Devrait afficher: 600 /path/to/app/.env
```

**Vérifier que les variables sont injectées dans le conteneur:**

```bash
# Après docker compose up
docker exec <container> env | grep VITE_

# Devrait afficher:
# VITE_SUPABASE_URL=http://192.168.1.74:8001
# VITE_SUPABASE_ANON_KEY=eyJhbGc...
# VITE_SUPABASE_PROJECT_ID=abc123
```

---

## 7. Checklist Post-Déploiement

### ✅ Vérifications Obligatoires

#### Avant le Build Docker

- [ ] `tailwind.config.ts` présent sur le serveur
- [ ] `postcss.config.js` présent sur le serveur
- [ ] `package.json` contient `tailwindcss` et `autoprefixer`
- [ ] Fichier `.env` créé avec les bonnes valeurs
- [ ] Permissions `.env` = 600 (lecture propriétaire uniquement)

#### Configuration Docker

- [ ] Port choisi est libre: `netstat -tlnp | grep :PORT`
- [ ] Nom du réseau Docker correct: `docker network ls`
- [ ] Dockerfile copie TOUS les fichiers de config nécessaires
- [ ] Build local testé avant déploiement distant

#### Configuration Nginx

- [ ] Cache configuré correctement (`must-revalidate` en dev)
- [ ] CSP permissive mais sécurisée (HTTP local si Supabase auto-hébergé)
- [ ] MIME types définis pour JS/CSS
- [ ] Compression gzip activée

#### Post-Déploiement

- [ ] CSS fait ~90-100 kB (Tailwind compilé): `docker exec <container> ls -lh /usr/share/nginx/html/assets/*.css`
- [ ] Accès HTTP fonctionne: `curl -I http://server:port` → 200 OK
- [ ] Logs sans erreurs: `docker logs <container>`
- [ ] Test dans le navigateur (mode privé pour éviter cache)
- [ ] Aucune erreur CSP dans la console browser (F12)
- [ ] Authentification Supabase fonctionne

### 🔍 Script de Vérification Automatique

```bash
#!/bin/bash
# post-deploy-check.sh

PI_HOST="user@host"
APP_DIR="/path/to/app"
CONTAINER="myapp-container"
APP_PORT="9000"

echo "🔍 Vérification du déploiement..."

# 1. Fichiers de configuration
echo -e "\n1️⃣ Fichiers de configuration:"
ssh "$PI_HOST" "ls -lh $APP_DIR/ | grep -E '(tailwind|postcss|\.env)'"

# 2. Conteneur
echo -e "\n2️⃣ Statut du conteneur:"
ssh "$PI_HOST" "docker ps | grep $CONTAINER"

# 3. Taille du CSS
echo -e "\n3️⃣ Taille du CSS buildé:"
ssh "$PI_HOST" "docker exec $CONTAINER ls -lh /usr/share/nginx/html/assets/*.css"

# 4. Test HTTP
echo -e "\n4️⃣ Test HTTP:"
curl -s -o /dev/null -w "Status: %{http_code}\nTime: %{time_total}s\n" "http://$PI_HOST:$APP_PORT"

# 5. Logs récents
echo -e "\n5️⃣ Logs récents (erreurs):"
ssh "$PI_HOST" "docker logs --tail 20 $CONTAINER 2>&1 | grep -i error || echo 'Aucune erreur'"

# 6. Variables d'environnement
echo -e "\n6️⃣ Variables d'environnement:"
ssh "$PI_HOST" "docker exec $CONTAINER env | grep -E '(VITE_|REACT_APP_|NEXT_PUBLIC_)' | wc -l"

echo -e "\n✅ Vérification terminée!"
```

---

## 📚 Ressources Complémentaires

### Documentation Interne

- [CHANGELOG-AND-FIXES.md](../../certidoclov/certidoc-proof/deployment-pi/CHANGELOG-AND-FIXES.md) - Historique des problèmes résolus
- [common-scripts/lib.sh](../../common-scripts/lib.sh) - Fonctions réutilisables
- [nginx.conf](../templates/react-spa/nginx.conf) - Template Nginx optimisé

### Outils de Debug

```bash
# Logs en temps réel
docker logs -f <container>

# Inspecter le conteneur
docker inspect <container>

# Entrer dans le conteneur
docker exec -it <container> sh

# Vérifier les fichiers buildés
docker exec <container> ls -lah /usr/share/nginx/html/assets/

# Tester Nginx config
docker exec <container> nginx -t
```

---

**Version**: 1.0.0
**Dernière mise à jour**: 2025-01-12
**Basé sur**: certidoc-proof/deployment-pi/CHANGELOG-AND-FIXES.md
