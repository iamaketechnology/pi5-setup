# 🚀 Workflows n8n - Supabase + Ollama + Email

> **3 workflows de démonstration** connectant n8n, Supabase, Ollama et Email pour automatiser l'analyse de documents.

---

## 🎯 Workflows Disponibles

### 📄 Workflow #1 : Résumé Automatique de Documents

**Utilité** : Générer automatiquement des résumés de documents avec IA locale

**Architecture** :
```
Manual Trigger → Supabase (5 docs) → Ollama (résumé) → Résultat
```

**Cas d'usage** :
- Résumer les 5 derniers documents uploadés
- Générer descriptions automatiques basées sur les noms de fichiers
- Créer des aperçus rapides pour notification email

**Données récupérées** : `id`, `filename`, `mime_type`, `created_at`

**Prompt Ollama** :
```
Résume en 2-3 phrases le type de fichier et son contenu probable
basé sur ce nom: {{ $json.filename }}
```

---

### 🏷️ Workflow #2 : Classificateur de Documents

**Utilité** : Classifier automatiquement les documents par catégorie

**Architecture** :
```
Manual Trigger → Supabase (10 docs) → Ollama (classifie) → Formater résultat
```

**Cas d'usage** :
- Organiser automatiquement les documents par type
- Préparer les données pour insertion dans `document_tags`
- Trier les documents par catégorie métier

**Catégories détectées** : Facture, Contrat, Photo, Exercice, Document, Autre

**Prompt Ollama** :
```
Classifie ce fichier en UNE SEULE catégorie parmi:
Facture, Contrat, Photo, Exercice, Document, Autre.
Fichier: {{ $json.filename }}.
Réponds avec UN SEUL MOT.
```

**Sortie formatée** :
```json
{
  "doc_id": "uuid",
  "filename": "document.pdf",
  "category": "Facture"
}
```

---

### 🔐 Workflow #3 : Vérificateur de Certificats

**Utilité** : Détecter les certificats invalides ou documents modifiés

**Architecture** :
```
Manual Trigger → Certificats → Documents → Compare SHA256
                                          → Alerte IA (si anomalie)
```

**Cas d'usage** :
- Surveiller l'intégrité des documents certifiés
- Alerter en cas de modification post-certification
- Générer rapports de sécurité automatiques

**Logique de vérification** :
```javascript
IF (certificates.cert_sha256 != documents.sha256) THEN
  → Générer alerte avec Ollama
ELSE
  → Document valide (no action)
```

