# 🚀 Installation Jellyfin & *Arr Stack

> **Installation automatisée de votre suite multimédia complète.**

---

## 📋 Prérequis

### Système
*   Raspberry Pi 5 (4 Go de RAM minimum, 8 Go recommandé).
*   Docker et Docker Compose installés.
*   Un disque de stockage externe pour vos médias est fortement recommandé.

### Ressources
*   **RAM** : ~1 Go (pour l'ensemble de la stack).
*   **Stockage** : ~2 Go pour les applications, plus l'espace pour vos médias.
*   **Ports** : 8096 (Jellyfin), 8989 (Sonarr), 7878 (Radarr), 9696 (Prowlarr).

---

## 🚀 Installation

L'installation se fait en deux étapes : d'abord le serveur de streaming (Jellyfin), puis la suite d'automatisation (*Arr).

### Étape 1 : Déployer Jellyfin

Ce script installe Jellyfin et configure l'accélération matérielle pour le transcodage.

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/01-jellyfin-deploy.sh | sudo bash
```

### Étape 2 : Déployer la Stack *Arr

Ce script installe Sonarr, Radarr et Prowlarr.

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/02-arr-stack-deploy.sh | sudo bash
```

---

## 📊 Ce Que Fait le Script

*   **`01-jellyfin-deploy.sh`** :
    1.  Crée les dossiers pour votre bibliothèque multimédia (`/media/movies`, `/media/tv`, etc.).
    2.  Génère un `docker-compose.yml` pour Jellyfin, en mappant le périphérique GPU du Pi 5 pour l'accélération matérielle.
    3.  Démarre le conteneur Jellyfin.
*   **`02-arr-stack-deploy.sh`** :
    1.  Crée les dossiers pour les téléchargements.
    2.  Génère un `docker-compose.yml` pour Sonarr, Radarr et Prowlarr.
    3.  Démarre les conteneurs.

---

## 🔧 Configuration Post-Installation

### Jellyfin

1.  Accédez à `http://<IP_DU_PI>:8096`.
2.  Suivez l'assistant de configuration pour créer votre compte administrateur.
3.  Ajoutez vos bibliothèques en pointant vers les dossiers `/media/movies`, `/media/tv`, etc.

### Stack *Arr

1.  **Prowlarr** (`http://<IP_DU_PI>:9696`) : Ajoutez vos "indexers" (les sites où chercher le contenu).
2.  **Sonarr/Radarr** (`http://<IP_DU_PI>:8989` et `7878`) : 
    *   Connectez-les à Prowlarr (Settings > Apps).
    *   Connectez-les à votre client de téléchargement.
    *   Configurez les "Root Folders" pour qu'ils pointent vers `/media/tv` et `/media/movies`.

---

## ✅ Validation Installation

**Test 1** : Vérifier que tous les conteneurs sont en cours d'exécution.

```bash
docker ps
```

**Résultat attendu** : Les conteneurs `jellyfin`, `sonarr`, `radarr`, `prowlarr` doivent être listés et `Up`.

**Test 2** : Vérifier l'accès aux interfaces web de chaque service.

**Test 3** : Ajouter un film dans Radarr et vérifier qu'il est bien envoyé au client de téléchargement, puis qu'il apparaît dans Jellyfin une fois terminé.

---

## 🛠️ Maintenance

### Mettre à jour la stack

```bash
# Pour Jellyfin
cd /opt/stacks/jellyfin
docker compose pull && docker compose up -d

# Pour la stack *Arr
cd /opt/stacks/jellyfin-arr
docker compose pull && docker compose up -d
```

---

## 🗑️ Désinstallation

```bash
cd /opt/stacks/jellyfin && docker-compose down -v
cd /opt/stacks/jellyfin-arr && docker-compose down -v
sudo rm -rf /opt/stacks/jellyfin /opt/stacks/jellyfin-arr
```

---

## 🔗 Liens Utiles

*   [Guide Débutant](jellyfin-guide.md)
*   [TRaSH Guides](https://trash-guides.info/) : La référence pour configurer la stack *Arr.
