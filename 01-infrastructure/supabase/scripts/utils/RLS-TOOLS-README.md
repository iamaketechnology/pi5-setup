# 🔐 Supabase RLS Tools - Guide Complet

> **Outils pour gérer Row Level Security (RLS) sur votre instance Supabase self-hosted**

---

## ⚠️ IMPORTANT - PostgREST Configuration (v3.45+)

### RLS Policies RequirePostgREST Schema Configuration

**Si vous utilisez Supabase v3.44 ou antérieur**, vos RLS policies ne fonctionneront PAS même si elles sont correctement configurées !

**Problème** : PostgREST doit avoir accès au schéma `auth` pour que `auth.uid()` fonctionne.

**Solution** : Assurez-vous que votre installation utilise v3.45+ du script de déploiement, OU exécutez :

```bash
# Pour installations existantes (v3.44 et antérieures)
./fix-postgrest-schemas.sh

# Ce script met à jour PGRST_DB_SCHEMAS de 'public' à 'public,auth,storage'
```

**Vérification** :
```bash
grep "PGRST_DB_SCHEMAS" ~/stacks/supabase/docker-compose.yml
# Doit afficher: PGRST_DB_SCHEMAS: public,auth,storage
```

✅ **Installations v3.45+** : Déjà configuré correctement, rien à faire !

**📖 Détails complets** : [CHANGELOG-POSTGREST-SCHEMAS-v3.45.md](../CHANGELOG-POSTGREST-SCHEMAS-v3.45.md)

---

## 📋 Vue d'Ensemble

Ces scripts vous aident à configurer et gérer les **Row Level Security policies** pour sécuriser votre base de données Supabase.

### 🎯 Pourquoi RLS ?

**Row Level Security (RLS)** est le mécanisme de sécurité de PostgreSQL qui contrôle quelles lignes un utilisateur peut voir/modifier dans une table.

**Sans RLS** :
```sql
SELECT * FROM users;
-- ❌ Retourne TOUTES les lignes (problème de sécurité!)
```

**Avec RLS** :
```sql
SELECT * FROM users;
-- ✅ Retourne uniquement les lignes que l'utilisateur a le droit de voir
```

---

## 🛠️ Les 3 Outils

| Script | Usage | Description |
|--------|-------|-------------|
| **diagnose-rls.sh** | Diagnostic | Analyser l'état actuel des RLS policies |
| **generate-rls-template.sh** | Génération | Créer des templates SQL de policies |
| **setup-rls-policies.sh** | Application | Appliquer les policies sur la base |

---

## 🔍 1. Diagnostic RLS (`diagnose-rls.sh`)

### Usage

```bash
# Analyser toutes les tables
./diagnose-rls.sh

# Analyser une table spécifique
./diagnose-rls.sh users

# Analyser une table avec détails
./diagnose-rls.sh posts --verbose
```

### Ce que ça vérifie

✅ **RLS activé/désactivé** sur chaque table
✅ **Policies existantes** (SELECT, INSERT, UPDATE, DELETE)
✅ **Structure de la table** (colonnes user_id, email, team_id)
✅ **Permissions PostgreSQL**
✅ **Problèmes courants** (RLS activé sans policies, etc.)
✅ **Suggestions** de policies adaptées

### Exemple de sortie

```
╔════════════════════════════════════════════════════════════╗
║  RLS DIAGNOSTIC: public.users
╚════════════════════════════════════════════════════════════╝

✓ Table exists
✓ RLS is ENABLED on public.users
✓ Found 4 policies

=== Policies ===
Policy Name                    | Operation | Roles
-----------------------------------------------------------
Users can view their own users | SELECT    | authenticated
Users can insert their own ... | INSERT    | authenticated
Users can update their own ... | UPDATE    | authenticated
Users can delete their own ... | DELETE    | authenticated

=== Table Columns ===
Column      | Type | Nullable
--------------------------------
id          | uuid | NO
email       | text | NO
user_id     | uuid | YES
created_at  | timestamp | NO

=== RLS-relevant Columns ===
✓ Has 'user_id' column (good for user-based policies)
✓ Has 'email' column (good for email-based policies)

=== Common Issues Check ===
✓ No common issues detected

=== Suggested Policies ===
💡 Recommended: Basic user-based policies
   ./generate-rls-template.sh users --basic
```

