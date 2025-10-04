# 📚 Guide Débutant - Supabase Stack

> **Pour qui ?** Débutants en développement backend et bases de données
> **Durée de lecture** : 15 minutes
> **Niveau** : Débutant (aucune connaissance préalable requise)

---

## 🤔 C'est quoi Supabase ?

### En une phrase
**Supabase = Une alternative open source à Firebase (Google) que tu héberges toi-même sur ton Raspberry Pi.**

### Analogie simple
Imagine que tu veux créer une application (site web, app mobile, etc.). Tu as besoin de :
- Un endroit pour **stocker les données** (comme une bibliothèque)
- Un système pour **gérer les utilisateurs** (inscription, connexion)
- Un moyen de **télécharger des fichiers** (photos, vidéos)
- Une **API** pour que ton application parle avec la base de données

**Supabase fait tout ça automatiquement** ! Au lieu de payer Google Firebase ou Amazon AWS chaque mois, tu as tout sur ton Pi gratuitement.

---

## 🎯 À quoi ça sert concrètement ?

### Use Cases (Exemples d'utilisation)

#### 1. **Application mobile/web personnelle**
Tu veux créer une app de gestion de tâches (To-Do List) :
```
Supabase fait :
✅ Base de données pour stocker tes tâches
✅ Connexion utilisateur (email/password)
✅ API automatique (pas besoin de coder le backend)
✅ Temps réel (les changements apparaissent instantanément)
```

#### 2. **Site web avec espace membre**
Tu crées un blog avec commentaires :
```
Supabase fait :
✅ Stockage des articles et commentaires
✅ Authentification des utilisateurs
✅ Upload d'images pour les articles
✅ Notifications temps réel des nouveaux commentaires
```

#### 3. **Application IoT/Domotique**
Tu veux logger les données de tes capteurs :
```
Supabase fait :
✅ Stockage historique des mesures (température, etc.)
✅ Dashboard en temps réel
✅ API pour que tes capteurs envoient les données
```

#### 4. **Prototype/MVP pour startup**
Tu testes une idée d'application :
```
Supabase fait :
✅ Backend complet sans coder
✅ Gratuit (hébergé chez toi)
✅ Évolutif (si ça marche, tu peux migrer vers le cloud)
```

---

## 🧩 Les Composants (Expliqués simplement)

### 1. **PostgreSQL** - La Base de Données
**C'est quoi ?** Un énorme tableau Excel ultra-puissant qui stocke toutes tes données.

**Exemple concret** :
```
Table "todos" :
┌────┬──────────────┬───────────┬────────────┐
│ id │ titre        │ terminé   │ user_id    │
├────┼──────────────┼───────────┼────────────┤
│ 1  │ Faire courses│ false     │ 42         │
│ 2  │ Apprendre SQL│ true      │ 42         │
└────┴──────────────┴───────────┴────────────┘
```

**Pourquoi PostgreSQL ?** C'est la Rolls-Royce des bases de données (gratuite, robuste, utilisée par des millions d'apps).

---

### 2. **Supabase Studio** - L'Interface Graphique
**C'est quoi ?** Une interface web style "Excel" pour gérer ta base de données sans taper de code.

**Tu peux** :
- Créer des tables (clic-bouton, pas de code)
- Voir/modifier tes données visuellement
- Gérer les utilisateurs
- Tester des requêtes SQL (optionnel)

**Accès** : `http://localhost:8000` ou `http://IP_DU_PI:8000`

**Exemple d'utilisation** :
1. Tu ouvres Studio dans ton navigateur
2. Tu cliques "New Table" → Nom : "todos"
3. Tu ajoutes des colonnes : `titre` (texte), `terminé` (vrai/faux)
4. Voilà ! Ta base de données est prête sans une ligne de code

---

### 3. **Auth (GoTrue)** - Gestion des Utilisateurs
**C'est quoi ?** Un système d'inscription/connexion automatique.

**Ce que ça fait** :
- Inscription par email/password
- Connexion avec Google, GitHub, etc. (OAuth)
- Réinitialisation de mot de passe
- Tokens JWT (sécurité automatique)

**Exemple d'utilisation** :
```javascript
// Dans ton app frontend (3 lignes de code)
import { createClient } from '@supabase/supabase-js'

const supabase = createClient('http://ton-pi:8000', 'ta-clé-API')

// Inscription
await supabase.auth.signUp({ email: 'user@example.com', password: '123456' })

// Connexion
await supabase.auth.signInWithPassword({ email: 'user@example.com', password: '123456' })
```

**Résultat** : Tu as un système d'authentification professionnel sans coder le backend !

---

### 4. **REST API (PostgREST)** - L'API Automatique
**C'est quoi ?** Dès que tu crées une table dans la base de données, une API REST apparaît automatiquement.

