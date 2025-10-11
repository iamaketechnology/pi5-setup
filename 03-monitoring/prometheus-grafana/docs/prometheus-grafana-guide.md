# 📊 Guide Débutant - Monitoring Raspberry Pi 5

> **Pour les novices : Surveillez votre Pi comme un pilote surveille son tableau de bord**

---

## 🎯 C'est Quoi le Monitoring ?

### Analogie Simple

Imaginez que vous conduisez une voiture :

- **Sans tableau de bord** : Vous roulez à l'aveugle. Vous ne savez pas votre vitesse, si vous avez de l'essence, si le moteur chauffe...
- **Avec tableau de bord** : Vous voyez tout en un coup d'œil ! Vitesse, essence, température moteur, alertes...

**Le monitoring, c'est pareil pour votre Raspberry Pi !**

Sans monitoring → Vous ne savez pas si :
- ❓ Le CPU est à 100% (ralentissements)
- ❓ La RAM est pleine (plantages)
- ❓ Le disque est plein (erreurs)
- ❓ Les containers Docker consomment trop
- ❓ Supabase fonctionne correctement

Avec monitoring → Vous voyez tout en temps réel :
- ✅ CPU : 25% (normal)
- ✅ RAM : 2.5 GB / 8 GB (ok)
- ✅ Disque : 45% utilisé
- ✅ Containers : tous en bonne santé
- ✅ Supabase : 15 connexions actives

---

## 🛠️ Les Outils de Monitoring

Notre stack utilise **4 outils complémentaires** :

### 1️⃣ Prometheus (Le Collecteur)

**Rôle** : Collecte les métriques toutes les 15 secondes

**Analogie** : Un comptable qui note tout dans un grand cahier :
- Toutes les 15 secondes : "CPU à 25%, RAM à 3GB, Disque à 45%..."
- Il stocke ces données pendant 30 jours
- Il ne les affiche pas, il les enregistre juste

**Ce qu'il surveille** :
- ✅ Métriques système (via Node Exporter)
- ✅ Métriques Docker (via cAdvisor)
- ✅ Métriques PostgreSQL (via postgres_exporter si Supabase installé)

**URL** : http://raspberrypi.local:9090

### 2️⃣ Grafana (Le Tableau de Bord)

**Rôle** : Affiche les métriques de façon visuelle

**Analogie** : Le tableau de bord de votre voiture
- Il demande à Prometheus : "Donne-moi le CPU des 24 dernières heures"
- Il affiche un beau graphique coloré
- Il crée des alertes visuelles (rouge si >80%)

**Ce que vous verrez** :
- 📊 Graphiques en temps réel
- 📈 Historiques sur 30 jours
- 🔴 Alertes visuelles (rouge/orange/vert)
- 📋 Tableaux de données

**URL** :
- DuckDNS : https://votresubdomain.duckdns.org/grafana
- Cloudflare : https://grafana.votredomaine.com
- VPN : http://raspberrypi.local:3002

**Login par défaut** : admin / admin (vous devrez changer au premier login)

### 3️⃣ Node Exporter (Capteur Système)

**Rôle** : Expose les métriques du Raspberry Pi

**Analogie** : Les capteurs dans votre voiture (vitesse, essence, température)

**Ce qu'il mesure** :
- 🔥 Température CPU
- 💻 Utilisation CPU (par core)
- 🧠 RAM utilisée/disponible
- 💾 Espace disque
- 🌐 Trafic réseau
- ⚡ Charge système

**URL** : http://raspberrypi.local:9100/metrics (format brut pour Prometheus)

### 4️⃣ cAdvisor (Capteur Docker)

**Rôle** : Expose les métriques des containers Docker

**Analogie** : Un compteur pour chaque passager dans votre voiture (combien chacun consomme)

**Ce qu'il mesure** :
- 📦 CPU utilisé par container
- 🧠 RAM utilisée par container
- 💾 Disque utilisé par container
- 🌐 Réseau par container