---

## 📝 2. Générateur de Templates (`generate-rls-template.sh`)

### Usage

```bash
# Template basique (user_id = auth.uid())
./generate-rls-template.sh users --basic

# Lecture publique, écriture par propriétaire
./generate-rls-template.sh posts --public-read

# Isolation stricte (chaque user voit uniquement ses données)
./generate-rls-template.sh profiles --owner-only

# Policies basées sur email
./generate-rls-template.sh invitations --email

# Policies basées sur rôles (admin/manager/user)
./generate-rls-template.sh documents --role

# Policies basées sur équipes/organisations
./generate-rls-template.sh projects --team

# Template personnalisé avec exemples
./generate-rls-template.sh custom_table --custom
```

### Types de Policies Disponibles

#### 1️⃣ **Basic** (Par défaut)

**Cas d'usage** : Tables avec colonne `user_id`

**Comportement** :
- Users peuvent voir/modifier uniquement leurs propres lignes
- Basé sur `user_id = auth.uid()`

**Exemple généré** :
```sql
CREATE POLICY "Users can view their own users"
ON public.users FOR SELECT TO authenticated
USING (user_id = auth.uid());
```

**Parfait pour** : users, profiles, settings

---

#### 2️⃣ **Public Read**

**Cas d'usage** : Contenu public en lecture, privé en écriture

**Comportement** :
- N'importe qui peut lire (même anonyme)
- Seuls les propriétaires peuvent modifier

**Exemple généré** :
```sql
-- Tout le monde peut lire
CREATE POLICY "Anyone can view posts"
ON public.posts FOR SELECT TO public
USING (true);

-- Seuls les propriétaires peuvent modifier
CREATE POLICY "Users can update their own posts"
ON public.posts FOR UPDATE TO authenticated
USING (user_id = auth.uid());
```

**Parfait pour** : posts, articles, comments (lecture publique)

---

#### 3️⃣ **Owner Only** (Isolation stricte)

**Cas d'usage** : Données très sensibles, isolation totale

**Comportement** :
- Utilisateurs complètement isolés
- Aucune visibilité sur les données des autres

**Exemple généré** :
```sql
CREATE POLICY "Users can only access their own data"
ON public.private_data FOR ALL TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
```

**Parfait pour** : financial_records, medical_data, private_notes

---

#### 4️⃣ **Email-based**

**Cas d'usage** : Tables avec colonne `email` au lieu de `user_id`

**Comportement** :
- Basé sur `email = auth.jwt()->>'email'`
- Utile pour invitations, notifications

**Exemple généré** :
```sql
CREATE POLICY "Users can view their own invitations"
ON public.email_invites FOR SELECT TO authenticated
USING (email = (auth.jwt() ->> 'email'));
```

**Parfait pour** : email_invitations, notifications, subscriptions

---

#### 5️⃣ **Role-based**

**Cas d'usage** : Différents niveaux d'accès (admin, manager, user)

**Comportement** :
- Admins : accès total
- Managers : peuvent voir/modifier tout
- Users : lecture seule

**Exemple généré** :
```sql
CREATE POLICY "Admins can do anything"
ON public.documents FOR ALL TO authenticated
USING ((auth.jwt() ->> 'role') = 'admin');

CREATE POLICY "Managers can manage"
ON public.documents FOR ALL TO authenticated
USING (
    (auth.jwt() ->> 'role') IN ('admin', 'manager')
    OR user_id = auth.uid()
);
```

**Parfait pour** : admin_panel, reports, analytics

**⚠️ Note** : Nécessite d'ajouter `role` aux JWT claims

---

#### 6️⃣ **Team-based**

**Cas d'usage** : Applications multi-tenant (SaaS, organisations)

**Comportement** :
- Utilisateurs d'une même équipe voient les mêmes données
- Isolation entre équipes

**Exemple généré** :
```sql
CREATE POLICY "Users can view team data"
ON public.projects FOR SELECT TO authenticated
USING (
    team_id = (auth.jwt() ->> 'team_id')::uuid
    OR user_id = auth.uid()
);
```