**Prompt Ollama (en cas d'anomalie)** :
```
ALERTE SÉCURITÉ: Le certificat du document {{ filename }}
ne correspond plus au document actuel. Le hash SHA256 a changé.
Génère un message d'alerte professionnel expliquant les risques.
```

---

## 🔧 Prérequis Techniques

### Services Requis

| Service | URL | Authentification |
|---------|-----|------------------|
| **n8n** | `http://localhost:5678` | API Key |
| **Supabase** | `http://supabase-kong:8000` | Service Role Key |
| **Ollama** | `http://ollama:11434` | Aucune |

### Connectivité Réseau

**Les 3 services doivent pouvoir communiquer** :

```bash
# Vérifier/corriger la connectivité
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/n8n/scripts/02-fix-n8n-connectivity.sh | sudo bash
```

**Ce script** :
- ✅ Connecte n8n au réseau Ollama
- ✅ Connecte n8n au réseau Supabase
- ✅ Teste la connectivité (ping)
- ✅ Affiche les URLs à utiliser

---

## 📦 Installation des Workflows

### Option A : Via API n8n (Recommandé)

**Prérequis** :
1. Générer une API Key n8n : Settings → n8n API → Create API Key
2. Récupérer le Service Role Key de Supabase : `~/stacks/supabase/.env`

**Script d'installation** :

```bash
# Variables
N8N_API_KEY="votre-cle-api-n8n"
SUPABASE_KEY="votre-service-role-key"

# Workflow #1 - Résumé
curl -X POST "http://localhost:5678/api/v1/workflows" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "📄 Résumé Automatique de Documents",
    "nodes": [...],
    "connections": {...},
    "settings": {"executionOrder": "v1"}
  }'

# Workflow #2 - Classificateur
curl -X POST "http://localhost:5678/api/v1/workflows" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{...}'

# Workflow #3 - Vérificateur
curl -X POST "http://localhost:5678/api/v1/workflows" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{...}'
```

**Fichiers JSON complets disponibles dans** : `workflows/`

---

### Option B : Import Manuel via UI

1. **Télécharger les workflows JSON** :
   - `workflow-resume-documents.json`
   - `workflow-classificateur-documents.json`
   - `workflow-verificateur-certificats.json`

2. **Importer dans n8n** :
   - Ouvrir n8n : http://localhost:5678
   - Cliquer sur menu (3 points) → Import from File
   - Sélectionner chaque fichier JSON

3. **Configurer l'authentification Supabase** :
   - Ouvrir chaque workflow
   - Éditer les nœuds "Récupérer Documents/Certificats"
   - Ajouter les headers d'authentification :
     ```
     apikey: [Service Role Key]
     Authorization: Bearer [Service Role Key]
     ```

---

## 🚀 Utilisation des Workflows

### Test Manuel (Interface n8n)

1. **Ouvrir n8n** : http://localhost:5678
2. **Sélectionner un workflow** dans la liste de gauche
3. **Cliquer sur "Execute Workflow"** (bouton en haut à droite)
4. **Observer les résultats** dans chaque nœud :
   - Vert ✅ = Succès
   - Rouge ❌ = Erreur (cliquer pour voir logs)

### Test via API n8n

```bash
# Lister les workflows
curl "http://localhost:5678/api/v1/workflows" \
  -H "X-N8N-API-KEY: $N8N_API_KEY"

# Exécuter un workflow (⚠️ nécessite webhook/schedule trigger)
curl -X POST "http://localhost:5678/webhook/resume-documents" \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## 🔄 Automatisation

### Remplacer Manual Trigger par Webhook

**Avantage** : Appeler le workflow via HTTP (API externe, script, etc.)

**Modification nœud déclencheur** :
```json
{
  "type": "n8n-nodes-base.webhook",
  "parameters": {
    "path": "resume-documents",
    "method": "POST"
  }
}
```

**Appel externe** :
```bash
curl -X POST "http://localhost:5678/webhook/resume-documents"
```

---

### Remplacer Manual Trigger par Schedule

**Avantage** : Exécution automatique périodique (toutes les X heures)

**Modification nœud déclencheur** :
```json
{
  "type": "n8n-nodes-base.scheduleTrigger",
  "parameters": {
    "rule": {
      "interval": [{"field": "hours", "value": 6}]
    }
  }
}
```

**Activation du workflow** :
```bash
curl -X PATCH "http://localhost:5678/api/v1/workflows/{id}" \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -d '{"active": true}'
```

---

## 🐛 Dépannage

### Erreur : "Authorization failed - please check your credentials"

**Cause** : Headers d'authentification Supabase manquants ou incorrects

**Solution** :
1. Vérifier le Service Role Key :
   ```bash
   sudo cat ~/stacks/supabase/.env | grep SUPABASE_SERVICE_KEY
   ```

2. Ajouter les headers dans le nœud HTTP Request :
   ```json
   {
     "sendHeaders": true,
     "headerParameters": {
       "parameters": [
         {"name": "apikey", "value": "YOUR_SERVICE_KEY"},
         {"name": "Authorization", "value": "Bearer YOUR_SERVICE_KEY"}
       ]
     }
   }
   ```

---

### Erreur : "Could not resolve hostname"

**Cause** : n8n ne peut pas joindre `supabase-kong` ou `ollama`

**Solution** :
```bash
# Fixer la connectivité réseau
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/n8n/scripts/02-fix-n8n-connectivity.sh | sudo bash
```

**Vérification manuelle** :
```bash
# Depuis le container n8n
docker exec n8n wget -qO- http://supabase-kong:8000/rest/v1/
docker exec n8n wget -qO- http://ollama:11434/api/tags
```

---

### Erreur : "Timeout" sur Ollama

**Cause** : Ollama met trop de temps à générer (modèle lourd ou prompt complexe)

**Solution** :
1. Augmenter le timeout HTTP Request :
   ```json
   {
     "options": {
       "timeout": 60000
     }
   }
   ```

2. Utiliser un modèle plus rapide :
   ```bash
   docker exec ollama ollama pull gemma2:2b  # Plus rapide que phi3
   ```

---

## 📊 Monitoring

### Voir les exécutions récentes

**Via n8n UI** :
- Menu "Executions" (à gauche)
- Filtrer par workflow, status, date

**Via API** :
```bash
curl "http://localhost:5678/api/v1/executions?limit=10" \
  -H "X-N8N-API-KEY: $N8N_API_KEY"
```

---

### Logs des conteneurs

```bash
# Logs n8n
docker logs n8n --tail 50

# Logs Ollama
docker logs ollama --tail 50

# Logs Supabase Kong
docker logs supabase-kong --tail 50
```

---

## 🎓 Ressources

- **n8n Documentation** : https://docs.n8n.io/
- **Supabase REST API** : https://supabase.com/docs/guides/api
- **Ollama API** : https://github.com/ollama/ollama/blob/main/docs/api.md
- **n8n Community** : https://community.n8n.io/

---

## 📝 Notes Techniques

### Authentification Supabase

**Méthode utilisée** : Headers manuels (pas de credentials n8n)

**Raison** :
- Bug connu du node Supabase officiel (conflit headers)
- Headers manuels = contrôle total
- Évite la complexité de création de credentials via API

**Headers requis** :
```
apikey: [Service Role Key]
Authorization: Bearer [Service Role Key]
```

**Source** : [GitHub Issue #17020](https://github.com/n8n-io/n8n/issues/17020)

---

### Expressions n8n

**Syntaxe de base** :
```javascript
{{ $json.field }}              // Champ du nœud courant
{{ $node["Node Name"].json }}  // JSON d'un autre nœud
{{ $json[0].field }}           // Indexation array
```

**Exemples utilisés** :
```javascript
// Workflow #1
{{ $json.filename }}

// Workflow #2
{{ $node["Récupérer Documents"].json.id }}

// Workflow #3
{{ $node["Récupérer Document Associé"].json[0].filename }}
```

---

### Filtres Supabase (PostgREST)

**Syntaxe** :
```
?select=columns&filter=eq.value&limit=N&order=column.desc
```

**Exemples** :
```bash
# 5 derniers documents
?select=id,filename,mime_type&order=created_at.desc&limit=5

# Document spécifique
?select=id,filename,sha256&id=eq.uuid-here

# Certificats récents
?select=id,doc_id,cert_sha256,created_at&limit=10
```

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-01-14
**Auteur** : PI5-SETUP Project
