# ⚡ Installation Rapide - Uptime Kuma

> **Installation directe via SSH**

---

## 🚀 Installation en 1 Commande

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/uptime-kuma/scripts/01-uptime-kuma-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ Uptime Kuma (serveur de monitoring)

**Durée :** ~3 minutes

---

## ✅ Vérification Installation

### Vérifier le service
```bash
cd ~/stacks/uptime-kuma
docker compose ps
# Le service doit être "Up"
```

### Accéder à l'interface web
L'URL dépend de votre configuration Traefik :
- **Avec Traefik (Cloudflare)** : `https://uptime.VOTRE-DOMAINE.com`
- **Avec Traefik (DuckDNS)** : `https://VOTRE-SOUS-DOMAINE.duckdns.org/uptime`
- **Sans Traefik** : `http://<IP-DU-PI>:3001`

L'URL exacte est affichée à la fin du script d'installation.

---

## 👤 Configuration Initiale

1.  **Ouvrez l'interface web** d'Uptime Kuma.
2.  Uptime Kuma vous guidera pour **créer un compte administrateur**.
3.  Choisissez votre langue, un nom d'utilisateur et un mot de passe.
4.  Cliquez sur "Créer".

Vous êtes maintenant sur le tableau de bord principal.

---

##  монитор Premier Moniteur

1.  Sur le tableau de bord, cliquez sur le bouton **"+ Ajouter un nouveau moniteur"**.
2.  **Type de moniteur** : Choisissez "HTTP(s)" pour un site web.
3.  **Nom Convivial** : Donnez un nom facile à retenir (ex: "Mon Blog").
4.  **URL** : Entrez l'adresse complète du site ou service à surveiller (ex: `https://google.com`).
5.  Cliquez sur **"Enregistrer"** en bas de la page.

Après quelques secondes, votre moniteur apparaîtra sur le tableau de bord avec son statut (Vert = en ligne, Rouge = en panne).

---

## 📚 Documentation Complète

- [Guide Débutant](uptime-kuma-guide.md) - Pour apprendre à configurer des alertes et des pages de statut.
- [README.md](README.md) - Vue d'ensemble du stack.
