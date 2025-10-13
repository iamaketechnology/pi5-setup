# 🌐 Guide Complet - Cloudflare Tunnel pour CertiDoc

> **Documentation complète de l'infrastructure Cloudflare Tunnel déployée**

**Version** : 1.0.0
**Date** : 2025-01-13
**Status** : ✅ Déployé et opérationnel

---

## 📊 Vue d'Ensemble

### Architecture Actuelle

```
Internet (Public)
    ↓
Cloudflare Edge Network
    ↓
Quick Tunnel (trycloudflare.com)
    ↓
cloudflared container (Pi)
    ↓
Docker Network (supabase_network)
    ↓
CertiDoc Frontend Container
```

**URL Publique Actuelle** :
```
https://playback-wildlife-daughters-jesse.trycloudflare.com
```

⚠️ **Note** : Cette URL change à chaque redémarrage du tunnel (comportement normal des Quick Tunnels gratuits)

---

## 🎯 Objectif Atteint

✅ **CertiDoc est maintenant accessible publiquement via HTTPS**
- Sans configuration de ports/NAT/firewall
- Sans domaine (gratuit à 100%)
- Avec certificat SSL automatique
- Avec protection DDoS Cloudflare

---

## 📁 Structure des Fichiers

### Scripts Créés

```
01-infrastructure/external-access/
├── scripts/
│   ├── 00-cloudflare-tunnel-wizard.sh          ⭐ Wizard intelligent
│   ├── setup-free-cloudflare-tunnel.sh         ✅ Utilisé pour CertiDoc
│   ├── migrate-to-custom-domain.sh             🎯 Pour migration future
│   └── cloudflare-tunnel-generic/
│       └── scripts/
│           ├── 01-setup-generic-tunnel.sh
│           ├── 02-add-app-to-tunnel.sh
│           ├── 03-remove-app-from-tunnel.sh
│           └── 04-list-tunnel-apps.sh
│
├── QUICK-REFERENCE-FREE-TUNNEL.md              📚 Guide de référence rapide
├── CLOUDFLARE-TUNNEL-COMPLETE-GUIDE.md         📘 Ce fichier
├── README.md                                    📖 Doc tunnel générique
├── HYBRID-APPROACH.md                           🔀 Architecture hybride
└── CERTIDOC-TUNNEL-SETUP.md                     🎓 Guide setup avec domaine
```

### Fichiers sur le Pi

```
/home/pi/tunnels/certidoc/
├── docker-compose.yml          # Configuration container tunnel
├── get-url.sh                  # Script pour obtenir URL
├── status.sh                   # Script de status complet
├── current-url.txt             # Cache dernière URL connue
└── QUICK-REFERENCE.md          # Guide de référence (copie)
```

---

## 🚀 Déploiement Réalisé

### Étapes Effectuées

1. **Wizard Intelligent** ✅
   - Script `00-cloudflare-tunnel-wizard.sh` créé
   - Détection environnement existant
   - Questions contextuelles intelligentes
   - Recommandation automatique (générique vs per-app)
   - UX améliorée (progress indicators 1/3, 2/3, 3/3)

2. **Installation Quick Tunnel** ✅
   - Script `setup-free-cloudflare-tunnel.sh` exécuté
   - Container `certidoc-tunnel` créé et démarré
   - Connexion au Docker network `supabase_network`
   - URL publique générée automatiquement
   - Scripts helpers créés (`get-url.sh`, `status.sh`)

3. **Tests de Connectivité** ✅
   - Tunnel accessible depuis Internet
   - CertiDoc répond correctement via tunnel
   - HTTPS fonctionnel avec certificat Cloudflare

4. **Documentation** ✅
   - 5 documents de référence créés
   - Guide rapide copié sur le Pi
   - Commandes essentielles documentées
   - TODO.md mis à jour

---

## 📝 Commandes Essentielles

### Obtenir l'URL Actuelle

**Méthode 1 : Script automatique (RECOMMANDÉ)** ⭐
```bash
bash /home/pi/tunnels/certidoc/get-url.sh
```

**Méthode 2 : Via les logs**
```bash
docker logs certidoc-tunnel 2>&1 | grep trycloudflare.com
```

**Méthode 3 : Fichier cache**
```bash
cat /home/pi/tunnels/certidoc/current-url.txt
```

**Méthode 4 : Status complet**
```bash
bash /home/pi/tunnels/certidoc/status.sh
```

---

### Gestion du Tunnel

**Voir le status**
```bash
bash /home/pi/tunnels/certidoc/status.sh
```

**Voir les logs en temps réel**
```bash
docker logs -f certidoc-tunnel
```

**Redémarrer le tunnel** (génère nouvelle URL)
```bash
cd /home/pi/tunnels/certidoc
docker compose restart

# Attendre 15 secondes puis obtenir nouvelle URL
sleep 15
bash get-url.sh
```

