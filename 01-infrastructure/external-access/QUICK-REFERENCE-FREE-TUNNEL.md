# ⚡ Guide de Référence Rapide - Cloudflare Tunnel Gratuit

> **Commandes essentielles pour gérer votre tunnel Cloudflare gratuit**

---

## 🌐 Récupérer l'URL Publique

### Méthode 1 : Script Automatique (RECOMMANDÉ) ⭐

```bash
bash /home/pi/tunnels/certidoc/get-url.sh
```

**Sortie** :
```
🌐 URL publique du tunnel :
https://votre-url.trycloudflare.com
```

---

### Méthode 2 : Via les Logs

```bash
docker logs certidoc-tunnel 2>&1 | grep trycloudflare.com
```

**Sortie** :
```
|  Your quick Tunnel has been created! Visit it at:                    |
|  https://votre-url.trycloudflare.com                                |
```

---

### Méthode 3 : Fichier Sauvegardé

```bash
cat /home/pi/tunnels/certidoc/current-url.txt
```

⚠️ **Note** : Contient la dernière URL sauvegardée (peut être obsolète après redémarrage)

---

### Méthode 4 : Script Status Complet

```bash
bash /home/pi/tunnels/certidoc/status.sh
```

**Sortie** :
```
═══ Status Tunnel certidoc ═══

✅ Container: UP (healthy)

🌐 URL publique:
https://votre-url.trycloudflare.com

💾 RAM:
  50.5MiB / 15.33GiB
```

---

## 🔄 Gestion du Tunnel

### Voir le Status

```bash
bash /home/pi/tunnels/certidoc/status.sh
```

---

### Voir les Logs en Temps Réel

```bash
docker logs -f certidoc-tunnel
```

**Appuyez sur `Ctrl+C` pour quitter**

---

### Voir les Dernières 50 Lignes de Logs

```bash
docker logs certidoc-tunnel --tail 50
```

---

### Redémarrer le Tunnel (Génère Nouvelle URL)

```bash
cd /home/pi/tunnels/certidoc
docker compose restart
```

**Puis récupérer la nouvelle URL** :
```bash
# Attendre 10-15 secondes
sleep 15

# Obtenir nouvelle URL
bash get-url.sh
```

---

### Arrêter le Tunnel

```bash
cd /home/pi/tunnels/certidoc
docker compose down
```

---

### Démarrer le Tunnel

```bash
cd /home/pi/tunnels/certidoc
docker compose up -d
```

**Puis récupérer l'URL** :
```bash
sleep 15
bash get-url.sh
```

---

### Redémarrer le Tunnel Sans Downtime

```bash
cd /home/pi/tunnels/certidoc
docker compose up -d --force-recreate
```

---

## 🧪 Tests et Vérification

### Tester l'URL depuis le Pi

```bash
# Obtenir l'URL
URL=$(bash /home/pi/tunnels/certidoc/get-url.sh | grep https)

# Tester
curl -I "$URL"
```

**Sortie attendue** :
```
HTTP/2 200
date: Mon, 13 Jan 2025 16:30:00 GMT
content-type: text/html
...
cf-ray: 123456789abc-CDG
```

**Si vous voyez `cf-ray`** → ✅ Ça marche !

---

### Tester CertiDoc en Local

```bash
curl -I http://localhost:9000
```

**Ou** :
```bash
curl -I http://certidoc-frontend:80
```

---

### Vérifier que CertiDoc Tourne

```bash
docker ps | grep certidoc-frontend
```

**Sortie attendue** :
```
<ID>  certidoc-frontend  ...  Up X minutes  0.0.0.0:9000->80/tcp
```

---

### Vérifier que le Tunnel Tourne

```bash
docker ps | grep certidoc-tunnel
```

**Sortie attendue** :
```
<ID>  cloudflare/cloudflared  ...  Up X minutes (healthy)  certidoc-tunnel
```

---

## 🐛 Troubleshooting

### Le Tunnel ne Démarre Pas

```bash
# Voir les logs d'erreur
docker logs certidoc-tunnel --tail 50

# Vérifier le réseau Docker
docker network inspect supabase_network

# Vérifier que CertiDoc tourne
docker ps | grep certidoc-frontend

# Redémarrer le tunnel
cd /home/pi/tunnels/certidoc
docker compose down
docker compose up -d
```

---

### L'URL ne Fonctionne Pas

