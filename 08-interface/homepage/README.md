# 🏠 Pi5 Homepage Stack - Dashboard Central

> **Portail d'accueil moderne pour accéder à tous vos services**

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](CHANGELOG.md)
[![Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.com/)
[![Homepage](https://img.shields.io/badge/Homepage-Latest-green.svg)](https://gethomepage.dev/)

---

## 🎯 Vue d'Ensemble

Homepage est un **dashboard moderne et rapide** qui centralise l'accès à tous vos services self-hosted.

### 🤔 Pourquoi Homepage ?

**Sans Homepage** :
```
Vous devez retenir :
- http://192.168.1.100:8000/studio    → Supabase
- https://monpi.duckdns.org/traefik   → Traefik
- http://192.168.1.100:8080           → Portainer
- https://grafana.monpi.fr            → Grafana
... et 10+ autres URLs
```

**Avec Homepage** :
```
Une seule URL :
→ https://monpi.fr (ou monpi.duckdns.org)

Affiche un beau dashboard avec :
✅ Tous vos services cliquables
✅ Stats système (CPU, RAM, disque)
✅ Monitoring Docker en temps réel
✅ Bookmarks vers documentation
```

---

## ✨ Fonctionnalités

### Services Détectés Automatiquement
- ✅ **Supabase** (Studio + API)
- ✅ **Traefik** Dashboard
- ✅ **Portainer** (si installé)
- ✅ **Grafana** (Phase 3, si installé)
- ✅ **Gitea** (Phase 5, si installé)
- ✅ Tous vos containers Docker

### Widgets Système
- 📊 **CPU** - Utilisation en temps réel
- 💾 **RAM** - Mémoire disponible/utilisée
- 💿 **Disque** - Espace utilisé/libre
- 🌡️ **Température** - Monitoring Pi 5
- ⏱️ **Uptime** - Temps de fonctionnement
- 🐳 **Docker** - Containers running/stopped

### Personnalisation
- 🎨 **Thèmes** : Dark, light, nord, catppuccin, dracula
- 🖼️ **Layout** : Colonnes, espacement, taille widgets
- 🔖 **Bookmarks** : Documentation, GitHub, liens utiles
- 🌐 **Intégrations** : 100+ services supportés (Sonarr, Radarr, Pi-hole, etc.)

---

## 📦 Installation

### Prérequis
- [x] Raspberry Pi 5 avec Docker installé
- [x] Traefik installé ([Phase 2](../pi5-traefik-stack/))
- [x] Scénario Traefik choisi (DuckDNS, Cloudflare, ou VPN)

### Installation Rapide

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homepage-stack/scripts/01-homepage-deploy.sh | sudo bash
```

**Le script va** :
1. Détecter votre scénario Traefik automatiquement
2. Détecter tous vos services installés (Supabase, Portainer, Grafana, etc.)
3. Générer la configuration Homepage personnalisée
4. Configurer les labels Traefik appropriés
5. Lancer Homepage dans Docker
6. Afficher l'URL d'accès

**Durée** : ~3-5 min

---

## 🚀 Accès

### Scénario DuckDNS
```
https://monpi.duckdns.org
```
(Homepage sur le chemin racine `/`)

### Scénario Cloudflare
```
https://monpi.fr              → Homepage (domaine racine)
https://home.monpi.fr         → Homepage (sous-domaine)
```

### Scénario VPN
```
https://pi.local              → Homepage
https://home.pi.local         → Homepage
```

---

## ⚙️ Configuration

### Structure des Fichiers

```
/home/pi/stacks/homepage/
├── docker-compose.yml
├── config/
│   ├── services.yaml      # Liste des services
│   ├── widgets.yaml       # Widgets système
│   ├── settings.yaml      # Apparence, thème
│   └── bookmarks.yaml     # Liens favoris
└── logs/
```

### Modifier la Configuration

**Option 1 : Via SSH**
```bash
cd /home/pi/stacks/homepage/config
nano services.yaml
# Ctrl+O pour sauvegarder, Ctrl+X pour quitter
```

**Option 2 : Via Portainer**
1. Ouvrir Portainer
2. Volumes → `homepage_config`
3. Browse → Éditer les fichiers YAML

**Option 3 : VSCode Remote SSH**
1. Connecter VSCode à votre Pi via SSH
2. Ouvrir `/home/pi/stacks/homepage/config/`
3. Éditer avec syntax highlighting YAML

**Changes are live** : Homepage recharge automatiquement la config (max 30s).

---

## 🎨 Personnalisation

### Ajouter un Service Manuellement

**Éditer** `services.yaml` :

```yaml
- Mes Apps:
    - Mon Application:
        href: https://monapp.monpi.fr
        description: Description de mon app
        icon: https://monapp.monpi.fr/favicon.ico
        widget:
          type: customapi
          url: https://monapp.monpi.fr/api/stats
          mappings:
            - field: users
              label: Users
```

### Changer le Thème

**Éditer** `settings.yaml` :

```yaml
color: slate          # slate, gray, zinc, neutral, stone
theme: dark           # dark ou light
headerStyle: clean    # clean, boxed, underlined
```

**Thèmes disponibles** : `slate`, `gray`, `zinc`, `neutral`, `stone`, `red`, `orange`, `amber`, `yellow`, `lime`, `green`, `emerald`, `teal`, `cyan`, `sky`, `blue`, `indigo`, `violet`, `purple`, `fuchsia`, `pink`, `rose`

### Ajouter des Widgets

**Éditer** `widgets.yaml` :

```yaml
- resources:
    cpu: true
    memory: true
    disk: /
    cputemp: true
    uptime: true
    units: metric

- search:
    provider: duckduckgo
    target: _blank

- datetime:
    text_size: xl
    format:
      dateStyle: long
      timeStyle: short
```

**Widgets disponibles** : resources, search, datetime, openmeteo (météo), unifi, glances, docker, kubernetes, etc.

---

## 🐳 Auto-Discovery Docker

Homepage peut **détecter automatiquement** vos containers Docker et afficher leurs stats.

### Activer pour un Container

**Ajouter labels** dans le `docker-compose.yml` du service :

```yaml
services:
  mon-service:
    image: monimage:latest
    labels:
      - "homepage.group=Mes Apps"
      - "homepage.name=Mon Service"
      - "homepage.icon=monicon.png"
      - "homepage.href=https://monservice.monpi.fr"
      - "homepage.description=Description courte"
      - "homepage.widget.type=customapi"
      - "homepage.widget.url=https://monservice.monpi.fr/api/stats"
```

**Redémarrer le container** :
```bash
docker compose up -d
```

Homepage détectera automatiquement le service ! ✨

---

## 📊 Widgets Intégrés

### Exemples de Widgets Populaires

**Sonarr** (TV Shows) :
```yaml
- Sonarr:
    href: https://sonarr.monpi.fr
    widget:
      type: sonarr
      url: https://sonarr.monpi.fr
      key: votre_api_key
```

**Radarr** (Movies) :
```yaml
- Radarr:
    href: https://radarr.monpi.fr
    widget:
      type: radarr
      url: https://radarr.monpi.fr
      key: votre_api_key
```

**Pi-hole** (DNS/Ad blocking) :
```yaml
- Pi-hole:
    href: https://pihole.monpi.fr
    widget:
      type: pihole
      url: https://pihole.monpi.fr
      key: votre_api_key
```

**Portainer** (Docker UI) :
```yaml
- Portainer:
    href: https://portainer.monpi.fr
    widget:
      type: portainer
      url: https://portainer.monpi.fr
      env: 1
      key: votre_api_key
```

**100+ services supportés** : Voir [liste complète](https://gethomepage.dev/latest/widgets/)

---

## 🆘 Troubleshooting

### "Cannot access Homepage"

**Vérifier container** :
```bash
docker ps | grep homepage
```

**Vérifier logs** :
```bash
docker logs homepage -f
```

**Redémarrer** :
```bash
cd /home/pi/stacks/homepage
docker compose restart
```

---

### "Config changes not appearing"

Homepage met jusqu'à **30 secondes** pour recharger la config.

**Forcer reload** :
```bash
docker restart homepage
```

**Vérifier syntax YAML** :
```bash
# Installer yamllint
sudo apt install yamllint

# Valider
yamllint /home/pi/stacks/homepage/config/*.yaml
```

---

### "Widgets not updating"

**Cause** : URL ou API key incorrecte

**Solution** :
1. Vérifier URL du widget (doit être accessible depuis le container)
2. Vérifier API key
3. Voir logs : `docker logs homepage | grep -i error`

---

### "Icons not showing"

**Cause** : Icône introuvable

**Solutions** :
- Utiliser icônes built-in : [Liste](https://github.com/walkxcode/dashboard-icons)
- URL complète : `icon: https://example.com/icon.png`
- mdi icons : `icon: mdi-rocket`

---

## 📚 Documentation Complète

### 🎓 Pour Débutants
👉 **[GUIDE DÉBUTANT](homepage-guide.md)** - Tout savoir sur Homepage en 15 min
- C'est quoi Homepage ? (analogies simples)
- Use cases concrets
- Configuration pas-à-pas
- Exemples de dashboards
- Personnalisation avancée

### 📖 Documentation Technique
- [Installation Rapide](homepage-setup.md)
- [Homepage Docs Officielles](https://gethomepage.dev/)
- [Widgets Disponibles](https://gethomepage.dev/latest/widgets/)
- [Configuration YAML](https://gethomepage.dev/latest/configs/)

---

## 💡 Exemples de Dashboards

### Homelab Basique
```
┌─────────────────────────────────────┐
│  Homepage - My Homelab              │
├─────────────────────────────────────┤
│ 📊 System Stats                     │
│ CPU: 15%  RAM: 4.2GB  Disk: 45%    │
├─────────────────────────────────────┤
│ Infrastructure                      │
│  • Traefik Dashboard                │
│  • Portainer (Docker)               │
├─────────────────────────────────────┤
│ Databases                           │
│  • Supabase Studio                  │
│  • Supabase API                     │
├─────────────────────────────────────┤
│ Monitoring                          │
│  • Grafana                          │
└─────────────────────────────────────┘
```

### Media Center
```
┌─────────────────────────────────────┐
│ Media Center                        │
├─────────────────────────────────────┤
│ Streaming                           │
│  • Jellyfin (Movies: 245, Shows: 87)│
│  • Plex (Watching: 3 users)        │
├─────────────────────────────────────┤
│ Downloads                           │
│  • Sonarr (Queue: 5)                │
│  • Radarr (Queue: 3)                │
│  • qBittorrent (↓ 5MB/s, ↑ 1MB/s)  │
├─────────────────────────────────────┤
│ Search                              │
│  • Prowlarr                         │
│  • Jackett                          │
└─────────────────────────────────────┘
```

---

## 🔐 Sécurité

### Recommandations

**✅ Activé par défaut** :
- HTTPS via Traefik
- Pas d'exposition directe (derrière reverse proxy)

**✅ Recommandé** :
- Activer Authelia/Authentik (SSO + 2FA) - Phase 9
- Restricter accès par IP (si VPN)
- Ne pas exposer publiquement sans auth

**Configuration Authelia** (exemple) :
```yaml
# Dans Traefik labels
- "traefik.http.routers.homepage.middlewares=authelia@docker"
```

---

## 📊 Performances

### Consommation Ressources
- **RAM** : ~50-80 MB
- **CPU** : <1% (idle), 2-5% (refresh widgets)
- **Disk** : ~100 MB (image Docker)

### Latence
- **Chargement page** : ~200-500ms
- **Refresh widgets** : Toutes les 15-60s (configurable)

---

## 🎯 Prochaines Étapes

Une fois Homepage installé :

1. **Personnaliser** :
   - Changer thème
   - Ajouter vos propres services
   - Configurer widgets

2. **Sécuriser** (optionnel) :
   - Activer Authelia (SSO + 2FA) - Phase 9
   - Configurer Cloudflare Access (si Cloudflare)

3. **Automatiser** (avancé) :
   - Script pour backup config
   - Git pour versionner config YAML
   - CI/CD pour déployer config

---

## 🤝 Ressources

### Documentation
- [Homepage Docs](https://gethomepage.dev/)
- [Liste Widgets](https://gethomepage.dev/latest/widgets/)
- [Configuration Services](https://gethomepage.dev/latest/configs/services/)

### Communautés
- [GitHub Homepage](https://github.com/gethomepage/homepage)
- [r/selfhosted](https://reddit.com/r/selfhosted)
- [Discord Homepage](https://discord.gg/homepage)

### Inspirations
- [Reddit r/homelab](https://reddit.com/r/homelab) - Voir dashboards d'autres users
- [GitHub Awesome Selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted)

---

**Dernière mise à jour** : 2025-10-04
**Version** : 1.0
**Mainteneur** : [@iamaketechnology](https://github.com/iamaketechnology)