**Arrêter le tunnel**
```bash
cd /home/pi/tunnels/certidoc
docker compose down
```

**Démarrer le tunnel**
```bash
cd /home/pi/tunnels/certidoc
docker compose up -d
```

---

## 🔧 Configuration Technique

### Docker Compose

```yaml
version: '3.8'

services:
  certidoc-tunnel:
    image: cloudflare/cloudflared:latest
    container_name: certidoc-tunnel
    restart: unless-stopped
    command: tunnel --url http://certidoc-frontend:80
    networks:
      - supabase_network
    environment:
      - TUNNEL_METRICS=0.0.0.0:9090
    healthcheck:
      test: ["CMD-SHELL", "pgrep cloudflared || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  supabase_network:
    external: true
    name: supabase_network
```

### Ressources

- **RAM** : ~50 MB (très léger)
- **CPU** : Négligeable (<1%)
- **Stockage** : ~100 MB (image Docker)

---

## 📊 Comparaison des Approches

### Quick Tunnel (Actuel) 🆓

**Avantages** :
- ✅ 100% gratuit
- ✅ Aucune configuration complexe
- ✅ HTTPS automatique
- ✅ Pas de domaine requis
- ✅ Setup en 5 minutes
- ✅ Protection DDoS incluse

**Limitations** :
- ⚠️ URL change à chaque redémarrage
- ⚠️ URL aléatoire (*.trycloudflare.com)
- ⚠️ Un seul service par tunnel
- ⚠️ Pas idéal pour production long-terme

**Cas d'usage** :
- Démonstrations
- Tests publics
- MVP rapide
- Partage temporaire

---

### Tunnel avec Domaine Custom 🎯

**Avantages** :
- ✅ URL permanente (ne change jamais)
- ✅ Domaine personnalisé (certidoc.fr)
- ✅ Support multi-apps
- ✅ Certificat SSL Let's Encrypt auto
- ✅ Professionnel

**Coût** :
- ~10-15€/an (domaine)

**Migration** :
```bash
# Quand vous aurez un domaine, lancez simplement :
sudo bash /path/to/migrate-to-custom-domain.sh
```

---

## 🎯 Roadmap Future

### Phase 1 : État Actuel (✅ TERMINÉ)
- [x] CertiDoc exposé via Quick Tunnel
- [x] URL : `https://playback-wildlife-daughters-jesse.trycloudflare.com`
- [x] Documentation complète
- [x] Scripts helpers

### Phase 2 : Migration Domaine Custom (🎯 FUTUR)
- [ ] Acheter domaine (ex: certidoc.fr)
- [ ] Ajouter domaine à Cloudflare
- [ ] Lancer `migrate-to-custom-domain.sh`
- [ ] URL permanente : `https://certidoc.fr`

### Phase 3 : Tunnel Générique Multi-Apps (⏳ OPTIONNEL)
- [ ] Créer tunnel générique pour autres apps
- [ ] Architecture hybride : CertiDoc dédié + autres partagé
- [ ] Utiliser scripts `01-setup-generic-tunnel.sh` + `02-add-app-to-tunnel.sh`

---

## 🐛 Troubleshooting

### Le Tunnel ne Démarre Pas

```bash
# Voir les logs d'erreur
docker logs certidoc-tunnel --tail 50

# Vérifier que CertiDoc tourne
docker ps | grep certidoc-frontend

# Vérifier le réseau Docker
docker network inspect supabase_network

# Redémarrer le tunnel
cd /home/pi/tunnels/certidoc
docker compose restart
```

---

### L'URL ne Fonctionne Pas

```bash
# 1. Vérifier que le tunnel tourne
docker ps | grep certidoc-tunnel

# 2. Voir les logs
docker logs certidoc-tunnel --tail 50

# 3. Vérifier que CertiDoc répond en local
curl -I http://certidoc-frontend:80

# 4. Redémarrer CertiDoc
cd /home/pi/certidoc
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

# 2. Vérifier le réseau
docker inspect certidoc-frontend | grep -A 5 '"Networks"'

# 3. Si besoin, éditer docker-compose.yml
cd /home/pi/tunnels/certidoc
nano docker-compose.yml
# Changer "name:" sous "networks:" avec le bon réseau
```

---

### Erreur 502 Bad Gateway

**Problème** : Le tunnel fonctionne mais CertiDoc ne répond pas

**Solution** :
```bash
# 1. Tester CertiDoc en local
curl -I http://localhost:9000

# 2. Voir logs CertiDoc
docker logs certidoc-frontend --tail 50

# 3. Redémarrer CertiDoc
cd /home/pi/certidoc
docker compose restart
```

---

## 📚 Documentation Complète

### Guides de Référence

