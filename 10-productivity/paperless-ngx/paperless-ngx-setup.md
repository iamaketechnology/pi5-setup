# ⚡ Installation Rapide - Paperless-ngx

> **Installation directe via SSH**

---

## 🚀 Installation en 1 Commande

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/paperless-ngx/scripts/01-paperless-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ Paperless-ngx Webserver (interface web)
- ✅ Paperless-ngx Consumer (traitement des documents)
- ✅ PostgreSQL (base de données)
- ✅ Redis (cache)

**Durée :** ~5-10 minutes

---

## ✅ Vérification Installation

### Vérifier les services
```bash
cd ~/stacks/paperless-ngx
docker compose ps
# Tous les services doivent être "Up (healthy)"
```

### Accéder à l'interface web
L'URL dépend de votre configuration Traefik :
- **Avec Traefik (Cloudflare)** : `https://paperless.VOTRE-DOMAINE.com`
- **Avec Traefik (DuckDNS)** : `https://VOTRE-SOUS-DOMAINE.duckdns.org/paperless`
- **Sans Traefik** : `http://<IP-DU-PI>:8000`

L'URL exacte est affichée à la fin du script d'installation.

---

## 👤 Création de l'utilisateur Admin

Paperless-ngx ne propose pas d'interface d'inscription. Vous devez créer le premier utilisateur en ligne de commande.

**Connectez-vous en SSH à votre Pi et lancez la commande suivante :**

```bash
cd ~/stacks/paperless-ngx
docker compose exec webserver createsuperuser
```

Le script vous posera quelques questions :
- **Username** : Choisissez un nom d'utilisateur (ex: `admin`).
- **Email address** : Votre email.
- **Password** : Choisissez un mot de passe solide.
- **Password (again)** : Confirmez le mot de passe.

Une fois la commande terminée, votre utilisateur est créé et vous pouvez vous connecter à l'interface web.

---

## 📂 Commencer à numériser

La façon la plus simple de commencer est d'ajouter des fichiers dans le dossier de consommation.

1.  **Placez un fichier PDF** (facture, lettre, etc.) dans le dossier suivant sur votre Pi :
    ```
    /home/pi/stacks/paperless-ngx/consume
    ```
    Vous pouvez utiliser un client SFTP comme FileZilla ou la ligne de commande (`scp`).

2.  **Attendez quelques instants.** Paperless-ngx va automatiquement récupérer le fichier, le traiter avec l'OCR (reconnaissance de caractères), et l'importer dans votre bibliothèque.

3.  **Rafraîchissez l'interface web.** Votre document devrait apparaître sur le tableau de bord !

---

## 📚 Documentation Complète

- [GUIDE-DEBUTANT.md](GUIDE-DEBUTANT.md) - Pour apprendre à organiser et automatiser votre vie sans papier.
- [README.md](README.md) - Vue d'ensemble du stack.
