# 🛡️ Infrastructure & Réseau

> **Catégorie** : Infrastructure de base pour le serveur Raspberry Pi 5

---

## 📦 Stacks Inclus

### 1. [Supabase](supabase/)
**Backend-as-a-Service Open Source**

- 🗄️ PostgreSQL 15 (ARM64 optimisé)
- 🔐 Auth (GoTrue) - Authentification complète
- 🌐 REST API (PostgREST) - API auto-générée
- ⚡ Realtime - WebSocket subscriptions
- 📁 Storage - Stockage fichiers S3-compatible
- 🎛️ Studio UI - Interface d'administration

**RAM** : ~1.2 GB
**Ports** : 5432 (PostgreSQL), 54321 (API), 54323 (Auth), 54324 (Storage)

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/01-prerequisites-setup.sh | sudo bash
# (reboot)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash
```

---

### 2. [Traefik](traefik/)
**Reverse Proxy Moderne avec HTTPS Automatique**

- 🔒 HTTPS automatique (Let's Encrypt)
- 🔄 Reverse proxy intelligent
- 📊 Dashboard intégré
- 🌐 3 scénarios : DuckDNS / Cloudflare / VPN

**RAM** : ~100 MB
**Ports** : 80 (HTTP), 443 (HTTPS), 8080 (Dashboard)

**Scénarios** :
1. **DuckDNS** (gratuit, débutants) : `https://monpi.duckdns.org`
2. **Cloudflare** (domaine perso) : `https://studio.mondomaine.fr`
3. **VPN** (privé, sécurité max) : `https://studio.pi.local`

**Installation** :
```bash
# Scénario 1 : DuckDNS
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash

# Scénario 2 : Cloudflare
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-cloudflare.sh | sudo bash

# Scénario 3 : VPN
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-vpn.sh | sudo bash
```

---

### 3. [VPN WireGuard](vpn-wireguard/)
**VPN Sécurisé pour Accès à Distance**

- 🔐 Accès sécurisé à distance
- 🌍 2 options : Tailscale (géré) ou WireGuard (self-hosted)
- ⚡ Performance optimale
- 📱 Apps mobiles/desktop disponibles

**RAM** : ~50 MB
**Ports** : Variable selon scénario (Tailscale : 41641 UDP, WireGuard : 51820 UDP)

**Installation** :
```bash
# Option 1 : Tailscale (recommandé, gratuit, facile)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vpn-wireguard/scripts/01-tailscale-setup.sh | sudo bash

# Option 2 : WireGuard self-hosted
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vpn-wireguard/scripts/02-wireguard-setup.sh | sudo bash
```

---

## 📊 Statistiques Catégorie

| Métrique | Valeur |
|----------|--------|
| **Nombre de stacks** | 3 |
| **RAM totale (tous actifs)** | ~1.35 GB |
| **Complexité** | ⭐⭐⭐ (Modérée) |
| **Priorité** | 🔴 **CRITIQUE** (infrastructure de base) |
| **Ordre installation** | 1. Supabase → 2. Traefik → 3. VPN (optionnel) |

---

## 🔗 Liens Utiles

- [ROADMAP.md](../ROADMAP.md) - Vue d'ensemble du projet
- [INSTALLATION-COMPLETE.md](../INSTALLATION-COMPLETE.md) - Guide installation complet
- [FIREWALL-FAQ.md](../FIREWALL-FAQ.md) - Configuration pare-feu
- [Stack Manager](../common-scripts/STACK-MANAGER.md) - Gestion des stacks

---

## 💡 Notes

- **Supabase** est le fondement de votre stack backend
- **Traefik** gère l'accès HTTPS à toutes vos applications
- **VPN** est optionnel mais recommandé pour la sécurité maximale
- Ces 3 stacks forment la base de tout le projet pi5-setup
