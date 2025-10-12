# 🚀 Installation Supabase

> **Installation automatisée via scripts idempotents**

---

## 📋 Prérequis

### Système
*   Raspberry Pi 5 (8 Go de RAM minimum, 16 Go recommandé).
*   Raspberry Pi OS 64-bit (Bookworm).
*   Docker et Docker Compose (installés automatiquement par le script de prérequis).
*   Connexion Internet filaire (Ethernet) recommandée.

### Ressources
*   **RAM** : ~4-6 Go
*   **Stockage** : ~10 Go pour les images Docker et les données initiales.
*   **Ports** : 8000 (API), 3000 (Studio), 5432 (PostgreSQL), et une plage pour les autres services.

### Dépendances
*   Le script d'installation des prérequis (`01-prerequisites-setup.sh`) doit être exécuté avant le déploiement de Supabase.

---

## 🚀 Installation

L'installation est divisée en deux étapes pour assurer une configuration correcte du système avant de déployer la stack.

### Étape 1 : Prérequis et Infrastructure (Si pas déjà fait)

Ce script prépare votre système, installe Docker et configure la sécurité de base. **Ne l'exécutez qu'une seule fois pour l'ensemble du projet pi5-setup.**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/00-preflight-checks.sh | sudo bash
```

**Ce que fait le script :**
*   Mise à jour du système.
*   Installation de Docker, Docker Compose, et autres dépendances.
*   Configuration du kernel pour la compatibilité avec PostgreSQL (`pagesize=4k`).
*   Déploiement de Portainer pour la gestion des conteneurs.

**⚠️ Un redémarrage est obligatoire après cette étape.**

```bash
sudo reboot
```

### Étape 2 : Déploiement de Supabase (Installation Rapide)

Après le redémarrage, lancez cette commande pour déployer la stack Supabase :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/01-supabase-deploy.sh | sudo bash
```

**Durée** : ~10-15 minutes

Le script est interactif et vous proposera plusieurs scénarios d'installation (Installation vierge, Migration, Multi-applications).

---

## 📊 Ce Que Fait le Script

Le script de déploiement automatise tout le processus :

1.  ✅ **Validation des prérequis** : Vérifie que Docker est en cours d'exécution et que la taille de page du kernel est correcte (4096).
2.  ✅ **Création de la structure** : Crée le dossier `/opt/stacks/supabase` pour héberger la configuration.
3.  ✅ **Génération de la configuration** : Génère un fichier `.env` avec des mots de passe et des secrets forts et uniques.
4.  ✅ **Déploiement Docker Compose** : Télécharge les images ARM64 compatibles et lance les 9+ services Supabase.
5.  ✅ **Configuration post-installation** : Initialise la base de données et applique les schémas nécessaires.
6.  ✅ **Tests de santé** : Attend que tous les services soient en état "healthy".
7.  ✅ **Affichage du résumé** : Affiche les URLs, les clés d'API et les identifiants à la fin de l'installation.

**Le script est idempotent** : vous pouvez l'exécuter plusieurs fois sans risque de casser votre installation. Il détectera une installation existante et proposera de la mettre à jour ou de la reconfigurer.

---

## 🔧 Configuration Post-Installation

### Accès Web
*   **Supabase Studio (Interface de gestion)** : `http://<IP_DU_PI>:3000`
*   **API Gateway** : `http://<IP_DU_PI>:8000`

Pour trouver l'adresse IP de votre Pi, utilisez la commande `hostname -I`.

### Credentials

Les informations critiques sont affichées à la fin de l'installation et sauvegardées dans `/opt/stacks/supabase/.env`. Les plus importantes sont :

*   `POSTGRES_PASSWORD` : Mot de passe de la base de données.
*   `JWT_SECRET` : Secret pour signer les tokens d'authentification.
*   `ANON_KEY` : Clé d'API publique à utiliser dans votre application frontend.
*   `SERVICE_ROLE_KEY` : Clé d'API secrète à utiliser côté serveur (ne jamais l'exposer !).

### Premier Login

1.  Ouvrez `http://<IP_DU_PI>:3000` dans votre navigateur.
2.  Utilisez l'email `admin@supabase.local` et le mot de passe `supabase-password` (ou ceux que vous avez configurés) pour vous connecter.

