# 🔒 Installation Tunnel Cloudflare Dédié pour CertiDoc

> **Guide complet pour installer un tunnel Cloudflare isolé pour CertiDoc**

---

## 🎯 Pourquoi un Tunnel Dédié pour CertiDoc ?

- ✅ **Isolation totale** : Si le tunnel générique redémarre, CertiDoc reste up
- ✅ **Sécurité renforcée** : Credentials séparées
- ✅ **Monitoring granulaire** : Logs et métriques dédiés
- ✅ **Configuration indépendante** : Modifier config CertiDoc sans impacter autres apps
- ✅ **Production-ready** : Idéal pour app critique en production

---

## 📋 Prérequis

- ✅ Raspberry Pi 5 avec Docker installé
- ✅ CertiDoc déployé et fonctionnel en local (`http://192.168.1.74:9000`)
- ✅ Compte Cloudflare (gratuit)
- ✅ Domaine configuré dans Cloudflare (ex: `certidoc.fr` ou sous-domaine)

---

## 🚀 Installation Étape par Étape

### Étape 1 : Créer la structure de dossiers

```bash
# Connexion SSH au Pi
ssh pi@192.168.1.74

# Créer dossier pour tunnel CertiDoc
sudo mkdir -p /home/pi/tunnels/certidoc
cd /home/pi/tunnels/certidoc
```

---

### Étape 2 : Installer cloudflared (si pas déjà fait)

```bash
# Vérifier si déjà installé
if command -v cloudflared &> /dev/null; then
    echo "✅ cloudflared déjà installé ($(cloudflared --version))"
else
    echo "📦 Installation de cloudflared..."

    # Télécharger pour ARM64
    sudo curl -fsSL \
      https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 \
      -o /usr/local/bin/cloudflared

    # Rendre exécutable
    sudo chmod +x /usr/local/bin/cloudflared

    # Vérifier installation
    cloudflared --version

    echo "✅ cloudflared installé"
fi
```

---

### Étape 3 : Authentification Cloudflare

```bash
# Lancer l'authentification OAuth
sudo cloudflared tunnel login
```

**Ce qui va se passer** :
1. Une URL s'affichera dans le terminal
2. Ouvrez cette URL dans votre navigateur
3. Connectez-vous à Cloudflare
4. Sélectionnez votre domaine
5. Autorisez l'accès

**Confirmation** :
```
You have successfully logged in.
If you wish to copy your credentials to a server, they have been saved to:
/root/.cloudflared/cert.pem
```

---

### Étape 4 : Créer le tunnel CertiDoc

```bash
# Créer tunnel dédié
sudo cloudflared tunnel create certidoc-tunnel
```

**Sortie attendue** :
```
Tunnel credentials written to /root/.cloudflared/<TUNNEL_ID>.json.
cloudflared chose this file based on where your origin certificate was found.
Keep this file secret. To revoke these credentials, delete the tunnel.

Created tunnel certidoc-tunnel with id <TUNNEL_ID>
```

**Note importante** : Copiez le `<TUNNEL_ID>` affiché, vous en aurez besoin !

---

### Étape 5 : Lister le tunnel (vérification)

```bash
# Vérifier que le tunnel a été créé
sudo cloudflared tunnel list
```

**Sortie attendue** :
```
ID                                   NAME              CREATED              CONNECTIONS
<TUNNEL_ID>                          certidoc-tunnel   2025-01-13T...       0
```

---

### Étape 6 : Configurer le DNS Cloudflare

```bash
# Créer route DNS automatique
sudo cloudflared tunnel route dns certidoc-tunnel certidoc.votredomaine.com
```

**Remplacez** :
- `certidoc.votredomaine.com` par votre vrai domaine (ex: `certidoc.fr` ou `app.certidoc.fr`)

**Sortie attendue** :
```
Created CNAME certidoc.votredomaine.com which will route to this tunnel
```

**Alternative manuelle** (si commande échoue) :
1. Allez sur https://dash.cloudflare.com
2. Sélectionnez votre domaine
3. DNS → Records → Add Record
4. Type: `CNAME`
5. Name: `certidoc` (ou `@` si domaine racine)
6. Target: `<TUNNEL_ID>.cfargotunnel.com`
7. Proxy status: **Proxied** (nuage orange)

