# 🔒 Database Security Audit Tool

**Version**: 1.0.0
**Dernière MAJ**: 2025-10-18

---

## 📋 Description

Script de sécurité complet qui scanne **toutes les bases de données PostgreSQL** sur votre Raspberry Pi et détecte les vulnérabilités les plus fréquentes.

---

## ✨ Fonctionnalités

### 12 Vérifications de Sécurité

| Check | Catégorie | Niveau |
|-------|-----------|--------|
| **1. SECURITY DEFINER sans search_path** | Functions | 🔴 CRITIQUE |
| **2. search_path sans pg_temp** | Functions | 🔴 CRITIQUE |
| **3. RLS policies avec role public** | Permissions | 🟡 WARNING |
| **4. search_path vide** | Functions | 🔴 CRITIQUE |
| **5. Tables sans RLS** | RLS | 🟡 WARNING |
| **6. Utilisateurs sans password** | Auth | 🔴 CRITIQUE |
| **7. Comptes superuser inutiles** | Auth | 🟡 WARNING |
| **8. Permissions PUBLIC dangereuses** | Permissions | 🟡 WARNING |
| **9. Risques d'injection SQL** | Functions | 🟡 WARNING |
| **10. Tables unlogged** | Data Loss | 🟡 WARNING |
| **11. Foreign keys sans index** | Performance | 🔵 INFO |
| **12. Méthodes d'auth faibles** | Auth | 🟡 WARNING |

---

## 🚀 Usage

### Via ligne de commande (SSH Pi)

```bash
# Copier le script sur le Pi
scp common-scripts/security/audit-all-databases.sh pi@pi5.local:/tmp/

# SSH et exécuter
ssh pi@pi5.local
sudo bash /tmp/audit-all-databases.sh
```

### Avec variable d'environnement (si détection auto échoue)

```bash
# Si tu as plusieurs containers avec passwords différents
export DB_PASSWORD="mon_password_custom"
sudo -E bash /tmp/audit-all-databases.sh
```

**Note** : Le script détecte **automatiquement** le password de chaque container via :
1. `docker inspect` (variables d'environnement)
2. Fichiers `.env` (stacks/supabase/.env, etc.)
3. `docker exec printenv` (lecture directe)

Aucun password n'est hardcodé - fonctionne sur **toutes les machines** !

### Via Admin Panel

1. Ouvrir **Admin Panel** → Onglet **Database**
2. Cliquer sur **"Lancer l'Audit Sécurité"**
3. Voir le résumé visuel
4. Cliquer **"Voir rapport complet"** pour les détails

---

## 📊 Exemple de Sortie

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔒 Multi-Database Security Audit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔍 Detecting PostgreSQL containers...
✅ Found containers:
   - supabase-db

🐳 Container: supabase-db

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Database: postgres (Container: supabase-db)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Check 1: SECURITY DEFINER Functions
✅ PASS - All SECURITY DEFINER functions have search_path protection

📋 Check 2: search_path with pg_temp
✅ PASS - All functions include pg_temp in search_path

📋 Check 3: RLS Policies Security
✅ PASS - No overly permissive RLS policies found

📋 Check 4: Empty search_path
✅ PASS - No functions with empty search_path

📋 Check 5: RLS Enabled on Tables
✅ PASS - All tables have RLS enabled

📋 Check 6: Password Security
✅ PASS - All users have passwords

📋 Check 7: Superuser Accounts
✅ PASS - No unnecessary superuser accounts

📋 Check 8: Public Schema Permissions
✅ PASS - No dangerous PUBLIC permissions

📋 Check 9: SQL Injection Risks
✅ PASS - No unsafe dynamic SQL detected

📋 Check 10: Unlogged Tables
✅ PASS - No unlogged tables (data is crash-safe)

📋 Check 11: Foreign Key Indexes
✅ PASS - All foreign keys have indexes

📋 Check 12: Authentication Methods
⚠️  WARNING - Found 2 weak authentication rule(s)
   💡 Consider using scram-sha-256 instead of password/trust

⚠️  Database secure, but 1 warning(s) detected

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Global Security Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total databases audited: 2
Secure databases: 2
Vulnerable databases: 0

🎉 ALL DATABASES ARE SECURE!
```

---

## 🛡️ Détail des Vérifications

### Check 1-4 : Protection SECURITY DEFINER (CRITIQUE)

**Pourquoi c'est important** : Les fonctions `SECURITY DEFINER` s'exécutent avec les privilèges du propriétaire. Sans protection `search_path`, un attaquant peut créer des fonctions malveillantes dans des schémas temporaires.

**Ce qui est vérifié** :
- Toutes les fonctions SECURITY DEFINER ont `SET search_path`
- Le search_path inclut `pg_temp` (critique!)
- Pas de search_path vide

**Exemple vulnérable** :
```sql
CREATE FUNCTION vulnerable_func()
RETURNS void
SECURITY DEFINER -- ❌ Pas de search_path!
AS $$
  SELECT * FROM users; -- Attaquant peut hijack "users" table
$$ LANGUAGE sql;
```

**Exemple sécurisé** :
```sql
CREATE FUNCTION secure_func()
RETURNS void
SECURITY DEFINER
SET search_path = public, pg_temp -- ✅ Protégé
AS $$
  SELECT * FROM users; -- Toujours la vraie table "users"
$$ LANGUAGE sql;
```

### Check 5 : RLS (Row Level Security)

**Ce qui est vérifié** : Toutes les tables publiques ont RLS activé.

**Pourquoi** : Sans RLS, n'importe qui peut lire/écrire toutes les lignes.

**Fix** :
```sql
ALTER TABLE ma_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Utilisateurs voient leurs données"
  ON ma_table FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());
