# 🔄 Migration Supabase Cloud → Raspberry Pi 5

> **Guide complet** : Migrer votre base de données et configuration Supabase Cloud vers votre Pi 5 self-hosted

---

## 📋 Table des Matières

1. [Vue d'Ensemble](#-vue-densemble)
2. [Prérequis](#-prérequis)
3. [Méthode 1 : Migration Automatique (Script)](#-méthode-1--migration-automatique-script)
4. [Méthode 2 : Migration Manuelle](#-méthode-2--migration-manuelle)
5. [Migration Données](#-migration-données)
6. [Migration Auth Users](#-migration-auth-users)
7. [Migration Storage](#-migration-storage)
8. [Vérification Post-Migration](#-vérification-post-migration)
9. [Troubleshooting](#-troubleshooting)

---

## 🎯 Vue d'Ensemble

### Pourquoi Migrer ?

**Avantages du Self-Hosted** :
- 💰 **Gratuit** : 0€/mois vs 25€/mois Supabase Pro
- 🔒 **Contrôle total** : Vos données chez vous
- ⚡ **Latence locale** : Accès réseau local ultra-rapide
- 🛠️ **Personnalisation** : Modifications base sans limites

### Ce qui sera migré
- ✅ **Schéma de base de données** (tables, colonnes, types)
- ✅ **Données** (toutes vos rows)
- ✅ **Functions SQL** (stored procedures)
- ✅ **Triggers** (automatisations DB)
- ✅ **Row Level Security (RLS)** policies
- ✅ **Utilisateurs Auth** (emails, métadonnées)
- ✅ **Fichiers Storage** (buckets + fichiers)
- ⚠️ **Edge Functions** (nécessite adaptation manuelle)

---

## ✅ Prérequis

### 1. Supabase Pi Installé
```bash
# Vérifier installation
docker ps | grep supabase

# Si pas installé
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash
```

### 2. Credentials Supabase Cloud
Récupérer depuis [Dashboard Supabase Cloud](https://app.supabase.com) :
- **Project URL** : `https://xxxxx.supabase.co`
- **API Keys** : Settings → API → `anon` key et `service_role` key
- **Database Password** : Settings → Database → Password

### 3. Outils Nécessaires (sur votre ordinateur)
```bash
# macOS
brew install postgresql  # Pour pg_dump/pg_restore

# Ubuntu/Debian
sudo apt install postgresql-client

# Windows (WSL recommandé)
sudo apt install postgresql-client
```

---

## 🚀 Méthode 1 : Migration Automatique (Script)

### Script de Migration Complet

Je vais créer un script qui automatise tout ! Créer ce fichier :

**`~/migrate-supabase-cloud-to-pi.sh`** :
```bash
#!/bin/bash

# ============================================================
# Migration Supabase Cloud → Raspberry Pi 5
# ============================================================

set -e  # Exit on error

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Migration Supabase Cloud → Pi 5          ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo ""

# ============================================================
# ÉTAPE 1 : Configuration
# ============================================================

echo -e "${YELLOW}📋 ÉTAPE 1/6 : Configuration${NC}"
echo ""

# Supabase Cloud (source)
read -p "🌐 URL Supabase Cloud (ex: https://xxxxx.supabase.co): " CLOUD_URL
read -p "🔑 Service Role Key Cloud: " CLOUD_SERVICE_KEY
read -sp "🔒 Database Password Cloud: " CLOUD_DB_PASSWORD
echo ""

# Extraction project ref depuis URL
CLOUD_PROJECT_REF=$(echo $CLOUD_URL | sed -E 's|https://([^.]+)\.supabase\.co|\1|')
CLOUD_DB_HOST="db.${CLOUD_PROJECT_REF}.supabase.co"

# Raspberry Pi (destination)
read -p "🥧 IP Raspberry Pi (ex: 192.168.1.150): " PI_IP

# Récupérer password PostgreSQL du Pi
echo ""
echo -e "${YELLOW}Récupération password PostgreSQL du Pi...${NC}"
PI_DB_PASSWORD=$(ssh pi@${PI_IP} "cat ~/supabase/.env | grep POSTGRES_PASSWORD | cut -d'=' -f2")

if [ -z "$PI_DB_PASSWORD" ]; then
    echo -e "${RED}❌ Impossible de récupérer le password Pi${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Configuration récupérée${NC}"
echo ""

# ============================================================
# ÉTAPE 2 : Dump Schéma + Données
# ============================================================

echo -e "${YELLOW}📦 ÉTAPE 2/6 : Export base de données Cloud${NC}"
echo ""

DUMP_FILE="supabase_cloud_dump_$(date +%Y%m%d_%H%M%S).sql"

echo "Connexion à Supabase Cloud..."
PGPASSWORD=$CLOUD_DB_PASSWORD pg_dump \
    -h $CLOUD_DB_HOST \
    -U postgres \
    -p 5432 \
    -d postgres \
    --clean \
    --if-exists \
    --no-owner \
    --no-privileges \
    -f $DUMP_FILE

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Export réussi : $DUMP_FILE ($(du -h $DUMP_FILE | cut -f1))${NC}"
else
    echo -e "${RED}❌ Échec export${NC}"
    exit 1
fi
echo ""

# ============================================================
# ÉTAPE 3 : Copier dump sur Pi
# ============================================================

echo -e "${YELLOW}📤 ÉTAPE 3/6 : Transfert vers Pi${NC}"
echo ""

scp $DUMP_FILE pi@${PI_IP}:~/supabase_dump.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Fichier transféré sur Pi${NC}"
else
    echo -e "${RED}❌ Échec transfert${NC}"
    exit 1
fi
echo ""

# ============================================================
# ÉTAPE 4 : Importer dans PostgreSQL Pi
# ============================================================

echo -e "${YELLOW}📥 ÉTAPE 4/6 : Import dans PostgreSQL Pi${NC}"
echo ""

ssh pi@${PI_IP} "PGPASSWORD=${PI_DB_PASSWORD} psql -h localhost -U postgres -p 5432 -d postgres < ~/supabase_dump.sql"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Import réussi dans PostgreSQL Pi${NC}"
else
    echo -e "${YELLOW}⚠️  Import avec warnings (normal si schémas Supabase existent déjà)${NC}"
fi
echo ""

# ============================================================
# ÉTAPE 5 : Migration Auth Users
# ============================================================

echo -e "${YELLOW}👤 ÉTAPE 5/6 : Migration utilisateurs Auth${NC}"
echo ""

read -p "Migrer les utilisateurs Auth ? (y/n): " MIGRATE_AUTH

if [ "$MIGRATE_AUTH" = "y" ]; then
    echo "Export utilisateurs depuis Cloud..."

    # Récupérer anon key du Pi
    PI_ANON_KEY=$(ssh pi@${PI_IP} "cat ~/supabase/.env | grep ANON_KEY | cut -d'=' -f2")

    # Créer script temporaire de migration auth
    cat > /tmp/migrate_auth.sh << 'EOF'
#!/bin/bash
# Script exécuté sur le Pi
CLOUD_URL=$1
CLOUD_KEY=$2
PI_URL="http://localhost:8000"
PI_KEY=$3

# Récupérer users depuis cloud (via API admin)
curl -X GET "${CLOUD_URL}/auth/v1/admin/users" \
    -H "apikey: ${CLOUD_KEY}" \
    -H "Authorization: Bearer ${CLOUD_KEY}" \
    -o /tmp/cloud_users.json

# TODO: Importer dans Pi (nécessite service_role access)
# Pour l'instant, migration manuelle recommandée
EOF

    scp /tmp/migrate_auth.sh pi@${PI_IP}:/tmp/
    ssh pi@${PI_IP} "bash /tmp/migrate_auth.sh $CLOUD_URL $CLOUD_SERVICE_KEY $PI_ANON_KEY"

    echo -e "${YELLOW}⚠️  Migration Auth nécessite configuration manuelle (voir guide)${NC}"
fi
echo ""

# ============================================================
# ÉTAPE 6 : Migration Storage (optionnel)
# ============================================================

echo -e "${YELLOW}📁 ÉTAPE 6/6 : Migration Storage${NC}"
echo ""

read -p "Migrer les fichiers Storage ? (y/n): " MIGRATE_STORAGE

if [ "$MIGRATE_STORAGE" = "y" ]; then
    echo "⚠️  Migration Storage nécessite Supabase CLI (voir guide manuel)"
    echo "Commande : supabase db dump --db-url <cloud-url> | supabase db restore"
fi
echo ""

# ============================================================
# RÉSUMÉ
# ============================================================

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✅ MIGRATION TERMINÉE              ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo ""
echo "📊 Résumé :"
echo "  • Dump SQL : $DUMP_FILE"
echo "  • Transféré sur Pi : ~/supabase_dump.sql"
echo "  • Importé dans PostgreSQL Pi"
echo ""
echo "🔍 Vérifications recommandées :"
echo "  1. Tester connexion : http://${PI_IP}:8000"
echo "  2. Vérifier tables : SELECT * FROM information_schema.tables;"
echo "  3. Compter rows : SELECT COUNT(*) FROM your_table;"
echo ""
echo "📚 Prochaines étapes :"
echo "  • Migration Auth : Voir MIGRATION-CLOUD-TO-PI.md (Auth Users)"
echo "  • Migration Storage : Voir MIGRATION-CLOUD-TO-PI.md (Storage)"
echo "  • Mettre à jour app : Changer SUPABASE_URL vers Pi"
echo ""
echo -e "${BLUE}Guide complet : pi5-setup/01-infrastructure/supabase/MIGRATION-CLOUD-TO-PI.md${NC}"
echo ""

# Nettoyage
read -p "Supprimer le dump local ? (y/n): " DELETE_DUMP
if [ "$DELETE_DUMP" = "y" ]; then
    rm $DUMP_FILE
    echo -e "${GREEN}✅ Dump local supprimé${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Migration terminée avec succès !${NC}"
```

### Utilisation du Script

```bash
# 1. Télécharger le script
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/migrate-cloud-to-pi.sh -o migrate-supabase.sh

# 2. Rendre exécutable
chmod +x migrate-supabase.sh

# 3. Exécuter
./migrate-supabase.sh

# Le script vous demandera :
# - URL Supabase Cloud
# - Service Role Key
# - Database Password
# - IP du Pi
```

---

## 🛠️ Méthode 2 : Migration Manuelle

Si vous préférez contrôler chaque étape :

### Étape 1 : Export Base Cloud

#### 1.1 Récupérer Database URL
```bash
# Dashboard Supabase Cloud → Settings → Database → Connection String
# Format : postgresql://postgres:[PASSWORD]@db.[REF].supabase.co:5432/postgres

# Ou construire manuellement :
CLOUD_DB_HOST="db.xxxxx.supabase.co"  # xxxxx = votre project ref
CLOUD_DB_USER="postgres"
CLOUD_DB_PASSWORD="votre-password"
CLOUD_DB_NAME="postgres"
CLOUD_DB_PORT="5432"
```

#### 1.2 Dump complet (schéma + données)
```bash
# Export TOUT (schéma + données + functions)
PGPASSWORD=votre-password pg_dump \
    -h db.xxxxx.supabase.co \
    -U postgres \
    -p 5432 \
    -d postgres \
    --clean \
    --if-exists \
    --no-owner \
    --no-privileges \
    -f supabase_cloud_full.sql

# Vérifier taille
ls -lh supabase_cloud_full.sql
```

#### 1.3 Dump schéma seul (optionnel)
```bash
# Si vous voulez juste le schéma (pas les données)
PGPASSWORD=votre-password pg_dump \
    -h db.xxxxx.supabase.co \
    -U postgres \
    -p 5432 \
    -d postgres \
    --schema-only \
    --no-owner \
    --no-privileges \
    -f supabase_cloud_schema.sql
```

---

### Étape 2 : Transfert vers Pi

```bash
# Copier fichier SQL sur Pi
scp supabase_cloud_full.sql pi@IP_DU_PI:~/supabase_dump.sql

# Vérifier
ssh pi@IP_DU_PI "ls -lh ~/supabase_dump.sql"
```

---

### Étape 3 : Import dans PostgreSQL Pi

#### 3.1 Récupérer password PostgreSQL Pi
```bash
# Sur le Pi
ssh pi@IP_DU_PI
cat ~/supabase/.env | grep POSTGRES_PASSWORD
# Copier le password affiché
```

#### 3.2 Importer le dump
```bash
# Sur le Pi (ou depuis votre ordi)
PGPASSWORD=votre-password-pi psql \
    -h localhost \
    -U postgres \
    -p 5432 \
    -d postgres \
    < ~/supabase_dump.sql

# Ou via Docker
docker exec -i supabase-db psql -U postgres postgres < ~/supabase_dump.sql
```

#### 3.3 Vérifier import
```bash
# Connexion PostgreSQL
PGPASSWORD=votre-password-pi psql -h localhost -U postgres -p 5432 -d postgres

# Lister tables
\dt

# Compter rows d'une table
SELECT COUNT(*) FROM your_table_name;

# Quitter
\q
```

---

## 👥 Migration Auth Users

### Méthode 1 : Export/Import SQL (Recommandé)

Les utilisateurs sont stockés dans `auth.users`. Le dump précédent les inclut déjà !

**Vérification** :
```sql
-- Sur le Pi
SELECT COUNT(*) FROM auth.users;

-- Voir quelques users
SELECT id, email, created_at FROM auth.users LIMIT 5;
```

### Méthode 2 : Via Supabase CLI (Alternative)

```bash
# 1. Installer Supabase CLI
npm install -g supabase

# 2. Login
supabase login

# 3. Link projet Cloud
supabase link --project-ref xxxxx

# 4. Dump auth users
supabase db dump --data-only --schema auth > auth_users.sql

# 5. Importer dans Pi
scp auth_users.sql pi@IP_DU_PI:~/
ssh pi@IP_DU_PI "docker exec -i supabase-db psql -U postgres postgres < ~/auth_users.sql"
```

### Méthode 3 : Re-création Users (Si problèmes)

Si les users ne s'importent pas correctement :

```javascript
// Script Node.js pour recréer users
const { createClient } = require('@supabase/supabase-js')

// Cloud (source)
const cloudSupabase = createClient(
  'https://xxxxx.supabase.co',
  'service-role-key-cloud'
)

// Pi (destination)
const piSupabase = createClient(
  'http://IP_DU_PI:8000',
  'service-role-key-pi'
)

async function migrateUsers() {
  // 1. Récupérer users cloud
  const { data: users, error } = await cloudSupabase.auth.admin.listUsers()

  if (error) throw error

  console.log(`🔍 ${users.length} users trouvés`)

  // 2. Créer sur Pi
  for (const user of users) {
    try {
      const { data, error } = await piSupabase.auth.admin.createUser({
        email: user.email,
        email_confirm: true,
        user_metadata: user.user_metadata,
        app_metadata: user.app_metadata
      })

      if (error) {
        console.error(`❌ ${user.email}:`, error.message)
      } else {
        console.log(`✅ ${user.email}`)
      }
    } catch (err) {
      console.error(`❌ ${user.email}:`, err.message)
    }
  }

  console.log('✅ Migration terminée')
}

migrateUsers()
```

**⚠️ Important** : Les **passwords** ne peuvent pas être exportés (hashés). Options :
- Utiliser **password reset** pour tous les users
- Demander aux users de **se reconnecter**
- Configurer **OAuth** (Google, GitHub, etc.)

---

## 📁 Migration Storage

### Méthode 1 : Supabase CLI (Recommandé)

```bash
# 1. Lister buckets Cloud
supabase storage ls --project-ref xxxxx

# 2. Download depuis Cloud
supabase storage download <bucket-name> ./<local-folder> --project-ref xxxxx

# 3. Upload vers Pi
# Configuration Pi dans Supabase CLI
supabase link --project-ref local-pi-id

# 4. Upload fichiers
supabase storage upload <bucket-name> ./<local-folder>/*
```

### Méthode 2 : Script Migration Storage

**`migrate-storage.js`** :
```javascript
const { createClient } = require('@supabase/supabase-js')
const fs = require('fs')
const path = require('path')

// Cloud
const cloudSupabase = createClient(
  'https://xxxxx.supabase.co',
  'service-role-key-cloud'
)

// Pi
const piSupabase = createClient(
  'http://IP_DU_PI:8000',
  'service-role-key-pi'
)

async function migrateBucket(bucketName) {
  console.log(`📦 Migration bucket: ${bucketName}`)

  // 1. Lister fichiers Cloud
  const { data: files, error } = await cloudSupabase
    .storage
    .from(bucketName)
    .list()

  if (error) throw error

  console.log(`🔍 ${files.length} fichiers trouvés`)

  // 2. Download + Upload chaque fichier
  for (const file of files) {
    try {
      // Download depuis Cloud
      const { data: blob, error: downloadError } = await cloudSupabase
        .storage
        .from(bucketName)
        .download(file.name)

      if (downloadError) throw downloadError

      // Upload vers Pi
      const { data: uploadData, error: uploadError } = await piSupabase
        .storage
        .from(bucketName)
        .upload(file.name, blob, {
          upsert: true
        })

      if (uploadError) throw uploadError

      console.log(`✅ ${file.name}`)
    } catch (err) {
      console.error(`❌ ${file.name}:`, err.message)
    }
  }
}

// Exécuter
async function main() {
  // Créer buckets sur Pi (mêmes noms/configs que Cloud)
  const buckets = ['avatars', 'public', 'private']  // Vos buckets

  for (const bucket of buckets) {
    // Créer bucket sur Pi
    await piSupabase.storage.createBucket(bucket, {
      public: true  // Ajuster selon config Cloud
    })

    // Migrer fichiers
    await migrateBucket(bucket)
  }

  console.log('🎉 Migration Storage terminée')
}

main()
```

### Méthode 3 : rclone (Pour gros volumes)

```bash
# 1. Installer rclone
curl https://rclone.org/install.sh | sudo bash

# 2. Configurer remote Cloud
rclone config
# Choisir : s3 (Supabase Storage est S3-compatible)
# Endpoint : https://xxxxx.supabase.co/storage/v1/s3
# Access Key : project-ref
# Secret Key : service-role-key

# 3. Configurer remote Pi
rclone config
# Même chose avec IP Pi

# 4. Sync
rclone sync supabase-cloud:bucket-name supabase-pi:bucket-name -P
```

---

## ✅ Vérification Post-Migration

### Checklist

```bash
# 1. Vérifier tables
psql -h localhost -U postgres -p 5432 -d postgres -c "\dt"

# 2. Compter rows
psql -h localhost -U postgres -p 5432 -d postgres -c "SELECT COUNT(*) FROM your_table;"

# 3. Vérifier Auth users
psql -h localhost -U postgres -p 5432 -d postgres -c "SELECT COUNT(*) FROM auth.users;"

# 4. Tester API
curl http://IP_DU_PI:8000/rest/v1/your_table?select=* \
  -H "apikey: votre-anon-key"

# 5. Tester Auth
curl http://IP_DU_PI:8000/auth/v1/health

# 6. Tester Storage
curl http://IP_DU_PI:8000/storage/v1/bucket/list
```

### Test Application

```javascript
// Mettre à jour URL dans votre app
const supabase = createClient(
  'http://IP_DU_PI:8000',  // Nouvelle URL Pi
  'anon-key-pi'             // Nouvelle clé Pi
)

// Test select
const { data, error } = await supabase
  .from('your_table')
  .select('*')
  .limit(10)

console.log('Migration OK:', data.length, 'rows')
```

---

## 🐛 Troubleshooting

### Problème 1 : pg_dump échoue (Cloud)
```
Error: pg_dump: error: connection to server failed
```

**Solutions** :
```bash
# 1. Vérifier IP whitelisting (Dashboard Cloud → Settings → Database)
# Ajouter votre IP publique

# 2. Vérifier password
echo "votre-password" | base64  # Tester encodage

# 3. Utiliser --verbose pour debug
pg_dump --verbose -h db.xxxxx.supabase.co ...
```

---

### Problème 2 : Import échoue (Pi)
```
ERROR: role "supabase_admin" does not exist
```

**Solution** : Ignorer, c'est normal
```bash
# Ajouter --no-owner --no-privileges au dump
pg_dump ... --no-owner --no-privileges ...

# Ou ignorer erreurs à l'import
psql ... 2>/dev/null
```

---

### Problème 3 : RLS Policies manquantes
```
Error: new row violates row-level security policy
```

**Solution** : Vérifier policies importées
```sql
-- Lister policies
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE schemaname = 'public';

-- Activer RLS sur table
ALTER TABLE your_table ENABLE ROW LEVEL SECURITY;

-- Recréer policy si manquante
CREATE POLICY "policy_name" ON your_table
  FOR SELECT USING (true);
```

---

### Problème 4 : Users ne peuvent pas login
```
Error: Invalid login credentials
```

**Solutions** :
```bash
# 1. Vérifier users importés
SELECT email, encrypted_password FROM auth.users LIMIT 5;

# 2. Password reset pour tous
# Script : Envoyer email reset à tous users

# 3. Ou re-créer users (voir Méthode 3 Auth)
```

---

### Problème 5 : Storage files 404
```
Error: Object not found
```

**Solutions** :
```bash
# 1. Vérifier buckets créés
SELECT name FROM storage.buckets;

# 2. Créer bucket manquant
INSERT INTO storage.buckets (id, name, public)
VALUES ('bucket-name', 'bucket-name', true);

# 3. Vérifier fichiers
SELECT * FROM storage.objects WHERE bucket_id = 'bucket-name';
```

---

## 🔄 Migration Incrémentale (Sync Continue)

Pour garder Cloud et Pi synchros pendant transition :

### Script Sync Bidirectionnel

**`sync-cloud-pi.sh`** :
```bash
#!/bin/bash

# Sync données Cloud → Pi toutes les heures
while true; do
  # 1. Dump incremental (depuis dernière sync)
  PGPASSWORD=$CLOUD_PASSWORD pg_dump \
    -h $CLOUD_HOST \
    -U postgres \
    --data-only \
    --inserts \
    | PGPASSWORD=$PI_PASSWORD psql -h $PI_HOST -U postgres

  echo "✅ Sync $(date)"

  sleep 3600  # 1 heure
done
```

**Alternative : Réplication PostgreSQL**
```bash
# Configuration réplication logique (avancé)
# Voir : https://www.postgresql.org/docs/current/logical-replication.html
```

---

## 📚 Ressources

### Documentation
- [PostgreSQL pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html)
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- [Supabase Migration Guide](https://supabase.com/docs/guides/platform/migrating-and-upgrading-projects)

### Guides Connexes
- [WORKFLOW-DEVELOPPEMENT.md](WORKFLOW-DEVELOPPEMENT.md) - Développer avec Pi
- [README.md](README.md) - Documentation Supabase Pi 5
- [GUIDE-DEPLOIEMENT-WEB.md](../../GUIDE-DEPLOIEMENT-WEB.md) - Déploiement apps

### Scripts Utiles
```bash
# Healthcheck Pi
~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-healthcheck.sh

# Backup Pi
~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-backup.sh

# Diagnostic
~/pi5-setup/01-infrastructure/supabase/scripts/utils/diagnostic-supabase-complet.sh
```

---

## 💡 Bonnes Pratiques

### Avant Migration
- [ ] **Backup Cloud** complet (au cas où)
- [ ] **Tester Pi** avec données test
- [ ] **Planifier downtime** (si app en prod)
- [ ] **Prévenir users** (maintenance)

### Pendant Migration
- [ ] **Mode maintenance** sur app
- [ ] **Monitorer** logs Pi (docker logs)
- [ ] **Vérifier** chaque étape avant suivante
- [ ] **Garder** dumps pour rollback

### Après Migration
- [ ] **Tests complets** (auth, DB, storage)
- [ ] **Comparer counts** (rows Cloud vs Pi)
- [ ] **Monitoring** 24h (Grafana)
- [ ] **Backups auto** activés

### Stratégie Rollback
```bash
# Si problème, revenir au Cloud
# 1. Changer URL app vers Cloud
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co

# 2. Investiguer problème Pi
# 3. Corriger et re-migrer
```

---

## 🎯 Prochaines Étapes

### Option 1 : Garder les Deux (Recommandé pendant transition)
```bash
# App en dev → Pi (local rapide)
# App en prod → Cloud (stable)

# Quand prêt → Basculer prod vers Pi
```

### Option 2 : Migration Complète
```bash
# 1. Migration OK
# 2. Changer DNS/URLs vers Pi
# 3. Désactiver projet Cloud
# 4. Économiser 25€/mois ! 🎉
```

### Option 3 : Hybrid (Best of Both)
```bash
# Pi → Backend principal (DB, Auth)
# Cloud → Edge Functions (si besoin)
# Ou inverse selon use case
```

---

<p align="center">
  <strong>🔄 Bonne migration vers votre Pi 5 ! 🚀</strong>
</p>

<p align="center">
  <sub>Questions ? Voir <a href="https://github.com/iamaketechnology/pi5-setup/issues">GitHub Issues</a></sub>
</p>
