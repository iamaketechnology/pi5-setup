# ⚙️ Installation - Jellyfin & *Arr Stack

> **Objectif** : Mettre en place une suite multimédia automatisée avec Jellyfin, Radarr, Sonarr, Prowlarr et qBittorrent.

---

## 📋 Prérequis

- **Docker et Docker Compose** installés.
- **Espace de stockage conséquent** pour vos médias.
- **(Optionnel mais recommandé)** Un VPN pour le client de téléchargement.

---

## 📂 Structure des Dossiers

Une structure de dossiers bien pensée est la clé du succès. Voici un exemple recommandé :

```
/mnt/storage/
├── data/                # Pour les configurations des conteneurs
│   ├── jellyfin/
│   ├── prowlarr/
│   ├── qbittorrent/
│   ├── radarr/
│   └── sonarr/
├── media/               # Votre bibliothèque multimédia
│   ├── movies/
│   ├── music/
│   └── tv/
└── torrents/            # Pour les téléchargements en cours et terminés
    ├── completed/
    └── incomplete/
```

**IMPORTANT** : Les *Arrs et le client de téléchargement doivent voir les dossiers `media` et `torrents` de la même manière. Par exemple, si qBittorrent télécharge dans `/downloads`, Radarr/Sonarr doivent aussi voir ce dossier comme `/downloads` pour pouvoir déplacer les fichiers.

---

## 🚀 Docker Compose

Voici un exemple de fichier `docker-compose.yml` pour lier tous ces services. Adaptez les volumes à votre structure.

```yaml
# [Contenu à compléter : stack docker-compose complète pour Jellyfin/*Arr]
version: "3.8"

services:
  jellyfin:
    image: jellyfin/jellyfin
    container_name: jellyfin
    ports:
      - "8096:8096"
    volumes:
      - ./data/jellyfin:/config
      - /mnt/storage/media:/media # Accès à toute la bibliothèque
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    ports:
      - "8989:8989"
    volumes:
      - ./data/sonarr:/config
      - /mnt/storage:/mnt/storage # Accès à la fois aux téléchargements et à la bibliothèque
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    ports:
      - "7878:7878"
    volumes:
      - ./data/radarr:/config
      - /mnt/storage:/mnt/storage # Idem que Sonarr
    restart: unless-stopped

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    ports:
      - "9696:9696"
    volumes:
      - ./data/prowlarr:/config
    restart: unless-stopped

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    network_mode: "service:vpn" # IMPORTANT: pour passer par le VPN
    volumes:
      - ./data/qbittorrent:/config
      - /mnt/storage/torrents:/downloads # Dossier de téléchargement
    restart: unless-stopped

  vpn:
    image: qmcgaw/gluetun
    container_name: vpn
    cap_add:
      - NET_ADMIN
    environment:
      - VPN_SERVICE_PROVIDER=nordvpn
      - VPN_TYPE=openvpn
      - OPENVPN_USER=...
      - OPENVPN_PASSWORD=...
    ports:
      - "8888:8888" # Port de l'UI web de qBittorrent
```

---

## ⚙️ Configuration Post-Installation

L'ordre est important.

### 1. **Prowlarr** (http://<IP>:9696)
- Allez dans `Settings` > `General` et configurez une URL de base si vous utilisez un reverse proxy.
- Allez dans `Indexers`, cliquez sur `Add Indexer` et ajoutez vos sites de torrents/usenet.

### 2. **qBittorrent** (http://<IP>:8888)
- Changez le mot de passe par défaut.
- Dans `Tools` > `Options` > `Downloads`, configurez les chemins pour les fichiers en cours et terminés pour qu'ils correspondent aux volumes Docker (ex: `/downloads/incomplete` et `/downloads/completed`).
- Activez l'API web.

### 3. **Sonarr & Radarr** (http://<IP>:8989 et http://<IP>:7878)
- **Connexion à Prowlarr** : Allez dans `Settings` > `Apps`, cliquez sur `+` et ajoutez Sonarr/Radarr. Prowlarr synchronisera les indexers automatiquement.
- **Connexion au client de téléchargement** : Dans `Settings` > `Download Clients`, ajoutez qBittorrent en utilisant son nom de conteneur et son port (ex: `http://qbittorrent:8080`).
- **Configuration des chemins** : Dans `Settings` > `Media Management`, activez `Rename Episodes/Movies` et configurez le format de nommage. C'est ici que la structure de dossiers partagée est cruciale.
- **Remote Path Mappings** : Si les chemins ne sont pas identiques entre le client de téléchargement et l'Arr, vous devez configurer un "Remote Path Mapping" pour que l'Arr sache où trouver les fichiers téléchargés.

### 4. **Jellyfin** (http://<IP>:8096)
- Suivez l'assistant de configuration initial.
- Allez dans le `Dashboard` > `Libraries`.
- Ajoutez une nouvelle bibliothèque pour chaque type de média (Movies, TV Shows).
- Pour le `Folder`, pointez vers le dossier correspondant dans votre bibliothèque (ex: `/media/tv` pour les séries).

---

## ✅ Vérification

1. Ajoutez une série dans Sonarr.
2. Vérifiez qu'elle est envoyée à qBittorrent et que le téléchargement commence.
3. Une fois terminé, vérifiez que Sonarr a bien renommé et déplacé le fichier dans votre bibliothèque.
4. Vérifiez que Jellyfin a bien scanné le nouveau fichier et l'affiche dans l'interface.

[Contenu à compléter avec des problèmes courants et leurs solutions]
