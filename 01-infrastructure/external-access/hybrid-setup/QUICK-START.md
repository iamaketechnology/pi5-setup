# ⚡ Quick Start - Configuration Hybride

## Installation en 1 commande

```bash
curl -fsSL https://raw.githubusercontent.com/VOTRE-REPO/pi5-setup/main/01-infrastructure/external-access/hybrid-setup/scripts/01-setup-hybrid-access.sh | bash
```

## Ce que vous aurez après installation

### 3 méthodes d'accès à votre Supabase :

```
🏠 Local      : http://192.168.1.100:3000       (0ms, ultra-rapide)
🌍 Public     : https://monpi.duckdns.org       (HTTPS sécurisé)
🔐 VPN        : http://100.x.x.x:3000           (chiffré bout-en-bout)
```

## Utilisation selon le contexte

| Vous êtes... | Utilisez | URL |
|--------------|----------|-----|
| 🏠 À la maison | Local | `http://192.168.1.100:3000` |
| ✈️ En voyage | VPN | `http://100.x.x.x:3000` |
| 👥 Partage avec ami | Public | `https://monpi.duckdns.org` |

## Durée d'installation

⏱️ **30-35 minutes** (dont 5 min de configuration routeur)

## Prérequis

- ✅ Raspberry Pi 5 avec Supabase
- ✅ Accès routeur (pour Port Forwarding)
- ✅ Compte Tailscale gratuit

---

**🚀 Lancez l'installation maintenant !**
