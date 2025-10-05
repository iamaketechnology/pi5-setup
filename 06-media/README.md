# 🎬 Média & Divertissement

> **Catégorie** : Serveur média et gestion bibliothèque

---

## 📦 Stacks Inclus

### 1. [Jellyfin + *arr Stack](jellyfin-arr/)

#### 🎥 Jellyfin
**Serveur Média (Plex / Emby alternative)**

- 🎬 Films + Séries TV
- 🎵 Musique
- 📚 Livres
- 📺 Live TV + DVR (optionnel)
- 📱 Apps : iOS, Android, TV, Roku, etc.
- 🔄 Transcoding matériel (ARM64)
- 👥 Multi-utilisateurs + profils

**RAM** : ~300 MB (idle), ~600 MB (transcoding)
**Port** : 8096

---

#### 📡 *arr Stack (Optionnel)
**Automation Média**

- **Sonarr** : Séries TV (recherche + download auto)
- **Radarr** : Films (recherche + download auto)
- **Prowlarr** : Gestion indexers (tracker search)
- **Bazarr** : Sous-titres automatiques

**RAM** : ~500 MB (tous combinés)
**Ports** : 8989 (Sonarr), 7878 (Radarr), 9696 (Prowlarr), 6767 (Bazarr)

---

### 2. [qBittorrent](qbittorrent/)
**Client Torrent avec WebUI**

**RAM** : ~150 MB | **Port** : 8080

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/qbittorrent/scripts/01-qbittorrent-deploy.sh | sudo bash
```

---

### 3. [Calibre-Web](calibre-web/)
**Bibliothèque Ebooks**

**RAM** : ~100 MB | **Port** : 8083

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/calibre-web/scripts/01-calibre-deploy.sh | sudo bash
```

---

### 4. [Navidrome](navidrome/)
**Serveur Streaming Musical**

**RAM** : ~100 MB | **Port** : 4533

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/navidrome/scripts/01-navidrome-deploy.sh | sudo bash
```


## 📊 Comparaison Jellyfin vs Plex

| Critère | Jellyfin | Plex |
|---------|----------|------|
| **Prix** | 💚 Gratuit | 💰 5€/mois (Pass) |
| **Open Source** | ✅ Oui | ❌ Non |
| **Transcoding HW** | ✅ ARM64 | ✅ Oui |
| **Apps** | ✅ Toutes plateformes | ✅ Toutes plateformes |
| **Compte cloud** | ❌ Non (local) | ✅ Oui |
| **Privacy** | ✅ 100% local | ⚠️ Télémétrie |

**Recommandation** : Jellyfin (gratuit, open source, privacy)

---

## 🚀 Installation

**Jellyfin uniquement** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/01-jellyfin-deploy.sh | sudo bash
```

**Jellyfin + *arr Stack complet** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/01-jellyfin-deploy.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/02-arr-stack-deploy.sh | sudo bash
```

**Accès** :
- Jellyfin : `http://raspberrypi.local:8096`
- Sonarr : `http://raspberrypi.local:8989`
- Radarr : `http://raspberrypi.local:7878`

---

## 🎯 Cas d'Usage

### Scénario 1 : Media Center Simple
**Jellyfin uniquement** pour lire vos fichiers existants
- Upload manuel fichiers dans `/home/pi/data/media/`
- Scan bibliothèque
- Regarder sur TV/mobile/web

### Scénario 2 : Automation Complète
**Jellyfin + *arr** pour gestion automatique
- Ajouter série dans Sonarr
- Sonarr cherche + télécharge épisodes
- Jellyfin détecte nouveaux épisodes automatiquement
- Notification mobile quand nouvel épisode disponible

---

## 📊 Statistiques Catégorie

| Métrique | Valeur |
|----------|--------|
| **Nombre de stacks** | 1 (2 composants) |
| **RAM totale** | ~800 MB (Jellyfin + *arr) |
| **Complexité** | ⭐⭐ (Modérée) |
| **Priorité** | 🟢 **OPTIONNEL** (loisir) |
| **Ordre installation** | Phase 8 |

---

## 💾 Structure Données

```
/home/pi/data/media/
├── movies/         # Films
├── tv/             # Séries
├── music/          # Musique
└── downloads/      # Téléchargements temporaires (*arr)
```

---

## 💡 Notes

- **Économies** : ~60€/an (vs Plex Pass)
- **Transcoding** : Pi 5 gère 1-2 flux simultanés 1080p
- **4K** : Déconseillé (transcoding trop lourd), utiliser Direct Play
- **Stockage** : Prévoir disque externe USB 3.0 pour bibliothèque importante
