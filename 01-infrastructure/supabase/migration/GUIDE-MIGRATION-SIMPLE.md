# 🚀 Migrer Supabase Cloud vers votre Raspberry Pi

> **En 3 étapes simples** - Pas besoin d'être développeur !

---

## ✅ Avant de commencer

Vous devez avoir :
- ✅ Un Raspberry Pi avec Supabase installé
- ✅ Un projet Supabase Cloud (gratuit ou payant)
- ✅ Un ordinateur Mac ou PC (pour lancer le script)

---

## 📋 Informations à préparer

Ouvrez votre [Dashboard Supabase Cloud](https://app.supabase.com) et notez :

### 1️⃣ URL de votre projet
- Allez dans **Settings** → **General**
- Copiez l'URL : `https://xxxxx.supabase.co`

### 2️⃣ Clé Service Role
- Allez dans **Settings** → **API**
- Copiez la clé **`service_role`** (longue chaîne commençant par `eyJ...`)

### 3️⃣ Mot de passe base de données
- Allez dans **Settings** → **Database**
- Si vous ne l'avez pas noté : cliquez sur **Reset Database Password**
- Copiez le nouveau mot de passe

### 4️⃣ IP de votre Raspberry Pi
Sur le Raspberry Pi, ouvrez un terminal et tapez :
```bash
hostname -I
```
Notez la première IP (ex: `192.168.1.74`)

---

## 🎯 Migration en 3 étapes

### Étape 1 : Télécharger le script

**Sur votre Mac/PC** (pas sur le Raspberry Pi !), ouvrez un terminal et tapez :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/migration/migrate-cloud-to-pi.sh -o migrate.sh
chmod +x migrate.sh
```

### Étape 2 : Lancer le script

```bash
./migrate.sh
```

### Étape 3 : Répondre aux questions

Le script va vous demander :

**Question 1 :** URL Supabase Cloud
```
→ Tapez : https://xxxxx.supabase.co
```

**Question 2 :** Service Role Key
```
→ Collez la clé eyJ... (elle ne s'affiche pas, c'est normal)
```

**Question 3 :** Mot de passe base de données
```
→ Tapez le mot de passe (il ne s'affiche pas, c'est normal)
```

**Question 4 :** IP du Raspberry Pi
```
→ Tapez : 192.168.1.74 (votre IP)
```

**Question 5 :** Continuer ?
```
→ Tapez : y
```

---

## ⏳ Que fait le script ?

1. **Exporte** votre base de données Cloud (tables, données, utilisateurs)
2. **Transfère** tout vers le Raspberry Pi
3. **Importe** dans votre Supabase Pi
4. **Vérifie** que tout fonctionne

⏱️ **Durée** : 5-15 minutes selon la taille de votre base

---

## ✅ C'est terminé !

Votre base de données est maintenant sur le Pi ! 🎉

### Vérifier que ça marche

Ouvrez dans votre navigateur :
```
http://IP_DU_PI:3000
```
(Remplacez `IP_DU_PI` par votre IP, exemple: `http://192.168.1.74:3000`)

Vous devriez voir Supabase Studio avec :
- ✅ Vos tables
- ✅ Vos données
- ✅ Vos utilisateurs (emails et métadonnées)

---

## ⚠️ Important à savoir

### ✅ Ce qui est migré automatiquement
- Tables et structure
- Toutes les données
- Règles de sécurité (RLS)
- Utilisateurs (emails, métadonnées)

### ❌ Ce qui n'est PAS migré
- **Mots de passe utilisateurs** (hashés, non migrables)
- **Fichiers stockés** (Storage)

---

## 🔧 Étapes suivantes

> 📖 **[Guide Post-Migration Complet →](POST-MIGRATION.md)**

Après la migration, il reste **2 choses importantes** à faire :

### 1️⃣ Mots de passe utilisateurs

Les mots de passe ne sont PAS migrés (hashés). Vos utilisateurs doivent :

**Option A : Reset automatique** (recommandé)

> ⚠️ **À exécuter sur votre Mac/PC** (pas sur le Pi)

```bash
# 1. Installer dépendances
npm install @supabase/supabase-js

# 2. Télécharger le script
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/migration/post-migration-password-reset.js -o password-reset.js

# 3. Lancer le script
node password-reset.js
```

**Option B : OAuth Google/GitHub**
- Configuration dans Supabase Studio
- Login immédiat sans reset

### 2️⃣ Fichiers Storage

Les fichiers (images, documents) doivent être migrés :

> ⚠️ **À exécuter sur votre Mac/PC** (pas sur le Pi)

**Prérequis : Récupérer la Service Role Key du Pi**

> 💻 **À exécuter sur ton Mac** (la commande SSH récupère automatiquement la clé depuis le Pi)

```bash
# Afficher la clé (connexion SSH automatique au Pi)
ssh pi@192.168.1.74 "cat ~/stacks/supabase/.env | grep SUPABASE_SERVICE_KEY"

# Résultat affiché :
# SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Copier uniquement la partie après "=" (commence par eyJ...)
```

**Migration interactive (v3.2.0) :**

```bash
# 1. Télécharger le script
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/migration/post-migration-storage.js -o storage-migration.js

# 2. Lancer la migration guidée (installe automatiquement les dépendances)
node storage-migration.js
```

> ⚡ **Nouveau v3.2.0** : Les dépendances npm sont installées automatiquement !

**Le script vous guide automatiquement à travers :**
- ✅ **Étape 0** : Configuration (URLs et clés)
- ✅ **Étape 1** : Test de connexion Cloud + Pi
- ✅ **Étape 2** : Analyse des buckets et fichiers
- ✅ **Étape 3** : Test de téléchargement (dry-run automatique)
- ✅ **Étape 4** : Migration réelle (avec barre de progression)
- ✅ **Étape 5** : Sauvegarde du rapport JSON
- ✅ **Étape 6** : Résumé final avec statistiques

**À chaque étape, vous devez confirmer avant de continuer.**

**Options avancées :**
- `--max-size=50` : Limite taille fichiers à 50MB (défaut: 100MB)
- `--skip-test` : Sauter le test automatique (non recommandé)

**Sécurités v2.0.0 :**
- ✅ Pagination automatique (> 1000 fichiers)
- ✅ Retry automatique (3 tentatives)
- ✅ Timeout 5min par fichier
- ✅ Validation taille max
- ✅ Manifest JSON des fichiers migrés

### 3️⃣ Mettre à jour votre application

Dans votre code (Next.js, React, etc.) :

**Avant (Cloud) :**
```javascript
const supabaseUrl = 'https://xxxxx.supabase.co'
const supabaseKey = 'eyJ...cloud...'
```

**Après (Pi) :**
```javascript
const supabaseUrl = 'http://192.168.1.74:8000'  // API Kong Gateway
const supabaseKey = 'eyJ...pi...'  // Voir ~/stacks/supabase/.env
```

> 📚 **Guide détaillé avec OAuth, SMTP, troubleshooting :** [POST-MIGRATION.md](POST-MIGRATION.md)

---

## 🆘 Problèmes courants

### "Impossible de se connecter au Pi"
```bash
# Sur votre Mac/PC, configurez SSH :
ssh-copy-id pi@192.168.1.74
```

### "Échec export base Cloud"
- Vérifiez que le mot de passe est correct
- Vérifiez votre connexion Internet

### "Les utilisateurs ne peuvent pas se connecter"
- Normal ! Les mots de passe ne sont pas migrés
- Envoyez un reset à tous : voir section "Mots de passe utilisateurs"

---

## 💡 Conseils

### Migration progressive

**Semaine 1 :** Développement
- Utilisez le Pi pour développer
- Gardez Cloud en production

**Semaine 2-3 :** Tests
- Testez tout sur le Pi
- Vérifiez les performances

**Semaine 4 :** Basculement
- Changez l'URL dans votre app
- Le Pi devient votre base principale
- **Économie : ~25€/mois !** 💰

### Rollback rapide

Si problème, retour au Cloud en 30 secondes :
```javascript
// Remettez l'ancienne URL
const supabaseUrl = 'https://xxxxx.supabase.co'
```

---

## 🎉 Résultat final

Après migration complète :
- ✅ Base de données sur le Pi (rapide, local)
- ✅ Utilisateurs fonctionnels (après reset mot de passe)
- ✅ Application connectée au Pi
- ✅ Plus de frais Supabase Cloud
- ✅ Contrôle total de vos données

**Économie annuelle : ~300€** 🚀

---

## 📞 Besoin d'aide ?

- 📖 [Guide technique complet](MIGRATION-CLOUD-TO-PI.md)
- 💬 [GitHub Issues](https://github.com/iamaketechnology/pi5-setup/issues)
- 🐛 [Problèmes courants](MIGRATION-RAPIDE.md#-problèmes-courants)

---

<p align="center">
  <strong>✨ Migration en 10 minutes chrono ! ✨</strong>
</p>
