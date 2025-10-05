# 🎛️ Interface & Dashboard

> **Catégorie** : Portail d'accueil et dashboards centralisés

---

## 📦 Stacks Inclus

### 1. [Homepage](homepage/)
**Dashboard Centralisé pour Toutes Vos Applications**

#### ✨ Fonctionnalités

- 📊 **Auto-détection services** : Supabase, Traefik, Portainer, Grafana, etc.
- 📈 **Widgets système** : CPU, RAM, disk, température, uptime, Docker stats
- 🎨 **Thèmes** : 10+ thèmes (dark, light, nord, catppuccin, dracula, etc.)
- 🔖 **Bookmarks** : Documentation, GitHub, Docker Hub
- 🔌 **100+ intégrations API** : Sonarr, Radarr, Pi-hole, Proxmox, etc.
- ⚡ **Léger** : ~50-80 MB RAM
- 🔄 **Live reload** : Config YAML rechargée automatiquement (30s)

**RAM** : ~80 MB
**Port** : 3001 (ou / selon scénario Traefik)

---

## 🚀 Installation

**Installation automatique** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash
```

**Le script détecte automatiquement** :
- ✅ Scénario Traefik (DuckDNS / Cloudflare / VPN)
- ✅ Services installés (Supabase, Grafana, Jellyfin, etc.)
- ✅ Génère config YAML personnalisée

**Résultat selon scénario** :
- **DuckDNS** : `https://monpi.duckdns.org` (chemin racine `/`)
- **Cloudflare** : `https://monpi.fr` ou `https://home.monpi.fr`
- **VPN** : `https://pi.local` ou `https://home.pi.local`
- **Sans Traefik** : `http://raspberrypi.local:3001`

---

## 🎨 Configuration

### Structure fichiers
```
/home/pi/stacks/homepage/config/
├── services.yaml    # Applications affichées
├── widgets.yaml     # Widgets système
├── settings.yaml    # Thème + langue
└── bookmarks.yaml   # Liens favoris
```

### Exemple services.yaml
```yaml
- Domotique:
    - Home Assistant:
        href: http://raspberrypi.local:8123
        description: Hub domotique
        icon: home-assistant.png
        widget:
          type: homeassistant
          url: http://raspberrypi.local:8123
          key: YOUR_LONG_LIVED_ACCESS_TOKEN
```

### Widgets système disponibles
```yaml
- resources:
    cpu: true
    memory: true
    disk: /
    cputemp: true
    uptime: true

- search:
    provider: duckduckgo
    target: _blank
```

---

## 🔌 Intégrations API Populaires

| Service | Widget | Données affichées |
|---------|--------|-------------------|
| **Sonarr** | ✅ | Séries manquantes, calendrier |
| **Radarr** | ✅ | Films manquants, calendrier |
| **Jellyfin** | ✅ | Streams actifs, bibliothèque |
| **Portainer** | ✅ | Containers running/stopped |
| **Traefik** | ✅ | Routers, services status |
| **Pi-hole** | ✅ | Queries, % bloqué |
| **Gitea** | ✅ | Repos, issues, PRs |
| **Nextcloud** | ✅ | Stockage utilisé |

[Voir toutes les 100+ intégrations](https://gethomepage.dev/en/widgets/)

---

## 📊 Statistiques Catégorie

| Métrique | Valeur |
|----------|--------|
| **Nombre de stacks** | 1 |
| **RAM totale** | ~80 MB |
| **Complexité** | ⭐ (Facile) |
| **Priorité** | 🟡 **RECOMMANDÉ** (UX améliorée) |
| **Ordre installation** | Phase 2b (après Traefik optionnel) |

---

## 🎯 Cas d'Usage

### Scénario 1 : Portail Famille
Dashboard unique pour accéder à :
- Jellyfin (films/séries)
- Nextcloud (fichiers)
- Home Assistant (domotique)

### Scénario 2 : Dashboard Monitoring
Vue d'ensemble serveur :
- Widgets système (CPU, RAM, température)
- Grafana dashboards intégrés
- Uptime Kuma status

### Scénario 3 : Dev Team Portal
Accès équipe développement :
- Gitea (repos Git)
- Portainer (containers)
- Grafana (métriques apps)

---

## 🎨 Thèmes Disponibles

- `dark` (défaut)
- `light`
- `nord`
- `catppuccin-mocha`
- `dracula`
- `gruvbox-dark`
- `solarized-dark`
- Et 10+ autres...

**Changer thème** : Éditer `settings.yaml` :
```yaml
color: slate
theme: dark
```

---

## 💡 Notes

- **Homepage** détecte automatiquement vos services installés
- Configuration YAML simple (pas de code)
- Live reload : modifications visibles après 30s max
- Accessible depuis mobile/tablette (responsive)
- Peut remplacer navigateur "favoris" pour serveur