```bash
# 1. Vérifier que le tunnel tourne
docker ps | grep certidoc-tunnel

# 2. Voir les logs
docker logs certidoc-tunnel --tail 50

# 3. Vérifier que CertiDoc répond en local
curl -I http://localhost:9000

# 4. Redémarrer CertiDoc
cd /home/pi/certidoc  # ou le dossier de votre docker-compose CertiDoc
docker compose restart

# 5. Redémarrer le tunnel
cd /home/pi/tunnels/certidoc
docker compose restart
```

---

### Erreur "no such host: certidoc-frontend"

**Problème** : Le tunnel ne trouve pas le container CertiDoc

**Solution** :
```bash
# 1. Vérifier le nom exact du container
docker ps | grep certidoc

# 2. Vérifier le réseau Docker
docker inspect certidoc-frontend | grep -A 5 '"Networks"'

# 3. Si le réseau est différent, éditer docker-compose.yml
cd /home/pi/tunnels/certidoc
nano docker-compose.yml

# Changer la ligne "name:" sous "networks:" avec le bon réseau
```

---

### Erreur 502 Bad Gateway

**Problème** : Le tunnel fonctionne mais CertiDoc ne répond pas

**Solution** :
```bash
# 1. Vérifier que CertiDoc tourne
docker ps | grep certidoc-frontend

# 2. Tester CertiDoc en local
curl -I http://localhost:9000

# 3. Voir logs CertiDoc
docker logs certidoc-frontend --tail 50

# 4. Redémarrer CertiDoc
cd /home/pi/certidoc
docker compose restart
```

---

## 💾 Informations Système

### RAM Utilisée par le Tunnel

```bash
docker stats certidoc-tunnel --no-stream --format "{{.MemUsage}}"
```

**Sortie** : `50.5MiB / 15.33GiB`

---

### RAM Totale des Tunnels

```bash
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" \
  $(docker ps --filter "name=tunnel" -q)
```

---

### Espace Disque Docker

```bash
docker system df
```

---

### Logs Totaux Taille

```bash
du -sh /var/lib/docker/containers/*/
```

---

## 📁 Fichiers et Dossiers

### Structure du Tunnel CertiDoc

```
/home/pi/tunnels/certidoc/
├── docker-compose.yml         # Configuration Docker
├── current-url.txt            # URL actuelle sauvegardée
├── get-url.sh                 # Script pour obtenir URL
└── status.sh                  # Script de status
```

---

### Éditer la Configuration

```bash
cd /home/pi/tunnels/certidoc
nano docker-compose.yml
```

**Après modification** :
```bash
docker compose down
docker compose up -d
```

---

## 🔧 Configuration Avancée

### Changer le Port CertiDoc

Si CertiDoc tourne sur un autre port (ex: 8080 au lieu de 80) :

```bash
cd /home/pi/tunnels/certidoc
nano docker-compose.yml

# Modifier la ligne :
command: tunnel --url http://certidoc-frontend:80
# En :
command: tunnel --url http://certidoc-frontend:8080

# Redémarrer
docker compose down
docker compose up -d
```

---

### Ajouter Plusieurs Apps au Même Tunnel

⚠️ **Pas possible avec Quick Tunnel gratuit**

Le Quick Tunnel ne supporte qu'**une seule app par tunnel**.

**Solutions** :
1. Créer un tunnel par app
2. Migrer vers tunnel avec domaine (supporte multi-apps)

---

### Activer les Métriques Prometheus

Le tunnel expose déjà des métriques sur le port 9090.

```bash
# Voir les métriques
curl http://localhost:9090/metrics
```

**Pour intégrer avec Prometheus** :
```yaml
# Ajouter dans prometheus.yml
- job_name: 'certidoc-tunnel'
  static_configs:
    - targets: ['certidoc-tunnel:9090']
```

---

## 🚀 Alias Pratiques

Ajoutez ces alias dans votre `~/.bashrc` :

```bash
# Éditer .bashrc
nano ~/.bashrc

# Ajouter à la fin :
alias certidoc-url='bash /home/pi/tunnels/certidoc/get-url.sh'
alias certidoc-status='bash /home/pi/tunnels/certidoc/status.sh'
alias certidoc-logs='docker logs -f certidoc-tunnel'
alias certidoc-restart='cd /home/pi/tunnels/certidoc && docker compose restart'

# Sauvegarder et recharger
source ~/.bashrc
```

**Utilisation** :
```bash
certidoc-url       # Obtenir URL
certidoc-status    # Voir status
certidoc-logs      # Voir logs
certidoc-restart   # Redémarrer
```

---

## 📊 Workflow Complet de Redémarrage

