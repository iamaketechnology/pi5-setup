# Immich - Alternative Google Photos avec IA

> **Google Photos self-hosted** avec reconnaissance faciale, objets, recherche sémantique

**Version** : Latest (ARM64 compatible)
**RAM** : ~500MB (ML désactivé) ou ~2GB (ML activé)
**Installation** : 5-10 min
**Niveau** : Débutant

---

## 🎯 Qu'est-ce qu'Immich ?

**Alternative open-source à Google Photos** avec :
- 📸 **Backup automatique photos/vidéos** (apps mobiles iOS/Android)
- 🤖 **IA reconnaissance faciale** + objets + lieux
- 🔍 **Recherche sémantique** ("chien sur la plage")
- 🗺️ **Carte photos géolocalisées**
- 👥 **Partage albums** avec famille/amis
- 📱 **Apps mobiles natives** (iOS/Android)

**Use Case** : Remplacer Google Photos, contrôle total de vos photos

---

## 🚀 Installation

### 📋 Choix de la Méthode

Ce repository propose **2 méthodes d'installation** :

| Méthode | Script | Avantages | Recommandé Pour |
|---------|--------|-----------|-----------------|
| **Custom** | [01-immich-deploy.sh](scripts/01-immich-deploy.sh) | Config simplifiée, intégration Pi5-setup | 🟢 Débutants |
| **Official + Wrapper** | [01-immich-deploy-official.sh](scripts/01-immich-deploy-official.sh) | Script upstream + intégration Traefik/Homepage | 🔵 Avancés |

**Les 2 méthodes donnent le même résultat** ✅

---

### Option 1 : Script Custom (Recommandé)

**Installation complète en 1 commande** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/immich/scripts/01-immich-deploy.sh | sudo bash
```

**Durée** : ~5 min

**Ce que fait le script** :
- ✅ Crée docker-compose.yml optimisé Pi5
- ✅ Génère .env sécurisé (passwords auto)
- ✅ Détecte scénario Traefik (DuckDNS/Cloudflare/VPN)
- ✅ Configure labels HTTPS automatiquement
- ✅ Démarre tous les services
- ✅ Ajoute à Homepage dashboard
- ✅ Affiche résumé (URLs, config apps mobiles)

---

### Option 2 : Script Officiel + Wrapper

**Utilise le script officiel Immich** (ARM64 testé upstream) :

```bash
# 1. Installation officielle
curl -o- https://raw.githubusercontent.com/immich-app/immich/main/install.sh | bash

# 2. Wrapper intégration (Traefik + Homepage + Backups)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/immich/scripts/01-immich-deploy-official.sh | sudo bash
```

**Durée** : ~10 min

**Avantages** :
- ✅ Script officiel maintenu par équipe Immich
- ✅ Dernière version stable
- ✅ + Intégration Traefik/Homepage/Backups

---

## 📱 Configuration Apps Mobiles

### iOS

1. **Télécharger** : [App Store - Immich](https://apps.apple.com/app/immich/id1613945652)
2. **Ouvrir** l'app
3. **Server URL** :
   - DuckDNS : `https://photos.monpi.duckdns.org`
   - Cloudflare : `https://photos.mondomaine.fr`
   - Local/VPN : `http://raspberrypi.local:2283`
