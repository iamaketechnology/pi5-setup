# 🔀 Approche Hybride : Combiner Tunnel Générique + Tunnels Dédiés

> **Utilisez le meilleur des deux mondes : tunnel générique pour apps non-critiques + tunnels dédiés pour apps sensibles**

---

## 📊 Concept

Vous pouvez **combiner** les deux approches sur le même serveur :

```
┌─────────────────────────────────────────────────────────────┐
│                     RASPBERRY PI 5                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  📦 Tunnel Générique (cloudflared-tunnel)                  │
│     ├──→ blog.domain.com → blog-app:80                     │
│     ├──→ portfolio.domain.com → portfolio:3000             │
│     └──→ demo.domain.com → demo-app:8080                   │
│                                                             │
│  🔒 Tunnel CertiDoc Dédié (certidoc-tunnel)                │
│     └──→ certidoc.domain.com → certidoc-frontend:80        │
│                                                             │
│  🔒 Tunnel Supabase Dédié (supabase-tunnel)                │
│     ├──→ api.domain.com → supabase-kong:8000              │
│     └──→ studio.domain.com → supabase-studio:3000         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Quand Utiliser l'Approche Hybride ?

### ✅ Utilisez un **Tunnel Générique** pour :

- **Apps non-critiques** (blog, portfolio, sites vitrine)
- **Apps en développement** (tests, démos)
- **Apps avec peu de trafic**
- **Apps sans données sensibles**

**Avantages** :
- Économie RAM (1 tunnel = 50 MB pour N apps)
- Gestion centralisée facile
- Ajout/suppression rapide

---

### 🔒 Utilisez des **Tunnels Dédiés** pour :

- **Apps en production critique** (CertiDoc, plateforme e-commerce)
- **Apps avec données sensibles** (Supabase, bases de données)
- **Apps nécessitant isolation totale**
- **Apps avec fort trafic** (éviter contention)

**Avantages** :
- Isolation totale (un tunnel plante ≠ autres apps impactées)
- Monitoring granulaire par app
- Credentials séparées (sécurité renforcée)
- Configuration indépendante

---

## 🛠️ Installation Hybride

### Étape 1 : Installer le Tunnel Générique

```bash
# Installation tunnel générique
sudo bash /path/to/01-setup-generic-tunnel.sh

# Ajouter apps non-critiques
sudo bash 02-add-app-to-tunnel.sh \
  --name blog \
  --hostname blog.domain.com \
  --service blog-app:80

sudo bash 02-add-app-to-tunnel.sh \
  --name portfolio \
  --hostname portfolio.domain.com \
  --service portfolio-app:3000
```

---

### Étape 2 : Installer Tunnels Dédiés pour Apps Critiques

#### Tunnel CertiDoc Dédié

```bash
# 1. Créer dossier dédié
mkdir -p /home/pi/tunnels/certidoc
cd /home/pi/tunnels/certidoc

# 2. Authentifier Cloudflare (si pas déjà fait)
cloudflared tunnel login

# 3. Créer tunnel dédié
cloudflared tunnel create certidoc-tunnel

# 4. Configurer tunnel
cat > config.yml << 'EOF'
tunnel: <TUNNEL_ID>
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: certidoc.domain.com
    service: http://certidoc-frontend:80
    originRequest:
      noTLSVerify: false

  - service: http_status:404
EOF

# 5. Copier credentials
sudo cp /root/.cloudflared/<TUNNEL_ID>.json ./credentials.json
chmod 600 credentials.json

