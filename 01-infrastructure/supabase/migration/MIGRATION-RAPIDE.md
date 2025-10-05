# ⚡ Migration Rapide Supabase Cloud → Pi 5

> **TL;DR** : Migrer votre base Supabase Cloud vers Pi en 5 minutes

---

## 🚀 Migration Automatique (Recommandé)

### ⚠️ Important : Où Exécuter le Script ?

**Le script doit être exécuté DEPUIS votre Mac/PC**, pas sur le Raspberry Pi !

- ✅ **Sur votre Mac/PC** → Le script se connecte au Pi via SSH
- ❌ **Sur le Pi** → Le script ne peut pas se connecter à lui-même

### Méthode Recommandée (Interactive)

**Sur votre Mac/PC (pas sur le Pi) :**

```bash
# 1. Télécharger le script
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/migration/migrate-cloud-to-pi.sh -o migrate.sh

# 2. Rendre exécutable
chmod +x migrate.sh

# 3. Exécuter en mode interactif
./migrate.sh
```

**Le script va vous demander :**
1. URL Supabase Cloud : `https://xxxxx.supabase.co`
2. Service Role Key Cloud
3. Database Password Cloud
4. **IP du Raspberry Pi** : `192.168.1.74` (exemple - votre IP locale)

> ℹ️ Le script installe automatiquement `postgresql-client` s'il n'est pas présent sur votre Mac/PC

### Ou Depuis le Repo Local

**Sur votre Mac/PC (pas sur le Pi) :**

```bash
# 1. Cloner repo (si pas déjà fait)
git clone https://github.com/iamaketechnology/pi5-setup.git
cd pi5-setup

# 2. Exécuter script
./pi5-setup/01-infrastructure/supabase/migration/migrate-cloud-to-pi.sh
```

### Prérequis SSH

Avant d'exécuter le script, assurez-vous de pouvoir vous connecter au Pi via SSH :

```bash
# Tester connexion SSH depuis votre Mac/PC
ssh pi@192.168.1.74

# Si échec, configurer clé SSH
ssh-copy-id pi@192.168.1.74
```

### Ce que le Script Fait

✅ **Automatiquement** :
- Export base Cloud (schéma + données)
- Transfert vers Pi
- Import dans PostgreSQL Pi
- Vérification post-migration
- Tests API/Auth

⚠️ **Manuellement** (après script) :
- Migration Auth Users (passwords)
- Migration Storage (fichiers)

---

## 📋 Informations Nécessaires

Le script vous demandera :