```bash
# 1. Redémarrer le tunnel (génère nouvelle URL)
cd /home/pi/tunnels/certidoc
docker compose restart

# 2. Attendre que le tunnel se connecte
echo "Attente de la génération de l'URL..."
sleep 15

# 3. Récupérer la nouvelle URL
NEW_URL=$(bash get-url.sh | grep https)

# 4. Afficher l'URL
echo ""
echo "═══════════════════════════════════════"
echo "  Nouvelle URL : $NEW_URL"
echo "═══════════════════════════════════════"
echo ""

# 5. Tester l'URL
curl -I "$NEW_URL"

# 6. Ouvrir dans le navigateur (depuis Mac via SSH)
# Copiez l'URL et ouvrez-la dans votre navigateur
```

---

## 📚 Commandes Essentielles Récapitulatives

| Action | Commande |
|--------|----------|
| **Obtenir URL** | `bash /home/pi/tunnels/certidoc/get-url.sh` |
| **Voir status** | `bash /home/pi/tunnels/certidoc/status.sh` |
| **Voir logs** | `docker logs -f certidoc-tunnel` |
| **Redémarrer** | `cd /home/pi/tunnels/certidoc && docker compose restart` |
| **Arrêter** | `docker compose down` |
| **Démarrer** | `docker compose up -d` |
| **Test local** | `curl -I http://localhost:9000` |
| **Test tunnel** | `curl -I $(bash get-url.sh \| grep https)` |

---

## 🆘 Support

### Logs Complets

```bash
# Log de l'installation
cat /var/log/cloudflare-free-tunnel-*.log

# Logs du tunnel
docker logs certidoc-tunnel --tail 200

# Logs CertiDoc
docker logs certidoc-frontend --tail 200
```

---

### Réinstaller le Tunnel

```bash
# 1. Arrêter et supprimer
cd /home/pi/tunnels/certidoc
docker compose down
cd ~
sudo rm -rf /home/pi/tunnels/certidoc

# 2. Relancer le script d'installation
sudo bash /tmp/setup-free-cloudflare-tunnel.sh
```

---

## 🔗 Liens Utiles

- **Documentation Cloudflare Tunnel** : https://developers.cloudflare.com/cloudflare-one/
- **GitHub PI5-SETUP** : https://github.com/iamaketechnology/pi5-setup
- **Cloudflare Dashboard** : https://dash.cloudflare.com

---

## ⚠️ Rappels Importants

1. ✅ **L'URL change** à chaque redémarrage du tunnel
2. ✅ **Gratuit à 100%**, aucune limite
3. ✅ **HTTPS automatique**, pas de config SSL
4. ✅ **Idéal pour tests/démos**, pas pour production long-terme
5. ✅ **Un seul service** par Quick Tunnel (pour multi-apps, utiliser tunnel avec domaine)

---

## 🎯 Migration vers Domaine Custom (Futur)

Quand vous serez prêt pour la production avec un domaine personnalisé :

### Migration Automatique (RECOMMANDÉ) ⭐

Utilisez le script de migration automatique qui gère tout pour vous :

```bash
sudo bash /path/to/pi5-setup/01-infrastructure/external-access/scripts/migrate-to-custom-domain.sh
```

**Ce script fait automatiquement** :
- ✅ Détecte et sauvegarde votre configuration actuelle
- ✅ Arrête le Quick Tunnel proprement
- ✅ Vous guide pour l'authentification Cloudflare
- ✅ Crée le nouveau tunnel avec votre domaine
- ✅ Configure le DNS automatiquement
- ✅ Met à jour tous les fichiers de config
- ✅ Redémarre le tunnel avec URL permanente
- ✅ Teste la connectivité

**Prérequis** :
1. Acheter un domaine (ex: certidoc.fr) ~10€/an
2. L'ajouter à Cloudflare (gratuit)
3. Avoir accès au Cloudflare Dashboard

**Résultat** :
- URL permanente : `https://certidoc.fr` (ne change plus jamais)
- ✅ Certificat SSL automatique (Let's Encrypt via Cloudflare)
- ✅ Protection DDoS Cloudflare incluse
- ✅ Zero downtime pendant la migration

### Migration Manuelle (Alternative)

Si vous préférez faire manuellement :

```bash
# 1. Authentification
cloudflared tunnel login

# 2. Créer tunnel
cloudflared tunnel create certidoc-prod

# 3. Router DNS
cloudflared tunnel route dns certidoc-prod certidoc.fr

# 4. Configurer et démarrer (voir documentation complète)
```

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-01-13
**Pour** : Cloudflare Quick Tunnel (trycloudflare.com)
**Testé sur** : Raspberry Pi 5, Docker 24.x
