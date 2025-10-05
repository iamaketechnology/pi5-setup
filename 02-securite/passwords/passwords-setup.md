# ⚡ Installation Rapide - Vaultwarden

> **Installation directe via SSH**

---

## 🚀 Installation en 1 Commande

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/passwords/scripts/01-vaultwarden-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ Vaultwarden (serveur Bitwarden auto-hébergé)
- ✅ Interface web pour la gestion du coffre-fort

**Durée :** ~3 minutes

---

## ✅ Vérification Installation

### Vérifier le service
```bash
cd ~/stacks/vaultwarden
docker compose ps
# Le service doit être "Up (healthy)"
```

### Accéder à l'interface web
L'URL dépend de votre configuration Traefik :
- **Avec Traefik (Cloudflare)** : `https://vaultwarden.VOTRE-DOMAINE.com`
- **Avec Traefik (DuckDNS)** : `https://VOTRE-SOUS-DOMAINE.duckdns.org/vaultwarden`
- **Sans Traefik** : `http://<IP-DU-PI>:8200`

L'URL exacte est affichée à la fin du script d'installation.

---

## 👤 Créer votre premier utilisateur

1.  Ouvrez l'interface web de Vaultwarden.
2.  Cliquez sur **"Créer un compte"**.
3.  Remplissez les champs (email, nom, mot de passe maître).
    - **⚠️ Choisissez un mot de passe maître TRÈS solide ! C'est la clé de tout votre coffre-fort.**
4.  Une fois le compte créé, vous pouvez vous connecter.

**IMPORTANT** : Par défaut, l'inscription est ouverte. Il est fortement recommandé de la désactiver après avoir créé les comptes nécessaires.

### Désactiver les inscriptions

1.  Ouvrez le fichier de configuration :
    ```bash
    sudo nano ~/stacks/vaultwarden/.env
    ```
2.  Changez la ligne `SIGNUPS_ALLOWED=true` en `SIGNUPS_ALLOWED=false`.
3.  Redémarrez Vaultwarden pour appliquer les changements :
    ```bash
    cd ~/stacks/vaultwarden && docker compose restart
    ```

---

## 📱 Utiliser les clients Bitwarden

Vaultwarden est compatible avec tous les clients officiels Bitwarden.

1.  **Téléchargez** l'extension de navigateur ou l'application mobile Bitwarden.
2.  Au moment de vous connecter, cliquez sur l'icône d'engrenage ⚙️ (ou "Paramètres") en haut de l'écran.
3.  Dans le champ **"URL du serveur"**, entrez l'adresse de votre instance Vaultwarden (ex: `https://vaultwarden.domaine.com`).
4.  Connectez-vous avec votre email et votre mot de passe maître.

---

## 📚 Documentation Complète

- [Guide Débutant](passwords-guide.md) - Pour comprendre pourquoi et comment utiliser un gestionnaire de mots de passe.
- [README.md](README.md) - Vue d'ensemble du stack.