### Supabase Cloud
1. **URL Projet** : `https://xxxxx.supabase.co`
   - Récupérer : [Dashboard Cloud](https://app.supabase.com) → Project Settings

2. **Service Role Key** : `eyJhbG...`
   - Récupérer : Settings → API → `service_role` key

3. **Database Password** : `votre-password`
   - Récupérer : Settings → Database → Password

### Raspberry Pi
4. **IP du Pi** : `192.168.1.150` (exemple)
   - Trouver : `hostname -I` sur le Pi

---

## 🎯 Résultat Attendu

### Après Migration

✅ **Base de données** :
```bash
# Toutes vos tables sur Pi
http://IP_PI:8000 → Supabase Studio
```

✅ **Données** :
```bash
# Toutes vos rows migrées
SELECT COUNT(*) FROM your_table;
```

✅ **RLS Policies** :
```bash
# Sécurité row-level préservée
```

⚠️ **Auth Users** :
- **Emails/metadata** : ✅ Migrés
- **Passwords** : ❌ Nécessite reset (voir guide complet)

⚠️ **Storage** :
- **Buckets** : ✅ Créés
- **Fichiers** : ❌ Migration manuelle (voir guide complet)

---

## 🔧 Prochaines Étapes

### 1. Migration Auth Users (Passwords)

**Option A : Password Reset** (Recommandé)
```javascript
// Script : Envoyer email reset à tous users
const { data: users } = await supabase.auth.admin.listUsers()

for (const user of users) {
  await supabase.auth.resetPasswordForEmail(user.email)
  console.log(`✅ Reset envoyé : ${user.email}`)
}
```

**Option B : OAuth** (Meilleure UX)
```bash
# Configurer Google/GitHub OAuth
# Settings → Authentication → Providers
# Users pourront se reconnecter via OAuth
```

### 2. Migration Storage Files

**Script Node.js** (`migrate-storage.js`) :
```javascript
// Voir guide complet : MIGRATION-CLOUD-TO-PI.md
// Section "Migration Storage"
```

**Ou Supabase CLI** :
```bash
supabase storage download bucket-name ./local-folder
supabase storage upload bucket-name ./local-folder/*
```

### 3. Mettre à Jour Application

**Variables d'environnement** :
```bash
# Avant (Cloud)
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...cloud-key...

# Après (Pi)
NEXT_PUBLIC_SUPABASE_URL=http://IP_PI:8000
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...pi-key...
```

**Récupérer clé Pi** :
```bash
ssh pi@IP_PI "cat ~/supabase/.env | grep ANON_KEY"
```

---

## 🐛 Problèmes Courants

### Erreur : "pg_dump: connection failed"
```bash
# Solution : Vérifier IP whitelisting
# Dashboard Cloud → Settings → Database → Add your IP
```

### Erreur : "SSH connection refused"
```bash
# Solution : Configurer clé SSH
ssh-copy-id pi@IP_PI
```

### Erreur : "role supabase_admin does not exist"
```bash
# Solution : Normal, ignorer (c'est géré par le script)
```

### Users ne peuvent pas login
```bash
# Solution : Passwords non migrés
# 1. Envoyer password reset à tous
# 2. Ou configurer OAuth
```

---

## 📚 Documentation Complète

Pour migration avancée (Auth, Storage, etc.) :

📖 **[MIGRATION-CLOUD-TO-PI.md](MIGRATION-CLOUD-TO-PI.md)** - Guide complet
- Migration Auth Users (3 méthodes)
- Migration Storage (scripts)
- Troubleshooting détaillé
- Migration incrémentale

📖 **[WORKFLOW-DEVELOPPEMENT.md](WORKFLOW-DEVELOPPEMENT.md)** - Développer avec Pi
- Configuration client Supabase
- Tests et debugging
- Best practices

---

## ✅ Checklist Migration

- [ ] **Backup Cloud** : Export complet (sécurité)
- [ ] **Script migration** : Exécuté avec succès
- [ ] **Vérification tables** : Compter rows Cloud vs Pi
- [ ] **Test API** : `curl http://IP_PI:8000/rest/v1/`
- [ ] **Migration Auth** : Password reset ou OAuth
- [ ] **Migration Storage** : Fichiers transférés
- [ ] **Update app** : Variables env changées
- [ ] **Tests complets** : Auth, DB, Storage OK
- [ ] **Monitoring** : Grafana actif (optionnel)
- [ ] **Backups Pi** : Automatiques configurés

---

## 💡 Conseils Pro

### Stratégie Migration Progressive

**Étape 1 : Dev/Test** (maintenant)
```bash
# Migrer vers Pi pour développement
# Garder Cloud en production
```

**Étape 2 : Staging** (1 semaine)
```bash
# Tester Pi avec données réelles
# Monitorer performance
```

**Étape 3 : Production** (quand prêt)
```bash
# Basculer prod vers Pi
# Économiser 25€/mois !
```

### Rollback Plan

Si problème, revenir au Cloud en 1 minute :
```bash
# .env.local
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co  # Rollback
```

---

## 🎉 Résultat Final

Après migration complète :

- ✅ **Base de données** → Pi (rapide, local)
- ✅ **Auth** → Pi (users fonctionnels)
- ✅ **Storage** → Pi (fichiers accessibles)
- ✅ **Application** → Connectée au Pi
- 💰 **Économie** → 25€/mois vs Supabase Pro !

---

<p align="center">
  <strong>⚡ Migration en 5 minutes chrono ! ⚡</strong>
</p>

<p align="center">
  Questions ? <a href="https://github.com/iamaketechnology/pi5-setup/issues">GitHub Issues</a>
</p>
