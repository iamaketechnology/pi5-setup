# ⚡ Quick Start - Installation en 1 commande

Choisissez votre option et copiez-collez la commande correspondante sur votre Raspberry Pi.

---

## 🚀 Option 1 : Port Forwarding + Traefik

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/VOTRE-REPO/pi5-setup/main/01-infrastructure/external-access/option1-port-forwarding/scripts/01-setup-port-forwarding.sh | bash
```

**Après installation** :
1. Suivez le guide pour configurer votre routeur
2. Accédez à : `https://VOTRE-DOMAINE.duckdns.org/studio`

---

## ☁️ Option 2 : Cloudflare Tunnel

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/VOTRE-REPO/pi5-setup/main/01-infrastructure/external-access/option2-cloudflare-tunnel/scripts/01-setup-cloudflare-tunnel.sh | bash
```

**Après installation** :
1. Suivez les instructions OAuth dans le terminal
2. Accédez à : `https://studio.VOTRE-DOMAINE.com`

---

## 🔐 Option 3 : Tailscale VPN (RECOMMANDÉ)

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/VOTRE-REPO/pi5-setup/main/01-infrastructure/external-access/option3-tailscale-vpn/scripts/01-setup-tailscale.sh | bash
```

**Après installation** :
1. Suivez l'authentification dans le navigateur
2. Installez Tailscale sur vos autres appareils : https://tailscale.com/download
3. Accédez à : `http://100.x.x.x:3000` (IP affichée dans le terminal)

---

## 📖 Documentation complète

- **README** : [Guide principal](README.md)
- **COMPARISON** : [Tableau comparatif détaillé](COMPARISON.md)
- **SUMMARY** : [Résumé installation](INSTALLATION-SUMMARY.md)

---

## ❓ Besoin d'aide pour choisir ?

Répondez à cette question :

**Qui doit accéder à votre instance Supabase ?**
- 🔐 **Seulement vous/votre équipe** → **Option 3** (Tailscale)
- 🌍 **N'importe qui sur Internet** → **Option 1** ou **2**

**Votre routeur est-il accessible ?**
- ✅ **Oui** → **Option 1** (performance max)
- ❌ **Non** → **Option 2** (sécurité max)

---

**🏆 Recommandation : Commencez avec Option 3 (Tailscale) !**
