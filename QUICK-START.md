# 🚀 Quick Start

> Installation rapide du setup Pi5 production

**Temps** : 1h30 | **RAM finale** : 2.5 GB / 16 GB

---

## Setup de Base (8 étapes)

### 1. Flasher Raspberry Pi OS

- [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
- OS : **Raspberry Pi OS 64-bit Bookworm**
- Config SSH + user `pi` + hostname `pi5-homelab`

### 2. Connexion SSH

```bash
ssh pi@192.168.1.XXX
```

### 3. Prérequis (Docker + Sécurité)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/01-prerequisites-setup.sh | sudo bash
```

⏳ 20 min → **Reboot** → Reconnecter SSH

### 4. Supabase (Backend)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash
```

⏳ 20 min → **Sauvegarder les credentials affichés**

### 5. Traefik (HTTPS)

**Choisir UN scénario** :

```bash
# DuckDNS (gratuit)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash

# OU Cloudflare (domaine perso)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-cloudflare.sh | sudo bash

# OU VPN Tailscale (privé)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-vpn.sh | sudo bash
```

⏳ 15 min

### 6. Intégration Supabase

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
```

⏳ 2 min

### 7. Homepage (Dashboard)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash
```

⏳ 5 min

### 8. Sauvegardes auto

```bash
sudo ~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-scheduler.sh
```

⏳ 3 min → Choisir option **1** (Daily)

---

## ✅ Terminé

| Service | URL |
|---------|-----|
| Homepage | `https://VOTRE_DOMAINE/` |
| Supabase Studio | `https://VOTRE_DOMAINE/studio` |
| Supabase API | `https://VOTRE_DOMAINE/api` |
| Traefik | `https://VOTRE_DOMAINE/traefik` |
| Portainer | `http://IP:8080` |

---

## Stacks Additionnels

```bash
# Monitoring (Grafana)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash

# VPN Tailscale
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vpn-wireguard/scripts/01-tailscale-setup.sh | sudo bash

# Git + CI/CD (Gitea)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/01-gitea-deploy.sh | sudo bash

# Backups Cloud
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/01-rclone-setup.sh | sudo bash

# Cloud Storage (FileBrowser)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/01-filebrowser-deploy.sh | sudo bash

# Media Server (Jellyfin)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/01-jellyfin-deploy.sh | sudo bash

# SSO + 2FA (Authelia)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/authelia/scripts/01-authelia-deploy.sh | sudo bash

# Domotique (Home Assistant)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/01-homeassistant-deploy.sh | sudo bash
```

---

## Gestion

```bash
# Stack Manager (start/stop services)
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh interactive

# Voir RAM utilisée
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh status
```

---

## Docs Complètes

- [Installation détaillée](INSTALLATION-COMPLETE.md)
- [Tous les stacks](ROADMAP.md)
- [Architecture](ARCHITECTURE.md)
- [Troubleshooting](INSTALLATION-COMPLETE.md#🆘-problèmes-courants)
