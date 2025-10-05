# ⚡ Installation Rapide - Joplin Server

> **Installation directe via SSH**

---

## 🚀 Installation en 1 Commande

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/joplin/scripts/01-joplin-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ Joplin Server (pour la synchronisation de vos notes)
- ✅ PostgreSQL (base de données pour le serveur)

**Durée :** ~5 minutes

---

## ✅ Vérification Installation

### Vérifier les services
```bash
cd ~/stacks/joplin
docker compose ps
# Les services doivent être "Up"
```

### Accéder à l'interface web
L'URL dépend de votre configuration Traefik :
- **Avec Traefik (Cloudflare)** : `https://joplin.VOTRE-DOMAINE.com`
- **Avec Traefik (DuckDNS)** : `https://VOTRE-SOUS-DOMAINE.duckdns.org/joplin`
- **Sans Traefik** : `http://<IP-DU-PI>:22300`

L'URL exacte est affichée à la fin du script d'installation.

---

## 👤 Connexion et Utilisation

Le serveur Joplin n'a pas d'interface de prise de notes. C'est uniquement un **serveur de synchronisation**. L'interface web ne sert qu'à l'administration.

1.  **Ouvrez l'interface web** de Joplin Server.
2.  **Connectez-vous** avec les identifiants par défaut :
    -   **Email** : `admin@localhost`
    -   **Mot de passe** : `admin`
3.  **Changez immédiatement le mot de passe administrateur** en cliquant sur "Admin", puis sur "Password".

---

## 📱 Connecter les applications Joplin

C'est ici que la magie opère. Vous devez configurer vos applications Joplin (desktop ou mobile) pour qu'elles se synchronisent avec VOTRE serveur.

1.  **Téléchargez et installez l'application Joplin** sur votre ordinateur ou votre téléphone depuis le [site officiel de Joplin](https://joplinapp.org/).
2.  Dans l'application, allez dans **Outils > Options > Synchronisation**.
3.  **Cible de synchronisation** : Choisissez **"Joplin Server"**.
4.  Remplissez les informations de votre serveur :
    -   **URL du serveur Joplin** : L'adresse de votre serveur (ex: `https://joplin.votre-domaine.com`).
    -   **Email de l'utilisateur Joplin** : `admin@localhost` (ou un autre utilisateur que vous pouvez créer dans l'interface web du serveur).
    -   **Mot de passe de l'utilisateur Joplin** : Le mot de passe que vous avez défini.
5.  Cliquez sur **"Vérifier la configuration de la synchronisation"**.
6.  Si tout est correct, un message de succès apparaîtra. Cliquez sur "Appliquer" ou "OK".

Vos notes seront maintenant synchronisées sur tous vos appareils via votre Raspberry Pi !

---

## 📚 Documentation Complète

- [Guide Débutant](joplin-guide.md) - Pour découvrir la puissance de Joplin et du Markdown.
- [README.md](README.md) - Vue d'ensemble du stack.
