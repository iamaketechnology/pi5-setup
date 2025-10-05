# ⚡ Installation Rapide - qBittorrent

> **Installation directe via SSH**

---

## 🚀 Installation en 1 Commande

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/qbittorrent/scripts/01-qbittorrent-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ qBittorrent avec son interface web (WebUI)

**Durée :** ~3 minutes

---

## ✅ Vérification Installation

### Vérifier le service
```bash
cd ~/stacks/qbittorrent
docker compose ps
# Le service doit être "Up"
```

### Accéder à l'interface web
L'URL dépend de votre configuration Traefik :
- **Avec Traefik (Cloudflare)** : `https://qbittorrent.VOTRE-DOMAINE.com`
- **Avec Traefik (DuckDNS)** : `https://VOTRE-SOUS-DOMAINE.duckdns.org/qbittorrent`
- **Sans Traefik** : `http://<IP-DU-PI>:8080`

L'URL exacte est affichée à la fin du script d'installation.

---

## 🔐 Identifiants par Défaut

Lors de la première connexion, vous devrez utiliser les identifiants par défaut :

-   **Nom d'utilisateur** : `admin`
-   **Mot de passe** : `adminadmin`

**⚠️ TRÈS IMPORTANT : Changez ce mot de passe immédiatement après votre première connexion !**

Pour changer le mot de passe :
1.  Cliquez sur l'icône d'engrenage ⚙️ (Options) en haut.
2.  Allez dans l'onglet **"Web UI"**.
3.  Dans la section "Authentification", changez le nom d'utilisateur et le mot de passe.
4.  Cliquez sur **"Enregistrer"** en bas.

---

## 📂 Dossiers

-   Les téléchargements terminés se trouvent dans : `/home/pi/data/downloads/completed`
-   Les téléchargements en cours se trouvent dans : `/home/pi/data/downloads/incomplete`

Ces chemins sont accessibles par d'autres services comme Sonarr, Radarr et Jellyfin pour une automatisation complète.

---

## 📚 Documentation Complète

- [Guide Débutant](qbittorrent-guide.md) - Pour apprendre les bases et les bonnes pratiques.
- [README.md](README.md) - Vue d'ensemble du stack.