**Parfait pour** : projects, team_documents, shared_resources

**⚠️ Note** : Nécessite colonne `team_id` et JWT claim

---

#### 7️⃣ **Custom**

**Cas d'usage** : Besoins spécifiques complexes

**Contient** :
- Exemples de policies temporelles (30 derniers jours)
- Policies conditionnelles (status = 'published')
- Policies avec sous-requêtes
- Exemples de bypass pour service_role

**Parfait pour** : cas d'usage uniques

---

## ⚙️ 3. Application des Policies (`setup-rls-policies.sh`)

### Usage

```bash
# Appliquer policies à toutes les tables (mode interactif)
./setup-rls-policies.sh

# Appliquer à une table spécifique
./setup-rls-policies.sh --table users

# Prévisualiser sans exécuter
./setup-rls-policies.sh --dry-run

# Appliquer un fichier SQL personnalisé
./setup-rls-policies.sh --custom rls-policies-users-basic.sql

# Lister les policies actuelles
./setup-rls-policies.sh --list

# Désactiver RLS (⚠️ use with caution!)
./setup-rls-policies.sh --table users --disable
```

### Workflow Automatique

Le script :

1. ✅ **Découvre** toutes les tables dans le schéma `public`
2. ✅ **Détecte** les colonnes pertinentes (user_id, email, team_id)
3. ✅ **Active** RLS sur chaque table
4. ✅ **Crée** les policies appropriées automatiquement :
   - Si `user_id` existe → policies basées sur `auth.uid()`
   - Si `email` existe → policies basées sur `auth.jwt()->>'email'`
5. ✅ **Vérifie** et affiche le statut final

### Exemple Complet

```bash
# 1. Diagnostic initial
./diagnose-rls.sh

# 2. Générer un template personnalisé
./generate-rls-template.sh users --basic

# 3. Éditer le template si nécessaire
nano rls-policies-users-basic.sql

# 4. Appliquer le template
./setup-rls-policies.sh --custom rls-policies-users-basic.sql

# 5. Vérifier
./diagnose-rls.sh users
```

---

## 🚀 Workflows Typiques

### Workflow 1 : Nouvelle Application (Quick Start)

**Situation** : Vous avez des tables, aucune RLS configurée

```bash
# 1. Voir l'état actuel
./diagnose-rls.sh

# 2. Appliquer policies par défaut à toutes les tables
./setup-rls-policies.sh

# 3. Vérifier
./diagnose-rls.sh --all
```

**Résultat** : RLS activé avec policies basiques sur toutes les tables

---

### Workflow 2 : Table Spécifique

**Situation** : Vous voulez configurer une table précise

```bash
# 1. Analyser la table
./diagnose-rls.sh email_invites

# 2. Générer template adapté (email-based)
./generate-rls-template.sh email_invites --email

# 3. Éditer si nécessaire
nano rls-policies-email_invites-email.sql

# 4. Appliquer
./setup-rls-policies.sh --custom rls-policies-email_invites-email.sql

# 5. Tester depuis votre app
# supabase.from('email_invites').select('*')
```

---

### Workflow 3 : Policies Avancées (Multi-tenant)

**Situation** : Application SaaS avec organisations

```bash
# 1. Générer template team-based
./generate-rls-template.sh projects --team

# 2. Éditer pour adapter à votre schéma
nano rls-policies-projects-team.sql

# Modifier pour utiliser votre colonne 'organization_id'
# sed -i 's/team_id/organization_id/g' rls-policies-projects-team.sql

# 3. Appliquer
./setup-rls-policies.sh --custom rls-policies-projects-team.sql

# 4. Configurer JWT claims (voir ci-dessous)
```

**Configurer JWT claims** :

```sql
-- Trigger pour ajouter organization_id au JWT
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb AS $$
DECLARE
  claims jsonb;
  user_org_id uuid;
BEGIN
  -- Get user's organization_id
  SELECT organization_id INTO user_org_id
  FROM public.users
  WHERE id = (event->>'user_id')::uuid;

  -- Add to claims
  claims := event->'claims';
  claims := jsonb_set(claims, '{organization_id}', to_jsonb(user_org_id));

  event := jsonb_set(event, '{claims}', claims);
  RETURN event;
END;
$$ LANGUAGE plpgsql;
```