---

## 🔗 Intégration Traefik (Optionnel)

Si Traefik est détecté sur votre système, le script de déploiement de Supabase proposera automatiquement de créer les fichiers de configuration pour exposer Supabase de manière sécurisée via HTTPS.

*   **API** : `https://supabase.votredomaine.com`
*   **Studio** : `https://studio.supabase.votredomaine.com`

Le script s'occupe de générer les labels Docker et les fichiers de configuration dynamiques pour Traefik. Aucune action manuelle n'est requise.

---

## ✅ Validation Installation

### Tests Automatiques

À la fin, le script affiche un résumé. Si vous voyez le message `✅ Supabase deployed successfully`, c'est que tout s'est bien passé.

### Tests Manuels

**Test 1** : Vérifier l'état des conteneurs

```bash
cd /opt/stacks/supabase
docker compose ps
```

**Résultat attendu** : Tous les services doivent avoir le statut `Up (healthy)`.

**Test 2** : Accéder à l'API

```bash
curl http://localhost:8000/rest/v1/
```

**Résultat attendu** : Vous devriez recevoir une réponse JSON avec la liste des tables (qui sera vide au début).

---

## 🛠️ Maintenance

Les scripts de maintenance sont des wrappers autour des `common-scripts` et sont situés dans `/opt/stacks/supabase/scripts/maintenance/`.

### Backup
```bash
sudo bash /opt/stacks/supabase/scripts/maintenance/supabase-backup.sh
```

### Mise à jour
```bash
sudo bash /opt/stacks/supabase/scripts/maintenance/supabase-update.sh
```

### Logs
```bash
sudo bash /opt/stacks/supabase/scripts/maintenance/supabase-logs.sh
```

### Healthcheck
```bash
sudo bash /opt/stacks/supabase/scripts/maintenance/supabase-healthcheck.sh
```

---

## 🐛 Troubleshooting

### Problème 1 : Un service reste "unhealthy"
*   **Symptôme** : `docker compose ps` montre un ou plusieurs services qui ne sont pas "healthy".
*   **Solution** : Regardez les logs du service en question pour identifier l'erreur.
    ```bash
    cd /opt/stacks/supabase
    docker compose logs -f <nom-du-service>
    ```
    Souvent, un simple redémarrage de la stack peut résoudre des problèmes de dépendances au démarrage : `docker compose restart`.

### Problème 2 : Erreur "Page size" au démarrage de PostgreSQL
*   **Symptôme** : Le conteneur `db` (PostgreSQL) ne démarre pas et les logs mentionnent une erreur de taille de page.
*   **Solution** : Cela signifie que l'étape 1 (prérequis) n'a pas été effectuée correctement. Assurez-vous d'avoir redémarré votre Pi après avoir exécuté `00-preflight-checks.sh`. Vérifiez la taille de page avec `getconf PAGESIZE`. Elle doit être `4096`.

### Problème 3 : Erreur 502 Bad Gateway via Traefik
*   **Symptôme** : Vous ne pouvez pas accéder à Supabase via son nom de domaine, mais l'accès par IP fonctionne.
*   **Solution** : Vérifiez les logs de Traefik (`docker logs traefik`). L'erreur la plus courante est que Traefik et Supabase ne sont pas dans le même réseau Docker. Assurez-vous que le réseau `traefik-network` est bien assigné aux conteneurs Supabase dans le fichier `docker-compose.yml`.

---

## 🗑️ Désinstallation

Pour supprimer complètement la stack Supabase et toutes ses données :

```bash
cd /opt/stacks/supabase
docker-compose down -v
cd /opt/stacks
sudo rm -rf supabase
```

**⚠️ Attention** : Cette action est irréversible et supprimera toutes vos données Supabase (base de données, fichiers stockés, etc.).

---

## 📊 Consommation Ressources

**Après installation** :
*   **RAM utilisée** : ~4-6 Go
*   **Stockage utilisé** : ~10 Go
*   **Conteneurs actifs** : 9+

---

## 🔗 Liens Utiles

*   [Guide Débutant](supabase-guide.md)
*   [README de la catégorie Infrastructure](../README.md)
*   [Documentation Officielle de Supabase](https://supabase.com/docs)
