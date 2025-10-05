# ⚡ Installation Rapide - Calibre-Web

> **Installation directe via SSH**

---

## 🚀 Installation en 1 Commande

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/calibre-web/scripts/01-calibre-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ Calibre-Web (interface web pour votre bibliothèque Calibre)

**Durée :** ~3 minutes

---

## ✅ Vérification Installation

### Vérifier le service
```bash
cd ~/stacks/calibre-web
docker compose ps
# Le service doit être "Up"
```

### Accéder à l'interface web
L'URL dépend de votre configuration Traefik :
- **Avec Traefik (Cloudflare)** : `https://books.VOTRE-DOMAINE.com`
- **Avec Traefik (DuckDNS)** : `https://VOTRE-SOUS-DOMAINE.duckdns.org/books`
- **Sans Traefik** : `http://<IP-DU-PI>:8083`

L'URL exacte est affichée à la fin du script d'installation.

---

## ⚙️ Configuration Initiale

La première fois que vous accédez à Calibre-Web, il vous demandera de configurer l'emplacement de votre bibliothèque Calibre.

**Prérequis : Vous devez avoir une bibliothèque Calibre existante.** Calibre-Web ne gère pas la bibliothèque, il ne fait que l'afficher.

1.  **Créez une bibliothèque avec l'application de bureau Calibre** sur votre ordinateur.
2.  **Copiez le dossier de la bibliothèque** sur votre Raspberry Pi. Un bon emplacement est `/home/pi/data/calibre-library`.
    -   Ce dossier doit contenir le fichier `metadata.db` et les dossiers des auteurs.
    -   Vous pouvez utiliser un client SFTP (FileZilla) ou la commande `scp` pour transférer le dossier.
3.  **Dans l'interface de configuration de Calibre-Web** :
    -   **Emplacement de la base de données Calibre** : Entrez le chemin que vous venez de créer sur le Pi. Par exemple : `/home/pi/data/calibre-library`.
    -   Cliquez sur **"Soumettre"**.
4.  Si le chemin est correct, Calibre-Web vous redirigera vers la page de connexion.
5.  **Connectez-vous** avec les identifiants par défaut :
    -   **Nom d'utilisateur** : `admin`
    -   **Mot de passe** : `admin123`

**⚠️ Changez ce mot de passe immédiatement** via le menu "Admin" > "Utilisateurs" > "admin".

---

## 📚 Documentation Complète

- [Guide Débutant](calibre-web-guide.md) - Pour apprendre à utiliser et profiter de votre bibliothèque en ligne.
- [README.md](README.md) - Vue d'ensemble du stack.