# 6. Créer docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  certidoc-tunnel:
    image: cloudflare/cloudflared:latest
    container_name: certidoc-tunnel
    restart: unless-stopped
    command: tunnel --config /etc/cloudflared/config.yml run
    volumes:
      - ./config.yml:/etc/cloudflared/config.yml:ro
      - ./credentials.json:/etc/cloudflared/credentials.json:ro
    networks:
      - traefik_network
    healthcheck:
      test: ["CMD-SHELL", "pgrep cloudflared || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  traefik_network:
    external: true
    name: traefik_network
EOF

# 7. Démarrer tunnel CertiDoc
docker compose up -d
```

---

#### Tunnel Supabase Dédié

```bash
# 1. Créer dossier dédié
mkdir -p /home/pi/tunnels/supabase
cd /home/pi/tunnels/supabase

# 2. Créer tunnel
cloudflared tunnel create supabase-tunnel

# 3. Configurer tunnel
cat > config.yml << 'EOF'
tunnel: <TUNNEL_ID>
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: api.domain.com
    service: http://supabase-kong:8000
    originRequest:
      noTLSVerify: false

  - hostname: studio.domain.com
    service: http://supabase-studio:3000
    originRequest:
      noTLSVerify: false

  - service: http_status:404
EOF

# 4. Copier credentials
sudo cp /root/.cloudflared/<TUNNEL_ID>.json ./credentials.json
chmod 600 credentials.json

# 5. Créer docker-compose.yml (similaire à CertiDoc)
# ... (remplacer nom container : supabase-tunnel)

# 6. Démarrer tunnel Supabase
docker compose up -d
```

---

## 📊 Comparaison Ressources

| Configuration | Containers | RAM Totale | Gestion |
|---------------|------------|------------|---------|
| **100% Générique** (10 apps) | 1 | 50 MB | ⭐⭐⭐ Très facile |
| **100% Dédiés** (10 apps) | 10 | 500 MB | ⭐ Complexe |
| **Hybride** (7 générique + 3 dédiés) | 4 | 200 MB | ⭐⭐ Moyen |

**Recommandation** : L'approche hybride est le **meilleur compromis** ! 🎯

---

## 🗂️ Structure Fichiers Hybride

```
/home/pi/
├── stacks/
│   └── cloudflare-tunnel-generic/        # Tunnel générique
│       ├── docker-compose.yml
│       ├── config/
│       │   ├── apps.json
│       │   ├── config.yml
│       │   └── credentials.json
│       └── scripts/
│
└── tunnels/                              # Tunnels dédiés
    ├── certidoc/
    │   ├── docker-compose.yml
    │   ├── config.yml
    │   └── credentials.json
    │
    └── supabase/
        ├── docker-compose.yml
        ├── config.yml
        └── credentials.json
```

---

## 🐳 Gestion Multi-Tunnels

### Lister tous les tunnels

```bash
# Via Cloudflare CLI
cloudflared tunnel list

# Via Docker
docker ps --filter "name=tunnel" --format "table {{.Names}}\t{{.Status}}"
```

**Sortie exemple** :
```
NAMES                   STATUS
cloudflared-tunnel      Up 2 hours (healthy)
certidoc-tunnel         Up 1 hour (healthy)
supabase-tunnel         Up 30 minutes (healthy)
```

---

### Démarrer tous les tunnels

```bash
# Tunnel générique
cd /home/pi/stacks/cloudflare-tunnel-generic
docker compose up -d

# Tunnel CertiDoc
cd /home/pi/tunnels/certidoc
docker compose up -d

# Tunnel Supabase
cd /home/pi/tunnels/supabase
docker compose up -d
```

---

### Arrêter un tunnel spécifique

```bash
# Arrêter seulement CertiDoc (autres tunnels continuent)
cd /home/pi/tunnels/certidoc
docker compose down
```

---

### Voir logs d'un tunnel spécifique

```bash
# Logs CertiDoc uniquement
docker logs -f certidoc-tunnel

# Logs Supabase uniquement
docker logs -f supabase-tunnel

# Logs tunnel générique
docker logs -f cloudflared-tunnel
```

---

## 🌐 Configuration DNS Hybride

Tous les subdomains pointent vers **la même IP publique** :

```
Type  Name         Content            Proxy
A     blog         203.0.113.42       DNS only (gris)
A     portfolio    203.0.113.42       DNS only (gris)
A     certidoc     203.0.113.42       DNS only (gris)
A     api          203.0.113.42       DNS only (gris)
A     studio       203.0.113.42       DNS only (gris)
```

**Cloudflare route automatiquement** chaque hostname vers le bon tunnel ! 🎯

---

## 🔧 Monitoring Hybride

### Script de monitoring global

```bash
#!/bin/bash
# monitor-all-tunnels.sh

echo "═══ Status Tunnels Cloudflare ═══"
echo ""

tunnels=("cloudflared-tunnel" "certidoc-tunnel" "supabase-tunnel")

for tunnel in "${tunnels[@]}"; do
    if docker ps --filter "name=$tunnel" --format "{{.Names}}" | grep -q "$tunnel"; then
        status=$(docker inspect --format='{{.State.Health.Status}}' "$tunnel" 2>/dev/null || echo "unknown")
        echo "✅ $tunnel : UP ($status)"
    else
        echo "❌ $tunnel : DOWN"
    fi
done

echo ""
echo "RAM utilisée par les tunnels :"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" $(docker ps --filter "name=tunnel" -q)
```

**Utilisation** :
```bash
bash monitor-all-tunnels.sh
```

---

## 🚨 Troubleshooting Hybride

### Conflit de noms de containers

**Problème** : `Error: container name already in use`

**Solution** : Utilisez des noms uniques pour chaque tunnel

```yaml
# ❌ Mauvais (conflit)
container_name: cloudflared-tunnel

# ✅ Bon (unique)
container_name: certidoc-tunnel
container_name: supabase-tunnel
```

---

### Conflit de credentials

**Problème** : Plusieurs tunnels utilisent le même `credentials.json`

**Solution** : Chaque tunnel doit avoir **son propre fichier credentials**

```bash
# Tunnel 1
/home/pi/stacks/cloudflare-tunnel-generic/config/credentials.json

# Tunnel 2
/home/pi/tunnels/certidoc/credentials.json

# Tunnel 3
/home/pi/tunnels/supabase/credentials.json
```

---

### Un tunnel impacte les autres

**Problème** : Redémarrage d'un tunnel fait planter les autres

**Cause** : Les tunnels partagent probablement le même réseau Docker

**Solution** : Vérifiez l'isolation réseau

```bash
docker inspect certidoc-tunnel | grep -A 10 Networks
```

Chaque tunnel devrait avoir **ses propres réseaux** (ou partager seulement les réseaux nécessaires).

---

## 💡 Best Practices Hybride

### 1. Organisation Claire

```
📁 Tunnel Générique → Apps non-critiques (blog, portfolio, démos)
📁 Tunnels Dédiés → Apps critiques (CertiDoc, Supabase, production)
```

### 2. Naming Convention

```yaml
# Tunnel générique
container_name: cloudflared-tunnel

# Tunnels dédiés
container_name: {app-name}-tunnel
# Ex: certidoc-tunnel, supabase-tunnel, app-prod-tunnel
```

### 3. Monitoring Séparé

- **Tunnel générique** : Monitoring groupé (toutes apps ensemble)
- **Tunnels dédiés** : Monitoring individuel (alertes par app)

### 4. Backups

```bash
# Sauvegarder configs tunnel générique
/home/pi/stacks/cloudflare-tunnel-generic/config/

# Sauvegarder configs tunnels dédiés
/home/pi/tunnels/*/
```

### 5. Documentation

Créez un fichier `TUNNELS-MAP.md` :

```markdown
# Carte des Tunnels

## Tunnel Générique (cloudflared-tunnel)
- blog.domain.com → blog-app:80
- portfolio.domain.com → portfolio-app:3000
- demo.domain.com → demo-app:8080

## Tunnel CertiDoc (certidoc-tunnel)
- certidoc.domain.com → certidoc-frontend:80

## Tunnel Supabase (supabase-tunnel)
- api.domain.com → supabase-kong:8000
- studio.domain.com → supabase-studio:3000
```

---

## 🎯 Exemple Réel : Startup avec 10 Apps

```
📦 Tunnel Générique (apps internes/tests)
   ├──→ docs.startup.com → documentation:3000
   ├──→ blog.startup.com → ghost-blog:2368
   ├──→ demo.startup.com → demo-app:8080
   ├──→ staging.startup.com → staging-app:3001
   └──→ tools.startup.com → internal-tools:5000

🔒 Tunnel App Principale (certidoc-tunnel)
   └──→ app.startup.com → certidoc-frontend:80

🔒 Tunnel API Backend (api-tunnel)
   ├──→ api.startup.com → supabase-kong:8000
   └──→ graphql.startup.com → hasura:8080

🔒 Tunnel Admin (admin-tunnel)
   ├──→ admin.startup.com → admin-panel:3002
   └──→ monitoring.startup.com → grafana:3000
```

**Ressources** :
- RAM Tunnels : 50 + 50 + 50 + 50 = **200 MB**
- vs Tout Dédi é : 10 × 50 = **500 MB**
- **Économie : 300 MB RAM** (60%) 💰

---

## ✅ Conclusion

L'approche **hybride** est **LA solution optimale** pour :

- ✅ **Économiser ressources** (RAM)
- ✅ **Isoler apps critiques** (sécurité)
- ✅ **Simplifier gestion** (tunnel générique pour le reste)
- ✅ **Flexibilité maximale** (ajuster selon besoins)

**Vous avez le meilleur des deux mondes !** 🎉

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-01-13
**Auteur** : PI5-SETUP Project
