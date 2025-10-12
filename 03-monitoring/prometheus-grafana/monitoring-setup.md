# 🚀 Installation Monitoring (Prometheus + Grafana)

> **Installation automatisée d'une stack de monitoring complète et pré-configurée.**

---

## 📋 Prérequis

### Système
*   Raspberry Pi 5.
*   Raspberry Pi OS 64-bit.
*   Docker et Docker Compose installés (via le script `00-preflight-checks.sh`).

### Ressources
*   **RAM** : ~500-800 Mo
*   **Stockage** : ~2 Go (principalement pour les données de Prometheus).
*   **Ports** : 3002 (Grafana), 9090 (Prometheus), 8080 (cAdvisor), 9100 (Node Exporter).

### Dépendances (Optionnel)
*   **Traefik** : Pour un accès HTTPS externe à Grafana et Prometheus.
*   **Supabase** : Pour activer le monitoring avancé de PostgreSQL.

---

## 🚀 Installation

### Option 1 : Installation Rapide (Recommandé)

Une seule commande pour déployer toute la stack :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash
```

**Durée** : ~2-3 minutes

### Option 2 : Installation Manuelle (Avancé)

Pour plus de contrôle, vous pouvez télécharger et exécuter le script manuellement.

```bash
# Télécharger le script
wget https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh
chmod +x 01-monitoring-deploy.sh

# Exécuter avec des options (exemple)
sudo GRAFANA_ADMIN_PASSWORD=MonMotDePasse ./01-monitoring-deploy.sh --verbose
```

---

## 📊 Ce Que Fait le Script

Le script automatise l'ensemble du processus de configuration :

1.  ✅ **Détection de l'environnement** : Vérifie si Traefik et Supabase sont installés pour adapter la configuration.
2.  ✅ **Création de la structure** : Crée le dossier `/opt/stacks/monitoring`.
3.  ✅ **Configuration de Prometheus** : Génère un fichier `prometheus.yml` avec les cibles de scraping (Node Exporter, cAdvisor, et Postgres Exporter si Supabase est présent).
4.  ✅ **Configuration de Grafana** : Prépare les fichiers de provisioning pour créer automatiquement la source de données Prometheus et importer les 3 dashboards pré-configurés.
5.  ✅ **Génération du Docker Compose** : Crée le fichier `docker-compose.yml` avec tous les services nécessaires.
6.  ✅ **Intégration Traefik** : Ajoute les labels Docker appropriés pour l'exposition HTTPS si Traefik est détecté.
7.  ✅ **Déploiement** : Lance la stack avec `docker compose up -d`.
8.  ✅ **Affichage du résumé** : Affiche les URLs d'accès à Grafana et Prometheus.

---

## 🔧 Configuration Post-Installation

### Accès Web

*   **Grafana (Dashboards)** :
    *   Local : `http://<IP_DU_PI>:3002`
    *   Avec Traefik : `https://grafana.mondomaine.com` (ou `/grafana` selon le scénario)
*   **Prometheus (Requêtes)** :
    *   Local : `http://<IP_DU_PI>:9090`
    *   Avec Traefik : `https://prometheus.mondomaine.com` (ou `/prometheus`)

### Credentials

*   **Utilisateur Grafana** : `admin`
*   **Mot de passe Grafana** : `admin` (par défaut). Il vous sera demandé de le changer lors de votre première connexion. C'est fortement recommandé.

---

## 🔗 Intégration Traefik

Le script gère automatiquement l'intégration avec les 3 scénarios de Traefik :

*   **Scénario DuckDNS** : Grafana sera accessible sur `.../grafana`, Prometheus sur `.../prometheus`.
*   **Scénario Cloudflare** : Grafana sera accessible sur `grafana.mondomaine.com`, Prometheus sur `prometheus.mondomaine.com`.
*   **Scénario VPN** : Pas d'intégration Traefik, l'accès se fait via l'IP locale et le port.

---

## ✅ Validation Installation

### Tests Automatiques

Le script se termine par un message de succès et les URLs d'accès. C'est le premier signe que tout va bien.

### Tests Manuels

**Test 1** : Vérifier que tous les conteneurs sont en cours d'exécution.

```bash
cd /opt/stacks/monitoring
docker compose ps
```

**Résultat attendu** : Les conteneurs `prometheus`, `grafana`, `node-exporter`, `cadvisor` (et `postgres-exporter` si applicable) doivent tous être à l'état `Up (healthy)`.

**Test 2** : Vérifier les cibles de Prometheus.

1.  Ouvrez l'interface de Prometheus (`http://<IP_DU_PI>:9090`).
2.  Allez dans `Status` > `Targets`.

**Résultat attendu** : Toutes les cibles listées doivent être à l'état `UP` (en vert).

**Test 3** : Vérifier les dashboards Grafana.

1.  Connectez-vous à Grafana.
2.  Allez dans `Dashboards`.

**Résultat attendu** : Les 3 dashboards pré-configurés doivent être présents et afficher des données.

---

## 🛠️ Maintenance

### Backup

Il est recommandé de sauvegarder la configuration, mais pas les données de séries temporelles qui sont volumineuses et non critiques.

```bash
# Créer une archive de la configuration
sudo tar -czf ~/monitoring_backup_config.tar.gz -C /opt/stacks/monitoring .
```

### Mise à jour

Pour mettre à jour les images des conteneurs vers leurs dernières versions :

```bash
cd /opt/stacks/monitoring
docker compose pull
docker compose up -d
```

---

## 🐛 Troubleshooting

### Problème 1 : Dashboards vides ou "N/A"
*   **Symptôme** : Les panneaux de Grafana n'affichent aucune donnée.
*   **Solution** : C'est presque toujours un problème de communication avec Prometheus. Suivez les étapes du **Test 2** de la section "Validation" pour vous assurer que les cibles de Prometheus sont bien `UP`.

### Problème 2 : Le dashboard Supabase est vide
*   **Symptôme** : Seul le dashboard PostgreSQL est vide.
*   **Solution** : La cible `postgres-exporter` est probablement `DOWN`. Vérifiez les logs du conteneur `postgres-exporter` (`docker compose logs postgres-exporter`). L'erreur la plus fréquente est un problème de connexion à la base de données (mot de passe, nom d'hôte).

### Problème 3 : Grafana inaccessible après le premier login
*   **Symptôme** : Vous avez changé le mot de passe admin et maintenant vous ne pouvez plus vous connecter.
*   **Solution** : Vous pouvez réinitialiser le mot de passe admin via la ligne de commande :
    ```bash
    docker exec -it grafana grafana-cli admin reset-admin-password 'NouveauMotDePasse'
    ```

---

## 🗑️ Désinstallation

Pour supprimer complètement la stack de monitoring :

```bash
cd /opt/stacks/monitoring
docker-compose down -v
cd /opt/stacks
sudo rm -rf monitoring
```

**⚠️ Attention** : Cette commande supprime tout l'historique des métriques.

---

## 📊 Consommation Ressources

*   **RAM utilisée** : ~500-800 Mo. Prometheus peut être gourmand en fonction de la quantité de métriques et de la rétention.
*   **Stockage utilisé** : ~2 Go, qui augmentera avec le temps en fonction de la durée de rétention des données.
*   **Conteneurs actifs** : 4 ou 5.

---

## 🔗 Liens Utiles

*   [Guide Débutant](monitoring-guide.md)
*   [README de la catégorie Monitoring](../README.md)
*   [Documentation Officielle de Prometheus](https://prometheus.io/docs/)
*   [Documentation Officielle de Grafana](https://grafana.com/docs/)
