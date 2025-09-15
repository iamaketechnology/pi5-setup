# 🚀 Guide d'utilisation Supabase sur Raspberry Pi 5

## 📋 Récupération des informations de connexion

### 🔑 Clés d'accès essentielles

```bash
cd /home/pi/stacks/supabase
cat .env | grep -E "POSTGRES_PASSWORD|JWT_SECRET|ANON_KEY|SERVICE_ROLE_KEY"
```

**📝 Notez ces informations importantes :**
- `POSTGRES_PASSWORD` - Mot de passe PostgreSQL direct
- `JWT_SECRET` - Secret principal pour signer les tokens
- `ANON_KEY` - Clé publique pour vos applications client
- `SERVICE_ROLE_KEY` - Clé administrateur (à garder secrète !)

### 🌐 URL d'accès

```bash
# Récupérer votre IP locale
hostname -I
```

## 🎯 Interfaces d'accès

### 📊 Supabase Studio (Interface Web)

**URL :** `http://VOTRE_IP:3000`

**Fonctionnalités :**
- 🗄️ Gestion des tables et données
- 👥 Configuration authentification
- 📁 Gestion des fichiers (Storage)
- 📝 Éditeur SQL intégré
- 📈 Monitoring et logs temps réel
- 🔐 Gestion des politiques RLS (Row Level Security)

### 🗄️ Accès direct PostgreSQL

```bash
# Via Docker (recommandé)
docker exec -it supabase-db psql -U postgres -d postgres

# Ou depuis le Pi (si psql installé)
psql -h localhost -p 5432 -U postgres -d postgres
```

**Mot de passe :** Utilisez votre `POSTGRES_PASSWORD`

## 📡 API REST et Services

### 🔗 URLs des services

| Service | URL | Description |
|---------|-----|-------------|
| **API REST** | `http://VOTRE_IP:8001/rest/v1/` | API automatique pour vos tables |
| **Auth** | `http://VOTRE_IP:8001/auth/v1/` | Authentification et gestion utilisateurs |
| **Storage** | `http://VOTRE_IP:8001/storage/v1/` | Upload et gestion de fichiers |
| **Realtime** | `http://VOTRE_IP:8001/realtime/v1/` | WebSockets temps réel |

### 🔑 Authentification API

```javascript
// Headers requis pour vos requêtes
const headers = {
  'apikey': 'VOTRE_ANON_KEY',
  'Authorization': `Bearer VOTRE_ANON_KEY`,
  'Content-Type': 'application/json'
}
```

### 📝 Exemples d'utilisation

#### Lire des données
```bash
curl -X GET "http://VOTRE_IP:8001/rest/v1/ma_table" \
  -H "apikey: VOTRE_ANON_KEY" \
  -H "Authorization: Bearer VOTRE_ANON_KEY"
```

#### Créer un enregistrement
```bash
curl -X POST "http://VOTRE_IP:8001/rest/v1/ma_table" \
  -H "apikey: VOTRE_ANON_KEY" \
  -H "Authorization: Bearer VOTRE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"nom": "test", "valeur": 123}'
```

## 🔧 Gestion Docker

### 📊 Surveillance des services

```bash
cd /home/pi/stacks/supabase

# État de tous les services
docker compose ps

# Logs d'un service spécifique
docker compose logs auth --tail=50
docker compose logs realtime --tail=50
docker compose logs storage --tail=50

# Logs de tous les services
docker compose logs --tail=20
```

### 🔄 Gestion des services

```bash
# Redémarrer un service
docker compose restart auth

# Redémarrer tous les services
docker compose restart

# Arrêter tous les services
docker compose down

# Démarrer tous les services
docker compose up -d

# Mettre à jour les images
docker compose pull
docker compose up -d
```

### 📈 Monitoring des ressources

```bash
# Utilisation des ressources par conteneur
docker stats

# Espace disque utilisé
docker system df

# Nettoyer les images non utilisées
docker system prune -f
```

## 🚀 Premiers pas avec Supabase

### 1. 🗄️ Créer votre première table