**URL** : http://raspberrypi.local:8080 (interface web simple)

---

## 📊 Les 3 Dashboards Pré-Configurés

### Dashboard 1 : Raspberry Pi 5 - Système

**Qu'est-ce que c'est ?**
Vue d'ensemble complète du matériel et de l'OS de votre Pi.

**Panneaux disponibles** :

1. **CPU Usage (%)** - Graphique en ligne
   - Montre l'utilisation CPU totale sur 24h
   - Alerte orange si >70%, rouge si >80%

2. **CPU Temperature (°C)** - Jauge
   - Température actuelle du CPU
   - 🟢 Vert : <60°C (normal)
   - 🟠 Orange : 60-70°C (chaud)
   - 🔴 Rouge : >70°C (trop chaud, vérifier ventilation !)

3. **Memory Usage (%)** - Jauge
   - RAM utilisée / RAM totale
   - 🟢 Vert : <70%
   - 🟠 Orange : 70-85%
   - 🔴 Rouge : >85% (risque de ralentissements)

4. **Disk Usage (/)** - Jauge
   - Espace disque utilisé
   - 🟢 Vert : <70%
   - 🟠 Orange : 70-85%
   - 🔴 Rouge : >85% (nettoyer les vieux backups !)

5. **Network Traffic (MB/s)** - Graphique double
   - Ligne bleue : Trafic entrant (download)
   - Ligne verte : Trafic sortant (upload)

6. **System Load (1m, 5m, 15m)** - Graphique triple
   - Charge système sur 1, 5 et 15 minutes
   - Idéalement : <4 (nombre de cores du Pi 5)

7. **Uptime** - Statistique
   - Depuis combien de temps le Pi tourne sans redémarrage
   - Ex: "15 days 3 hours 42 minutes"

**Quand consulter ce dashboard ?**
- 📅 **Quotidien** : Vérifier que tout est vert
- 🔥 **Si lenteurs** : Vérifier CPU/RAM
- 🌡️ **En été** : Surveiller température
- 💾 **Avant backups** : Vérifier espace disque

**Exemple de lecture** :
```
CPU Usage      : 28% 🟢 (normal, vous pouvez installer plus de services)
CPU Temp       : 55°C 🟢 (pas besoin de ventilateur actif)
Memory Usage   : 45% 🟢 (3.6 GB / 8 GB)
Disk Usage     : 62% 🟢 (vous avez encore 150 GB)
Network Traffic: 2 MB/s entrant (streaming vidéo ?)
System Load    : 1.2 🟢 (bien en-dessous de 4)
Uptime         : 30 days (aucun crash !)
```

### Dashboard 2 : Docker Containers

**Qu'est-ce que c'est ?**
Vue détaillée de TOUS vos containers Docker et leur consommation.

**Panneaux disponibles** :

1. **Containers CPU Usage (Top 10)** - Tableau
   - Liste des 10 containers qui consomment le plus de CPU
   - Colonnes : Nom, CPU%, Tendance
   - Trié du plus gourmand au moins gourmand

2. **Containers Memory Usage (Top 10)** - Tableau
   - Liste des 10 containers qui consomment le plus de RAM
   - Colonnes : Nom, RAM (MB), % du total

3. **Container CPU Over Time** - Graphique multi-lignes
   - Une ligne colorée par container
   - Permet de voir quel container a un pic de CPU et quand

4. **Container Memory Over Time** - Graphique multi-lignes
   - Évolution de la RAM par container sur 24h
   - Détecte les fuites mémoire (ligne qui monte sans redescendre)

5. **Container Network I/O** - Tableau
   - Trafic réseau entrant/sortant par container
   - Colonnes : Nom, RX (received), TX (transmitted)

6. **Container Disk I/O** - Tableau
   - Lecture/écriture disque par container
   - Colonnes : Nom, Read (MB), Write (MB)