**Exemple magique** :
1. Tu crées une table `todos` dans Studio
2. Supabase génère automatiquement ces endpoints :
   - `GET /rest/v1/todos` → Liste toutes les tâches
   - `POST /rest/v1/todos` → Créer une tâche
   - `PATCH /rest/v1/todos?id=eq.1` → Modifier la tâche 1
   - `DELETE /rest/v1/todos?id=eq.1` → Supprimer la tâche 1

**Utilisation** :
```javascript
// Récupérer toutes les tâches
const { data } = await supabase.from('todos').select('*')

// Ajouter une tâche
await supabase.from('todos').insert({ titre: 'Nouvelle tâche' })

// Modifier une tâche
await supabase.from('todos').update({ terminé: true }).eq('id', 1)
```

**Pourquoi c'est incroyable ?** Tu gagnes des semaines de développement backend !

---

### 5. **Realtime** - Le Temps Réel
**C'est quoi ?** Les changements dans la base de données apparaissent instantanément dans toutes les apps connectées (comme Google Docs).

**Exemple concret** :
```javascript
// Écouter les nouvelles tâches
supabase
  .channel('todos')
  .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'todos' }, (payload) => {
    console.log('Nouvelle tâche ajoutée !', payload.new)
    // Met à jour l'interface automatiquement
  })
  .subscribe()
```

**Use case** :
- Chat en temps réel
- Dashboard mis à jour instantanément
- Notifications live

---

### 6. **Storage** - Stockage de Fichiers
**C'est quoi ?** Un Google Drive/Dropbox intégré à ton backend.

**Tu peux** :
- Uploader des images, vidéos, PDFs
- Organiser en dossiers (buckets)
- Redimensionner automatiquement les images
- Sécuriser l'accès (public/privé)

**Exemple** :
```javascript
// Uploader une photo de profil
const { data } = await supabase.storage
  .from('avatars')
  .upload('user-42.png', fichierImage)

// Récupérer l'URL publique
const { publicURL } = supabase.storage
  .from('avatars')
  .getPublicUrl('user-42.png')
```

---

### 7. **Edge Functions** - Code Serveur Sans Serveur
**C'est quoi ?** Tu peux exécuter du code côté serveur (comme des scripts Python/JavaScript) sans gérer de serveur.

**Exemple d'utilisation** :
- Envoyer des emails automatiquement
- Traiter des paiements (Stripe)
- Générer des PDFs
- Appeler des APIs tierces (OpenAI, etc.)

**Exemple simple** :
```javascript
// Fonction qui envoie un email de bienvenue
Deno.serve(async (req) => {
  const { email } = await req.json()

  // Envoyer email via API (Resend, SendGrid, etc.)
  await sendWelcomeEmail(email)

  return new Response('Email envoyé !')
})
```

