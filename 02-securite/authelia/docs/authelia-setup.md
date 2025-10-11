# ⚙️ Installation - Authelia

> **Objectif** : Déployer Authelia pour sécuriser les services web avec une authentification centralisée.

---

## 📋 Prérequis

- **Reverse Proxy** : Traefik (recommandé), Nginx, ou autre. Ce guide suppose l'utilisation de Traefik.
- **Services à protéger** : Au moins une application web (ex: Portainer, Grafana) déjà configurée pour être accessible via le reverse proxy.
- **Fichiers de configuration** : Accès pour modifier la configuration de votre reverse proxy et pour créer les fichiers de configuration d'Authelia.

---

## 🚀 Étapes d'Installation

### 1. Création des Fichiers de Configuration

Créez un dossier pour la configuration d'Authelia et ajoutez les fichiers suivants :

- `configuration.yml` (configuration principale)
- `users_database.yml` (base de données des utilisateurs)

```bash
# [Contenu à compléter : commandes pour créer la structure de dossiers et les fichiers vides]
mkdir -p /path/to/authelia/config
touch /path/to/authelia/config/configuration.yml
touch /path/to/authelia/config/users_database.yml
```

### 2. Configuration d'Authelia (`configuration.yml`)

Remplissez le fichier `configuration.yml` avec les informations de base.

```yaml
# [Contenu à compléter : exemple de configuration.yml de base]
# Exemple :
theme: dark

server:
  host: 0.0.0.0
  port: 9091

session:
  domain: "votre-domaine.com" # Important !
  secret: "un_secret_tres_long_et_aleatoire"

authentication_backend:
  file:
    path: /config/users_database.yml
```

### 3. Création d'un Utilisateur (`users_database.yml`)

Générez un mot de passe hashé et ajoutez un utilisateur.

```bash
# [Contenu à compléter : commande pour hasher un mot de passe]
# Exemple :
# docker run --rm authelia/authelia:latest authelia hash-password 'mon_mot_de_passe'
```

Ajoutez le résultat dans `users_database.yml`.

```yaml
# [Contenu à compléter : exemple de users_database.yml]
users:
  admin:
    displayname: "Admin"
    password: "$argon2id$v=19$m=65536,t=3,p=4$LONG_HASH_GENERE"
    email: admin@votre-domaine.com
    groups:
      - admins
```

### 4. Déploiement avec Docker Compose

Ajoutez Authelia à votre stack Docker.

```yaml
# [Contenu à compléter : service docker-compose pour Authelia]
# Exemple :
version: '3.8'

services:
  authelia:
    image: authelia/authelia:latest
    container_name: authelia
    volumes:
      - /path/to/authelia/config:/config
    networks:
      - traefik_proxy # Votre réseau de reverse proxy
    restart: unless-stopped
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.authelia.rule=Host(`auth.votre-domaine.com`)"
      - "traefik.http.routers.authelia.service=authelia"
      - "traefik.http.services.authelia.loadbalancer.server.port=9091"
```

### 5. Intégration avec Traefik

Configurez Traefik pour utiliser Authelia comme middleware.

```yaml
# [Contenu à compléter : configuration du middleware dans traefik.yml ou via labels Docker]
# Exemple (via labels sur l'application à protéger) :
# labels:
#   - "traefik.http.routers.mon-app.middlewares=authelia@docker"
```

---

## ✅ Vérification

1. **Démarrez la stack** : `docker-compose up -d`
2. **Accédez à votre application protégée** (ex: `http://app.votre-domaine.com`).
3. **Redirection** : Vous devriez être redirigé vers `auth.votre-domaine.com`.
4. **Connexion** : Connectez-vous avec l'utilisateur créé.
5. **Accès** : Après connexion, vous devriez accéder à votre application.

---

## 🆘 Troubleshooting

- **Erreur "Too many redirects"** : Vérifiez la configuration du `domain` de session dans `configuration.yml`. Il doit être le domaine parent commun à Authelia et à vos applications.
- **Mot de passe non reconnu** : Assurez-vous que le hash du mot de passe a été correctement copié dans `users_database.yml`.

[Contenu à compléter avec d'autres problèmes courants]
