# Supabase Schema Setup

Configuration de la base de données Supabase pour le PI5 Control Center v4.0.

---

## 📋 Fichiers

| Fichier | Description |
|---------|-------------|
| `schema.sql` | Tables, indexes, triggers, views |
| `policies.sql` | Row Level Security (RLS) policies |
| `seed.sql` | Données initiales (migration pi5 actuel) |

---

## 🚀 Installation

### Option 1 : Via Supabase Studio (Recommandé)

1. **Accéder à Supabase Studio**
   ```bash
   # URL locale (si Supabase sur pi5)
   open http://pi5.local:8001/project/default

   # Ou via tunnel SSH
   ssh -L 3000:localhost:3000 pi@pi5.local
   open http://localhost:3000
   ```

2. **Exécuter les scripts SQL**
   - Aller dans **SQL Editor** (icône ⚡)
   - Copier/coller le contenu de chaque fichier **dans l'ordre** :
     1. `schema.sql` → Run
     2. `policies.sql` → Run
     3. `seed.sql` → Run

3. **Vérifier l'installation**
   ```sql
   -- Vérifier le schema
   SELECT table_name
   FROM information_schema.tables
   WHERE table_schema = 'control_center';

   -- Vérifier le Pi migré
   SELECT * FROM control_center.pis;
   ```

### Option 2 : Via psql (Ligne de commande)

1. **Se connecter à PostgreSQL**
   ```bash
   # Depuis Mac (tunnel SSH)
   ssh -L 5432:localhost:5432 pi@pi5.local

   # Dans un autre terminal
   psql "postgresql://postgres:RGm4e181qnFue5TG9XooHo3nNW7tPXiK@localhost:5432/postgres"
   ```

2. **Exécuter les scripts**
   ```bash
   \i /path/to/schema.sql
   \i /path/to/policies.sql
   \i /path/to/seed.sql
   ```

### Option 3 : Script automatique (À venir)

```bash
# Futur : Installation automatisée
cd tools/admin-panel
npm run db:setup
```

---

## 🗂️ Structure du Schema

```
control_center (schema)
├── pis (table)                    # Inventaire Raspberry Pi
├── installations (table)          # Historique installations
├── system_stats (table)           # Métriques système
├── scheduled_tasks (table)        # Tâches planifiées
├── pis_with_stats (view)          # Pis + dernières stats
└── installation_summary (view)    # Résumé par Pi
```

---

## 🔐 Sécurité (RLS)

- ✅ **Service Role** : Accès complet (backend API)
- ✅ **Authenticated** : Lecture seule (futur web UI)
- ❌ **Anonymous** : Aucun accès
- 🔒 **RLS activé** sur toutes les tables

---

## 🧪 Tests Rapides

### Vérifier le Pi migré
```sql
SELECT
    name,
    hostname,
    status,
    tags
FROM control_center.pis;
```

**Résultat attendu** :
```
 name |  hostname   | status |       tags
------+-------------+--------+------------------
 pi5  | pi5.local   | active | {production,main}
```

### Tester une insertion
```sql
INSERT INTO control_center.installations (
    pi_id,
    script_name,
    status,
    started_at
) SELECT
    id,
    'test-script.sh',
    'success',
    NOW()
FROM control_center.pis
WHERE hostname = 'pi5.local';

-- Vérifier
SELECT * FROM control_center.installations;
```

### Vue avec stats
```sql
SELECT
    name,
    hostname,
    status,
    cpu_percent,
    ram_percent
FROM control_center.pis_with_stats;
```

---

## 🔧 Maintenance

### Nettoyer anciennes stats (7 jours)
```sql
SELECT control_center.cleanup_old_system_stats();
```

### Supprimer toutes les données (reset)
```sql
TRUNCATE TABLE control_center.system_stats CASCADE;
TRUNCATE TABLE control_center.installations CASCADE;
TRUNCATE TABLE control_center.scheduled_tasks CASCADE;
DELETE FROM control_center.pis;
```

### Supprimer le schema complet
```sql
DROP SCHEMA control_center CASCADE;
```

---

## 📝 Notes

- **Schema `control_center`** : Isolation du schema `public`
- **UUID** : IDs compatibles Supabase Realtime
- **TIMESTAMPTZ** : Timestamps avec timezone
- **JSONB** : Métadonnées flexibles
- **RLS** : Sécurité multi-tenant (prêt pour futur)

---

## 🔗 Prochaines Étapes

1. ✅ Exécuter `schema.sql`, `policies.sql`, `seed.sql`
2. 🔄 Créer `lib/supabase-client.js` (Phase 2)
3. 🔄 Refactorer `server.js` pour utiliser Supabase
4. 🔄 Migrer routes `/api/pis` vers Supabase

---

**Version** : 4.0.0
**Last Updated** : 2025-01-17
