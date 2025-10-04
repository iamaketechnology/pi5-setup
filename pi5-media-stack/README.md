# 🎬 Serveur Média Personnel sur Raspberry Pi 5

> **Netflix-like chez vous : Jellyfin + Stack *arr (Radarr/Sonarr/Prowlarr)**

---

## Vue d'Ensemble

Le **stack média personnel** transforme votre Raspberry Pi 5 en un serveur multimédia complet, offrant une alternative 100% open source et gratuite à Netflix, Plex Pass ou Emby Premiere. Cette solution combine **Jellyfin** (serveur de streaming média) avec le **stack *arr** (Radarr, Sonarr, Prowlarr) pour une gestion automatisée de votre bibliothèque multimédia.

**Pourquoi héberger son propre serveur média ?**

- **Contrôle total** : Vos données restent chez vous, aucun tracking externe
- **Économies** : 0€/mois vs ~60€/an pour Plex Pass ou Emby Premiere
- **Stockage illimité** : Limité uniquement par votre disque dur (vs quotas cloud)
- **Performance** : Streaming local ultra-rapide, pas de buffering
- **Flexibilité** : Formats supportés (MKV, AVI, MP4, FLAC, etc.), pas de restrictions DRM

**Deux composants complémentaires** :

1. **Jellyfin** : Serveur de lecture multimédia (films, séries, musique, photos) avec apps natives iOS/Android/TV
2. **Stack *arr** : Automation complète (recherche, téléchargement, organisation, renommage automatique)

**Cas d'usage concrets** :

- Bibliothèque films/séries familiale accessible sur toutes vos TV et mobiles
- Gestion automatisée de nouvelles sorties (suivi séries, notifications films)
- Galerie photos centralisée (vacances, événements familiaux)
- Lecteur audio pour collection musicale (MP3, FLAC, AAC)
- Streaming sécurisé depuis l'extérieur via VPN (Tailscale)

**Accélération GPU Raspberry Pi 5** : Le VideoCore VII intégré permet le transcodage matériel H.264/H.265, offrant 2-3 streams 1080p simultanés avec une consommation CPU minimale (<15%).

---

## Architecture Technique

```
📦 Stack Média Personnel
│
├── 🎬 Jellyfin (Serveur Média)
│   ├── Container : jellyfin/jellyfin:latest
│   ├── RAM : ~300 MB (idle), ~500 MB (1 stream 1080p)
│   ├── GPU : VideoCore VII (H.264/H.265 hardware transcoding)
│   ├── Port : 8096 (HTTP)
│   └── Volumes :
│       ├── /home/pi/media/movies → /media/movies
│       ├── /home/pi/media/tv → /media/tv
│       ├── /home/pi/media/music → /media/music
│       └── /home/pi/media/photos → /media/photos
│
└── 🎯 *arr Stack (Gestion Automatisée)
    │
    ├── 🔍 Prowlarr (Indexer Manager)
    │   ├── Container : lscr.io/linuxserver/prowlarr:latest
    │   ├── RAM : ~100 MB
    │   ├── Port : 9696
    │   └── Rôle : Gestion centralisée indexers (recherche torrents/usenet)
    │
    ├── 🎬 Radarr (Films)
    │   ├── Container : lscr.io/linuxserver/radarr:latest
    │   ├── RAM : ~200 MB
    │   ├── Port : 7878
    │   └── Rôle : Recherche, téléchargement, organisation films
    │
    └── 📺 Sonarr (Séries TV)
        ├── Container : lscr.io/linuxserver/sonarr:latest
        ├── RAM : ~200 MB
        ├── Port : 8989
        └── Rôle : Suivi séries, téléchargement épisodes, organisation

    Volumes partagés :
    ├── /home/pi/media/ (bibliothèques médias)
    └── /home/pi/downloads/ (téléchargements temporaires)
```

**Flux de données** :
```
┌─────────────┐      ┌──────────┐      ┌─────────────┐
│  Prowlarr   │─────▶│  Radarr  │─────▶│ Jellyfin    │
│ (Indexers)  │      │ (Films)  │      │ (Lecture)   │
└─────────────┘      └──────────┘      └─────────────┘
                            │                  │
                            ▼                  ▼
                     /downloads/        /media/movies/
                                              │
┌─────────────┐      ┌──────────┐            │
│  Prowlarr   │─────▶│  Sonarr  │────────────┤
│ (Indexers)  │      │ (Séries) │            │
└─────────────┘      └──────────┘            ▼
                            │          /media/tv/
                            ▼
                     /downloads/
```

---

## Fonctionnalités Clés

### Jellyfin (Serveur Média)

- 🎬 **Serveur multimédia universel** : Films, séries, musique, photos, livres audio
- 🎮 **GPU transcoding Pi5** : H.264/H.265 matériel via VideoCore VII (2-3 streams 1080p)
- 📱 **Apps natives** : iOS, Android, Android TV, Fire TV, Roku, Samsung TV, LG WebOS
- 👥 **Multi-utilisateurs** : Profils séparés avec bibliothèques personnalisées
- 🌍 **Sous-titres automatiques** : Intégration OpenSubtitles
- 📊 **Statistiques visionnage** : Historique, temps regardé, progression
- 🔄 **Sync multi-appareils** : Reprendre lecture sur n'importe quel appareil
- 🎨 **Métadonnées riches** : Posters, fanarts, résumés (TMDB, TVDB, MusicBrainz)
- 📡 **Live TV & DVR** : Support tuners TV (optionnel)
- 🔐 **Contrôle parental** : Restrictions contenu par profil