1. Accédez à **Supabase Studio** : `http://VOTRE_IP:3000`
2. Allez dans **Table Editor**
3. Cliquez **New Table**
4. Exemple de table :
   ```sql
   CREATE TABLE posts (
     id SERIAL PRIMARY KEY,
     title TEXT NOT NULL,
     content TEXT,
     author_id UUID REFERENCES auth.users(id),
     created_at TIMESTAMP DEFAULT NOW()
   );
   ```

### 2. 👥 Configurer l'authentification

1. Dans Studio → **Authentication** → **Settings**
2. Configurez les providers (Email, OAuth, etc.)
3. Définissez les politiques RLS :
   ```sql
   -- Activer RLS
   ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

   -- Politique : les utilisateurs voient leurs propres posts
   CREATE POLICY "Users can view own posts" ON posts
     FOR SELECT USING (auth.uid() = author_id);
   ```

### 3. 📁 Configuration du Storage

1. Studio → **Storage**
2. Créer un bucket :
   ```sql
   INSERT INTO storage.buckets (id, name, public)
   VALUES ('images', 'images', true);
   ```

### 4. ⚡ Realtime (temps réel)

```javascript
// Connexion WebSocket
const socket = new WebSocket('ws://VOTRE_IP:8001/realtime/v1/websocket');

// Écouter les changements sur une table
socket.send(JSON.stringify({
  topic: 'realtime:public:posts',
  event: 'phx_join',
  payload: {},
  ref: 1
}));
```

## 🔒 Sécurité et bonnes pratiques

### 🛡️ Gestion des clés

- **ANON_KEY** : Côté client, lecture seule avec RLS
- **SERVICE_ROLE_KEY** : Côté serveur uniquement, accès complet
- **JWT_SECRET** : Ne jamais exposer, uniquement serveur

### 🔐 Row Level Security (RLS)

```sql
-- Toujours activer RLS sur vos tables
ALTER TABLE ma_table ENABLE ROW LEVEL SECURITY;

-- Exemples de politiques
CREATE POLICY "Lecture publique" ON ma_table
  FOR SELECT USING (public = true);

CREATE POLICY "Modification propriétaire" ON ma_table
  FOR UPDATE USING (auth.uid() = user_id);
```

### 🔄 Sauvegardes

```bash
# Sauvegarde PostgreSQL
docker exec supabase-db pg_dump -U postgres -d postgres > backup_$(date +%Y%m%d).sql

# Sauvegarde des volumes Docker
sudo tar -czf supabase_volumes_$(date +%Y%m%d).tar.gz /home/pi/stacks/supabase/volumes/
```

## 🐛 Dépannage courant

### ❌ Service qui redémarre

```bash
# Voir les logs d'erreur
docker compose logs [service] --tail=50

# Redémarrer proprement
docker compose restart [service]
```

### 🔍 Vérifier la connectivité

```bash
# Test de connectivité API
curl -I http://VOTRE_IP:8001/rest/v1/

# Test PostgreSQL
docker exec supabase-db pg_isready -U postgres
```

### 💾 Problèmes d'espace disque

```bash
# Nettoyer Docker
docker system prune -a -f

# Vérifier l'espace
df -h
```

## 📚 Ressources utiles

### 📖 Documentation officielle

- [Supabase Docs](https://supabase.com/docs)
- [API Reference](https://supabase.com/docs/reference/api)
- [SQL Reference](https://supabase.com/docs/reference/sql)

### 🛠️ Outils de développement

- [Supabase CLI](https://supabase.com/docs/reference/cli)
- [Client Libraries](https://supabase.com/docs/reference/javascript)
- [Dashboard](https://supabase.com/dashboard)

### 🔧 Configuration avancée

```bash
# Variables d'environnement personnalisées
cd /home/pi/stacks/supabase
nano .env

# Redémarrer après modification
docker compose down && docker compose up -d
```

## 🎯 Prochaines étapes

1. **Créer vos tables** dans Supabase Studio
2. **Configurer l'authentification** selon vos besoins
3. **Développer votre première app** avec les clients Supabase
4. **Mettre en place les sauvegardes** automatiques
5. **Configurer un nom de domaine** (Week 3 du guide)

---

**🎉 Votre Supabase est maintenant opérationnel sur Raspberry Pi 5 !**

Pour toute question ou problème, référez-vous aux logs Docker et à la documentation officielle Supabase.