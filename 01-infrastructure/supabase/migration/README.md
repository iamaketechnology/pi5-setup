# 📦 Migration Supabase Cloud → Pi

> **Tous les outils pour migrer votre Supabase Cloud vers le Raspberry Pi**

---

## 📚 Guides de Migration

### Pour Débutants
- **[GUIDE-MIGRATION-SIMPLE.md](GUIDE-MIGRATION-SIMPLE.md)** ⭐ Commencez ici !
  - Langage simple, pas de jargon technique
  - Migration en 3 étapes
  - ~10 minutes

### Guide Rapide
- **[MIGRATION-RAPIDE.md](MIGRATION-RAPIDE.md)**
  - TL;DR pour utilisateurs expérimentés
  - Commandes essentielles
  - ~5 minutes

### Guide Technique Complet
- **[MIGRATION-CLOUD-TO-PI.md](MIGRATION-CLOUD-TO-PI.md)**
  - Documentation exhaustive
  - Tous les scénarios
  - Troubleshooting avancé

### Après la Migration
- **[POST-MIGRATION.md](POST-MIGRATION.md)** ⭐ Important !
  - Reset des mots de passe utilisateurs
  - Migration des fichiers Storage
  - Configuration OAuth
  - Mise à jour de l'application

### Développement
- **[WORKFLOW-DEVELOPPEMENT.md](WORKFLOW-DEVELOPPEMENT.md)**
  - Développer avec Supabase Pi
  - Best practices
  - Testing & debugging

---

## 🛠️ Scripts Automatiques

### Migration Principale
```bash
# Script de migration automatique
./migrate-cloud-to-pi.sh
```
**Migre :** Base de données, schéma, données, RLS policies

### Post-Migration

#### Reset Mots de Passe
```bash
# Envoie un email de reset à tous les utilisateurs
npm install @supabase/supabase-js
node post-migration-password-reset.js
```

#### Migration Storage
```bash
# Migre tous les fichiers (images, documents, etc.)
npm install @supabase/supabase-js
node post-migration-storage.js
```

---

## 🚀 Quick Start

### Étape 1 : Migration Base de Données
```bash
# Sur votre Mac/PC
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/migration/migrate-cloud-to-pi.sh -o migrate.sh
chmod +x migrate.sh
./migrate.sh
```

### Étape 2 : Reset Passwords
```bash
npm install @supabase/supabase-js
node post-migration-password-reset.js
```

### Étape 3 : Migration Storage (optionnel)
```bash
node post-migration-storage.js
```

---

## 📋 Informations Nécessaires

Avant de commencer, préparez :

### Supabase Cloud
1. **URL** : `https://xxxxx.supabase.co` (Dashboard → Settings → General)
2. **Service Role Key** : `eyJ...` (Settings → API)
3. **Database Password** : (Settings → Database)

### Raspberry Pi
4. **IP** : `192.168.1.74` (commande `hostname -I` sur le Pi)

---

## 📊 Ce qui est Migré

### ✅ Automatiquement
- Tables et structure
- Données (toutes les rows)
- RLS Policies
- Fonctions et triggers
- Utilisateurs (emails et métadonnées)

### ❌ Migration Manuelle
- **Mots de passe** : Script `post-migration-password-reset.js`
- **Fichiers Storage** : Script `post-migration-storage.js`

---

## 🔄 Workflow Recommandé

```
1. Migration Base → migrate-cloud-to-pi.sh
          ↓
2. Vérification  → http://PI_IP:3000 (Studio)
          ↓
3. Reset Passwords → post-migration-password-reset.js
          ↓
4. Migration Storage → post-migration-storage.js
          ↓
5. Update App Config → Changez URL vers Pi
          ↓
6. Tests Complets → Auth, DB, Storage
```

---

## 🆘 Support

- 📖 [Guides détaillés](.) - Tous dans ce dossier
- 💬 [GitHub Issues](https://github.com/iamaketechnology/pi5-setup/issues)
- 🐛 Problèmes ? Voir [POST-MIGRATION.md](POST-MIGRATION.md#-problèmes-courants)

---

## 🎯 Résultat Final

Après migration complète :
- ✅ Base de données sur le Pi (rapide, local)
- ✅ Utilisateurs peuvent se connecter
- ✅ Fichiers accessibles
- ✅ Application fonctionnelle
- 💰 **Économie : ~300€/an** vs Supabase Cloud

---

<p align="center">
  <strong>🚀 Migration en 15 minutes chrono ! 🚀</strong>
</p>