---

### Étape 7 : Copier les credentials

```bash
# Extraire le TUNNEL_ID (si vous l'avez perdu)
TUNNEL_ID=$(sudo cloudflared tunnel list | grep certidoc-tunnel | awk '{print $1}')

echo "Tunnel ID: $TUNNEL_ID"

# Copier les credentials
sudo cp /root/.cloudflared/${TUNNEL_ID}.json /home/pi/tunnels/certidoc/credentials.json

# Permissions sécurisées
sudo chmod 600 /home/pi/tunnels/certidoc/credentials.json
sudo chown pi:pi /home/pi/tunnels/certidoc/credentials.json

# Vérifier
ls -l credentials.json
```

**Sortie attendue** :
```
-rw------- 1 pi pi 1234 Jan 13 10:30 credentials.json
```

---

### Étape 8 : Créer la configuration du tunnel

```bash
# Obtenir le TUNNEL_ID
TUNNEL_ID=$(sudo cloudflared tunnel list | grep certidoc-tunnel | awk '{print $1}')

# Créer config.yml
cat > /home/pi/tunnels/certidoc/config.yml << EOF
# Cloudflare Tunnel - Configuration CertiDoc
# Créé le: $(date)
# Tunnel ID: ${TUNNEL_ID}

tunnel: ${TUNNEL_ID}
credentials-file: /etc/cloudflared/credentials.json

ingress:
  # CertiDoc Frontend
  - hostname: certidoc.votredomaine.com
    service: http://certidoc-frontend:80
    originRequest:
      noTLSVerify: false
      connectTimeout: 30s
      tlsTimeout: 10s

  # Catch-all rule (obligatoire)
  - service: http_status:404
EOF

# Permissions
chmod 600 /home/pi/tunnels/certidoc/config.yml
```

**⚠️ IMPORTANT** : Remplacez `certidoc.votredomaine.com` par votre vrai domaine !

---

### Étape 9 : Vérifier le nom du container CertiDoc

```bash
# Lister containers CertiDoc
docker ps | grep certidoc
```

**Sortie attendue** :
```
<CONTAINER_ID>  certidoc-frontend  ...  Up X minutes  0.0.0.0:9000->80/tcp
```

**Si le nom est différent** (ex: `certidoc_frontend_1`), mettez à jour `config.yml` :
```yaml
service: http://certidoc_frontend_1:80
```

---

### Étape 10 : Vérifier le réseau Docker

```bash
# Vérifier sur quel réseau est CertiDoc
docker inspect certidoc-frontend | grep -A 10 '"Networks"'
```

**Sortie attendue** :
```json
"Networks": {
    "certidoc_default": { ... }
}
```

**Note** : Le tunnel doit être sur le **même réseau Docker** que CertiDoc.

---

### Étape 11 : Créer docker-compose.yml

```bash
cat > /home/pi/tunnels/certidoc/docker-compose.yml << 'EOF'
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
      - certidoc_default
    healthcheck:
      test: ["CMD-SHELL", "pgrep cloudflared || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  certidoc_default:
    external: true
    name: certidoc_default
EOF
```