### *arr Stack (Automation)

#### 🔍 Prowlarr (Indexer Manager)
- Gestion centralisée indexers torrents/usenet
- Configuration une fois, propagation auto vers Radarr/Sonarr
- Test connexion, statistiques indexers
- Support 500+ indexers (publics et privés)

#### 🎬 Radarr (Films)
- **Recherche intelligente** : Filtres qualité (1080p, 4K, HDR), langue, taille
- **Téléchargement automatique** : Intégration clients torrents (qBittorrent, Transmission, Deluge)
- **Organisation fichiers** : Renommage selon template personnalisé
- **Gestion bibliothèque** : Détection doublons, upgrades qualité
- **Calendrier sorties** : Notifications nouveaux films (cinéma, Blu-ray)
- **Listes automatiques** : Import listes IMDB, Trakt, TMDB

#### 📺 Sonarr (Séries TV)
- **Suivi séries actif** : Track épisodes manquants
- **Téléchargement auto** : Nouveaux épisodes dès sortie
- **Organisation saisons/épisodes** : Structure standard (S01E01)
- **Profils qualité** : Par série (1080p pour Breaking Bad, 720p pour sitcoms)
- **Calendrier épisodes** : Planning sorties hebdomadaires
- **Gestion multi-saisons** : Choisir saisons à suivre

---

## Installation Rapide

### Jellyfin (Serveur Média)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-media-stack/scripts/01-jellyfin-deploy.sh | sudo bash
```

**Durée** : ~10 minutes
**Actions** :
- Installation container Jellyfin
- Configuration GPU transcoding (VideoCore VII)
- Création structure dossiers `/home/pi/media/`
- Configuration permissions utilisateur
- Intégration Traefik (HTTPS automatique)

**Accès** :
- Local : `http://pi.local:8096`
- Traefik : `https://jellyfin.votredomaine.com`

### *arr Stack (Gestion Automatisée)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-media-stack/scripts/02-arr-stack-deploy.sh | sudo bash
```

**Durée** : ~10 minutes
**Actions** :
- Installation Prowlarr, Radarr, Sonarr
- Configuration volumes partagés
- Création dossiers `/home/pi/downloads/`
- Intégration Traefik

**Accès** :
- Prowlarr : `http://pi.local:9696`
- Radarr : `http://pi.local:7878`
- Sonarr : `http://pi.local:8989`

---

## GPU Transcoding (Raspberry Pi 5)

### Capacités VideoCore VII

Le GPU VideoCore VII du Raspberry Pi 5 supporte l'accélération matérielle pour :

| Codec | Decode (Lecture) | Encode (Transcoding) |
|-------|------------------|----------------------|
| **H.264** | ✅ Hardware | ✅ Hardware |
| **H.265/HEVC** | ✅ Hardware | ❌ Software (CPU) |
| **VP9** | ❌ Software (CPU) | ❌ Software (CPU) |
| **AV1** | ❌ Software (CPU) | ❌ Software (CPU) |

### Performances Transcoding

**Tests réels sur Raspberry Pi 5** :

| Source | Cible | FPS | CPU % | Méthode |
|--------|-------|-----|-------|---------|
| 4K H.264 | 1080p H.264 | 30-40 | 10-15% | GPU decode + encode |
| 1080p H.264 | 720p H.264 | 60+ | 8-12% | GPU decode + encode |
| 1080p H.265 | 1080p H.264 | 25-30 | 15-20% | GPU decode + CPU encode |
| 4K H.265 | 1080p H.264 | 20-25 | 20-30% | GPU decode + CPU encode |

**Streams simultanés** :
- **2-3 streams 1080p → 720p** : Fluide (GPU)
- **1 stream 4K → 1080p** : Fluide si H.264 source
- **Direct Play** (pas de transcoding) : 10+ clients simultanés

### Configuration Jellyfin GPU

**Activer transcoding matériel** (automatique avec script `01-jellyfin-deploy.sh`) :

1. Jellyfin Web UI → **Dashboard** → **Playback**
2. Section **Hardware Acceleration** :
   - **Hardware acceleration** : `Video Acceleration API (VAAPI)`
   - **VA API Device** : `/dev/dri/renderD128`
   - **Enable hardware decoding** : ✅ Tous codecs supportés
   - **Enable hardware encoding** : ✅ H.264

**Vérification GPU** :
```bash
# Vérifier périphérique GPU
ls -la /dev/dri/renderD128
# Doit exister et être accessible

# Vérifier groupes utilisateur
groups pi
# Doit contenir 'video' et 'render'
```

---

## Applications Clientes

### Jellyfin Apps Officielles

**TV & Streaming Boxes** :

