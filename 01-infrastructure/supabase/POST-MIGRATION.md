# 🔧 Étapes Post-Migration Supabase

> **Après avoir migré votre base Cloud → Pi** - Que faire maintenant ?

---

## ✅ Migration Terminée !

Votre base de données est maintenant sur le Pi avec :
- ✅ Tables et données
- ✅ Utilisateurs (emails et métadonnées)
- ✅ Règles de sécurité (RLS)
- ✅ Fonctions et triggers

Mais il reste 2 choses à faire :

---

## 1️⃣ Réinitialiser les Mots de Passe Utilisateurs

### Pourquoi ?

Les mots de passe sont **hashés** dans Supabase Cloud et ne peuvent pas être migrés. Vos utilisateurs doivent créer de nouveaux mots de passe.

### Option A : Reset Automatique (Recommandé)

**Prérequis : Configurer SMTP**

Éditez `~/stacks/supabase/.env` sur le Pi :

```bash
# Configuration SMTP (exemple Gmail)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=votre-email@gmail.com
SMTP_PASS=votre-app-password
SMTP_ADMIN_EMAIL=noreply@votreapp.com
```

Puis redémarrez Supabase :
```bash
cd ~/stacks/supabase
docker compose down
docker compose up -d
```

**Exécuter le script de reset :**

```bash
# Installer les dépendances
npm install @supabase/supabase-js

# Exécuter le script
node ~/pi5-setup/01-infrastructure/supabase/scripts/post-migration-password-reset.js
```

Le script va :
1. Lister tous vos utilisateurs
2. Envoyer un email de reset à chacun
3. Afficher le résumé

### Option B : OAuth (Alternative)

Configurez Google ou GitHub OAuth et vos utilisateurs pourront se connecter directement :