---

### Workflow 4 : Débug Erreur 403 (Permission Denied)

**Situation** : Votre app reçoit 403 Forbidden

```bash
# 1. Identifier la table concernée
# Regarder les logs : "permission denied for table XXX"

# 2. Diagnostic complet
./diagnose-rls.sh posts

# Vérifier :
# - ❌ RLS is DISABLED → Activer RLS
# - ❌ No policies found → Créer policies
# - ✅ Policies exist → Vérifier la logique

# 3. Si RLS activé mais pas de policies
./generate-rls-template.sh posts --public-read
./setup-rls-policies.sh --custom rls-policies-posts-public-read.sql

# 4. Si policies existent mais ne fonctionnent pas
# Vérifier dans le template généré :
# - Colonne user_id existe ?
# - auth.uid() retourne bien l'ID user ?
# - JWT claims corrects ?

# 5. Test en SQL direct
# ssh pi@192.168.1.74
# docker exec -it supabase-db psql -U postgres -d postgres
# SET ROLE authenticated;
# SET request.jwt.claims TO '{"sub": "YOUR_USER_ID"}';
# SELECT * FROM posts;
```

---

## 📚 Exemples de Cas d'Usage

### Cas 1 : Blog Public

**Tables** :
- `posts` : Articles (lecture publique, écriture par auteur)
- `comments` : Commentaires (lecture publique, écriture par user authentifié)
- `authors` : Profils auteurs (lecture publique)

**Policies** :

```bash
# Posts - lecture publique, écriture par auteur
./generate-rls-template.sh posts --public-read
./setup-rls-policies.sh --custom rls-policies-posts-public-read.sql

# Comments - idem
./generate-rls-template.sh comments --public-read
./setup-rls-policies.sh --custom rls-policies-comments-public-read.sql

# Authors - lecture publique, écriture par propriétaire
./generate-rls-template.sh authors --public-read
./setup-rls-policies.sh --custom rls-policies-authors-public-read.sql
```

---

### Cas 2 : Application SaaS (Multi-tenant)

