# ⚙️ Installation - File Browser & Nextcloud

> **Objectif** : Déployer des services de gestion et de synchronisation de fichiers.

---

## 📋 Prérequis

- **Docker et Docker Compose** installés.
- **Un dossier sur votre serveur** pour stocker les fichiers que vous souhaitez rendre accessibles.
- **(Pour Nextcloud)** Une base de données (PostgreSQL ou MariaDB est recommandé).

---

## 🚀 Installation de File Browser (Simple et Léger)

### 1. Docker Compose

Voici un exemple de service `docker-compose.yml` pour File Browser :

```yaml
# [Contenu à compléter : service docker-compose pour File Browser]
version: '3.7'

services:
  filebrowser:
    image: filebrowser/filebrowser
    container_name: filebrowser
    user: "${PUID}:${PGID}" # Assurez-vous que ces variables sont définies dans votre .env
    ports:
      - "8081:80"
    volumes:
      - /path/to/your/files:/srv # Le dossier que vous voulez explorer
      - ./filebrowser/database.db:/database.db
      - ./filebrowser/settings.json:/config.json
    restart: unless-stopped
```

### 2. Premier Lancement

- Lors du premier lancement, File Browser utilisera les identifiants par défaut `admin`/`admin`.
- Connectez-vous et changez immédiatement le mot de passe dans les paramètres.

---

## 🚀 Installation de Nextcloud (Solution Complète)

L'installation de Nextcloud est plus complexe car elle implique une base de données et plusieurs conteneurs.

### 1. Docker Compose (Exemple avec PostgreSQL)

```yaml
# [Contenu à compléter : stack docker-compose complète pour Nextcloud]
version: '3'

services:
  db:
    image: postgres
    container_name: nextcloud_db
    restart: always
    volumes:
      - ./db:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
      - POSTGRES_PASSWORD=VOTRE_MOT_DE_PASSE_DB

  app:
    image: nextcloud
    container_name: nextcloud_app
    restart: always
    ports:
      - "8080:80"
    links:
      - db
    volumes:
      - ./app/data:/var/www/html
    environment:
      - POSTGRES_HOST=db
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=nextcloud
      - POSTGRES_PASSWORD=VOTRE_MOT_DE_PASSE_DB
      - NEXTCLOUD_ADMIN_USER=admin
      - NEXTCLOUD_ADMIN_PASSWORD=VOTRE_MOT_DE_PASSE_ADMIN
```

### 2. Configuration Initiale

1. **Lancez la stack** : `docker-compose up -d`.
2. **Attendez quelques minutes** que Nextcloud et la base de données s'initialisent.
3. **Accédez à l'interface web** via l'adresse IP de votre serveur et le port configuré (ex: `http://<IP_DU_PI>:8080`).
4. **Créez le compte administrateur** et configurez la connexion à la base de données en utilisant les informations du `docker-compose.yml`.

---

## ✅ Vérification

- **File Browser** : Accédez à l'URL et connectez-vous. Vous devriez voir les fichiers du volume que vous avez monté.
- **Nextcloud** : Connectez-vous avec le compte administrateur. L'interface principale (le "Dashboard") doit s'afficher sans erreur.

---

## 💡 Optimisations Recommandées pour Nextcloud

- **Utiliser Redis pour le cache mémoire** : Améliore considérablement les performances de l'interface.
- **Configurer un serveur STUN/TURN** : Nécessaire pour que Nextcloud Talk (visioconférence) fonctionne correctement derrière un NAT.
- **Passer la configuration en HTTPS** avec un reverse proxy comme Traefik.

[Contenu à compléter avec des instructions plus détaillées sur ces optimisations]
