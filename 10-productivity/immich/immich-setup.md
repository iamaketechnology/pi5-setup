# ⚡ Installation Rapide - Immich

> **Installation directe via SSH**

---

## 🚀 Installation en 1 Commande

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/immich/scripts/01-immich-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ Immich Server (backend)
- ✅ Immich Web (interface web)
- ✅ PostgreSQL (base de données)
- ✅ Redis (cache)
- ✅ Machine Learning (reconnaissance d'objets et de visages)

**Durée :** ~10-15 minutes (le téléchargement des images Docker peut être long)

---

## ✅ Vérification Installation

### Vérifier les services
```bash
cd ~/stacks/immich
docker compose ps
# Tous les services doivent être "Up (healthy)"
```

### Accéder à l'interface web
L'URL dépend de votre configuration Traefik :
- **Avec Traefik (Cloudflare)** : `https://immich.VOTRE-DOMAINE.com`
- **Avec Traefik (DuckDNS)** : `https://VOTRE-SOUS-DOMAINE.duckdns.org/immich`
- **Sans Traefik** : `http://<IP-DU-PI>:2283`

L'URL exacte est affichée à la fin du script d'installation.

---

## 👤 Configuration Initiale

1.  **Ouvrez l'interface web** d'Immich.
2.  La première page est l'écran d'accueil. Cliquez sur **"Get Started"**.
3.  **Créez votre compte administrateur** en remplissant votre nom, adresse email et mot de passe.
4.  Connectez-vous avec le compte que vous venez de créer.

C'est tout ! Vous pouvez maintenant commencer à uploader des photos.

---

## 📱 Synchronisation Mobile

L'une des fonctionnalités les plus puissantes d'Immich est la sauvegarde automatique des photos de votre téléphone.

1.  **Téléchargez l'application Immich** sur votre téléphone depuis l'App Store (iOS) ou le Google Play Store (Android).
2.  Ouvrez l'application.
3.  Dans le champ **"Server Endpoint URL"**, entrez l'adresse de votre instance Immich (ex: `https://immich.domaine.com`).
4.  Connectez-vous avec votre email et mot de passe.
5.  Cliquez sur l'icône de nuage en haut à droite pour **configurer la sauvegarde**.
6.  Choisissez les albums que vous souhaitez sauvegarder et activez la sauvegarde.

Vos photos commenceront à être uploadées sur votre Raspberry Pi !

---

## 📚 Documentation Complète

- [Guide Débutant](immich-guide.md) - Pour découvrir toutes les fonctionnalités d'Immich.
- [README.md](README.md) - Vue d'ensemble du stack.
