# ⚡ Installation Rapide - n8n

> **Installation directe via SSH**

---

## 🚀 Installation en 1 Commande

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/n8n/scripts/01-n8n-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ n8n (serveur d'automatisation de workflows)
- ✅ PostgreSQL (base de données pour n8n)

**Durée :** ~5-10 minutes

---

## ✅ Vérification de l'Installation

### Vérifier les services
```bash
cd ~/stacks/n8n
docker compose ps
# Les services n8n et n8n-postgres doivent être "Up (healthy)"
```

### Accéder à l'interface web
L'URL dépend de votre configuration Traefik :
- **Avec Traefik (Cloudflare)** : `https://n8n.VOTRE-DOMAINE.com`
- **Avec Traefik (DuckDNS)** : `https://VOTRE-SOUS-DOMAINE.duckdns.org/n8n`
- **Sans Traefik** : `http://<IP-DU-PI>:5678`

L'URL exacte est affichée à la fin du script d'installation.

---

## 👤 Configuration Initiale

1.  **Ouvrez l'interface web** de n8n.
2.  La première fois, n8n vous demandera de **créer un compte propriétaire**. C'est le compte administrateur principal.
3.  Remplissez votre email et un mot de passe solide.
4.  Vous serez ensuite guidé à travers quelques questions de configuration de base.

Une fois terminé, vous arriverez sur le canevas de workflow, prêt à créer votre première automatisation.

---

## 🔑 Gestion des "Credentials"

Pour connecter n8n à d'autres services (Google, OpenAI, Discord, etc.), vous devez fournir des "credentials" (clés d'API, tokens, etc.).

1.  Dans l'interface n8n, allez dans le menu de gauche et cliquez sur **"Credentials"**.
2.  Cliquez sur **"Add credential"**.
3.  Cherchez le service que vous voulez connecter (ex: `OpenAI API`).
4.  Remplissez les informations demandées (ex: votre clé d'API OpenAI).
5.  Enregistrez.

n8n chiffrera et stockera ces informations de manière sécurisée pour que vous puissiez les réutiliser dans tous vos workflows.

---

## 📚 Documentation Complète

- **[n8n-guide.md](n8n-guide.md)** - Pour apprendre à créer vos premiers workflows.
- **[README.md](README.md)** - Vue d'ensemble technique du stack n8n.