```

### Check 6 : Passwords NULL

**Ce qui est vérifié** : Aucun utilisateur avec login autorisé n'a un password NULL.

**Fix** :
```sql
ALTER USER vulnerable_user PASSWORD 'strong_password_here';
```

### Check 9 : Injection SQL

**Ce qui est vérifié** : Fonctions utilisant EXECUTE ou format() sans quote_literal/quote_ident.

**Exemple vulnérable** :
```sql
CREATE FUNCTION bad(table_name text)
RETURNS void AS $$
BEGIN
  EXECUTE 'SELECT * FROM ' || table_name; -- ❌ Injection!
END;
$$ LANGUAGE plpgsql;
```

**Exemple sécurisé** :
```sql
CREATE FUNCTION good(table_name text)
RETURNS void AS $$
BEGIN
  EXECUTE 'SELECT * FROM ' || quote_ident(table_name); -- ✅ Safe
END;
$$ LANGUAGE plpgsql;
```

---

## 🔧 Corrections Automatiques

Pour corriger automatiquement les problèmes détectés, voir :

- **CertiDoc** : `/certidoc-proof/supabase/migrations/20251018120000_fix_all_security_issues_complete.sql`
- **Script générique** : À créer selon les problèmes détectés

---

## 📚 Références

- [PostgreSQL SECURITY DEFINER](https://www.postgresql.org/docs/current/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY)
- [search_path Attack Prevention](https://www.postgresql.org/docs/current/ddl-schemas.html#DDL-SCHEMAS-PATH)
- [Supabase RLS Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [OWASP SQL Injection](https://owasp.org/www-community/attacks/SQL_Injection)

---

## 📞 Support

**Problème détecté ?**

1. Lancer l'audit : `sudo bash audit-all-databases.sh`
2. Lire le rapport complet
3. Appliquer les corrections via migrations SQL
4. Re-tester jusqu'à 0 vulnérabilités

**Faux positifs Supabase Studio ?**

Voir `/certidoc-proof/docs/SECURITY-AUDIT.md` - Ignore les alertes Studio, utilise ce script.

---

**Mainteneur** : [@iamaketechnology](https://github.com/iamaketechnology)
**Projet** : [pi5-setup](https://github.com/iamaketechnology/pi5-setup)