**Dans Supabase Studio** (http://PI_IP:3000) :
1. Allez dans **Authentication** → **Providers**
2. Activez **Google** ou **GitHub**
3. Configurez les credentials OAuth

**Avantage :** Pas besoin de reset, connexion immédiate avec compte Google/GitHub

---

## 2️⃣ Migrer les Fichiers Storage

### Pourquoi ?

Les fichiers uploadés (images, documents, etc.) sont stockés séparément de PostgreSQL et doivent être migrés manuellement.

### Script Automatique

```bash
# Installer les dépendances
npm install @supabase/supabase-js

# Exécuter le script
node ~/pi5-setup/01-infrastructure/supabase/scripts/post-migration-storage.js
```

Le script va :
1. Lister tous vos buckets Cloud
2. Créer les buckets sur le Pi
3. Télécharger et uploader tous les fichiers
4. Afficher la progression

### Alternative : Migration Manuelle

**Télécharger depuis Cloud :**
```bash
# Via Supabase CLI
supabase storage download bucket-name ./backup-files/
```

**Uploader vers Pi :**
```bash
# Via l'interface web
http://PI_IP:3000 → Storage → Upload files
```

---

## 3️⃣ Mettre à Jour Votre Application

### Variables d'Environnement

**Avant (Cloud) :**
```javascript
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...cloud-key...
```

**Après (Pi) :**
```javascript
NEXT_PUBLIC_SUPABASE_URL=http://192.168.1.74:8000
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...pi-key...
```

**Récupérer la clé Pi :**
```bash
# Sur le Pi
cat ~/stacks/supabase/.env | grep ANON_KEY
```

### Code Application

**Next.js / React :**
```javascript
// lib/supabase.js
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

Redémarrez votre app et testez !

---

## 4️⃣ Vérifications

### Tester l'API

```bash
# Test REST API
curl http://PI_IP:8000/rest/v1/ \
  -H "apikey: VOTRE_ANON_KEY"
```

### Tester Auth

```javascript
// Login test
const { data, error } = await supabase.auth.signInWithPassword({
  email: 'user@example.com',
  password: 'nouveau-mot-de-passe'
})
```

### Tester Storage

```javascript
// Upload test
const { data, error } = await supabase.storage
  .from('bucket-name')
  .upload('test.txt', new Blob(['Hello Pi!']))
```

---

## 5️⃣ Configuration OAuth (Optionnel)

### Google OAuth

**1. Créer OAuth dans Google Cloud Console :**
- Allez sur https://console.cloud.google.com
- APIs & Services → Credentials
- Create OAuth 2.0 Client ID
- Type : Web application
- Authorized redirect URIs : `http://PI_IP:8000/auth/v1/callback`

**2. Configurer dans Supabase :**

Dans `~/stacks/supabase/.env` :
```bash
GOTRUE_EXTERNAL_GOOGLE_ENABLED=true
GOTRUE_EXTERNAL_GOOGLE_CLIENT_ID=votre-client-id
GOTRUE_EXTERNAL_GOOGLE_SECRET=votre-secret
GOTRUE_EXTERNAL_GOOGLE_REDIRECT_URI=http://PI_IP:8000/auth/v1/callback
```

Redémarrer :
```bash
cd ~/stacks/supabase && docker compose restart
```

**3. Dans votre app :**
```javascript
const { data, error } = await supabase.auth.signInWithOAuth({
  provider: 'google'
})
```

### GitHub OAuth

Même principe avec GitHub :
- https://github.com/settings/developers
- New OAuth App
- Authorization callback URL : `http://PI_IP:8000/auth/v1/callback`

---

## 🆘 Problèmes Courants

### "Users can't login"
- **Cause :** Mots de passe non migrés
- **Solution :** Exécuter script de reset ou configurer OAuth

### "Storage files not found"
- **Cause :** Fichiers non migrés
- **Solution :** Exécuter script de migration Storage

### "SMTP error when sending reset emails"
- **Cause :** SMTP mal configuré
- **Solution :** Vérifier les credentials dans `.env`

### "API returns 401 Unauthorized"
- **Cause :** Mauvaise clé API
- **Solution :** Récupérer la bonne clé depuis `~/stacks/supabase/.env`

---

## 📊 Checklist Post-Migration

- [ ] ✅ Base de données migrée et vérifiée
- [ ] 🔐 SMTP configuré (si reset passwords)
- [ ] 📧 Emails de reset envoyés aux users
- [ ] 📦 Fichiers Storage migrés
- [ ] 🔑 Variables d'env mises à jour dans l'app
- [ ] 🧪 Tests API/Auth/Storage réussis
- [ ] 🔗 OAuth configuré (optionnel)
- [ ] 🚀 Application redéployée avec nouvelle config
- [ ] 💾 Backups Pi configurés

---

## 🎉 Migration Complète !

Après ces étapes :
- ✅ Base sur le Pi (rapide, local)
- ✅ Users peuvent se connecter
- ✅ Fichiers accessibles
- ✅ Application fonctionnelle
- 💰 **Économie : ~300€/an** vs Supabase Cloud

---

## 📚 Ressources

- **Scripts :**
  - [post-migration-password-reset.js](scripts/post-migration-password-reset.js)
  - [post-migration-storage.js](scripts/post-migration-storage.js)

- **Guides :**
  - [GUIDE-MIGRATION-SIMPLE.md](GUIDE-MIGRATION-SIMPLE.md) - Migration initiale
  - [MIGRATION-CLOUD-TO-PI.md](MIGRATION-CLOUD-TO-PI.md) - Guide technique complet
  - [WORKFLOW-DEVELOPPEMENT.md](WORKFLOW-DEVELOPPEMENT.md) - Développer avec le Pi

- **Support :**
  - [GitHub Issues](https://github.com/iamaketechnology/pi5-setup/issues)
  - [Supabase Docs](https://supabase.com/docs)

---

<p align="center">
  <strong>🚀 Votre application tourne maintenant 100% sur le Pi ! 🚀</strong>
</p>