**Quand consulter ce dashboard ?**
- 🐌 **Si le Pi ralentit** : Identifier quel container consomme trop
- 🔍 **Après installation** : Vérifier la consommation d'un nouveau service
- 🛠️ **Pour optimiser** : Désactiver les containers inutilisés
- 🔴 **Alertes RAM** : Voir quel container fait exploser la mémoire

**Exemple de lecture** :
```
Top 10 CPU:
1. supabase-db        : 15% (normal, c'est la base de données)
2. supabase-realtime  : 8%
3. grafana            : 5%
4. supabase-studio    : 3%
5. homepage           : 1%

Top 10 Memory:
1. supabase-db        : 1200 MB (normal pour PostgreSQL)
2. grafana            : 350 MB
3. prometheus         : 280 MB
4. supabase-storage   : 180 MB

→ Conclusion : Supabase est le plus gourmand (attendu), le reste est OK
```

**Comment optimiser si un container consomme trop ?**

1. **Redémarrer le container** :
   ```bash
   cd ~/stacks/supabase
   docker compose restart <nom-du-service>
   ```

2. **Voir les logs** pour comprendre :
   ```bash
   docker compose logs -f <nom-du-service>
   ```

3. **Arrêter un container inutilisé** :
   ```bash
   docker compose stop <nom-du-service>
   ```

### Dashboard 3 : Supabase PostgreSQL (si installé)

**Qu'est-ce que c'est ?**
Métriques avancées de la base de données PostgreSQL de Supabase.

**Ce dashboard n'apparaît QUE si Supabase est installé.**

**Panneaux disponibles** :

1. **Active Connections** - Statistique + Graphique
   - Nombre de connexions actives à la base de données
   - Normal : 5-20 connexions
   - Alerte si >80 connexions (limite par défaut : 100)

2. **Database Size (MB)** - Statistique + Graphique
   - Taille totale de la base de données
   - Surveiller la croissance (si +10% par jour → prévoir nettoyage)

3. **Cache Hit Ratio (%)** - Jauge
   - % de requêtes servies depuis la RAM (cache)
   - 🟢 Vert : >95% (excellent)
   - 🟠 Orange : 85-95% (correct)
   - 🔴 Rouge : <85% (besoin de plus de RAM ou optimisation)

4. **Transaction Rate (txn/s)** - Graphique
   - Nombre de transactions par seconde
   - Pic lors d'imports de données ou forte charge

5. **Query Duration (P50, P95, P99)** - Graphique triple
   - P50 : 50% des requêtes prennent moins de X ms (médiane)
   - P95 : 95% des requêtes prennent moins de X ms
   - P99 : 99% des requêtes (les plus lentes)
   - Idéal : P95 <50ms, P99 <200ms

6. **Locks** - Statistique
   - Nombre de verrous actifs (requêtes en attente)
   - Normal : 0-2
   - Alerte si >10 (requêtes bloquantes)

7. **WAL (Write-Ahead Log) Size** - Graphique
   - Taille du journal de transactions
   - Si croissance infinie → problème de réplication

**Quand consulter ce dashboard ?**
- 🐌 **Si Supabase est lent** : Vérifier connexions, cache hit ratio, locks
- 📊 **Pour dimensionner** : Voir si besoin de plus de RAM/CPU
- 🔍 **Après migration** : Vérifier que les index fonctionnent (cache hit ratio)
- 🛠️ **Optimisation requêtes** : Identifier les requêtes lentes (P99)

**Exemple de lecture** :
```
Active Connections : 12 🟢 (normal)
Database Size      : 450 MB (croissance : +5 MB/jour)
Cache Hit Ratio    : 97.8% 🟢 (excellent !)
Transaction Rate   : 15 txn/s (pics à 100 lors des sauvegardes)
Query Duration P95 : 35ms 🟢 (rapide)
Query Duration P99 : 180ms 🟢 (acceptable)
Locks              : 0 🟢 (aucun blocage)
WAL Size           : 120 MB 🟢 (stable)

→ Conclusion : Base de données en excellente santé !
```

