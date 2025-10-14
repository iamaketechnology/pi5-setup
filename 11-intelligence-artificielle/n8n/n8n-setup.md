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
- **Avec Traefik (DuckDNS)** : `https://n8n.VOTRE-SOUS-DOMAINE.duckdns.org`
- **Avec Traefik (Cloudflare)** : `https://n8n.VOTRE-DOMAINE.com`
- **Sans Traefik (local)** : `http://pi5.local:5678` ou `http://<IP-DU-PI>:5678`

⚠️ **Erreur "secure cookie"** : Si vous voyez une erreur de cookie sécurisé en accédant via `pi5.local`, utilisez `localhost` avec un tunnel SSH :
```bash
ssh -L 5678:localhost:5678 pi@pi5.local
```
Puis ouvrez : `http://localhost:5678`

L'URL exacte est affichée à la fin du script d'installation.

---

## 👤 Configuration Initiale

1.  **Ouvrez l'interface web** de n8n.
2.  La première fois, n8n vous demandera de **créer un compte propriétaire**. C'est le compte administrateur principal.
3.  Remplissez votre email et un mot de passe solide.
4.  Vous serez ensuite guidé à travers quelques questions de configuration de base.

Une fois terminé, vous arriverez sur le canevas de workflow, prêt à créer votre première automatisation.

---

## 🤖 Intégration avec Ollama (IA Locale)

Si vous avez installé **Ollama** sur votre Pi, vous pouvez connecter n8n pour utiliser des LLM locaux dans vos workflows.

### Vérifier la Connectivité

**Script de vérification/fix automatique** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/n8n/scripts/02-fix-n8n-connectivity.sh | sudo bash
```

**Ce script** :
- ✅ Vérifie que n8n, Ollama et Supabase sont démarrés
- ✅ Connecte n8n aux réseaux Docker si nécessaire
- ✅ Teste la connectivité réseau (ping)
- ✅ Idempotent (safe à relancer)
- ✅ Gère les cas où Ollama ou Supabase ne sont pas installés

### Configuration dans n8n

#### URLs à utiliser dans vos workflows

**Ollama (LLM local)** :
```
http://ollama:11434
```

**Supabase (Base de données)** :
```
http://supabase-kong:8000/rest/v1
```

#### Exemple 1 : Workflow n8n → Ollama

1. **Nœud "Manual Trigger"** (déclencheur manuel)
2. **Nœud "HTTP Request"** :
   - Method: `POST`
   - URL: `http://ollama:11434/api/generate`
   - Body (JSON):
     ```json
     {
       "model": "phi3:3.8b",
       "prompt": "Écris un poème court sur le Raspberry Pi",
       "stream": false
     }
     ```
3. **Tester** : Cliquez sur "Execute Workflow"

#### Exemple 2 : Workflow Supabase → Ollama → Supabase

1. **Nœud "HTTP Request"** : Récupérer données de Supabase
   - URL: `http://supabase-kong:8000/rest/v1/documents?select=*`
2. **Nœud "HTTP Request"** : Analyser avec Ollama
   - URL: `http://ollama:11434/api/generate`
3. **Nœud "HTTP Request"** : Enregistrer résultat dans Supabase
   - Method: `POST`
   - URL: `http://supabase-kong:8000/rest/v1/analysis`

**Modèles Ollama disponibles** :
```bash
docker exec ollama ollama list
```

Pour installer des modèles, consultez le guide [Ollama](../../ollama/ollama-setup.md).

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
