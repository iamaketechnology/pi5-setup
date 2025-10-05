# 📦 Installation Pi5-Monitoring-Stack

> **Guide détaillé d'installation du stack Prometheus + Grafana pour Raspberry Pi 5**

---

## 📋 Table des Matières

- [Prérequis](#-prérequis)
- [Installation Rapide](#-installation-rapide)
- [Installation Détaillée](#-installation-détaillée)
- [Vérification Post-Installation](#-vérification-post-installation)
- [Configuration Initiale Grafana](#-configuration-initiale-grafana)
- [Résolution de Problèmes](#-résolution-de-problèmes)

---

## ✅ Prérequis

### Matériel

- **Raspberry Pi 5** (8 GB recommandé, 4 GB minimum)
- **Carte SD** : 32 GB minimum (64 GB recommandé)
- **Alimentation** : Officielle 27W USB-C
- **(Optionnel)** Ventilateur actif si monitoring intensif

### Logiciels

| Composant | Version | Installation |
|-----------|---------|--------------|
| **Raspberry Pi OS** | 64-bit (Bookworm) | [Raspberry Pi Imager](https://www.raspberrypi.com/software/) |
| **Docker** | 20.10+ | Via [01-prerequisites-setup.sh](../common-scripts/01-prerequisites-setup.sh) |
| **Docker Compose** | 2.0+ | Inclus avec Docker |

### Stacks Optionnels (Auto-Détectés)

| Stack | Requis ? | Bénéfice si Installé |
|-------|----------|----------------------|
| **Traefik** | Non | Accès HTTPS externe (duckdns/cloudflare/vpn) |
| **Supabase** | Non | Monitoring PostgreSQL avec postgres_exporter |
| **Homepage** | Non | Lien dashboard Homepage → Grafana |

---

## ⚡ Installation Rapide

### Option 1 : Curl One-Liner (Recommandé)

```bash
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/pi5-monitoring-stack/scripts/01-monitoring-deploy.sh | sudo bash
```

**Durée** : ~2-3 minutes

**Ce qui est installé** :
- ✅ Prometheus (port 9090)
- ✅ Grafana (port 3002)
- ✅ Node Exporter (port 9100)
- ✅ cAdvisor (port 8080)
- ✅ postgres_exporter (si Supabase détecté)
- ✅ 3 dashboards pré-configurés
- ✅ Intégration Traefik (si installé)

### Option 2 : Télécharger + Exécuter

```bash
# Télécharger le script
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/pi5-monitoring-stack/scripts/01-monitoring-deploy.sh -o monitoring-deploy.sh

# Rendre exécutable
chmod +x monitoring-deploy.sh

# Exécuter
sudo ./monitoring-deploy.sh --yes --verbose
```

---

## 🔧 Installation Détaillée

### Étape 1 : Préparer l'Environnement

#### 1.1 Installer Docker (si pas déjà fait)

```bash
# Vérifier si Docker est installé
docker --version

# Si absent, installer via prerequisites
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/common-scripts/01-prerequisites-setup.sh | sudo bash
sudo reboot
```

**Après reboot** :

```bash
# Vérifier Docker
docker --version
# → Docker version 24.0.7

# Vérifier Docker Compose
docker compose version
# → Docker Compose version v2.23.0
```

#### 1.2 Vérifier Stacks Existants (Optionnel)

```bash
# Vérifier Traefik
ls -la ~/stacks/traefik/
# Si présent → Monitoring s'intégrera automatiquement

# Vérifier Supabase
ls -la ~/stacks/supabase/
# Si présent → postgres_exporter sera activé

# Vérifier Homepage
ls -la ~/stacks/homepage/
# Si présent → Lien sera ajouté automatiquement
```

### Étape 2 : Télécharger le Script

```bash
# Créer répertoire temporaire
mkdir -p ~/pi5-install
cd ~/pi5-install

# Télécharger script
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/pi5-monitoring-stack/scripts/01-monitoring-deploy.sh -o monitoring-deploy.sh

# Vérifier téléchargement
ls -lh monitoring-deploy.sh
# → -rw-r--r-- 1 pi pi 35K monitoring-deploy.sh

# Rendre exécutable
chmod +x monitoring-deploy.sh
```

### Étape 3 : Dry-Run (Simulation)

**Recommandé pour première installation** :

```bash
sudo ./monitoring-deploy.sh --dry-run --verbose
```

**Ce que fait le dry-run** :
- ✅ Affiche ce qui SERAIT fait (sans modifier le système)
- ✅ Détecte Traefik (scénario duckdns/cloudflare/vpn)
- ✅ Détecte Supabase (activation postgres_exporter)
- ✅ Affiche structure docker-compose.yml
- ✅ Affiche targets Prometheus détectés

**Exemple de sortie** :

```
[INFO] Détection de l'environnement...
[INFO] ✅ Traefik détecté : Scénario Cloudflare
[INFO] ✅ Supabase détecté : postgres_exporter sera activé
[INFO]
[DRY-RUN] Création de ~/stacks/monitoring/
[DRY-RUN] Génération docker-compose.yml avec services :
  - prometheus (port 9090)
  - grafana (port 3002)
  - node-exporter (port 9100)
  - cadvisor (port 8080)
  - postgres-exporter (port 9187)
[DRY-RUN] Configuration Prometheus avec 4 targets :
  - prometheus:9090
  - node-exporter:9100
  - cadvisor:8080
  - postgres-exporter:9187
[DRY-RUN] Copie dashboards :
  - raspberry-pi-dashboard.json
  - docker-containers-dashboard.json
  - supabase-postgres-dashboard.json
[DRY-RUN] Ajout labels Traefik (scénario: cloudflare)
[DRY-RUN] docker compose up -d
[SUCCESS] Monitoring serait installé avec succès !
```

**Vérifier dry-run** : Aucune erreur ? Passez à l'étape suivante.

### Étape 4 : Installation Réelle

#### 4.1 Installation Simple (Défauts)

```bash
sudo ./monitoring-deploy.sh --yes --verbose
```

**Paramètres par défaut** :
- Grafana user : `admin`
- Grafana password : `admin` (à changer au premier login)
- Rétention Prometheus : `30d`
- Scrape interval : `15s`

#### 4.2 Installation Personnalisée

```bash
# Avec mot de passe Grafana personnalisé
sudo GRAFANA_ADMIN_PASSWORD=SuperSecure123 \
     ./monitoring-deploy.sh --yes --verbose

# Avec rétention 60 jours
sudo PROMETHEUS_RETENTION=60d \
     ./monitoring-deploy.sh --yes --verbose

# Combinaison
sudo GRAFANA_ADMIN_PASSWORD=SuperSecure123 \
     PROMETHEUS_RETENTION=60d \
     SCRAPE_INTERVAL=30s \
     ./monitoring-deploy.sh --yes --verbose
```

### Étape 5 : Attendre la Fin de l'Installation

**Durée** : ~2-3 minutes

**Étapes du script** :

```
[1/10] Détection environnement...
  ✅ Traefik : Scénario Cloudflare
  ✅ Supabase : Détecté

[2/10] Création répertoire ~/stacks/monitoring/...
  ✅ Créé

[3/10] Génération docker-compose.yml...
  ✅ Généré (5 services)

[4/10] Configuration Prometheus...
  ✅ prometheus.yml créé (4 targets)

[5/10] Configuration Grafana...
  ✅ grafana.ini créé
  ✅ Datasource Prometheus provisionné

[6/10] Copie dashboards...
  ✅ raspberry-pi-dashboard.json
  ✅ docker-containers-dashboard.json
  ✅ supabase-postgres-dashboard.json

[7/10] Ajout labels Traefik...
  ✅ Labels Cloudflare ajoutés

[8/10] Démarrage containers...
  ✅ Creating network monitoring_default
  ✅ Creating monitoring-prometheus
  ✅ Creating monitoring-grafana
  ✅ Creating monitoring-node-exporter
  ✅ Creating monitoring-cadvisor
  ✅ Creating monitoring-postgres-exporter

[9/10] Vérification santé services...
  ✅ prometheus : healthy
  ✅ grafana : healthy
  ✅ node-exporter : healthy
  ✅ cadvisor : healthy
  ✅ postgres-exporter : healthy

[10/10] Affichage URLs...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Monitoring Stack Installé avec Succès !
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Grafana      : https://grafana.votredomaine.com
🔍 Prometheus   : https://prometheus.votredomaine.com
🖥️  cAdvisor    : http://raspberrypi.local:8080

🔐 Login Grafana :
   Username : admin
   Password : admin (changez au premier login !)

📁 Installation : /home/pi/stacks/monitoring/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## ✔️ Vérification Post-Installation

### Vérifier les Containers

```bash
cd ~/stacks/monitoring
docker compose ps
```

**Sortie attendue** :

```
NAME                            STATUS              PORTS
monitoring-cadvisor             Up 30 seconds       0.0.0.0:8080->8080/tcp
monitoring-grafana              Up 30 seconds       0.0.0.0:3002->3000/tcp
monitoring-node-exporter        Up 30 seconds       0.0.0.0:9100->9100/tcp
monitoring-postgres-exporter    Up 30 seconds       0.0.0.0:9187->9187/tcp
monitoring-prometheus           Up 30 seconds       0.0.0.0:9090->9090/tcp
```

**Tous doivent être `Up` !**

Si un service est `Exited` :

```bash
docker compose logs <nom-service>
# Ex: docker compose logs grafana
```

### Vérifier les Ports Ouverts

```bash
netstat -tuln | grep -E '(3002|9090|9100|8080|9187)'
```

**Sortie attendue** :

```
tcp6  0  0 :::3002   :::*  LISTEN  (Grafana)
tcp6  0  0 :::9090   :::*  LISTEN  (Prometheus)
tcp6  0  0 :::9100   :::*  LISTEN  (Node Exporter)
tcp6  0  0 :::8080   :::*  LISTEN  (cAdvisor)
tcp6  0  0 :::9187   :::*  LISTEN  (postgres_exporter, si Supabase)
```

### Vérifier Prometheus Targets

```bash
# Ouvrir dans navigateur
firefox http://raspberrypi.local:9090/targets
# ou
chromium http://raspberrypi.local:9090/targets
```

**Tous les targets doivent être UP (vert)** :

| Endpoint | State | Labels |
|----------|-------|--------|
| `http://prometheus:9090/metrics` | **UP** | job=prometheus |
| `http://node-exporter:9100/metrics` | **UP** | job=node-exporter |
| `http://cadvisor:8080/metrics` | **UP** | job=cadvisor |
| `http://postgres-exporter:9187/metrics` | **UP** | job=postgres-exporter |

Si un target est **DOWN** (rouge) :

```bash
cd ~/stacks/monitoring
docker compose restart <nom-service>
```

### Tester Accès Grafana

```bash
# Local (sans Traefik)
curl -I http://raspberrypi.local:3002

# Avec Traefik (DuckDNS)
curl -I https://votresubdomain.duckdns.org/grafana

# Avec Traefik (Cloudflare)
curl -I https://grafana.votredomaine.com
```

**Sortie attendue** :

```
HTTP/1.1 302 Found
Location: /login
...
```

---

## 🎨 Configuration Initiale Grafana

### Première Connexion

1. **Ouvrir Grafana dans navigateur** :
   - Local : http://raspberrypi.local:3002
   - DuckDNS : https://votresubdomain.duckdns.org/grafana
   - Cloudflare : https://grafana.votredomaine.com

2. **Page de login** :
   - Username : `admin`
   - Password : `admin`

3. **Changement mot de passe obligatoire** :
   - Entrer nouveau mot de passe (minimum 8 caractères)
   - Confirmer
   - Cliquer **Submit**

**⚠️ IMPORTANT** : Notez le nouveau mot de passe dans un gestionnaire de mots de passe sécurisé !

### Vérifier Datasource Prometheus

1. **Menu hamburger (☰)** en haut à gauche
2. **Connections** > **Data Sources**
3. Cliquer sur **Prometheus**

**Configuration attendue** :

| Champ | Valeur |
|-------|--------|
| **URL** | `http://prometheus:9090` |
| **Access** | `Server (default)` |
| **Scrape interval** | `15s` |

4. **Cliquer Test en bas** :
   - ✅ "Data source is working"
   - ❌ Si erreur → Vérifier que container `prometheus` tourne

### Accéder aux Dashboards

1. **Menu (☰)** > **Dashboards**
2. Vous devriez voir **3 dashboards** :

| Dashboard | Description |
|-----------|-------------|
| **Raspberry Pi 5 - Système** | Métriques matériel/OS |
| **Docker Containers** | Métriques containers |
| **Supabase PostgreSQL** | Métriques DB (si Supabase installé) |

3. **Cliquer sur "Raspberry Pi 5 - Système"**

**Dashboard doit afficher** :
- ✅ CPU Usage (graphique avec données)
- ✅ CPU Temperature (jauge avec valeur)
- ✅ Memory Usage (jauge avec %)
- ✅ Disk Usage (jauge avec %)
- ✅ Network Traffic (graphique)
- ✅ System Load (graphique)
- ✅ Uptime (statistique)

**Si "No Data"** → Voir [Résolution de Problèmes](#-résolution-de-problèmes)

### Personnaliser l'Interface

#### Thème Sombre/Clair

1. **Icône utilisateur** (en bas à gauche)
2. **Preferences**
3. **Interface theme** : Dark / Light
4. **Save**

#### Timezone

1. **Icône utilisateur** > **Preferences**
2. **Timezone** : Browser Time / UTC / Custom
3. **Save**

#### Page d'Accueil par Défaut

1. Ouvrir dashboard "Raspberry Pi 5"
2. **Icône étoile (⭐)** en haut
3. Dashboard devient favori et apparaît en premier

---

## 🆘 Résolution de Problèmes

### Problème 1 : Grafana Ne S'Ouvre Pas

**Erreur** : "Unable to connect" ou timeout

**Solutions** :

1. **Vérifier container** :
   ```bash
   docker compose ps | grep grafana
   ```

   Si `Exited` :
   ```bash
   docker compose logs grafana
   docker compose restart grafana
   ```

2. **Vérifier port** :
   ```bash
   netstat -tuln | grep 3002
   ```

   Si vide → Port pas ouvert :
   ```bash
   docker compose up -d
   ```

3. **Tester avec IP locale** :
   ```bash
   hostname -I
   # Ex: 192.168.1.50
   ```
   Ouvrir : `http://192.168.1.50:3002`

### Problème 2 : Dashboards Vides ("No Data")

**Cause** : Prometheus ne collecte pas les données

**Solutions** :

1. **Vérifier Prometheus targets** :
   - Ouvrir http://raspberrypi.local:9090/targets
   - Tous doivent être **UP**

   Si **DOWN** :
   ```bash
   docker compose restart <nom-service>
   ```

2. **Attendre 30 secondes** :
   - Prometheus scrappe toutes les 15s
   - Rafraîchir dashboard (F5)

3. **Changer intervalle temps** :
   - En haut à droite : "Last 6 hours" → "Last 24 hours"

4. **Vérifier datasource** :
   - **Connections** > **Data Sources** > **Prometheus**
   - Cliquer **Test** → "Working"

### Problème 3 : postgres_exporter DOWN

**Symptôme** : Dashboard "Supabase PostgreSQL" vide, target DOWN

**Solutions** :

1. **Vérifier Supabase** :
   ```bash
   cd ~/stacks/supabase
   docker compose ps | grep db
   ```

   Si `supabase-db` n'est pas `Up` :
   ```bash
   docker compose up -d
   ```

2. **Vérifier connexion réseau Docker** :
   ```bash
   docker network ls
   # Doit montrer réseau "monitoring_default"

   docker network inspect monitoring_default
   # Vérifier que postgres-exporter et supabase-db sont dedans
   ```

3. **Vérifier DSN** :
   ```bash
   grep POSTGRES_DSN ~/stacks/monitoring/.env
   ```

   Format attendu :
   ```
   POSTGRES_DSN=postgresql://postgres:PASSWORD@supabase-db:5432/postgres?sslmode=disable
   ```

4. **Tester connexion** :
   ```bash
   docker exec monitoring-postgres-exporter psql \
     "postgresql://postgres:PASSWORD@supabase-db:5432/postgres" \
     -c "SELECT version();"
   ```

### Problème 4 : Erreur Permission Denied

**Erreur** :

```
Error response from daemon: failed to create shim task: OCI runtime create failed:
runc create failed: unable to start container process: exec:
"/bin/prometheus": permission denied
```

**Cause** : Fichiers téléchargés sans permissions exécutables

**Solution** :

```bash
cd ~/stacks/monitoring
sudo chmod +x -R data/
docker compose down
docker compose up -d
```

### Problème 5 : Port Déjà Utilisé

**Erreur** :

```
Error starting userland proxy: listen tcp4 0.0.0.0:3002: bind: address already in use
```

**Cause** : Un autre service écoute sur le port 3002

**Solutions** :

1. **Identifier le processus** :
   ```bash
   sudo lsof -i :3002
   ```

   Sortie :
   ```
   COMMAND  PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
   docker   1234 root   10u  IPv6  12345      0t0  TCP *:3002 (LISTEN)
   ```

2. **Arrêter le service conflit** :
   ```bash
   sudo kill 1234
   # ou
   docker stop <container-qui-utilise-port>
   ```

3. **Ou changer port Grafana** :
   ```bash
   cd ~/stacks/monitoring
   nano docker-compose.yml
   ```

   Modifier :
   ```yaml
   grafana:
     ports:
       - "3003:3000"  # Changer 3002 → 3003
   ```

   Redémarrer :
   ```bash
   docker compose up -d
   ```

   Nouvelle URL : http://raspberrypi.local:3003

### Problème 6 : Espace Disque Plein

**Erreur** :

```
Error: database is locked
no space left on device
```

**Cause** : Prometheus TSDB a rempli le disque

**Solutions** :

1. **Vérifier espace disque** :
   ```bash
   df -h
   ```

2. **Réduire rétention Prometheus** :
   ```bash
   cd ~/stacks/monitoring
   nano docker-compose.yml
   ```

   Modifier :
   ```yaml
   prometheus:
     command:
       - '--storage.tsdb.retention.time=15d'  # Au lieu de 30d
   ```

   Redémarrer :
   ```bash
   docker compose up -d
   ```

3. **Nettoyer vieilles données** :
   ```bash
   docker compose stop prometheus
   sudo rm -rf data/prometheus/*
   docker compose up -d prometheus
   ```

   **⚠️ Attention** : Perte de tout l'historique !

---

## 🔄 Désinstallation

### Désinstallation Complète

```bash
cd ~/stacks/monitoring

# Arrêter et supprimer containers
docker compose down -v

# Supprimer répertoire
cd ~
sudo rm -rf ~/stacks/monitoring/

# (Optionnel) Supprimer images Docker
docker rmi prom/prometheus:latest
docker rmi grafana/grafana:latest
docker rmi prom/node-exporter:latest
docker rmi gcr.io/cadvisor/cadvisor:latest
docker rmi quay.io/prometheuscommunity/postgres-exporter:latest
```

### Désinstallation Partielle (Garder Config)

```bash
cd ~/stacks/monitoring

# Sauvegarder config
tar -czf ~/backups/monitoring-config-$(date +%Y%m%d).tar.gz config/ docker-compose.yml .env

# Arrêter containers
docker compose down

# Supprimer données (garder config)
sudo rm -rf data/
```

**Pour réinstaller** :

```bash
docker compose up -d
```

---

## 📚 Prochaines Étapes

Après installation réussie :

1. ✅ **Tester dashboards** :
   - Ouvrir "Raspberry Pi 5 - Système"
   - Vérifier que toutes les jauges sont vertes

2. ✅ **Configurer alertes email** (optionnel) :
   - Éditer `config/grafana/grafana.ini`
   - Ajouter section SMTP
   - Créer alertes sur CPU/RAM/Disque

3. ✅ **Personnaliser dashboards** :
   - Ajouter panneaux custom
   - Modifier seuils (70% → 80%)
   - Importer dashboards communautaires

4. ✅ **Automatiser backups config** :
   - Ajouter cron job pour sauvegarder `config/`
   - Exclure `data/` (trop volumineux)

5. ✅ **Intégrer avec Homepage** (si installé) :
   - Homepage détecte automatiquement Grafana
   - Ajoute widget + lien

---

## 🔗 Documentation Complémentaire

- **[README.md](README.md)** - Documentation complète du stack
- **[GUIDE-DEBUTANT.md](GUIDE-DEBUTANT.md)** - Guide pédagogique pour novices
- **[ROADMAP.md](../ROADMAP.md)** - Plan de développement Pi5-Setup
- **[Prometheus Docs](https://prometheus.io/docs/)** - Documentation officielle
- **[Grafana Docs](https://grafana.com/docs/)** - Documentation officielle

---

<p align="center">
  <strong>📊 Installation Monitoring Terminée ! 📊</strong>
</p>

<p align="center">
  <sub>Surveillance temps réel • Dashboards pré-configurés • Production-ready</sub>
</p>