**Signaux d'alerte à surveiller** :

| Métrique | Valeur Normale | ⚠️ Alerte Si | 🔴 Critique Si | Action |
|----------|----------------|--------------|----------------|--------|
| **Connexions** | 5-20 | >50 | >80 | Augmenter `max_connections` |
| **Cache Hit** | >95% | <90% | <85% | Augmenter `shared_buffers` |
| **P99 Query** | <200ms | >500ms | >1000ms | Optimiser requêtes/index |
| **Locks** | 0-2 | >10 | >20 | Identifier requête bloquante |
| **DB Size** | Croissance lente | +20%/jour | +50%/jour | Nettoyer vieilles données |

---

## 🚀 Installation

### Prérequis

Avant d'installer le monitoring, vous devez avoir :

- ✅ **Raspberry Pi 5** avec Raspberry Pi OS 64-bit
- ✅ **Docker + Docker Compose** installés (via `01-prerequisites-setup.sh`)
- ✅ **(Optionnel)** Traefik pour accès HTTPS externe
- ✅ **(Optionnel)** Supabase pour monitoring PostgreSQL

### Installation Simple (Curl One-Liner)

```bash
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/pi5-monitoring-stack/scripts/01-monitoring-deploy.sh | sudo bash
```

### Installation Avancée (avec options)

```bash
# Télécharger le script
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/pi5-monitoring-stack/scripts/01-monitoring-deploy.sh -o monitoring-deploy.sh
chmod +x monitoring-deploy.sh

# Installer avec options
sudo ./monitoring-deploy.sh --verbose --yes
```

### Ce que fait le script

1. ✅ Détecte si Traefik est installé (et quel scénario)
2. ✅ Détecte si Supabase est installé
3. ✅ Crée le répertoire `~/stacks/monitoring/`
4. ✅ Génère `docker-compose.yml` avec :
   - Prometheus (port 9090)
   - Grafana (port 3002)
   - Node Exporter (port 9100)
   - cAdvisor (port 8080)
   - postgres_exporter (si Supabase détecté)
5. ✅ Configure Prometheus (cibles de scraping)
6. ✅ Configure Grafana (datasource Prometheus)
7. ✅ Copie les 3 dashboards pré-configurés
8. ✅ Ajoute les labels Traefik (si installé)
9. ✅ Démarre les containers Docker
10. ✅ Affiche les URLs d'accès

**Durée** : ~2-3 minutes

---

## 🎨 Accéder aux Interfaces

### Prometheus

**URL selon scénario** :
- **Sans Traefik** : http://raspberrypi.local:9090
- **DuckDNS** : https://votresubdomain.duckdns.org/prometheus
- **Cloudflare** : https://prometheus.votredomaine.com
- **VPN** : http://raspberrypi.local:9090

**À quoi ça sert ?**
- Vérifier que les cibles sont bien scrapées (Status > Targets)
- Tester des requêtes PromQL (Graph)
- Voir les alertes (Alerts)