| Document | Description | Usage |
|----------|-------------|-------|
| **QUICK-REFERENCE-FREE-TUNNEL.md** | Commandes essentielles | Référence rapide quotidienne |
| **CLOUDFLARE-TUNNEL-COMPLETE-GUIDE.md** | Vue d'ensemble complète | Compréhension globale |
| **README.md** | Tunnel générique multi-apps | Setup pour autres apps |
| **HYBRID-APPROACH.md** | Architecture mixte | Décisions d'architecture |
| **CERTIDOC-TUNNEL-SETUP.md** | Setup avec domaine custom | Migration future |

---

### Scripts Disponibles

| Script | Description | Statut |
|--------|-------------|---------|
| `00-cloudflare-tunnel-wizard.sh` | Wizard choix architecture | ✅ Utilisé |
| `setup-free-cloudflare-tunnel.sh` | Installation Quick Tunnel | ✅ Déployé |
| `migrate-to-custom-domain.sh` | Migration vers domaine | 🎯 Ready |
| `01-setup-generic-tunnel.sh` | Tunnel multi-apps | 📦 Disponible |
| `02-add-app-to-tunnel.sh` | Ajouter app | 📦 Disponible |
| `03-remove-app-from-tunnel.sh` | Retirer app | 📦 Disponible |
| `04-list-tunnel-apps.sh` | Lister apps | 📦 Disponible |

---

## 🤝 Architecture Hybride (Recommandé)

### Vision Globale

**CertiDoc** : Tunnel dédié (critique, production)
- URL actuelle : `https://playback-wildlife-daughters-jesse.trycloudflare.com`
- Future : `https://certidoc.fr`
- RAM : 50 MB
- Container : `certidoc-tunnel`

**Autres Apps** : Tunnel générique partagé (économique)
- Future : Dashboard, admin, API test, etc.
- RAM : 50 MB total (multi-apps)
- Container : `cloudflare-tunnel-generic`

**Total RAM** : ~100 MB pour toute l'infrastructure Cloudflare

**Setup tunnel générique** (quand nécessaire) :
```bash
sudo bash 01-setup-generic-tunnel.sh

# Puis ajouter apps :
sudo bash 02-add-app-to-tunnel.sh \
  --name dashboard \
  --hostname dashboard.votredomaine.com \
  --service dashboard-frontend:80
```

---

## 📞 Support et Ressources

### Logs Complets

```bash
# Log installation
cat /var/log/cloudflare-free-tunnel-*.log

# Logs tunnel
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
sudo rm -rf /home/pi/tunnels/certidoc

# 2. Relancer le script
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/external-access/scripts/setup-free-cloudflare-tunnel.sh | sudo bash
```

---

### Liens Utiles

- **Documentation Cloudflare Tunnel** : https://developers.cloudflare.com/cloudflare-one/
- **GitHub PI5-SETUP** : https://github.com/iamaketechnology/pi5-setup
- **Cloudflare Dashboard** : https://dash.cloudflare.com

---

## ✅ Checklist Déploiement

- [x] ✅ Wizard intelligent créé et testé
- [x] ✅ Quick Tunnel installé sur Pi
- [x] ✅ Container `certidoc-tunnel` démarré
- [x] ✅ URL publique générée et testée
- [x] ✅ CertiDoc accessible depuis Internet
- [x] ✅ Scripts helpers créés (`get-url.sh`, `status.sh`)
- [x] ✅ Documentation complète (5 guides)
- [x] ✅ TODO.md mis à jour
- [x] ✅ Script de migration vers domaine prêt
- [x] ✅ Guide de référence rapide copié sur Pi
- [x] ✅ Tests de connectivité réussis

---

## 🎉 Résumé Final

### Ce qui a été accompli

1. **Infrastructure Cloudflare Tunnel déployée** ✅
   - CertiDoc accessible publiquement via HTTPS
   - Aucune configuration réseau/NAT/firewall requise
   - Protection DDoS Cloudflare active

2. **Architecture Flexible** ✅
   - Quick Tunnel pour démarrage rapide (gratuit)
   - Script de migration prêt pour domaine custom
   - Support tunnel générique multi-apps disponible

3. **Documentation Complète** ✅
   - 5 guides détaillés créés
   - Commandes essentielles documentées
   - Troubleshooting complet

4. **Scripts Production-Ready** ✅
   - Idempotents
   - Error handling robuste
   - UX optimisée (progress indicators)
   - Helpers automatiques

### Prochaine Étape (Quand Prêt)

**Acheter un domaine** → **Lancer la migration** :
```bash
sudo bash /path/to/migrate-to-custom-domain.sh
```
→ CertiDoc sera accessible sur URL permanente `https://certidoc.fr`

---

**Version** : 1.0.0
**Auteur** : PI5-SETUP Project
**Date** : 2025-01-13
**Status** : ✅ Production Ready

---

*Ce guide sera mis à jour après la migration vers domaine custom*