**Tables** :
- `organizations` : Les organisations (chaque user voit la sienne)
- `team_members` : Membres d'équipe
- `projects` : Projets (partagés dans l'organisation)
- `tasks` : Tâches

**Policies** :

```bash
# Organizations - user voit sa propre org
./generate-rls-template.sh organizations --owner-only

# Projects - team-based
./generate-rls-template.sh projects --team
# Éditer pour utiliser organization_id
sed -i 's/team_id/organization_id/g' rls-policies-projects-team.sql
./setup-rls-policies.sh --custom rls-policies-projects-team.sql

# Tasks - team-based
./generate-rls-template.sh tasks --team
sed -i 's/team_id/organization_id/g' rls-policies-tasks-team.sql
./setup-rls-policies.sh --custom rls-policies-tasks-team.sql
```

---

### Cas 3 : Application E-commerce

**Tables** :
- `products` : Produits (lecture publique)
- `orders` : Commandes (privées)
- `cart_items` : Panier (privé)
- `reviews` : Avis (lecture publique, écriture après achat)

**Policies** :

```bash
# Products - lecture publique, admin peut modifier
./generate-rls-template.sh products --custom
# Éditer pour permettre :
# - SELECT : public (true)
# - INSERT/UPDATE/DELETE : admin only

# Orders - strict owner only
./generate-rls-template.sh orders --owner-only

# Cart items - owner only
./generate-rls-template.sh cart_items --owner-only

# Reviews - custom (peut reviewer si a acheté)
./generate-rls-template.sh reviews --custom
# Éditer pour ajouter :
# USING (
#   user_id = auth.uid()
#   OR product_id IN (
#     SELECT product_id FROM orders
#     WHERE user_id = auth.uid() AND status = 'completed'
#   )
# )
```

---

## ⚠️ Points d'Attention

### 1. **Service Role Bypass**

Le rôle `service_role` **bypass RLS** par défaut.

```javascript
// ❌ BAD: Service role depuis le frontend
const supabase = createClient(url, SERVICE_KEY) // Expose la clé admin!

// ✅ GOOD: Anon key depuis le frontend
const supabase = createClient(url, ANON_KEY) // Respecte RLS
```

---

### 2. **JWT Claims personnalisés**

Pour policies basées sur `team_id`, `role`, etc., vous devez ajouter ces champs au JWT.

**Méthode 1 : Database Trigger** (recommandé)

```sql
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb AS $$
DECLARE
  claims jsonb;
  user_role text;
  user_team_id uuid;
BEGIN
  SELECT role, team_id INTO user_role, user_team_id
  FROM public.users
  WHERE id = (event->>'user_id')::uuid;

  claims := event->'claims';
  claims := jsonb_set(claims, '{role}', to_jsonb(user_role));
  claims := jsonb_set(claims, '{team_id}', to_jsonb(user_team_id));

  event := jsonb_set(event, '{claims}', claims);
  RETURN event;
END;
$$ LANGUAGE plpgsql;
```

**Méthode 2 : Auth metadata** (via Supabase Studio)

Dans Studio → Authentication → Users → Edit User → User Metadata :
```json
{
  "role": "manager",
  "team_id": "uuid-here"
}
```

---

### 3. **Performance**

Les policies avec sous-requêtes peuvent être lentes.

**❌ Slow** :
```sql
USING (
  team_id IN (
    SELECT team_id FROM team_members WHERE user_id = auth.uid()
  )
)
```

**✅ Faster** :
```sql
-- Ajouter team_id directement au JWT
USING (team_id = (auth.jwt() ->> 'team_id')::uuid)
```

---

### 4. **Debugging**

Pour tester une policy en SQL :

```sql
-- Se connecter à la DB
docker exec -it supabase-db psql -U postgres -d postgres

-- Simuler un user authentifié
SET ROLE authenticated;
SET request.jwt.claims TO '{
  "sub": "user-uuid-here",
  "email": "user@example.com",
  "role": "user"
}';

-- Tester la requête
SELECT * FROM your_table;

-- Reset
RESET ROLE;
RESET request.jwt.claims;
```

---

## 📖 Ressources Complémentaires

### Documentation Officielle

- [Supabase RLS Docs](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [JWT Claims](https://supabase.com/docs/guides/auth/managing-user-data#using-triggers)

### Vidéos Recommandées

- [Supabase RLS Explained (YouTube)](https://www.youtube.com/results?search_query=supabase+rls+tutorial)
- [Multi-tenant RLS](https://www.youtube.com/results?search_query=supabase+multi+tenant)

---

## 🆘 Dépannage

### Erreur : "permission denied for table XXX"

**Cause** : RLS activé sans policies ou policies trop restrictives

**Solution** :
```bash
./diagnose-rls.sh XXX
./generate-rls-template.sh XXX --basic
./setup-rls-policies.sh --custom rls-policies-XXX-basic.sql
```

---

### Erreur : "function auth.uid() does not exist"

**Cause** : Installation Supabase incomplète

**Solution** :
```bash
# Vérifier que le schéma auth existe
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db \
  psql -U postgres -d postgres -c "\dn"

# Doit afficher : auth | ...
```

---

### Policies ne fonctionnent pas (toujours 403)

**Checklist** :

1. ✅ RLS activé ? `./diagnose-rls.sh table_name`
2. ✅ Policies créées ? `./setup-rls-policies.sh --list`
3. ✅ Colonne `user_id` existe ? Vérifier structure table
4. ✅ `auth.uid()` retourne bien l'UUID user ? Tester en SQL
5. ✅ JWT claims corrects ? Vérifier token dans app

---

## 📝 Checklist Migration Production

Avant de déployer en production :

- [ ] Toutes les tables ont RLS activé (`./diagnose-rls.sh --all`)
- [ ] Policies testées avec différents users
- [ ] Service key sécurisé (jamais exposé au frontend)
- [ ] JWT claims configurés si nécessaire
- [ ] Backup de la base avant application (`pg_dump`)
- [ ] Rollback plan préparé
- [ ] Logs activés pour tracer les 403
- [ ] Tests d'intégration avec RLS passants

---

**Version** : 1.0
**Date** : 2025-10-10
**Auteur** : Claude Code Assistant

**🔐 Sécurisez votre Supabase avec confiance !**