| Plateforme | App | Téléchargement |
|------------|-----|----------------|
| **Android TV** | Jellyfin for Android TV | [Play Store](https://play.google.com/store/apps/details?id=org.jellyfin.androidtv) |
| **Fire TV** | Jellyfin for Fire TV | [Amazon Appstore](https://www.amazon.com/gp/product/B081RFTTQ9) |
| **Roku** | Jellyfin | [Roku Channel Store](https://channelstore.roku.com/details/592369/jellyfin) |
| **Apple TV** | Swiftfin | [App Store](https://apps.apple.com/app/swiftfin/id1604098728) |
| **Samsung TV** | Jellyfin (Tizen) | App Store Samsung |
| **LG WebOS** | Jellyfin WebOS | LG Content Store |

**Mobile** :

| Plateforme | App | Téléchargement |
|------------|-----|----------------|
| **iOS/iPadOS** | Jellyfin Mobile | [App Store](https://apps.apple.com/app/jellyfin-mobile/id1480192618) |
| **Android** | Jellyfin Mobile | [Play Store](https://play.google.com/store/apps/details?id=org.jellyfin.mobile) |

**Desktop** :

| Plateforme | App | Téléchargement |
|------------|-----|----------------|
| **Windows** | Jellyfin Media Player | [GitHub Releases](https://github.com/jellyfin/jellyfin-media-player/releases) |
| **macOS** | Jellyfin Media Player | [GitHub Releases](https://github.com/jellyfin/jellyfin-media-player/releases) |
| **Linux** | Jellyfin Media Player | [GitHub Releases](https://github.com/jellyfin/jellyfin-media-player/releases) |
| **Navigateur** | Jellyfin Web | `http://pi.local:8096` |

**Fonctionnalités apps** :
- ✅ Streaming direct et transcoding
- ✅ Téléchargement offline (mobile)
- ✅ Sync progression multi-appareils
- ✅ Sous-titres (SRT, ASS, SSA)
- ✅ Audio multi-pistes
- ✅ Contrôle parental

---

## Workflow Automatisé (*arr Stack)

### Scénario 1 : Ajouter un Film (Radarr)

```
┌────────────────────────────────────────────────────────────────┐
│ 1. RECHERCHE FILM                                              │
├────────────────────────────────────────────────────────────────┤
│ Radarr Web UI (http://pi.local:7878)                          │
│ → Clic "Add Movies"                                            │
│ → Recherche : "Inception 2010"                                 │
│ → Sélection film (métadonnées TMDB)                           │
│ → Profil qualité : "1080p Bluray" (ou personnalisé)          │
│ → Dossier racine : /media/movies                              │
│ → Clic "Add Movie"                                             │
└────────────────────────────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────────────────────────────┐
│ 2. RECHERCHE AUTOMATIQUE                                       │
├────────────────────────────────────────────────────────────────┤
│ Radarr → Prowlarr (via API)                                   │
│ → Recherche : "Inception 2010 1080p"                          │
│ → Prowlarr interroge indexers configurés (publics/privés)    │
│ → Retour résultats triés (seeders, qualité, taille)          │
│ → Radarr analyse résultats selon profil qualité              │
└────────────────────────────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────────────────────────────┐
│ 3. TÉLÉCHARGEMENT                                              │
├────────────────────────────────────────────────────────────────┤
│ Radarr → Client torrent (qBittorrent/Transmission)           │
│ → Ajout torrent à la queue                                    │
│ → Téléchargement vers /downloads/movies/                      │
│ → Radarr surveille progression (polling API client)          │
└────────────────────────────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────────────────────────────┐
│ 4. IMPORT & ORGANISATION                                       │
├────────────────────────────────────────────────────────────────┤
│ Download terminé (100%)                                        │
│ → Radarr détecte fin téléchargement                           │
│ → Renommage selon template :                                  │
│   "Inception (2010) - 1080p Bluray.mkv"                       │
│ → Déplacement vers :                                           │
│   /media/movies/Inception (2010)/Inception (2010).mkv         │
│ → Suppression fichiers temporaires /downloads/                │
└────────────────────────────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────────────────────────────┐
│ 5. JELLYFIN SCAN & MÉTADONNÉES                                │
├────────────────────────────────────────────────────────────────┤
│ Jellyfin détecte nouveau fichier (scan auto 30 min)          │
│ → Extraction métadonnées TMDB :                               │
│   - Poster, fanart, logo                                       │
│   - Synopsis, acteurs, réalisateur                            │
│   - Note, genres, durée                                        │
│ → Film apparaît bibliothèque immédiatement                    │
└────────────────────────────────────────────────────────────────┘
```

**Temps total** : 10-60 minutes selon taille film

### Scénario 2 : Suivre une Série TV (Sonarr)

```
┌────────────────────────────────────────────────────────────────┐
│ 1. AJOUT SÉRIE                                                 │
├────────────────────────────────────────────────────────────────┤
│ Sonarr Web UI (http://pi.local:8989)                          │
│ → Clic "Add Series"                                            │
│ → Recherche : "Breaking Bad"                                   │
│ → Sélection série (métadonnées TVDB/TMDB)                    │
│ → Profil qualité : "1080p WEB-DL"                             │
│ → Monitoring :                                                 │
│   - "All Episodes" (toutes saisons existantes)                │
│   - "Future Episodes" (nouveaux épisodes seulement)           │
│   - "Latest Season" (dernière saison uniquement)              │
│ → Dossier racine : /media/tv                                   │
│ → Clic "Add Series"                                            │
└────────────────────────────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────────────────────────────┐
│ 2. RECHERCHE ÉPISODES MANQUANTS                               │
├────────────────────────────────────────────────────────────────┤
│ Sonarr analyse saisons :                                       │
│ → Breaking Bad : 5 saisons, 62 épisodes                       │
│ → Status actuel : 0 épisodes présents                         │
│ → Queue recherche automatique :                               │
│   S01E01 "Pilot"                                               │
│   S01E02 "Cat's in the Bag..."                                │
│   ... (tous épisodes selon monitoring)                        │
│ → Recherche via Prowlarr (même workflow que Radarr)          │
└────────────────────────────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────────────────────────────┐
│ 3. TÉLÉCHARGEMENT & IMPORT                                     │
├────────────────────────────────────────────────────────────────┤
│ Pour chaque épisode :                                          │
│ → Download via client torrent                                 │
│ → Renommage selon template :                                  │
│   "Breaking Bad - S01E01 - Pilot.mkv"                         │
│ → Déplacement vers :                                           │
│   /media/tv/Breaking Bad/Season 01/                           │
│   Breaking.Bad.S01E01.Pilot.1080p.WEB-DL.mkv                  │
└────────────────────────────────────────────────────────────────┘
              ↓
┌────────────────────────────────────────────────────────────────┐
│ 4. SUIVI NOUVEAUX ÉPISODES (Automation Continue)             │
├────────────────────────────────────────────────────────────────┤
│ Sonarr vérifie calendrier quotidiennement :                   │
│ → Nouveau épisode détecté (ex: S06E01 sort dans 2 jours)     │
│ → Ajout automatique à la queue de recherche                  │
│ → J+0 (jour sortie) : Recherche via Prowlarr                 │
│ → Download auto dès disponibilité                             │
│ → Import auto → Notification (optionnel)                      │
│ → Jellyfin scan → Épisode apparaît bibliothèque              │
└────────────────────────────────────────────────────────────────┘
```

**Avantages suivi automatique** :
- Plus besoin de chercher manuellement nouveaux épisodes
- Disponibilité immédiate après sortie
- Organisation cohérente (S01E01, S01E02...)
- Métadonnées complètes (synopsis épisode, captures écran)

---

## Ressources Système

### Consommation Jellyfin

**RAM** :
- Idle (aucun stream) : ~300 MB
- 1 stream 1080p (GPU transcoding) : ~450 MB
- 1 stream 4K → 1080p : ~500 MB
- 3 streams 1080p simultanés : ~700 MB

**CPU** :
- Idle : <5%
- 1 stream GPU transcoding : 10-15%
- 1 stream CPU transcoding (H.265) : 40-60%
- Scan bibliothèque (métadonnées) : 20-30%

**GPU (VideoCore VII)** :
- 1 stream H.264 : ~30-40% utilisation GPU
- 2 streams H.264 : ~60-80% utilisation GPU

### Consommation *arr Stack

**Par composant** :

| App | RAM (Idle) | RAM (Active) | CPU (Idle) | CPU (Scan) |
|-----|------------|--------------|------------|------------|
| **Prowlarr** | 100 MB | 120 MB | <2% | 5-10% |
| **Radarr** | 180 MB | 250 MB | <3% | 10-15% |
| **Sonarr** | 180 MB | 250 MB | <3% | 10-15% |

**Total *arr stack** : ~600 MB RAM, <10% CPU (idle)

### Consommation Totale Stack Média

**Stack complet (Jellyfin + *arr)** :
- RAM : ~900 MB (idle), ~1.2 GB (1 stream + scan)
- CPU : <10% (idle), 20-30% (transcoding + scan)

**Intégration Pi5-Setup (Phases 1-7)** :
```
Phase 1 (Base)       : ~800 MB RAM
Phase 2 (Traefik)    : ~100 MB RAM
Phase 3 (Portainer)  : ~80 MB RAM
Phase 4 (Homepage)   : ~50 MB RAM
Phase 5 (VPN)        : ~60 MB RAM
Phase 6 (Monitoring) : ~300 MB RAM
Phase 7 (Backup)     : ~50 MB RAM
───────────────────────────────────
Sous-total Phases    : ~1.44 GB RAM
Stack Média (Phase 8): ~1.2 GB RAM
───────────────────────────────────
TOTAL                : ~2.64 GB / 16 GB (16.5%)
Marge disponible     : ~13.36 GB ✅
```

**Optimisation RAM** :
- Swappiness configuré à 10 (préférence RAM)
- Zram activé (compression RAM)
- Logs rotatifs (pas d'accumulation disque)

---

## Intégration Pi5-Setup

### Avec Traefik (Reverse Proxy)

**Auto-détection scénario réseau** :

Le script `01-jellyfin-deploy.sh` détecte automatiquement votre configuration Traefik et génère les labels appropriés :

**Scénario 1 : DuckDNS** (`/home/pi/stacks/traefik/duckdns.env` présent)
```yaml
labels:
  - "traefik.http.routers.jellyfin.rule=Host(`subdomain.duckdns.org`) && PathPrefix(`/jellyfin`)"
  - "traefik.http.routers.jellyfin.tls.certresolver=duckdns"
```
**Accès** : `https://subdomain.duckdns.org/jellyfin`

**Scénario 2 : Cloudflare** (`/home/pi/stacks/traefik/cloudflare.env` présent)
```yaml
labels:
  - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.votredomaine.com`)"
  - "traefik.http.routers.jellyfin.tls.certresolver=cloudflare"
```
**Accès** : `https://jellyfin.votredomaine.com`

**Scénario 3 : VPN uniquement** (Tailscale sans DNS public)
```yaml
labels:
  - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.pi.local`)"
  - "traefik.http.routers.jellyfin.tls=false"
```
**Accès** : `http://jellyfin.pi.local` (VPN requis)

**Certificats HTTPS** :
- Génération automatique via Let's Encrypt
- Renouvellement auto tous les 60 jours
- Wildcard supporté (Cloudflare DNS challenge)

### Avec Homepage (Dashboard)

**Widgets Jellyfin** :

```yaml
- Jellyfin:
    icon: jellyfin.png
    href: https://jellyfin.votredomaine.com
    description: Serveur média personnel
    widget:
      type: jellyfin
      url: http://jellyfin:8096
      key: YOUR_JELLYFIN_API_KEY
      enableBlocks: true
      enableNowPlaying: true
```

**Affichage** :
- Nombre de films/séries
- Épisodes récemment ajoutés
- Lecture en cours (Now Playing)
- Statistiques bibliothèque

**Widgets *arr** :

```yaml
- Radarr:
    icon: radarr.png
    href: http://pi.local:7878
    widget:
      type: radarr
      url: http://radarr:7878
      key: YOUR_RADARR_API_KEY

- Sonarr:
    icon: sonarr.png
    href: http://pi.local:8989
    widget:
      type: sonarr
      url: http://sonarr:8989
      key: YOUR_SONARR_API_KEY
```

**Récupération clés API** :
```bash
# Radarr
docker exec radarr cat /config/config.xml | grep '<ApiKey>'

# Sonarr
docker exec sonarr cat /config/config.xml | grep '<ApiKey>'

# Jellyfin
# Web UI → Dashboard → API Keys → Create
```

### Avec VPN (Tailscale)

**Streaming sécurisé depuis n'importe où** :

1. **Connexion VPN Tailscale** (depuis mobile/laptop)
2. **Accès Jellyfin** : `https://100.x.y.z:8096` (IP Tailscale Pi)
3. **Streaming chiffré** : Tout le trafic passe par tunnel VPN

**Avantages** :
- Pas d'exposition Internet public (pas de port forwarding)
- Chiffrement bout-en-bout
- Adresses IP stables
- Access control Tailscale ACLs

**Configuration Jellyfin pour VPN** :
```bash
# Dashboard → Networking
# Ajouter IP Tailscale aux trusted proxies
LAN Networks: 192.168.1.0/24, 100.64.0.0/10
```

---

## Comparaison vs Solutions Cloud

### Jellyfin vs Plex/Emby

| Feature | Jellyfin (Pi5) | Plex Pass | Emby Premiere |
|---------|----------------|-----------|---------------|
| **Coût mensuel** | 0€ | 5€ | 5€ |
| **Coût annuel** | 0€ | 60€ (~120€ lifetime) | 54€ (~120€ lifetime) |
| **Stockage** | Illimité (disque) | 1 TB cloud (payant) | Limité cloud |
| **Privacy** | 100% local | Tracking Plex.tv | Tracking limité |
| **Authentification** | Locale ou LDAP | Compte Plex obligatoire | Compte Emby optionnel |
| **GPU transcoding** | ✅ Gratuit | ✅ Plex Pass requis | ✅ Premiere requis |
| **Apps mobiles** | ✅ Gratuites | ✅ Gratuites | ✅ Gratuites (limité sans Premiere) |
| **Apps TV** | ✅ Toutes | ✅ Toutes | ✅ Toutes |
| **Live TV & DVR** | ✅ Gratuit | ✅ Gratuit | ✅ Payant |
| **Intro Skip** | ✅ Plugin | ✅ Natif | ✅ Natif |
| **Open Source** | ✅ GPLv2 | ❌ Propriétaire | ❌ Propriétaire |
| **Téléchargement offline** | ✅ | ✅ Plex Pass requis | ✅ Premiere requis |
| **Utilisateurs simultanés** | Illimité | Limité bande passante | Illimité |
| **Sync progression** | ✅ | ✅ | ✅ |

**Économies annuelles** :
- Jellyfin (Pi5) : **0€/an**
- Plex Pass : **60€/an** (ou 120€ lifetime)
- Emby Premiere : **54€/an** (ou 120€ lifetime)

**Économie totale sur 5 ans** : **300€+** vs Plex Pass

### Jellyfin vs Netflix/Prime

| Feature | Jellyfin (Pi5) | Netflix Premium | Amazon Prime |
|---------|----------------|-----------------|--------------|
| **Coût mensuel** | 0€ | 18€ | 7€ |
| **Coût annuel** | 0€ | 216€ | 84€ |
| **Bibliothèque** | Votre collection | Catalogue Netflix | Catalogue Amazon |
| **Contenu rotatif** | ❌ Permanent | ✅ Films partent | ✅ Films partent |
| **4K** | ✅ Si source 4K | ✅ | ✅ |
| **Offline** | ✅ Illimité | ✅ Limité | ✅ Limité |
| **Partage famille** | ✅ Illimité | ✅ 1 profil simultané | ✅ 2 appareils |
| **DRM** | ❌ Aucun | ✅ Restrictif | ✅ Restrictif |

**Complément** : Jellyfin + Netflix = Meilleur des deux mondes
- Jellyfin : Collection personnelle permanente
- Netflix : Nouveautés et exclusivités

---

## Cas d'Usage Concrets

### 1. Bibliothèque Films Familiale

**Scénario** : Collection 200 films sur disque externe 2 TB

**Setup** :
```bash
# Monter disque externe
sudo mount /dev/sda1 /mnt/external

# Lien symbolique vers bibliothèque Jellyfin
ln -s /mnt/external/films /home/pi/media/movies

# Scanner bibliothèque Jellyfin
# Web UI → Dashboard → Libraries → Scan
```

**Résultat** :
- Tous les films accessibles sur TV salon (Android TV app)
- Posters + métadonnées automatiques
- Streaming 1080p sans transcoding (direct play)
- Enfants : Profil avec films enfants uniquement

### 2. Suivi Automatique Série TV

**Scénario** : Suivre "The Mandalorian" (nouvelles saisons)

**Setup** :
```
1. Sonarr → Add Series → "The Mandalorian"
2. Monitoring : "Future Episodes Only"
3. Qualité : 1080p WEB-DL
```

**Workflow** :
```
Nouvel épisode S03E05 sort vendredi 10h
→ Sonarr détecte release (scan automatique)
→ Recherche via Prowlarr (10h30)
→ Download WEB-DL 1080p (11h-12h)
→ Import auto vers /media/tv/The Mandalorian/Season 03/
→ Jellyfin scan (12h30)
→ Notification mobile : "Nouvel épisode disponible"
→ Lecture sur TV salon le soir même
```

**Gain de temps** : 0 manipulation manuelle

### 3. Galerie Photos Vacances

**Scénario** : 5000 photos vacances (2015-2024)

**Setup** :
```bash
# Upload photos vers Pi
scp -r ~/Photos/Vacances/* pi@pi.local:/home/pi/media/photos/Vacances/

# Jellyfin scan automatique
```

**Résultat** :
- Galerie photos accessible web/mobile
- Organisation par dossier (Vacances 2024, Noël 2023...)
- Lecture diaporama sur TV
- Partage avec famille (profils utilisateurs)

### 4. Collection Musicale

**Scénario** : 2000 albums MP3/FLAC

**Setup** :
```bash
# Copier collection musicale
rsync -avh /media/musique/ pi@pi.local:/home/pi/media/music/

# Jellyfin scan + métadonnées MusicBrainz
```

**Fonctionnalités** :
- Lecteur audio web/mobile
- Organisation par artiste/album/genre
- Playlists personnalisées
- Sync offline (download albums sur mobile)
- Lyrics (plugin)

### 5. Streaming Mobile Hors Ligne

**Scénario** : Voyage en avion (10h sans WiFi)

**Préparation** :
```
Jellyfin Mobile App (iOS/Android)
→ Bibliothèque Films
→ Film "Inception"
→ Menu ⋮ → "Download"
→ Qualité : 720p (~1.5 GB)
→ Download complet avant départ
```

**En vol** :
- App Jellyfin → "Downloads"
- Lecture offline complète
- Reprise progression après atterrissage (sync cloud)

### 6. Multi-Profils Utilisateurs

**Scénario** : Famille 4 personnes

**Configuration** :
```
Profil 1: Papa (Admin)
→ Accès : Tout
→ Lecture : Films adultes, séries

Profil 2: Maman
→ Accès : Tout sauf admin
→ Lecture : Séries, films

Profil 3: Enfants (7 ans)
→ Accès : Bibliothèque "Films Enfants" uniquement
→ Restriction : G, PG ratings
→ PIN code requis pour sortir profil

Profil 4: Ado (15 ans)
→ Accès : Films, Séries (PG-13 max)
→ Restriction : R-rated bloqué
```

**Avantages** :
- Historiques séparés
- Recommandations personnalisées
- Contrôle parental granulaire

---

## Scripts Disponibles

| Script | Chemin | Description | Durée | Dépendances |
|--------|--------|-------------|-------|-------------|
| **01-jellyfin-deploy.sh** | `scripts/01-jellyfin-deploy.sh` | Installation Jellyfin + GPU transcoding + structure dossiers | ~10 min | Docker, Traefik (optionnel) |
| **02-arr-stack-deploy.sh** | `scripts/02-arr-stack-deploy.sh` | Installation Prowlarr + Radarr + Sonarr | ~10 min | Docker, Traefik (optionnel) |

### Détails Scripts

#### 01-jellyfin-deploy.sh

**Actions** :
1. Vérification dépendances (Docker, permissions)
2. Création structure dossiers :
   ```
   /home/pi/media/
   ├── movies/
   ├── tv/
   ├── music/
   └── photos/
   ```
3. Configuration permissions (user `pi`, groupes `video`, `render`)
4. Génération `docker-compose.yml` avec GPU transcoding (`/dev/dri/renderD128`)
5. Détection scénario Traefik (DuckDNS/Cloudflare/VPN)
6. Déploiement container Jellyfin
7. Vérification santé (health check)
8. Affichage URLs accès

**Commande** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-media-stack/scripts/01-jellyfin-deploy.sh | sudo bash
```

#### 02-arr-stack-deploy.sh

**Actions** :
1. Vérification Jellyfin déployé (prérequis)
2. Création dossiers downloads :
   ```
   /home/pi/downloads/
   ├── movies/
   ├── tv/
   └── incomplete/
   ```
3. Génération `docker-compose.yml` multi-services (Prowlarr, Radarr, Sonarr)
4. Configuration volumes partagés (`/home/pi/media`, `/home/pi/downloads`)
5. Déploiement stack
6. Configuration inter-apps (API keys, connexions)
7. Affichage URLs accès + wizard initial

**Commande** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-media-stack/scripts/02-arr-stack-deploy.sh | sudo bash
```

---

## Maintenance

### Jellyfin

**Logs en temps réel** :
```bash
docker compose -f /home/pi/stacks/jellyfin/docker-compose.yml logs -f
```

**Restart service** :
```bash
docker compose -f /home/pi/stacks/jellyfin/docker-compose.yml restart
```

**Scanner bibliothèque manuellement** :
```
Web UI → Dashboard → Libraries
→ Sélectionner bibliothèque (Films, Séries...)
→ Clic "Scan Library"
```

**Mise à jour Jellyfin** :
```bash
cd /home/pi/stacks/jellyfin
docker compose pull
docker compose up -d
```

**Vérifier GPU transcoding** :
```bash
# Logs transcoding en temps réel
docker compose -f /home/pi/stacks/jellyfin/docker-compose.yml logs -f | grep -i vaapi

# Doit afficher :
# [AVHWDeviceContext @ ...] Initialised VAAPI connection: version 1.x
```

**Backup configuration** :
```bash
# Backup dossier config (DB, métadonnées, utilisateurs)
tar -czf jellyfin-backup-$(date +%F).tar.gz /home/pi/stacks/jellyfin/config
```

### *arr Stack

**Logs par service** :
```bash
# Radarr
docker compose -f /home/pi/stacks/arr/docker-compose.yml logs -f radarr

# Sonarr
docker compose -f /home/pi/stacks/arr/docker-compose.yml logs -f sonarr

# Prowlarr
docker compose -f /home/pi/stacks/arr/docker-compose.yml logs -f prowlarr
```

**Restart stack entier** :
```bash
docker compose -f /home/pi/stacks/arr/docker-compose.yml restart
```

**Restart service spécifique** :
```bash
docker compose -f /home/pi/stacks/arr/docker-compose.yml restart radarr
```

**Vérifier espace disque** :
```bash
# Dossiers médias
du -sh /home/pi/media/*

# Dossiers downloads
du -sh /home/pi/downloads/*
```

**Mise à jour *arr stack** :
```bash
cd /home/pi/stacks/arr
docker compose pull
docker compose up -d
```

**Backup configurations** :
```bash
# Backup tous les configs *arr (DB, settings, API keys)
tar -czf arr-backup-$(date +%F).tar.gz \
  /home/pi/stacks/arr/prowlarr-config \
  /home/pi/stacks/arr/radarr-config \
  /home/pi/stacks/arr/sonarr-config
```

---

## Troubleshooting

### Jellyfin : GPU Transcoding ne Fonctionne Pas

**Symptôme** : Transcoding utilise CPU (lent, >50% CPU)

**Diagnostic** :
```bash
# 1. Vérifier périphérique GPU existe
ls -la /dev/dri/renderD128
# Doit afficher : crw-rw---- 1 root video ... /dev/dri/renderD128

# 2. Vérifier groupes utilisateur Pi
groups pi
# Doit contenir : pi adm dialout cdrom sudo audio video plugdev games users input render netdev

# 3. Vérifier container accède GPU
docker exec jellyfin ls -la /dev/dri/
# Doit afficher renderD128
```

**Solution** :
```bash
# Ajouter utilisateur pi aux groupes video + render
sudo usermod -aG video,render pi

# Redémarrer container
docker compose -f /home/pi/stacks/jellyfin/docker-compose.yml restart

# Vérifier logs GPU
docker logs jellyfin 2>&1 | grep -i vaapi
# Doit afficher : "Initialised VAAPI connection"
```

**Vérification Web UI** :
```
Dashboard → Playback → Hardware Acceleration
→ Hardware acceleration: Video Acceleration API (VAAPI)
→ VA API Device: /dev/dri/renderD128
→ Enable hardware decoding: ✅ H264, HEVC
→ Enable hardware encoding: ✅ H264
→ Save
```

### Radarr/Sonarr : Films/Séries ne s'Importent Pas

**Symptôme** : Download terminé mais fichier reste dans `/downloads/`

**Diagnostic** :
```bash
# 1. Vérifier permissions dossiers
ls -la /home/pi/media/movies
ls -la /home/pi/downloads
# Doit être : drwxr-xr-x pi pi

# 2. Vérifier logs Radarr
docker compose -f /home/pi/stacks/arr/docker-compose.yml logs radarr | tail -50
# Chercher erreurs : "Permission denied", "Path not found"
```

**Solution permissions** :
```bash
# Corriger ownership
sudo chown -R pi:pi /home/pi/media
sudo chown -R pi:pi /home/pi/downloads

# Corriger permissions
chmod -R 755 /home/pi/media
chmod -R 755 /home/pi/downloads

# Restart Radarr/Sonarr
docker compose -f /home/pi/stacks/arr/docker-compose.yml restart radarr sonarr
```

**Vérification configuration Radarr** :
```
Settings → Media Management
→ Root Folder: /media/movies (doit être exactement ça)
→ Importing: ✅ Use Hardlinks instead of Copy
→ File Management: ✅ Delete empty folders
```

### Prowlarr : Indexers ne Retournent Aucun Résultat

**Symptôme** : Recherche Radarr/Sonarr = 0 résultats

**Diagnostic** :
```
Prowlarr Web UI
→ Indexers
→ Clic "Test All"
→ Vérifier statuts (vert = OK, rouge = erreur)
```

**Solutions** :

**1. Indexer bloqué (rate limit)** :
```
→ Attendre 1h
→ Ou ajouter indexers supplémentaires (YTS, EZTV, RARBG...)
```

**2. Proxy/VPN bloque indexers** :
```
Settings → General
→ Proxy: Disable (si pas besoin VPN pour indexers)
```

**3. Ajouter indexers publics** :
```
Add Indexer → Templates
→ YTS (films)
→ EZTV (séries)
→ 1337x (général)
→ Save
```

### Jellyfin : Métadonnées Manquantes (Pas de Posters)

**Symptôme** : Films apparaissent sans poster/synopsis

**Causes** :
1. Nommage fichier incorrect
2. TMDB API rate limit
3. Scan non terminé

**Solution nommage** :
```bash
# Format correct :
/media/movies/Inception (2010)/Inception (2010).mkv

# Format incorrect (pas de métadonnées) :
/media/movies/inception.mkv
/media/movies/Inception/inception_1080p.mkv

# Renommer si besoin :
mv /media/movies/inception.mkv "/media/movies/Inception (2010)/Inception (2010).mkv"
```

**Forcer refresh métadonnées** :
```
Bibliothèque Films
→ Clic droit film concerné
→ "Identify"
→ Rechercher manuellement "Inception 2010"
→ Sélectionner bon résultat TMDB
→ OK → Métadonnées téléchargées
```

### Transcoding : Playback Saccadé (Buffering)

**Symptôme** : Lecture se pause toutes les 10 secondes

**Causes** :
1. CPU surchargé (pas de GPU)
2. Disque lent (SD card)
3. Réseau WiFi faible

**Solutions** :

**1. Vérifier GPU actif** (voir section GPU ci-dessus)

**2. Baisser qualité transcoding** :
```
Jellyfin App (mobile/TV)
→ Paramètres → Playback
→ Max Streaming Bitrate: 8 Mbps (au lieu de 20 Mbps)
→ Video Quality: 720p (au lieu de 1080p)
```

**3. Direct Play (pas de transcoding)** :
```
App Settings → Playback
→ Préférer "Direct Play" si client supporte format source
```

**4. Ethernet vs WiFi** :
```bash
# Vérifier bande passante réseau
iperf3 -s # Sur Pi
iperf3 -c pi.local # Sur client

# Si <20 Mbps : Passer en Ethernet ou WiFi 5 GHz
```

---

## Documentation Complète

- **[Guide Installation](docs/INSTALL.md)** - Installation détaillée step-by-step
- **[Guide Débutant](docs/GUIDE-DEBUTANT.md)** - Explications pédagogiques concepts
- **[Common Scripts](../common-scripts/README.md)** - Scripts réutilisables (backup, monitoring)
- **[Phase 2 Traefik](../traefik/README.md)** - Configuration reverse proxy HTTPS
- **[Phase 5 VPN](../vpn-tailscale/README.md)** - Accès distant sécurisé

---

## Liens Utiles

**Projets** :
- **Jellyfin** : https://jellyfin.org/
- **Radarr** : https://radarr.video/
- **Sonarr** : https://sonarr.tv/
- **Prowlarr** : https://prowlarr.com/

**Documentation** :
- **Jellyfin Docs** : https://jellyfin.org/docs/
- **Servarr Wiki** (Radarr/Sonarr) : https://wiki.servarr.com/
- **Raspberry Pi GPU** : https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#videocore-vii

**Community** :
- **Jellyfin Forum** : https://forum.jellyfin.org/
- **r/jellyfin** : https://reddit.com/r/jellyfin
- **r/radarr** : https://reddit.com/r/radarr
- **r/sonarr** : https://reddit.com/r/sonarr

**Apps Clientes** :
- **Jellyfin Apps** : https://jellyfin.org/downloads/clients
- **Android TV** : https://play.google.com/store/apps/details?id=org.jellyfin.androidtv
- **iOS** : https://apps.apple.com/app/jellyfin-mobile/id1480192618

---

<p align="center">
  <strong>🎬 Votre Netflix Personnel sur Raspberry Pi 5 🎬</strong>
</p>

<p align="center">
  <sub>Jellyfin • GPU Transcoding • Apps Natives • 100% Open Source • 0€/mois</sub>
</p>
