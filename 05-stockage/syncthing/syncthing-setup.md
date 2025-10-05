# ⚡ Installation Rapide - Syncthing

> **Installation directe via SSH**

---

## 🚀 Installation en 1 Commande

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/syncthing/scripts/01-syncthing-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ Syncthing (service de synchronisation de fichiers P2P)

**Durée :** ~3 minutes

---

## ✅ Vérification Installation

### Vérifier le service
```bash
cd ~/stacks/syncthing
docker compose ps
# Le service doit être "Up"
```

### Accéder à l'interface web
L'URL dépend de votre configuration Traefik :
- **Avec Traefik (Cloudflare)** : `https://syncthing.VOTRE-DOMAINE.com`
- **Avec Traefik (DuckDNS)** : `https://VOTRE-SOUS-DOMAINE.duckdns.org/syncthing`
- **Sans Traefik** : `http://<IP-DU-PI>:8384`

L'URL exacte est affichée à la fin du script d'installation.

---

## 🔗 Connecter votre premier appareil

Syncthing fonctionne en connectant directement deux ou plusieurs appareils.

1.  **Installez Syncthing** sur un autre appareil (votre ordinateur, un autre serveur, ou votre téléphone via une app comme `Mobiussync` sur Android).

2.  **Ouvrez l'interface web de Syncthing sur votre Pi**.
    -   Cliquez sur **Actions > Afficher l'ID** en haut à droite.
    -   Copiez cet ID. C'est l'adresse unique de votre Pi sur le réseau Syncthing.

3.  **Ouvrez l'interface de Syncthing sur votre autre appareil**.
    -   Cliquez sur **"+ Ajouter un appareil distant"**.
    -   Collez l'ID de votre Pi.
    -   Donnez un nom à votre Pi (ex: "Raspberry Pi 5").
    -   Enregistrez.

4.  **Retournez sur l'interface de votre Pi**.
    -   Une notification devrait apparaître en haut, vous demandant d'accepter le nouvel appareil. Cliquez sur **"Ajouter l'appareil"**.

Vos deux appareils sont maintenant connectés !

---

## 📂 Partager votre premier dossier

1.  **Sur l'appareil où se trouve le dossier à synchroniser** (ex: votre ordinateur), cliquez sur **"+ Ajouter un dossier"**.
    -   **Label du dossier** : Un nom pour le partage (ex: "Mes Documents").
    -   **Chemin du dossier** : Le chemin exact sur votre ordinateur (ex: `C:\Users\VotreNom\Documents`).

2.  Allez dans l'onglet **"Partage"**.
    -   Cochez la case à côté de votre Raspberry Pi.
    -   Enregistrez.

3.  **Retournez sur l'interface de votre Pi**.
    -   Une notification vous demandera d'accepter le nouveau dossier partagé.
    -   Cliquez sur **"Ajouter"**.
    -   **IMPORTANT** : Choisissez le **chemin où le dossier doit être synchronisé sur le Pi**. Par exemple : `/home/pi/data/syncthing/documents`.
    -   Enregistrez.

La synchronisation va commencer. Les fichiers de votre ordinateur apparaîtront dans le dossier que vous avez spécifié sur le Pi.

---

## 📚 Documentation Complète

- [Guide Débutant](syncthing-guide.md) - Pour comprendre la philosophie de Syncthing.
- [README.md](README.md) - Vue d'ensemble du stack.