**Interface simple** :
- Pas de login requis
- Interface minimaliste (pas besoin d'y aller souvent)
- Grafana est plus joli pour visualiser

### Grafana

**URL selon scénario** :
- **Sans Traefik** : http://raspberrypi.local:3002
- **DuckDNS** : https://votresubdomain.duckdns.org/grafana
- **Cloudflare** : https://grafana.votredomaine.com
- **VPN** : http://raspberrypi.local:3002

**Login par défaut** :
- Username : `admin`
- Password : `admin`

**⚠️ Au premier login** :
Grafana vous demandera de changer le mot de passe admin. Utilisez un mot de passe fort !

**Navigation** :
1. Cliquez sur le menu hamburger (☰) en haut à gauche
2. Allez dans **Dashboards**
3. Vous verrez vos 3 dashboards :
   - Raspberry Pi 5 - Système
   - Docker Containers
   - Supabase PostgreSQL (si Supabase installé)

### Node Exporter

**URL** : http://raspberrypi.local:9100/metrics

**À quoi ça sert ?**
- Interface brute (texte) avec toutes les métriques
- Utilisée par Prometheus pour scraper les données
- Pas besoin de consulter directement (utilisez Grafana)

### cAdvisor

**URL** : http://raspberrypi.local:8080

**À quoi ça sert ?**
- Interface web simple pour voir les containers Docker
- Cliquez sur un container pour voir ses métriques en temps réel
- Alternative simple si Grafana est trop compliqué

---

## 🔍 Utilisation Quotidienne

### Check Rapide Quotidien (30 secondes)

**Ouvrez Grafana → Dashboard "Raspberry Pi 5 - Système"**

1. ✅ CPU < 70% ? → Vert, OK
2. ✅ Température < 60°C ? → Vert, OK
3. ✅ RAM < 70% ? → Vert, OK
4. ✅ Disque < 70% ? → Vert, OK

**Si tout est vert → Votre Pi va bien ! 🎉**

### Quand Consulter le Dashboard Docker ?

- 🐌 **Lenteurs** : Identifier quel container consomme trop
- 🆕 **Après installation** : Vérifier consommation du nouveau service
- 🔴 **Alerte RAM/CPU** : Voir la répartition par container

### Quand Consulter le Dashboard Supabase ?

- 🐌 **Supabase lent** : Vérifier connexions, cache, locks
- 📊 **Optimisation** : Analyser durée des requêtes (P95/P99)
- 💾 **Capacité** : Surveiller croissance de la base de données

---

## 📖 Exemples de Scénarios Réels

### Scénario 1 : Le Pi Ralentit

**Symptômes** : Interface Supabase Studio très lente

**Démarche** :

1. **Ouvrir Grafana → Dashboard "Raspberry Pi 5 - Système"**
   - CPU : 95% 🔴 (problème !)
   - RAM : 85% 🟠
   - Température : 72°C 🔴

2. **Ouvrir Dashboard "Docker Containers"**
   - Top CPU :
     1. supabase-db : 60% 🔴
     2. grafana : 5%
     3. autres : <2%

3. **Diagnostic** : Supabase DB consomme trop de CPU

4. **Solution** :
   ```bash
   # Voir les logs
   cd ~/stacks/supabase
   docker compose logs -f db

   # Si rien d'anormal, redémarrer
   docker compose restart db
   ```

5. **Vérification** : Attendre 1 minute, rafraîchir Grafana
   - CPU redescendu à 25% 🟢
   - Température à 58°C 🟢

**Résultat** : Problème résolu en 3 minutes grâce au monitoring !

### Scénario 2 : Le Disque Se Remplit

**Symptômes** : Alerte disque à 88% 🔴

**Démarche** :

1. **Ouvrir Dashboard "Raspberry Pi 5"**
   - Disque : 88% 🔴 (il reste seulement 50 GB)

2. **Identifier les gros fichiers** :
   ```bash
   # Lister les répertoires les plus gros
   sudo du -h --max-depth=1 /home/pi | sort -hr | head -10
   ```

3. **Résultat** :
   ```
   25G  /home/pi/backups
   10G  /home/pi/stacks
   5G   /home/pi/Downloads
   ```

4. **Action** : Nettoyer les vieux backups
   ```bash
   # Les scripts de backup gardent automatiquement :
   # - 7 backups quotidiens
   # - 4 backups hebdomadaires
   # - 12 backups mensuels
   # Mais on peut supprimer manuellement les très vieux :

   ls -lht /home/pi/backups/supabase/
   sudo rm /home/pi/backups/supabase/supabase-20240101-*.tar.gz
   ```

5. **Vérification dans Grafana** :
   - Disque : 72% 🟢 (libéré 16% → ~70 GB)

**Résultat** : Disque nettoyé, alerte résolue !

### Scénario 3 : Supabase Très Lent

**Symptômes** : Requêtes API qui prennent 5-10 secondes

**Démarche** :

1. **Ouvrir Dashboard "Supabase PostgreSQL"**
   - Active Connections : 85 🔴 (trop !)
   - Cache Hit Ratio : 75% 🔴 (mauvais)
   - P99 Query Duration : 3500ms 🔴 (très lent)
   - Locks : 15 🔴

2. **Diagnostic** : Trop de connexions + requêtes lentes + locks

3. **Solution immédiate** : Redémarrer Supabase
   ```bash
   cd ~/stacks/supabase
   docker compose restart
   ```

4. **Solution long-terme** : Optimiser la base
   - Ajouter des index sur les tables fréquemment requêtées
   - Augmenter `shared_buffers` dans PostgreSQL
   - Limiter le nombre de connexions simultanées

5. **Vérification** :
   - Connexions : 12 🟢
   - Cache Hit : 96% 🟢
   - P99 : 180ms 🟢
   - Locks : 0 🟢

**Résultat** : Performance restaurée !

---

## 🛠️ Configuration Avancée

### Personnaliser la Rétention des Données

Par défaut, Prometheus garde **30 jours** de métriques.

**Modifier la rétention** :

```bash
cd ~/stacks/monitoring
nano docker-compose.yml
```

**Trouver la section Prometheus** :
```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=30d'  # ← Changer ici
```

**Exemples** :
- `15d` : 15 jours (économiser espace disque)
- `60d` : 60 jours (historique long)
- `1y` : 1 an (attention à l'espace disque !)

**Appliquer** :
```bash
docker compose up -d
```

### Ajouter des Alertes Email

**Grafana peut envoyer des emails** quand une métrique dépasse un seuil.

**Exemple** : Email si CPU >80% pendant 5 minutes

1. **Configurer SMTP dans Grafana** :
   ```bash
   cd ~/stacks/monitoring
   nano config/grafana/grafana.ini
   ```

2. **Ajouter** :
   ```ini
   [smtp]
   enabled = true
   host = smtp.gmail.com:587
   user = votre-email@gmail.com
   password = votre-mot-de-passe-application
   from_address = votre-email@gmail.com
   from_name = Grafana Pi5
   ```

3. **Redémarrer Grafana** :
   ```bash
   docker compose restart grafana
   ```

4. **Dans Grafana** :
   - Aller dans **Alerting > Contact Points**
   - Ajouter votre email
   - Créer une alerte sur le panneau "CPU Usage"

### Ajouter un Nouveau Dashboard

**Importer un dashboard communautaire** :

1. Aller sur [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
2. Chercher "Raspberry Pi" ou "Docker"
3. Noter l'ID (ex: 1860)
4. Dans Grafana : **Dashboards > Import**
5. Entrer l'ID et cliquer **Load**
6. Sélectionner datasource "Prometheus"
7. Cliquer **Import**

**Dashboards recommandés** :
- **1860** : Node Exporter Full (très complet)
- **893** : Docker and System Monitoring
- **11074** : Node Exporter for Prometheus Dashboard

---

## 🆘 Troubleshooting

### Grafana Ne S'Ouvre Pas

**Erreur** : "Unable to connect" sur http://raspberrypi.local:3002

**Solutions** :

1. **Vérifier que le container tourne** :
   ```bash
   cd ~/stacks/monitoring
   docker compose ps
   ```

   Si `grafana` est `Exited` :
   ```bash
   docker compose logs grafana
   docker compose restart grafana
   ```

2. **Vérifier le port** :
   ```bash
   netstat -tuln | grep 3002
   ```

   Si pas de résultat → Le port n'écoute pas
   ```bash
   docker compose up -d
   ```

3. **Essayer avec l'IP locale** :
   ```bash
   # Trouver l'IP du Pi
   hostname -I
   # Exemple : 192.168.1.50

   # Ouvrir dans navigateur
   http://192.168.1.50:3002
   ```

### Dashboards Vides

**Symptôme** : Dashboards ouverts mais aucune donnée ("No data")

**Solutions** :

1. **Vérifier que Prometheus collecte les données** :
   - Ouvrir Prometheus : http://raspberrypi.local:9090
   - Aller dans **Status > Targets**
   - Tous les targets doivent être **UP** (vert)

   Si un target est **DOWN** (rouge) :
   ```bash
   cd ~/stacks/monitoring
   docker compose restart <nom-du-service>
   # Exemples : node-exporter, cadvisor, postgres-exporter
   ```

2. **Vérifier la datasource dans Grafana** :
   - Dans Grafana : **Connections > Data Sources**
   - Cliquer sur "Prometheus"
   - Cliquer **Test** en bas
   - Doit afficher "Data source is working"

   Si erreur :
   - Vérifier l'URL : `http://prometheus:9090`
   - Vérifier que le container Prometheus tourne

3. **Rafraîchir les dashboards** :
   - Cliquer sur l'icône de rafraîchissement (🔄) en haut à droite
   - Changer l'intervalle de temps (Last 6 hours → Last 24 hours)

### Métriques PostgreSQL Manquantes

**Symptôme** : Dashboard "Supabase PostgreSQL" vide

**Cause** : Le script n'a pas détecté Supabase ou postgres_exporter ne tourne pas

**Solutions** :

1. **Vérifier que postgres_exporter est déployé** :
   ```bash
   cd ~/stacks/monitoring
   docker compose ps | grep postgres-exporter
   ```

   Si absent :
   ```bash
   # Réinstaller le monitoring avec détection de Supabase
   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/pi5-monitoring-stack/scripts/01-monitoring-deploy.sh | sudo bash
   ```

2. **Vérifier la connexion PostgreSQL** :
   ```bash
   # Tester depuis l'hôte
   docker exec supabase-db psql -U postgres -c "SELECT version();"
   ```

   Si erreur → Vérifier le mot de passe dans `~/stacks/supabase/.env`

3. **Vérifier les targets dans Prometheus** :
   - Ouvrir http://raspberrypi.local:9090/targets
   - Chercher `postgres-exporter`
   - Doit être **UP**

   Si **DOWN** :
   ```bash
   docker compose logs postgres-exporter
   ```

### CPU/Température Toujours en Rouge

**Symptôme** : CPU >80% ou Température >70°C en permanence

**Solutions** :

1. **Identifier le container gourmand** :
   - Ouvrir Dashboard "Docker Containers"
   - Regarder le Top 10 CPU
   - Redémarrer le container problématique

2. **Vérifier la ventilation** :
   - Le Pi 5 a-t-il un ventilateur actif ?
   - Le boîtier permet-il une bonne circulation d'air ?
   - Acheter un ventilateur PWM si >70°C constant

3. **Réduire la charge** :
   - Arrêter les services non-critiques :
     ```bash
     cd ~/stacks/<service>
     docker compose stop
     ```

4. **Overclock ?** :
   - Si vous avez overclocké le Pi → Retour config stock
   - Éditer `/boot/firmware/config.txt` et retirer lignes `over_voltage`, `arm_freq`

---

## 📚 Pour Aller Plus Loin

### Apprendre PromQL (Langage de Requêtes)

**PromQL** = Langage pour interroger Prometheus

**Exemples de requêtes simples** :

```promql
# CPU usage moyen
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# RAM utilisée en GB
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes

# Nombre de containers Docker
count(container_last_seen{name!=""})

# Top 5 containers par CPU
topk(5, rate(container_cpu_usage_seconds_total[5m]))
```

**Tester dans Prometheus** :
- Ouvrir http://raspberrypi.local:9090
- Aller dans **Graph**
- Coller une requête
- Cliquer **Execute**

### Créer un Dashboard Custom

**Tutoriel simple** :

1. Dans Grafana : **Dashboards > New Dashboard**
2. Cliquer **+ Add visualization**
3. Sélectionner datasource "Prometheus"
4. Dans **Metrics browser**, choisir une métrique (ex: `node_cpu_seconds_total`)
5. Ajuster la requête PromQL
6. Changer le type de visualisation (Graph, Gauge, Stat, etc.)
7. Ajuster les seuils (vert <70%, orange 70-85%, rouge >85%)
8. Cliquer **Apply**
9. Cliquer **Save dashboard** (icône disquette en haut)

**Exemple** : Créer un panneau "Containers en cours d'exécution"
- **Requête** : `count(container_last_seen{name!=""})`
- **Type** : Stat (gros chiffre)
- **Titre** : "Running Containers"

### Exporter un Dashboard

**Pour sauvegarder ou partager** :

1. Ouvrir le dashboard
2. Cliquer sur l'icône **Share** (partage)
3. Onglet **Export**
4. Cliquer **Save to file**
5. Un fichier JSON est téléchargé

**Pour importer** :
1. **Dashboards > Import**
2. **Upload JSON file**
3. Sélectionner le fichier
4. Cliquer **Import**

---

## 🎓 Résumé pour les Débutants

### Ce Que Vous Devez Retenir

1. **Monitoring = Tableau de bord de votre Pi**
   - Comme une voiture : vous voyez vitesse, essence, température
   - Permet de détecter les problèmes AVANT qu'ils ne causent des pannes

2. **4 Outils Complémentaires**
   - **Prometheus** : Collecte les métriques toutes les 15s
   - **Grafana** : Affiche de beaux graphiques
   - **Node Exporter** : Métriques système (CPU, RAM, disque)
   - **cAdvisor** : Métriques Docker (containers)

3. **3 Dashboards Pré-Configurés**
   - **Raspberry Pi 5** : Vue d'ensemble matériel/OS
   - **Docker Containers** : Consommation par container
   - **Supabase PostgreSQL** : Métriques base de données (si installé)

4. **Check Quotidien (30 secondes)**
   - Ouvrir Grafana
   - Dashboard "Raspberry Pi 5"
   - Vérifier que tout est vert (CPU, RAM, Disque, Température)

5. **Quand Consulter ?**
   - 📅 **Quotidien** : Check rapide (tout vert ?)
   - 🐌 **Lenteurs** : Identifier le container gourmand
   - 🔥 **Surchauffe** : Vérifier température et CPU
   - 💾 **Espace disque** : Nettoyer backups si >70%

6. **URLs à Retenir**
   - **Grafana** : http://raspberrypi.local:3002 (login: admin/admin)
   - **Prometheus** : http://raspberrypi.local:9090
   - **cAdvisor** : http://raspberrypi.local:8080

---

## 🔗 Liens Utiles

### Documentation Officielle

- **[Prometheus Docs](https://prometheus.io/docs/)** - Documentation complète
- **[Grafana Docs](https://grafana.com/docs/)** - Guides et tutoriels
- **[PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)** - Requêtes courantes

### Dashboards Communautaires

- **[Grafana Dashboard Library](https://grafana.com/grafana/dashboards/)** - 6000+ dashboards gratuits
- **[Node Exporter Full (1860)](https://grafana.com/grafana/dashboards/1860)** - Dashboard Pi complet
- **[Docker Monitoring (893)](https://grafana.com/grafana/dashboards/893)** - Dashboard containers

### Guides Pi5-Setup

- **[ROADMAP.md](../../../ROADMAP.md)** - Plan de développement complet
- **[Monitoring Stack README](../README.md)** - Documentation technique du stack
- **[Common Scripts](../../../common-scripts/README.md)** - Scripts de maintenance

---

<p align="center">
  <strong>📊 Surveillez Votre Pi Comme un Pro 📊</strong>
</p>

<p align="center">
  <sub>Métriques temps réel • Dashboards pré-configurés • Alertes • Production-ready</sub>
</p>