**Déclenchement** :
- Automatique (quand un user s'inscrit)
- Manuel (depuis ton app frontend)
- Webhook (depuis une autre app)

---

## 🚀 Comment l'utiliser ? (Pas à pas)

### Étape 1 : Accéder à Supabase Studio

1. **Trouve l'IP de ton Pi** :
   ```bash
   hostname -I
   ```
   → Exemple : `192.168.1.100`

2. **Ouvre ton navigateur** :
   ```
   http://192.168.1.100:8000
   ```

3. **Connexion** :
   - Email : celui configuré lors de l'installation
   - Password : celui configuré lors de l'installation

---

### Étape 2 : Créer ta première table

1. **Dans Studio** → "Table Editor" (menu gauche)
2. **Clic "New Table"**
3. **Remplis** :
   - Nom : `todos`
   - Colonnes :
     - `id` (bigint, primary key, auto-increment) → Créé automatiquement
     - `titre` (text)
     - `terminé` (boolean, default: false)
     - `created_at` (timestamp, default: now()) → Créé automatiquement

4. **Clic "Save"**

🎉 **Ta première base de données est créée !**

---

### Étape 3 : Ajouter des données

**Option A : Via Studio (visuel)**
1. Ouvre la table `todos`
2. Clic "Insert row"
3. Entre un titre : "Ma première tâche"
4. Clic "Save"

**Option B : Via API (code)**
```javascript
const { data } = await supabase
  .from('todos')
  .insert({ titre: 'Apprendre Supabase' })
```

---

### Étape 4 : Lire les données

**Depuis ton app frontend** :
```javascript
// Récupérer toutes les tâches
const { data: taches } = await supabase
  .from('todos')
  .select('*')

console.log(taches)
// [{ id: 1, titre: 'Ma première tâche', terminé: false }]
```

---

### Étape 5 : Connecter ton application

#### A. **Récupérer les infos de connexion**

Depuis ton Pi :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-supabase-stack/scripts/utils/get-supabase-info.sh | sudo bash
```

Tu obtiens :
```
API URL: http://192.168.1.100:8000
ANON KEY: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### B. **Configurer ton app**

**React/Next.js** :
```bash
npm install @supabase/supabase-js
```

```javascript
// lib/supabase.js
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'http://192.168.1.100:8000'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'

export const supabase = createClient(supabaseUrl, supabaseKey)
```

**Vue.js/Nuxt** : Même chose
**Flutter/Mobile** : Package `supabase_flutter`
**Python** : Package `supabase-py`

---

## 🛠️ Cas d'Usage Complets

### Exemple 1 : To-Do List avec authentification

```javascript
// 1. Inscription/Connexion
const { user } = await supabase.auth.signUp({
  email: 'moi@example.com',
  password: 'monmotdepasse'
})

// 2. Créer une tâche
await supabase.from('todos').insert({
  titre: 'Faire les courses',
  user_id: user.id // Associer à l'utilisateur
})

// 3. Récupérer MES tâches uniquement
const { data } = await supabase
  .from('todos')
  .select('*')
  .eq('user_id', user.id)

// 4. Marquer comme terminé
await supabase
  .from('todos')
  .update({ terminé: true })
  .eq('id', 1)
```

---

### Exemple 2 : Blog avec commentaires temps réel

```javascript
// 1. Récupérer les articles
const { data: articles } = await supabase
  .from('articles')
  .select('*, auteur:users(nom)')

// 2. Écouter les nouveaux commentaires (temps réel)
supabase
  .channel('comments')
  .on('postgres_changes',
    { event: 'INSERT', schema: 'public', table: 'commentaires' },
    (payload) => {
      console.log('Nouveau commentaire !', payload.new)
      // Afficher dans l'UI sans recharger la page
    }
  )
  .subscribe()

// 3. Poster un commentaire
await supabase.from('commentaires').insert({
  article_id: 123,
  texte: 'Super article !',
  user_id: user.id
})
```

---

### Exemple 3 : Upload de photo de profil

```javascript
// 1. Sélectionner un fichier
const fichier = document.getElementById('avatar').files[0]

// 2. Uploader
const { data, error } = await supabase.storage
  .from('avatars')
  .upload(`${user.id}/avatar.png`, fichier, {
    cacheControl: '3600',
    upsert: true // Écrase l'ancien si existe
  })

// 3. Récupérer l'URL publique
const { publicURL } = supabase.storage
  .from('avatars')
  .getPublicUrl(`${user.id}/avatar.png`)

// 4. Sauvegarder l'URL dans le profil user
await supabase
  .from('profiles')
  .update({ avatar_url: publicURL })
  .eq('id', user.id)
```

---

## 📊 Quand utiliser Supabase vs autres solutions ?

| Besoin | Supabase | Alternative |
|--------|----------|-------------|
| **Backend simple** (API + DB) | ✅ Parfait | Firebase, Appwrite |
| **Authentification utilisateurs** | ✅ Intégré | Auth0 (payant), NextAuth |
| **Base de données relationnelle** | ✅ PostgreSQL | MySQL, MongoDB |
| **Temps réel** | ✅ WebSockets intégrés | Socket.io (à coder) |
| **Stockage fichiers** | ✅ Intégré | AWS S3 (payant), Cloudflare R2 |
| **Self-hosted** | ✅ Sur ton Pi | Firebase (cloud only) |
| **Gratuit** | ✅ 100% sur ton Pi | Firebase (limité gratuit) |

**Supabase est idéal si** :
- Tu veux un backend complet sans coder
- Tu as besoin de relations entre données (SQL)
- Tu veux héberger chez toi (contrôle total)
- Tu es débutant et veux apprendre

**Pas idéal si** :
- Tu veux juste une base NoSQL simple (utilise MongoDB)
- Tu as besoin de performances extrêmes (100k+ requêtes/s)

---

## 🎓 Apprendre par la pratique

### Tutoriels officiels Supabase
1. **[Quick Start](https://supabase.com/docs/guides/getting-started)** - 10 min
2. **[Build a To-Do App](https://supabase.com/docs/guides/getting-started/tutorials/with-react)** - 30 min
3. **[Authentication](https://supabase.com/docs/guides/auth)** - Guide complet

### Projets débutants recommandés

**Niveau 1 - Facile** (1-2h)
- [ ] Liste de tâches (To-Do List)
- [ ] Carnet de notes (Notes App)
- [ ] Liste de courses partagée

**Niveau 2 - Intermédiaire** (3-5h)
- [ ] Blog personnel avec commentaires
- [ ] Gestionnaire de signets (Bookmarks)
- [ ] Galerie photos avec upload

**Niveau 3 - Avancé** (1-2 jours)
- [ ] Réseau social minimal (posts, likes, follow)
- [ ] Chat temps réel
- [ ] Dashboard IoT (capteurs + graphiques)

---

## 🔧 Commandes Utiles

### Voir les infos de connexion
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-supabase-stack/scripts/utils/get-supabase-info.sh | sudo bash
```

### Vérifier que Supabase fonctionne
```bash
cd ~/stacks/supabase
docker compose ps
```

Tous les services doivent être `Up (healthy)`.

### Voir les logs
```bash
# Logs de tous les services
docker compose logs -f

# Logs PostgreSQL uniquement
docker compose logs -f db

# Logs API
docker compose logs -f rest
```

### Redémarrer Supabase
```bash
cd ~/stacks/supabase
docker compose restart
```

### Arrêter Supabase
```bash
docker compose stop
```

### Démarrer Supabase
```bash
docker compose up -d
```

---

## 🆘 Problèmes Courants

### "Je ne peux pas accéder à Studio"

**Vérifications** :
1. Supabase est démarré ?
   ```bash
   docker compose ps
   ```

2. Le port 8000 est accessible ?
   ```bash
   curl http://localhost:8000
   ```

3. Firewall bloque le port ?
   ```bash
   sudo ufw allow 8000
   ```

---

### "Mon app ne se connecte pas à l'API"

**Vérifications** :
1. L'URL est correcte ? (remplace `localhost` par l'IP du Pi si depuis un autre appareil)
2. La clé ANON est bonne ?
   ```bash
   # Récupère les bonnes valeurs
   ~/pi5-setup/pi5-supabase-stack/scripts/utils/get-supabase-info.sh
   ```

---

### "Erreur 'relation does not exist'"

**Cause** : La table n'existe pas ou mauvais nom.

**Solution** :
1. Vérifie le nom exact dans Studio
2. SQL est case-sensitive : `Todos` ≠ `todos`

---

### "Permission denied"

**Cause** : Problème de sécurité Row Level Security (RLS).

**Solution débutant** (⚠️ UNIQUEMENT EN DEV) :
1. Dans Studio → Table Editor → ta table
2. Clic icône sécurité (cadenas)
3. Désactive "Enable RLS" temporairement

**Solution production** :
Apprends à configurer les policies RLS (voir [docs Supabase Auth](https://supabase.com/docs/guides/auth/row-level-security)).

---

## 📚 Ressources pour Débutants

### Documentation
- **[Supabase Docs](https://supabase.com/docs)** - Officielle, excellente
- **[PostgreSQL Tutorial](https://www.postgresqltutorial.com/)** - Apprendre SQL
- **[SQL Cheat Sheet](https://www.sqltutorial.org/sql-cheat-sheet/)** - Référence rapide

### Vidéos YouTube
- "Supabase in 100 Seconds" - Fireship (2 min)
- "Supabase Crash Course" - Traversy Media (1h)
- "Build a Full Stack App with Supabase" - freeCodeCamp (3h)

### Communautés
- [Discord Supabase](https://discord.supabase.com) - Support communautaire
- [r/Supabase](https://reddit.com/r/Supabase) - Reddit
- [GitHub Discussions](https://github.com/supabase/supabase/discussions)

---

## 🎯 Prochaines Étapes

Une fois à l'aise avec Supabase :

1. **Activer les sauvegardes automatiques** :
   ```bash
   sudo ~/pi5-setup/pi5-supabase-stack/scripts/maintenance/supabase-scheduler.sh
   ```

2. **Sécuriser avec Traefik (HTTPS)** → Voir [Phase 2 de la Roadmap](../ROADMAP.md#-phase-2---reverse-proxy--https--portail)

3. **Ajouter monitoring** → [Phase 3](../ROADMAP.md#-phase-3---observabilité--monitoring)

4. **Déployer Gitea pour héberger ton code** → [Phase 5](../ROADMAP.md#-phase-5---git-self-hosted--cicd)

---

## ✅ Checklist Maîtrise Supabase

**Niveau Débutant** :
- [ ] Je peux créer une table dans Studio
- [ ] Je peux ajouter/modifier des données via Studio
- [ ] Je comprends c'est quoi une API REST
- [ ] J'ai connecté une app frontend à Supabase

**Niveau Intermédiaire** :
- [ ] J'ai mis en place l'authentification utilisateurs
- [ ] Je sais faire des requêtes avec filtres (`.eq()`, `.gt()`, etc.)
- [ ] J'ai uploadé des fichiers dans Storage
- [ ] Je comprends les relations entre tables (foreign keys)

**Niveau Avancé** :
- [ ] J'ai configuré Row Level Security (RLS)
- [ ] J'utilise le temps réel (Realtime subscriptions)
- [ ] J'ai créé une Edge Function
- [ ] Je sais faire des backups/restores

---

**Besoin d'aide ?** Consulte la [documentation complète](../docs/README.md) ou pose tes questions sur le [Discord Supabase](https://discord.supabase.com) !

🎉 **Bon développement !**
