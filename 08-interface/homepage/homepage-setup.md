# 🚀 Installation Homepage

> **Installation automatisée de votre portail d'accueil personnel.**

---

## 📋 Prérequis

### Système
*   Raspberry Pi 5.
*   Docker et Docker Compose installés.
*   Traefik installé et configuré (recommandé pour l'accès HTTPS).

### Ressources
*   **RAM** : ~50-100 Mo
*   **Stockage** : ~150 Mo
*   **Ports** : 3000 (si non exposé via Traefik).

---

## 🚀 Installation

### Installation Rapide (Recommandé)

Une seule commande pour déployer un dashboard pré-configuré et intelligent :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash
```

**Durée** : ~2-3 minutes

---

## 📊 Ce Que Fait le Script

1.  ✅ **Détection de l'environnement** : Le script détecte automatiquement votre configuration Traefik (DuckDNS, Cloudflare, VPN) pour configurer l'URL d'accès.
2.  ✅ **Détection des services** : Il scanne votre système pour trouver les services déjà installés (Supabase, Portainer, Grafana, etc.).
3.  ✅ **Génération de la configuration** : Il crée un ensemble de fichiers de configuration YAML dans `/opt/stacks/homepage/config/` avec les services qu'il a trouvés.
4.  ✅ **Déploiement** : Il lance le conteneur Homepage via Docker Compose.
5.  ✅ **Affichage du résumé** : Il vous donne l'URL finale pour accéder à votre nouveau dashboard.

---

## 🔧 Configuration Post-Installation

Votre dashboard est entièrement configurable via des fichiers YAML simples.

**Emplacement des fichiers** : `/opt/stacks/homepage/config/`

*   `services.yaml` : La liste des groupes et des services affichés.
*   `widgets.yaml` : Les widgets à afficher (stats système, météo, etc.).
*   `settings.yaml` : Les paramètres généraux comme le thème et les couleurs.
*   `bookmarks.yaml` : Une liste de vos liens favoris.

Pour modifier votre dashboard, éditez ces fichiers (par exemple, avec `nano`), et les changements apparaîtront automatiquement sur la page en quelques secondes (pas besoin de redémarrer).

### Exemple : Ajouter un service

Éditez `services.yaml` et ajoutez :

```yaml
- Mon Groupe:
    - Mon Service:
        href: http://192.168.1.101
        description: Un service que j'aime bien
        icon: mdi-rocket
```

### Intégration d'API (Widgets)

Pour activer les widgets qui affichent des informations en temps réel (comme les stats de Sonarr, Radarr, ou Pi-hole), vous devrez ajouter les informations de connexion (URL et clé d'API) dans la section `widget` de votre service dans `services.yaml`.

```yaml
- Media:
    - Sonarr:
        href: http://sonarr.mondomaine.com
        widget:
          type: sonarr
          url: http://sonarr:8989 # URL interne au réseau Docker
          key: VOTRE_CLE_API_SONARR
```

### Thèmes Disponibles

Changez l'apparence de votre dashboard en modifiant `settings.yaml` :

```yaml
theme: dark # ou light
color: slate # ou blue, green, red, etc.
```

---

## ✅ Validation Installation

**Test 1** : Vérifier que le conteneur est en cours d'exécution.

```bash
docker ps --filter "name=homepage"
```

**Test 2** : Accéder à l'URL fournie par le script à la fin de l'installation. Le dashboard doit s'afficher avec les services qu'il a détectés.

---

## 🛠️ Maintenance

### Mettre à jour Homepage

```bash
cd /opt/stacks/homepage
docker compose pull
docker compose up -d
```

### Sauvegarder la configuration

```bash
sudo tar -czf ~/homepage_config_backup.tar.gz -C /opt/stacks/homepage/config .
```

---

## 🗑️ Désinstallation

```bash
cd /opt/stacks/homepage
docker-compose down -v
cd /opt/stacks
sudo rm -rf homepage
```

---

## 🔗 Liens Utiles

*   [Guide Débutant](homepage-guide.md)
*   [Documentation Officielle de Homepage](https://gethomepage.dev/)
*   [Liste de toutes les intégrations de widgets](https://gethomepage.dev/latest/widgets/)