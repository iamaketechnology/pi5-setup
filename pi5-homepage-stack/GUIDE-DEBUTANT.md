# 📚 Guide Débutant - Homepage Dashboard

> **Pour qui ?** Débutants en self-hosting qui veulent un tableau de bord élégant pour leur homelab
> **Durée de lecture** : 15 minutes
> **Niveau** : Débutant (aucune connaissance préalable requise)

---

## 🤔 C'est quoi Homepage ?

### En une phrase
**Homepage = La table des matières élégante de ton serveur - un portail unique pour accéder à tous tes services.**

### Analogie simple
Imagine que tu as plusieurs applications sur ton serveur (Supabase, Grafana, Portainer, Nextcloud, etc.). Sans Homepage, c'est comme avoir 10 sites web différents ouverts dans ton navigateur - tu dois te souvenir de chaque URL, chaque port, chaque login.

**Homepage = La page d'accueil de ton navigateur, mais pour ton homelab !**

C'est comme :
- La **télécommande universelle** de ton salon (contrôle tout depuis un seul endroit)
- Le **tableau de bord** de ta voiture (voit tout en un coup d'œil : vitesse, essence, température)
- Le **hall d'entrée** de ta maison (toutes les pièces sont accessibles depuis là)

Au lieu d'avoir des dizaines d'onglets ouverts, tu as **une seule page** qui :
- Liste tous tes services avec des jolies icônes
- Affiche l'état de ton système (CPU, RAM, disque)
- Montre tes conteneurs Docker actifs
- Intègre la météo, ton calendrier, tes bookmarks préférés
- S'adapte en dark mode automatiquement

---

## 🎯 À quoi ça sert concrètement ?

### Use Cases (Exemples d'utilisation)

#### 1. **Point d'accès unique pour ton homelab**
Tu as installé Supabase, Traefik, Portainer, Grafana... et tu ne te souviens plus des URLs ?
```
Homepage fait :
✅ Affiche tous tes services avec des icônes claires
✅ Un clic pour accéder à n'importe quel service
✅ Organise par catégories (Databases, Monitoring, Media, etc.)
✅ Ajoute des descriptions pour ne pas oublier à quoi sert chaque service
```

**Résultat** : Tu ouvres `http://homepage.pi.local` et TOUT est là, propre et organisé.

---

#### 2. **Monitoring système visuel**
Tu veux savoir si ton Pi est en bonne santé sans ouvrir un terminal ?
```
Homepage fait :
✅ Widget CPU : pourcentage d'utilisation en temps réel
✅ Widget RAM : mémoire utilisée vs disponible
✅ Widget Disque : espace restant sur ta carte SD
✅ Widget Docker : nombre de conteneurs actifs/arrêtés
✅ Widget Réseau : vitesse upload/download
```

**Résultat** : Un coup d'œil te dit si ton serveur va bien ou si un conteneur a crashé.

---

#### 3. **Impressionner amis/famille**
Tu veux montrer ton setup homelab de manière professionnelle ?
```
Homepage fait :
✅ Interface moderne et responsive (fonctionne sur mobile)
✅ Thèmes personnalisables (dark mode, couleurs custom)
✅ Animations fluides
✅ Widgets météo, horloge, recherche Google intégrée
```

**Résultat** : Tes visiteurs pensent que tu es un pro du self-hosting (même si tu as commencé hier).

---

#### 4. **Productivité quotidienne**
Tu veux centraliser tes outils de travail/loisirs ?
```
Homepage fait :
✅ Bookmarks rapides (GitHub, Reddit, YouTube, docs)
✅ Recherche intégrée (Google, DuckDuckGo)
✅ Calendrier (Google Calendar, Nextcloud)
✅ Liste de tâches (Todoist, Notion)
✅ Widgets RSS (flux d'actualités)
```

**Résultat** : Homepage devient ta page d'accueil de navigateur personnalisée.

---

#### 5. **Détection automatique de services**
Tu installes un nouveau conteneur Docker et tu veux qu'il apparaisse automatiquement ?
```
Homepage fait :
✅ Auto-détecte les conteneurs Docker avec labels
✅ Extrait automatiquement le nom, l'icône, l'URL
✅ Affiche le statut (running/stopped) en temps réel
✅ Montre les stats (CPU/RAM par conteneur)
```

**Résultat** : Tu installes Jellyfin → il apparaît automatiquement dans Homepage (magie !).

---

## 🧩 Les Composants (Expliqués simplement)

### 1. **Homepage Core** - L'Application Principale
**C'est quoi ?** Un serveur web ultra-léger (Next.js) qui génère ton dashboard.

**Ressources** :
- RAM : ~50-80 MB (presque rien)
- CPU : ~1-2% au repos
- Stockage : ~150 MB

**Pourquoi c'est génial ?** :
- **Léger** : Tourne facilement sur un Pi Zero 2W
- **Rapide** : Chargement instantané
- **Moderne** : Technologies web récentes (React, Tailwind CSS)

---

### 2. **Fichiers de Configuration YAML** - Le Cerveau
**C'est quoi ?** Des fichiers texte simples pour configurer ton dashboard.

**Structure** :
```yaml
config/
├── settings.yaml     # Paramètres généraux (thème, langue, titre)
├── services.yaml     # Liste de tes services (Supabase, Grafana, etc.)
├── widgets.yaml      # Widgets (CPU, RAM, Docker, météo)
├── bookmarks.yaml    # Liens favoris
├── docker.yaml       # Configuration Docker auto-discovery
└── custom.css        # Personnalisation visuelle (optionnel)
```

**Exemple concret** (services.yaml) :
```yaml
---
# Groupe : Databases
- Databases:
    - Supabase Studio:
        icon: supabase
        href: https://studio.domain.com
        description: Backend & Database

    - PostgreSQL Admin:
        icon: postgresql
        href: https://pgadmin.domain.com
        description: Gestion PostgreSQL

# Groupe : Monitoring
- Monitoring:
    - Grafana:
        icon: grafana
        href: https://grafana.domain.com
        description: Dashboards & Métriques

    - Portainer:
        icon: portainer
        href: https://portainer.domain.com
        description: Gestion Docker
```

**Résultat visuel** (dans Homepage) :
```
┌─────────────────────────────────────────┐
│ DATABASES                                │
├─────────────────────────────────────────┤
│ 🟢 Supabase Studio                      │
│    Backend & Database                    │
│                                          │
│ 🟢 PostgreSQL Admin                     │
│    Gestion PostgreSQL                    │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ MONITORING                               │
├─────────────────────────────────────────┤
│ 🟢 Grafana                              │
│    Dashboards & Métriques                │
│                                          │
│ 🟢 Portainer                            │
│    Gestion Docker                        │
└─────────────────────────────────────────┘
```

**Pourquoi YAML ?** :
- Simple à lire/écrire (comme du français)
- Pas de programmation requise
- Modifiable avec n'importe quel éditeur (nano, VSCode, etc.)

---

### 3. **Widgets** - Les Modules Dynamiques
**C'est quoi ?** Des petits blocs qui affichent des infos en temps réel.

**Widgets disponibles** :

#### A. **Système**
```yaml
- resources:
    cpu: true          # Utilisation CPU
    memory: true       # Utilisation RAM
    disk: /            # Espace disque
    uptime: true       # Temps depuis dernier reboot
```

**Affichage** :
```
┌─────────────────────┐
│ SYSTÈME             │
├─────────────────────┤
│ CPU    : 23% 🟢    │
│ RAM    : 2.1/8 GB   │
│ Disque : 45/64 GB   │
│ Uptime : 5d 3h 12m  │
└─────────────────────┘
```

---

#### B. **Docker**
```yaml
- docker:
    server: my-docker
    container: portainer  # Stats d'un conteneur spécifique
```

**Affichage** :
```
┌─────────────────────┐
│ DOCKER              │
├─────────────────────┤
│ Conteneurs : 12/14  │
│ Images     : 23     │
│ Volumes    : 8      │
└─────────────────────┘
```

---

#### C. **Météo**
```yaml
- openmeteo:
    latitude: 48.8566
    longitude: 2.3522
    units: metric
    cache: 5  # Minutes
```

**Affichage** :
```
┌─────────────────────┐
│ PARIS 🌤️           │
├─────────────────────┤
│ 18°C                │
│ Partiellement nuageux
│ Humidité : 65%      │
└─────────────────────┘
```

---

#### D. **Recherche**
```yaml
- search:
    provider: google
    target: _blank
```

**Affichage** : Barre de recherche en haut du dashboard → tape, appuie Entrée → recherche Google directe.

---

#### E. **Horloge & Date**
```yaml
- datetime:
    text_size: xl
    format:
      dateStyle: long
      timeStyle: short
```

**Affichage** :
```
Vendredi 4 octobre 2025
14:32
```

---

### 4. **Docker Integration** - L'Auto-Découverte
**C'est quoi ?** Homepage peut lire les labels de tes conteneurs Docker et les afficher automatiquement.

**Exemple magique** :

Tu déploies un conteneur avec ces labels :
```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin
    labels:
      - "homepage.group=Media"
      - "homepage.name=Jellyfin"
      - "homepage.icon=jellyfin.png"
      - "homepage.href=https://jellyfin.domain.com"
      - "homepage.description=Serveur média"
      - "homepage.widget.type=jellyfin"
      - "homepage.widget.url=http://jellyfin:8096"
      - "homepage.widget.key=YOUR_API_KEY"
```

**Résultat** : Jellyfin apparaît automatiquement dans Homepage avec :
- Icône Jellyfin officielle
- Lien cliquable
- Widget affichant nombre de films/séries
- Statut en temps réel (online/offline)

**Aucune modification de services.yaml requise !**

---

### 5. **Thèmes** - La Personnalisation
**C'est quoi ?** Change l'apparence complète de Homepage en modifiant une ligne.

**Thèmes pré-installés** :
- `dark` (défaut) : Fond noir, texte blanc
- `light` : Fond blanc, texte noir
- `nord` : Palette nordique (bleus froids)
- `catppuccin` : Palette pastel douce
- `dracula` : Violet/rose foncé

**Configuration** (settings.yaml) :
```yaml
color: slate         # Couleur principale
theme: dark          # dark | light
background: /images/bg.jpg  # Image de fond (optionnel)
cardBlur: md         # Effet flou des cartes
```

**Résultat** : Changement immédiat de tout le design (pas de redémarrage requis).

---

### 6. **API Integrations** - Les Super-Pouvoirs
**C'est quoi ?** Homepage peut se connecter à d'autres services pour afficher leurs stats.

**Exemples** :

#### Sonarr/Radarr (Gestion médias)
```yaml
- Sonarr:
    widget:
      type: sonarr
      url: http://sonarr:8989
      key: YOUR_API_KEY
      # Affiche : Séries à venir, espace disque, queue
```

#### Pi-hole (Bloqueur pub DNS)
```yaml
- Pi-hole:
    widget:
      type: pihole
      url: http://pihole.local
      key: YOUR_API_KEY
      # Affiche : Requêtes bloquées, % bloqué, clients actifs
```

#### Proxmox (Virtualisation)
```yaml
- Proxmox:
    widget:
      type: proxmox
      url: https://proxmox:8006
      username: api@pam
      password: YOUR_TOKEN
      # Affiche : VMs actives, CPU/RAM cluster
```

**+ 100 intégrations disponibles** : Nextcloud, Home Assistant, qBittorrent, Plex, Nginx Proxy Manager, Authentik, etc.

---

## 🚀 Comment l'utiliser ? (Pas à pas)

### Étape 1 : Accéder à Homepage

1. **Trouve l'IP de ton Pi** :
   ```bash
   hostname -I
   ```
   → Exemple : `192.168.1.100`

2. **Ouvre ton navigateur** :
   ```
   http://192.168.1.100:3000
   ```

3. **Première visite** :
   Tu verras un dashboard par défaut avec :
   - Widget système (CPU, RAM, disque)
   - Quelques services exemples
   - Barre de recherche Google

---

### Étape 2 : Modifier la Configuration

**Option A : Via SSH (nano)**

1. **Connecte-toi à ton Pi** :
   ```bash
   ssh pi@192.168.1.100
   ```

2. **Navigue vers le dossier config** :
   ```bash
   cd ~/stacks/homepage/config
   ls -la
   ```

   Tu verras :
   ```
   settings.yaml    # Paramètres généraux
   services.yaml    # Liste des services
   widgets.yaml     # Widgets
   bookmarks.yaml   # Favoris
   ```

3. **Édite services.yaml** :
   ```bash
   nano services.yaml
   ```

4. **Ajoute ton premier service** :
   ```yaml
   ---
   # Groupe : Mon Homelab
   - Mon Homelab:
       - Portainer:
           icon: portainer
           href: http://192.168.1.100:9000
           description: Gestion Docker

       - Supabase:
           icon: supabase
           href: http://192.168.1.100:8000
           description: Base de données
   ```

5. **Sauvegarde** : `Ctrl+X` → `Y` → `Entrée`

6. **Résultat** : Rafraîchis Homepage → tes services apparaissent immédiatement !

---

**Option B : Via Portainer (interface graphique)**

1. **Ouvre Portainer** : `http://192.168.1.100:9000`
2. **Va dans** : Containers → `homepage`
3. **Clic "Exec Console"** → `/bin/sh`
4. **Édite** :
   ```bash
   cd /app/config
   vi services.yaml  # ou nano si installé
   ```

---

**Option C : Via VSCode Remote SSH (le plus confortable)**

1. **Installe extension** : "Remote - SSH" dans VSCode
2. **Connecte-toi** : `ssh pi@192.168.1.100`
3. **Ouvre dossier** : `~/stacks/homepage/config`
4. **Édite** : Auto-complétion, coloration syntaxe YAML, aperçu instantané

---

### Étape 3 : Ajouter des Widgets

**Exemple : Widgets système + Docker**

1. **Édite widgets.yaml** :
   ```bash
   nano ~/stacks/homepage/config/widgets.yaml
   ```

2. **Ajoute** :
   ```yaml
   ---
   # Première ligne : Recherche + Système
   - search:
       provider: google
       target: _blank

   - resources:
       cpu: true
       memory: true
       disk: /
       uptime: true
       label: Raspberry Pi 5

   # Deuxième ligne : Docker + Météo
   - docker:
       server: my-docker

   - openmeteo:
       label: Paris
       latitude: 48.8566
       longitude: 2.3522
       units: metric
       cache: 5
   ```

3. **Résultat** :
   ```
   ┌─────────────┬─────────────┬─────────────┬─────────────┐
   │ RECHERCHE   │ SYSTÈME     │ DOCKER      │ MÉTÉO       │
   │ [Google___] │ CPU : 18%   │ 12/14 ✅    │ Paris 🌤️   │
   │             │ RAM : 3.2GB │ 2 images    │ 18°C        │
   │             │ Disk: 45GB  │ 8 volumes   │ Nuageux     │
   └─────────────┴─────────────┴─────────────┴─────────────┘
   ```

---

### Étape 4 : Personnaliser l'Apparence

**Exemple : Mode sombre + couleur personnalisée**

1. **Édite settings.yaml** :
   ```bash
   nano ~/stacks/homepage/config/settings.yaml
   ```

2. **Modifie** :
   ```yaml
   ---
   title: Mon Homelab Pi5
   favicon: https://github.com/yourusername.png  # Ta photo GitHub

   theme: dark
   color: slate

   headerStyle: boxed  # ou clean, underlined

   layout:
     Mon Homelab:
       style: row      # Services en ligne
       columns: 4      # 4 colonnes
     Monitoring:
       style: column   # Services en colonne

   quicklaunch:
     searchDescriptions: true
     hideInternetSearch: false
   ```

3. **Options de couleur** :
   - `slate` (gris/bleu foncé)
   - `zinc` (gris neutre)
   - `red` (rouge)
   - `blue` (bleu)
   - `emerald` (vert)
   - `purple` (violet)

---

### Étape 5 : Ajouter des Bookmarks

**Exemple : Liens rapides documentation**

1. **Édite bookmarks.yaml** :
   ```bash
   nano ~/stacks/homepage/config/bookmarks.yaml
   ```

2. **Ajoute** :
   ```yaml
   ---
   - Documentation:
       - Supabase Docs:
           - icon: supabase
             href: https://supabase.com/docs

       - Traefik Docs:
           - icon: traefik
             href: https://doc.traefik.io/traefik/

       - Docker Docs:
           - icon: docker
             href: https://docs.docker.com

   - Communautés:
       - Reddit Homelab:
           - icon: reddit
             href: https://reddit.com/r/homelab

       - Self-Hosted:
           - icon: reddit
             href: https://reddit.com/r/selfhosted
   ```

3. **Résultat** : Section "Bookmarks" en haut avec icônes cliquables.

---

### Étape 6 : Auto-Découverte Docker (Avancé)

**Exemple : Ajouter labels à Supabase**

1. **Édite docker-compose.yml de Supabase** :
   ```bash
   nano ~/stacks/supabase/docker-compose.yml
   ```

2. **Ajoute labels au service studio** :
   ```yaml
   studio:
     image: supabase/studio
     labels:
       - "homepage.group=Databases"
       - "homepage.name=Supabase Studio"
       - "homepage.icon=supabase.png"
       - "homepage.href=http://192.168.1.100:8000"
       - "homepage.description=Backend & Auth"
       - "homepage.weight=1"  # Ordre d'affichage
   ```

3. **Redémarre Supabase** :
   ```bash
   cd ~/stacks/supabase
   docker compose up -d
   ```

4. **Configure docker.yaml dans Homepage** :
   ```bash
   nano ~/stacks/homepage/config/docker.yaml
   ```

   ```yaml
   my-docker:
     socket: /var/run/docker.sock
   ```

5. **Résultat** : Supabase apparaît automatiquement dans Homepage (magie !).

---

## 🛠️ Cas d'Usage Complets

### Exemple 1 : Dashboard Homelab Basique

**Objectif** : Page d'accueil avec services essentiels + monitoring.

**Configuration complète** :

```yaml
# services.yaml
---
- Infrastructure:
    - Portainer:
        icon: portainer
        href: https://portainer.domain.com
        description: Gestion Docker
        widget:
          type: portainer
          url: http://portainer:9000
          env: 1
          key: ptr_YOUR_API_KEY

    - Traefik:
        icon: traefik
        href: https://traefik.domain.com
        description: Reverse Proxy
        widget:
          type: traefik
          url: http://traefik:8080

- Databases:
    - Supabase:
        icon: supabase
        href: https://studio.domain.com
        description: PostgreSQL + Auth + Storage

- Monitoring:
    - Grafana:
        icon: grafana
        href: https://grafana.domain.com
        description: Dashboards
        widget:
          type: grafana
          url: http://grafana:3000
          username: admin
          password: YOUR_PASSWORD
```

```yaml
# widgets.yaml
---
- search:
    provider: duckduckgo
    target: _blank

- resources:
    label: Raspberry Pi 5
    cpu: true
    memory: true
    disk: /
    uptime: true

- docker:
    server: my-docker

- datetime:
    text_size: xl
    format:
      dateStyle: full
      timeStyle: short
      hour12: false
```

**Résultat** : Dashboard professionnel en 5 minutes.

---

### Exemple 2 : Dashboard Média Center

**Objectif** : Interface unifiée pour Plex/Jellyfin + automatisation.

```yaml
# services.yaml
---
- Media:
    - Jellyfin:
        icon: jellyfin
        href: https://jellyfin.domain.com
        widget:
          type: jellyfin
          url: http://jellyfin:8096
          key: YOUR_API_KEY

    - Plex:
        icon: plex
        href: https://plex.domain.com
        widget:
          type: plex
          url: http://plex:32400
          key: YOUR_PLEX_TOKEN

- Automation:
    - Sonarr:
        icon: sonarr
        href: https://sonarr.domain.com
        widget:
          type: sonarr
          url: http://sonarr:8989
          key: YOUR_API_KEY

    - Radarr:
        icon: radarr
        href: https://radarr.domain.com
        widget:
          type: radarr
          url: http://radarr:7878
          key: YOUR_API_KEY

    - qBittorrent:
        icon: qbittorrent
        href: https://qbit.domain.com
        widget:
          type: qbittorrent
          url: http://qbittorrent:8080
          username: admin
          password: YOUR_PASSWORD

- Storage:
    - Nextcloud:
        icon: nextcloud
        href: https://cloud.domain.com
        widget:
          type: nextcloud
          url: http://nextcloud:80
          username: admin
          password: YOUR_PASSWORD
```

**Widgets affichent** :
- Jellyfin : Films/Séries à venir, utilisateurs actifs
- Sonarr/Radarr : Téléchargements en cours, calendrier
- qBittorrent : Vitesse download/upload, ratio

---

### Exemple 3 : Dashboard Domotique

**Objectif** : Intégrer Home Assistant + capteurs IoT.

```yaml
# services.yaml
---
- Domotique:
    - Home Assistant:
        icon: home-assistant
        href: https://ha.domain.com
        widget:
          type: homeassistant
          url: http://homeassistant:8123
          key: YOUR_LONG_LIVED_TOKEN
          custom:
            - state: sensor.temperature_salon
              label: Salon
            - state: sensor.humidity_salon
              label: Humidité

- Sécurité:
    - Frigate:
        icon: frigate
        href: https://frigate.domain.com
        widget:
          type: frigate
          url: http://frigate:5000

    - AdGuard Home:
        icon: adguard-home
        href: https://adguard.domain.com
        widget:
          type: adguard
          url: http://adguard:3000
          username: admin
          password: YOUR_PASSWORD
```

**Widgets affichent** :
- Home Assistant : Température, humidité, état appareils
- Frigate : Détections récentes, flux caméras
- AdGuard : Requêtes bloquées, % publicités filtrées

---

## 📊 Quand utiliser Homepage vs autres solutions ?

| Besoin | Homepage | Alternative |
|--------|----------|-------------|
| **Dashboard simple** | ✅ Parfait | Dashy, Flame, Heimdall |
| **Widgets système** | ✅ Intégré | Netdata, Glances |
| **Intégrations API** | ✅ 100+ services | Organizr (moins) |
| **Auto-découverte Docker** | ✅ Labels automatiques | Homer (manuel) |
| **Légèreté** | ✅ ~50MB RAM | Grafana (~200MB) |
| **Configuration simple** | ✅ YAML | Dashy (JSON/YAML) |
| **Responsive mobile** | ✅ Excellent | Heimdall (ok) |
| **Widgets météo/calendrier** | ✅ Intégré | Homarr (similaire) |
| **Open Source** | ✅ MIT License | Tous |

**Homepage est idéal si** :
- Tu veux un dashboard moderne et rapide
- Tu as plusieurs services à organiser
- Tu veux des widgets de monitoring légers
- Tu préfères YAML à JSON
- Tu utilises Docker (auto-découverte magique)

**Pas idéal si** :
- Tu veux créer des dashboards Grafana complexes (utilise Grafana)
- Tu as besoin d'authentification SSO intégrée (utilise Organizr ou ajoute Authelia)
- Tu veux un dashboard très minimaliste (utilise Flame ou Homer)

---

## 🎓 Apprendre par la pratique

### Tutoriels officiels Homepage
1. **[Quick Start](https://gethomepage.dev/latest/installation/)** - 5 min
2. **[Services Configuration](https://gethomepage.dev/latest/configs/services/)** - 10 min
3. **[Widgets Guide](https://gethomepage.dev/latest/widgets/)** - Tous les widgets disponibles

### Projets débutants recommandés

**Niveau 1 - Facile** (30min - 1h)
- [ ] Ajouter 3-5 services manuellement (Portainer, Supabase, Grafana)
- [ ] Configurer widgets système (CPU, RAM, disque)
- [ ] Changer le thème et la couleur
- [ ] Ajouter des bookmarks (docs, Reddit, GitHub)

**Niveau 2 - Intermédiaire** (2-3h)
- [ ] Configurer auto-découverte Docker (labels)
- [ ] Ajouter widgets API (Portainer, Traefik stats)
- [ ] Intégrer météo et calendrier
- [ ] Créer groupes de services personnalisés
- [ ] Ajouter image de fond et CSS custom

**Niveau 3 - Avancé** (1 jour)
- [ ] Intégrer 10+ services avec widgets API
- [ ] Configurer scripts custom (boutons d'action)
- [ ] Créer layout multi-colonnes complexe
- [ ] Reverse proxy Homepage avec Traefik (HTTPS)
- [ ] Ajouter authentification (Authelia/Authentik)

---

## 🔧 Commandes Utiles

### Voir les logs Homepage
```bash
cd ~/stacks/homepage
docker compose logs -f
```

### Redémarrer Homepage (après modif config)
```bash
docker compose restart
```
**Note** : Normalement pas nécessaire, Homepage recharge automatiquement !

### Vérifier la configuration YAML
```bash
# Valider syntaxe YAML
docker run --rm -v ~/stacks/homepage/config:/config mikefarah/yq e . /config/services.yaml
```

### Sauvegarder ta configuration
```bash
# Backup manuel
tar -czf homepage-config-$(date +%Y%m%d).tar.gz ~/stacks/homepage/config/

# Restaurer
tar -xzf homepage-config-20251004.tar.gz -C ~/
```

### Réinitialiser à la config par défaut
```bash
cd ~/stacks/homepage
docker compose down
rm -rf config/*
docker compose up -d
# Copie les configs par défaut automatiquement
```

### Trouver les icônes disponibles
```bash
# Liste complète : https://github.com/walkxcode/dashboard-icons
# 2000+ icônes : portainer, supabase, grafana, plex, etc.

# Chercher une icône
curl -s https://api.github.com/repos/walkxcode/dashboard-icons/contents/png | grep -i "jellyfin"
```

### Tester une URL de widget
```bash
# Test API Portainer
curl http://localhost:9000/api/status

# Test API Sonarr
curl http://localhost:8989/api/v3/system/status?apikey=YOUR_KEY
```

---

## 🆘 Problèmes Courants

### "Je ne peux pas accéder à Homepage"

**Vérifications** :
1. Homepage est démarré ?
   ```bash
   docker compose ps
   ```
   Doit afficher `Up` pour `homepage`.

2. Le port 3000 est accessible ?
   ```bash
   curl http://localhost:3000
   ```

3. Firewall bloque le port ?
   ```bash
   sudo ufw allow 3000
   sudo ufw status
   ```

**Solution** : Redémarre Homepage :
```bash
cd ~/stacks/homepage
docker compose restart
```

---

### "Mes modifications de config n'apparaissent pas"

**Cause** : Erreur de syntaxe YAML ou cache navigateur.

**Vérifications** :
1. Syntaxe YAML correcte ?
   ```bash
   # Les espaces comptent ! Indentation = 2 ou 4 espaces (pas tabs)
   # INCORRECT :
   - Mon Service:
   	href: http://...  # TAB utilisé ❌

   # CORRECT :
   - Mon Service:
       href: http://...  # 4 espaces ✅
   ```

2. Vide le cache du navigateur : `Ctrl+Shift+R` (Chrome/Firefox)

3. Regarde les logs :
   ```bash
   docker compose logs homepage
   # Cherche "ERROR" ou "WARNING"
   ```

**Solution** : Valide ton YAML avec un outil en ligne (yamllint.com) ou :
```bash
docker run --rm -v $(pwd)/config:/config mikefarah/yq e . /config/services.yaml
```

---

### "Widgets ne s'affichent pas / Erreur API"

**Causes courantes** :
1. **URL incorrecte** :
   ```yaml
   # INCORRECT :
   url: http://portainer  # Hostname seul

   # CORRECT :
   url: http://portainer:9000  # Avec port
   ```

2. **API Key invalide** :
   ```bash
   # Récupère la vraie clé depuis Portainer :
   # Settings → API Access → Create Access Token
   ```

3. **Service pas accessible depuis Homepage** :
   ```bash
   # Teste depuis le conteneur Homepage
   docker exec homepage wget -O- http://portainer:9000/api/status
   # Doit retourner du JSON
   ```

**Solution** :
1. Vérifie que les conteneurs sont sur le même réseau Docker
2. Utilise le nom du service Docker (pas localhost)
3. Regarde les logs du widget :
   ```bash
   docker compose logs homepage | grep -i "error"
   ```

---

### "Icône ne s'affiche pas"

**Causes** :
1. Nom d'icône incorrect :
   ```yaml
   # INCORRECT :
   icon: portainer.png  # Pas besoin de .png

   # CORRECT :
   icon: portainer
   # ou
   icon: si-portainer  # Simple Icons (préfixe si-)
   # ou
   icon: https://example.com/logo.png  # URL custom
   ```

2. Icône n'existe pas dans la bibliothèque.

**Solution** : Cherche les icônes disponibles :
- **Dashboard Icons** : https://github.com/walkxcode/dashboard-icons/tree/main/png
- **Simple Icons** : https://simpleicons.org (préfixe `si-`)
- **Custom** : Héberge ton image et utilise l'URL complète

---

### "Auto-découverte Docker ne fonctionne pas"

**Vérifications** :
1. docker.yaml est configuré ?
   ```yaml
   # config/docker.yaml
   my-docker:
     socket: /var/run/docker.sock
   ```

2. Homepage a accès au socket Docker ?
   ```yaml
   # docker-compose.yml
   volumes:
     - /var/run/docker.sock:/var/run/docker.sock:ro  # ← Doit être présent
   ```

3. Les labels sont corrects ?
   ```yaml
   # Conteneur cible
   labels:
     - "homepage.group=Infrastructure"
     - "homepage.name=Mon Service"
     - "homepage.icon=service-icon"
     - "homepage.href=http://service:8080"
   ```

**Solution** :
```bash
# Redémarre Homepage après ajout de labels
cd ~/stacks/homepage
docker compose restart

# Vérifie les labels d'un conteneur
docker inspect portainer | grep homepage
```

---

### "Performance lente / Homepage rame"

**Causes** :
1. Trop de widgets API (chacun fait des requêtes)
2. Cache désactivé
3. Intervalles de rafraîchissement trop courts

**Solutions** :
1. Augmente le cache des widgets :
   ```yaml
   - openmeteo:
       cache: 60  # 60 minutes au lieu de 5
   ```

2. Désactive les widgets API non critiques

3. Utilise des images optimisées :
   ```yaml
   # settings.yaml
   background: /images/bg-compressed.jpg  # < 500KB
   ```

4. Vérifie les ressources Pi :
   ```bash
   htop  # CPU/RAM usage
   ```

---

## 📚 Ressources pour Débutants

### Documentation
- **[Homepage Docs](https://gethomepage.dev)** - Officielle, excellente
- **[Services List](https://gethomepage.dev/latest/configs/services/)** - Tous les widgets disponibles
- **[YAML Tutorial](https://yaml.org/start.html)** - Apprendre YAML en 5 min
- **[Dashboard Icons](https://github.com/walkxcode/dashboard-icons)** - 2000+ icônes

### Vidéos YouTube
- "Homepage Dashboard in 100 Seconds" - Techno Tim (2 min)
- "Ultimate Homepage Setup Guide" - DBTech (20 min)
- "Self-Hosted Dashboard Comparison" - Wolfgang's Channel (15 min)

### Exemples de configurations
- **[Awesome Homepage](https://github.com/benphelps/homepage/discussions/categories/show-and-tell)** - Configs partagées par la communauté
- **[r/selfhosted](https://reddit.com/r/selfhosted)** - Posts "My Homepage setup"

### Communautés
- [Discord Homepage](https://discord.gg/homepage) - Support communautaire
- [r/selfhosted](https://reddit.com/r/selfhosted) - Reddit
- [GitHub Discussions](https://github.com/benphelps/homepage/discussions)

---

## 🎯 Prochaines Étapes

Une fois à l'aise avec Homepage :

1. **Intégrer avec Traefik (HTTPS)** :
   ```bash
   # Ajoute Homepage au reverse proxy
   sudo ~/pi5-setup/pi5-traefik-stack/scripts/integrate-service.sh
   ```
   → Accès via `https://home.domain.com`

2. **Ajouter authentification SSO** → Authelia/Authentik (Phase 9)

3. **Backup automatique de la config** :
   ```bash
   # Cron job quotidien
   0 2 * * * tar -czf /backups/homepage-$(date +\%Y\%m\%d).tar.gz ~/stacks/homepage/config/
   ```

4. **Créer des widgets custom** → [API Docs](https://gethomepage.dev/latest/widgets/services/)

5. **Explorer intégrations avancées** :
   - Home Assistant (domotique)
   - Proxmox (virtualisation)
   - Unifi Controller (réseau)
   - N8n (automatisation)

---

## ✅ Checklist Maîtrise Homepage

**Niveau Débutant** :
- [ ] J'ai accédé à Homepage via le navigateur
- [ ] J'ai ajouté 3-5 services manuellement
- [ ] J'ai configuré les widgets système (CPU, RAM)
- [ ] J'ai changé le thème et la couleur
- [ ] Je comprends la structure YAML

**Niveau Intermédiaire** :
- [ ] J'ai configuré l'auto-découverte Docker
- [ ] J'ai ajouté des widgets API (Portainer, Sonarr, etc.)
- [ ] J'ai intégré météo et calendrier
- [ ] J'ai créé des bookmarks personnalisés
- [ ] J'ai configuré le layout (colonnes, groupes)

**Niveau Avancé** :
- [ ] J'ai intégré 10+ services avec widgets
- [ ] J'ai configuré Homepage derrière Traefik (HTTPS)
- [ ] J'ai ajouté du CSS custom
- [ ] J'ai créé des scripts de backup automatiques
- [ ] J'ai exploré les API custom pour créer mes propres widgets

---

**Besoin d'aide ?** Consulte la [documentation complète](https://gethomepage.dev) ou pose tes questions sur le [Discord Homepage](https://discord.gg/homepage) !

🎉 **Bon dashboarding !**