4. **Se connecter** (créer compte dans interface web d'abord)
5. **Activer backup automatique** (Settings → Auto Backup)

### Android

1. **Télécharger** : [Google Play - Immich](https://play.google.com/store/apps/details?id=app.alextran.immich)
2. **Suivre** mêmes étapes que iOS

---

## ⚙️ Configuration Post-Installation

### Activer Machine Learning (Reconnaissance Faciale)

Par défaut, ML est **désactivé** pour économiser RAM (~500MB vs ~2GB).

**Pour activer** :

```bash
cd ~/stacks/immich  # ou ~/immich-app si install officielle

# Éditer .env
nano .env
# Changer: ML_ENABLED=true

# Redémarrer
docker-compose up -d
```

**ML ajoute** :
- ✅ Reconnaissance faciale (clustering automatique)
- ✅ Détection objets (chien, voiture, fleur, etc.)
- ✅ Recherche sémantique ("photos de montagne")

**Coût** : ~1.5GB RAM supplémentaire

---

## 📊 URLs d'Accès

Selon votre scénario Traefik :

| Scénario | URL Web | URL Mobile |
|----------|---------|------------|
| **DuckDNS** | `https://photos.monpi.duckdns.org` | Identique |
| **Cloudflare** | `https://photos.mondomaine.fr` | Identique |
| **VPN** | `https://photos.pi.local` | Identique (VPN actif) |
| **Sans Traefik** | `http://raspberrypi.local:2283` | Identique (réseau local) |

---

## 💾 Backups

### Backup Automatique (GFS)

Si installé via script officiel + wrapper :

```bash
# Backup manuel
~/bin/backup-immich.sh

# Automatique : Daily 2h (rotation 7d/4w/12m)
ls -lh ~/backups/immich/
```

### Backup Manuel (Custom)

```bash
cd ~/stacks/immich  # ou ~/immich-app

# Stop containers
docker-compose stop

# Backup database
docker exec immich-postgres pg_dumpall -U postgres > immich_backup_$(date +%Y%m%d).sql

# Backup photos (si pas sur stockage externe)
tar -czf immich_photos_$(date +%Y%m%d).tar.gz ~/data/immich/upload/

# Restart
docker-compose start
```

---

## 🔧 Gestion

### Commandes Utiles

```bash
# Installation custom
cd ~/stacks/immich

# Installation officielle
cd ~/immich-app

# Logs
docker-compose logs -f immich-server

# Redémarrer
docker-compose restart

# Arrêter
docker-compose down

# Mettre à jour
docker-compose pull
docker-compose up -d

# Voir consommation RAM
docker stats immich-server immich-machine-learning
```

### Stack Manager

```bash
# Voir RAM Immich
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh status

# Arrêter (libérer ~500MB-2GB)
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop immich

# Redémarrer
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh start immich

# Désactiver démarrage auto
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh disable immich
```

---

## 🎨 Fonctionnalités

### Interface Web

- 📸 **Timeline** : Vue chronologique photos
- 👥 **Personnes** : Clustering automatique visages
- 📍 **Carte** : Photos géolocalisées sur carte
- 🔍 **Recherche** : Par date, personne, lieu, objet
- 📁 **Albums** : Organisation manuelle
- 🔗 **Partage** : Liens publics albums
- ⚙️ **Paramètres** : Config backup, ML, users

### Apps Mobiles

- 📤 **Auto-backup** : Photos/vidéos en arrière-plan
- 📥 **Téléchargement sélectif** : Économie espace
- 🔄 **Sync bidirectionnel** : Modifs serveur ↔ app
- 🚀 **Rapide** : Upload optimisé
- 🌙 **Mode sombre** : Confort visuel

---

## 📈 Ressources

### RAM par Configuration

| Config | RAM Utilisée | Fonctionnalités |
|--------|-------------|-----------------|
| **ML désactivé** | ~500MB | Backup, timeline, albums, recherche basique |
| **ML activé** | ~2GB | + Reconnaissance faciale, objets, recherche sémantique |

### Stockage

- **Photos originales** : `~/data/immich/upload/` ou `~/immich-app/upload/`
- **Cache thumbnails** : Généré automatiquement
- **Base de données** : PostgreSQL (métadonnées)

**Estimation** : ~1GB par 1000 photos (originaux)

---

## 🆘 Problèmes Courants

### "Cannot connect to server"

**Vérifier** :
```bash
# Containers running?
docker ps | grep immich

# Logs erreurs?
docker-compose logs immich-server

# Redémarrer
docker-compose restart
```

### "Upload fails"

**Causes** :
- Permissions dossier upload
- Espace disque plein
- RAM insuffisante

**Solution** :
```bash
# Vérifier espace
df -h

# Vérifier RAM
free -h

# Permissions
sudo chown -R 1000:1000 ~/data/immich/upload/
```

### "ML très lent sur ARM64"

**Normal** : ARM64 est 2-3x plus lent que x86_64 pour ML.

**Solutions** :
- ✅ Utiliser tag `-armnn` pour optimisation ARM : `image: ghcr.io/immich-app/immich-machine-learning:release-armnn`
- ✅ Traiter par petits lots (100-200 photos à la fois)
- ✅ Laisser tourner la nuit

---

## 📚 Documentation Officielle

- **Site** : https://immich.app
- **GitHub** : https://github.com/immich-app/immich
- **Docs** : https://immich.app/docs
- **Discord** : https://discord.gg/immich

---

## 🎯 Use Cases

### 🏠 Famille

- Backup photos tous les membres
- Albums partagés (vacances, événements)
- Reconnaissance automatique famille
- Apps mobiles simples

### 📸 Photographe

- Stockage illimité (selon espace disque)
- Gestion collections
- Recherche rapide par date/lieu
- Export facile

### 🔒 Privacy-First

- Données chez vous (pas Google)
- Aucune analyse tierce
- Contrôle total
- Gratuit à vie

---

**🎉 Profitez de votre Google Photos self-hosted ! 🎉**