**⚠️ IMPORTANT** : Remplacez `certidoc_default` par le vrai nom du réseau Docker de CertiDoc (trouvé à l'étape 10).

---

### Étape 12 : Démarrer le tunnel CertiDoc

```bash
# Se placer dans le dossier
cd /home/pi/tunnels/certidoc

# Démarrer le tunnel
docker compose up -d

# Vérifier le status
docker ps | grep certidoc-tunnel
```

**Sortie attendue** :
```
<ID>  cloudflare/cloudflared  ...  Up X seconds (health: starting)  certidoc-tunnel
```

---

### Étape 13 : Vérifier les logs

```bash
# Voir les logs en temps réel
docker logs -f certidoc-tunnel
```

**Logs normaux** (succès) :
```
2025-01-13T10:30:00Z INF Starting tunnel tunnelID=<TUNNEL_ID>
2025-01-13T10:30:01Z INF Connection registered connIndex=0
2025-01-13T10:30:01Z INF Connection registered connIndex=1
2025-01-13T10:30:01Z INF Connection registered connIndex=2
2025-01-13T10:30:01Z INF Connection registered connIndex=3
```

**Logs d'erreur** (à corriger) :
```
ERR Failed to connect error="dial tcp: lookup certidoc-frontend: no such host"
→ Solution : Vérifier nom container et réseau Docker
```

**Appuyez sur Ctrl+C** pour sortir des logs.

---

### Étape 14 : Tester l'accès local CertiDoc

```bash
# Tester que CertiDoc répond en local
curl -I http://localhost:9000
```

**Sortie attendue** :
```
HTTP/1.1 200 OK
...
```

Si erreur, CertiDoc ne tourne pas correctement. Vérifiez :
```bash
docker ps | grep certidoc
docker logs certidoc-frontend
```

---

### Étape 15 : Attendre propagation DNS (5-10 minutes)

```bash
# Tester résolution DNS
dig certidoc.votredomaine.com

# Doit afficher un CNAME vers *.cfargotunnel.com
```

**Sortie attendue** :
```
;; ANSWER SECTION:
certidoc.votredomaine.com.  300  IN  CNAME  <TUNNEL_ID>.cfargotunnel.com.
```

---

### Étape 16 : Tester l'accès HTTPS depuis Internet

```bash
# Tester depuis le Pi
curl -I https://certidoc.votredomaine.com

# Tester depuis votre Mac
curl -I https://certidoc.votredomaine.com
```

**Sortie attendue** :
```
HTTP/2 200
date: Mon, 13 Jan 2025 10:30:00 GMT
content-type: text/html
...
cf-ray: 123456789abc-CDG
```

**Si vous voyez `cf-ray`** → ✅ **Ça marche !** Le trafic passe par Cloudflare ! 🎉

---

## ✅ Vérification Finale

Checklist complète :

```bash
# 1. Tunnel créé
sudo cloudflared tunnel list | grep certidoc-tunnel

# 2. Container actif
docker ps | grep certidoc-tunnel

# 3. Container healthy
docker inspect certidoc-tunnel --format='{{.State.Health.Status}}'
# Doit afficher: healthy

# 4. DNS résolu
dig certidoc.votredomaine.com

# 5. HTTPS fonctionne
curl -I https://certidoc.votredomaine.com

# 6. Logs propres
docker logs certidoc-tunnel --tail 20
```

---

## 🐳 Gestion du Tunnel CertiDoc

### Arrêter le tunnel

```bash
cd /home/pi/tunnels/certidoc
docker compose down
```

### Démarrer le tunnel

```bash
cd /home/pi/tunnels/certidoc
docker compose up -d
```

### Redémarrer le tunnel

```bash
docker compose restart certidoc-tunnel
```

### Voir les logs

```bash
# Temps réel
docker logs -f certidoc-tunnel

# Dernières 50 lignes
docker logs certidoc-tunnel --tail 50
```

### Status du tunnel

```bash
# Via Docker
docker ps --filter "name=certidoc-tunnel"

# Via Cloudflare CLI
sudo cloudflared tunnel info certidoc-tunnel
```

---

## 🔧 Configuration DNS Finale

Dans Cloudflare Dashboard, vous devriez voir :

```
Type   Name      Target                          Proxy Status
CNAME  certidoc  <TUNNEL_ID>.cfargotunnel.com    Proxied (orange)
```

**Proxy Status** :
- ✅ **Proxied (orange)** : Recommandé (protection DDoS, cache CDN)
- ⚠️ **DNS only (gris)** : Fonctionne aussi, mais pas de protection Cloudflare

---

## 🛡️ Sécurité

### Permissions des fichiers sensibles

```bash
# Vérifier permissions
ls -l /home/pi/tunnels/certidoc/

# Doit afficher :
# -rw------- (600) pour credentials.json
# -rw------- (600) pour config.yml
```

### Backup des credentials

```bash
# Créer backup
sudo cp /home/pi/tunnels/certidoc/credentials.json \
       /home/pi/backups/certidoc-tunnel-credentials-$(date +%Y%m%d).json

# Permissions sécurisées
sudo chmod 600 /home/pi/backups/certidoc-tunnel-credentials-*.json
```

---

## 📊 Monitoring

### Script de monitoring CertiDoc

```bash
cat > /home/pi/tunnels/certidoc/monitor.sh << 'EOF'
#!/bin/bash

echo "═══ CertiDoc Tunnel Status ═══"
echo ""

# Container status
if docker ps --filter "name=certidoc-tunnel" --format "{{.Names}}" | grep -q "certidoc-tunnel"; then
    health=$(docker inspect certidoc-tunnel --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    echo "✅ Container: UP ($health)"
else
    echo "❌ Container: DOWN"
fi

# RAM usage
echo ""
echo "RAM Usage:"
docker stats --no-stream --format "  {{.Name}}: {{.MemUsage}}" certidoc-tunnel

# Dernière erreur
echo ""
echo "Dernières erreurs (si présentes):"
docker logs certidoc-tunnel --tail 100 | grep -i "ERR\|error\|fail" | tail -5 || echo "  Aucune erreur récente"

# Test connectivité
echo ""
echo "Test HTTPS:"
if curl -sf -o /dev/null https://certidoc.votredomaine.com; then
    echo "  ✅ HTTPS accessible"
else
    echo "  ❌ HTTPS non accessible"
fi
EOF

chmod +x /home/pi/tunnels/certidoc/monitor.sh

# Utilisation
bash /home/pi/tunnels/certidoc/monitor.sh
```

---

## 🐛 Troubleshooting

### Erreur : "no such host: certidoc-frontend"

**Cause** : Le tunnel ne trouve pas le container CertiDoc.

**Solutions** :
```bash
# 1. Vérifier nom exact du container
docker ps | grep certidoc

# 2. Mettre à jour config.yml avec le bon nom
# 3. Vérifier que les containers sont sur le même réseau Docker
docker network inspect certidoc_default
```

---

### Erreur 502 Bad Gateway

**Cause** : Le tunnel se connecte mais CertiDoc ne répond pas.

**Solutions** :
```bash
# 1. Vérifier que CertiDoc tourne
docker ps | grep certidoc-frontend

# 2. Tester en local
curl -I http://localhost:9000

# 3. Vérifier logs CertiDoc
docker logs certidoc-frontend --tail 50

# 4. Redémarrer CertiDoc
cd /home/pi/certidoc
docker compose restart
```

---

### DNS ne résout pas

**Solutions** :
```bash
# 1. Attendre 5-10 minutes (propagation)

# 2. Vérifier DNS
dig certidoc.votredomaine.com

# 3. Vérifier dans Cloudflare Dashboard
# DNS → Records → Chercher "certidoc"

# 4. Re-créer route DNS
sudo cloudflared tunnel route dns certidoc-tunnel certidoc.votredomaine.com
```

---

### Tunnel démarre puis s'arrête

**Solutions** :
```bash
# 1. Voir logs détaillés
docker logs certidoc-tunnel --tail 100

# 2. Vérifier credentials
ls -l /home/pi/tunnels/certidoc/credentials.json

# 3. Tester credentials
sudo cloudflared tunnel info certidoc-tunnel

# 4. Recréer credentials si nécessaire
TUNNEL_ID=$(sudo cloudflared tunnel list | grep certidoc-tunnel | awk '{print $1}')
sudo cp /root/.cloudflared/${TUNNEL_ID}.json /home/pi/tunnels/certidoc/credentials.json
```

---

## 🎉 Résultat Final

Après installation complète, vous avez :

✅ **Tunnel CertiDoc dédié** isolé des autres apps
✅ **HTTPS automatique** via Cloudflare
✅ **Protection DDoS** gratuite
✅ **Cache CDN** pour performances
✅ **Container monitored** avec healthchecks
✅ **Logs dédiés** pour debugging
✅ **Configuration indépendante** des autres apps

**URL d'accès** : `https://certidoc.votredomaine.com` 🚀

---

## 📚 Prochaines Étapes

1. **Installer le tunnel générique** pour vos autres apps :
   ```bash
   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/external-access/cloudflare-tunnel-generic/scripts/01-setup-generic-tunnel.sh | sudo bash
   ```

2. **Ajouter apps au tunnel générique** :
   ```bash
   sudo bash 02-add-app-to-tunnel.sh --name blog --hostname blog.votredomaine.com --service blog-app:80
   ```

3. **Consulter le guide hybride** : [HYBRID-APPROACH.md](HYBRID-APPROACH.md)

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-01-13
**Testé sur** : Raspberry Pi 5 (16GB), CertiDoc v1.0
