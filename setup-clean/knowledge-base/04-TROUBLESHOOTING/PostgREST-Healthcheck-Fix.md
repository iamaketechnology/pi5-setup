# 🔧 Fix PostgREST Healthcheck - Raspberry Pi 5

> **Problème** : PostgREST reste "unhealthy" car le healthcheck utilise `nc` qui n'existe pas dans l'image
> **Symptôme** : `exec: "nc": executable file not found in $PATH`
> **Impact** : Services dépendants (Kong, Storage) ne démarrent pas

---

## 🚨 Diagnostic Rapide

```bash
# Vérifier le statut
cd ~/stacks/supabase
docker compose ps

# Voir les logs PostgREST
docker logs supabase-rest --tail 20

# Si vous voyez "Successfully connected to PostgreSQL" mais status "unhealthy"
# → C'est ce bug du healthcheck
```

---

## ✅ Solution Immédiate (Fix Manuel)

### Étape 1 : Arrêter les Services

```bash
cd ~/stacks/supabase
docker compose down
```

### Étape 2 : Éditer docker-compose.yml

```bash
nano docker-compose.yml
```

### Étape 3 : Trouver la Section `rest:` et Modifier le Healthcheck

**AVANT (ligne ~660-665)** :
```yaml
rest:
  # ...
  healthcheck:
    test: ["CMD-SHELL", "timeout 5 nc -z localhost 3000 || exit 1"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 90s
```

**APRÈS** :
```yaml
rest:
  # ...
  healthcheck:
    test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 90s
```

### Étape 4 : Faire la Même Correction pour Autres Services

**Services à corriger** (chercher `nc -z` et remplacer) :

1. **auth** (ligne ~632)
2. **rest** (ligne ~661) ← **CELUI-CI EST BLOQUANT**
3. **realtime** (ligne ~700)
4. **storage** (ligne ~737)
5. **meta** (ligne ~767)
6. **studio** (ligne ~836)
7. **imgproxy** (ligne ~862)
8. **edge-functions** (ligne ~890)

**Commande de Remplacement Rapide (Bash)** :

```bash
cd ~/stacks/supabase

# Backup
cp docker-compose.yml docker-compose.yml.backup

# Remplacer tous les healthchecks nc par wget
sed -i 's|timeout 5 nc -z localhost \([0-9]*\) || exit 1|wget --no-verbose --tries=1 --spider http://localhost:\1/ || exit 1|g' docker-compose.yml

# Vérifier les changements
grep "wget.*spider" docker-compose.yml
```

### Étape 5 : Redémarrer les Services

```bash
cd ~/stacks/supabase
docker compose up -d

# Attendre ~2 minutes et vérifier
docker compose ps
```

---

## 🎯 Solution Automatique (Nouveau Script)

Télécharger le script corrigé depuis la Knowledge Base :

```bash
# Sur votre Raspberry Pi 5
cd ~

# Télécharger le script corrigé (une fois mis à jour dans le repo)
curl -fsSL https://raw.githubusercontent.com/VOTRE-REPO/pi5-setup/main/scripts/setup-week2-supabase-FIXED-HEALTHCHECK.sh -o setup-week2-fixed.sh

chmod +x setup-week2-fixed.sh

# Nettoyer installation précédente
cd ~/stacks/supabase 2>/dev/null && docker compose down -v

# Relancer avec le script corrigé
sudo ~/setup-week2-fixed.sh
```

---

## 📋 Vérification Post-Fix

```bash
cd ~/stacks/supabase

# Tous les services doivent être "healthy" ou "running"
docker compose ps

# Vérifier healthcheck REST spécifiquement
docker inspect supabase-rest --format='{{.State.Health.Status}}'
# Doit afficher: healthy

# Vérifier tous les healthchecks
for service in auth rest realtime storage meta kong studio; do
  echo -n "$service: "
  docker inspect "supabase-$service" --format='{{.State.Health.Status}}' 2>/dev/null || echo "no healthcheck"
done
```

### Résultat Attendu

```
NAMES                    STATUS                 PORTS
supabase-db              Up 3 minutes (healthy)
supabase-auth            Up 3 minutes (healthy)
supabase-rest            Up 3 minutes (healthy)  ← DOIT ÊTRE HEALTHY
supabase-meta            Up 3 minutes (healthy)
supabase-realtime        Up 3 minutes (healthy)
supabase-storage         Up 3 minutes (healthy)
supabase-kong            Up 3 minutes (healthy)
supabase-studio          Up 3 minutes (healthy)
supabase-edge-functions  Up 3 minutes (healthy)
supabase-imgproxy        Up 3 minutes (healthy)
```

---

## 🐛 Pourquoi `nc` Ne Fonctionne Pas ?

### Image PostgREST

L'image `postgrest/postgrest:v12.2.0` est basée sur une **image minimale** qui ne contient **ni** `nc` (netcat) **ni** `bash`.

```bash
# Vérifier les outils disponibles dans l'image
docker run --rm postgrest/postgrest:v12.2.0 ls /bin

# Output (approximatif) :
# sh, wget, ...
# PAS DE: nc, netcat, bash
```

### Solutions Possibles

| Commande | Disponible ? | Recommandation |
|----------|--------------|----------------|
| `nc -z localhost 3000` | ❌ Non | Ne fonctionne pas |
| `wget --spider http://localhost:3000/` | ✅ Oui | **RECOMMANDÉ** |
| `curl -f http://localhost:3000/` | ⚠️ Selon image | Pas toujours dispo |
| `/bin/sh -c "wget ..."` | ✅ Oui | OK (sh existe) |

**Solution Choisie** : `wget --spider` car :
- ✅ Disponible dans PostgREST image
- ✅ Léger (ne télécharge pas le contenu)
- ✅ Exit code 0 si succès, 1 si échec
- ✅ Compatible healthcheck Docker

---

## 🔍 Comprendre le Healthcheck Docker

### Syntaxe Correcte

```yaml
healthcheck:
  test: ["CMD-SHELL", "commande || exit 1"]
  interval: 30s      # Tester toutes les 30s
  timeout: 10s       # Max 10s pour répondre
  retries: 3         # 3 échecs → unhealthy
  start_period: 90s  # Grace period au démarrage
```

### Commande de Test Idéale pour PostgREST

```bash
# Option 1 : wget (RECOMMANDÉ)
wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

# Option 2 : wget version courte
wget -q -O- http://localhost:3000/ >/dev/null || exit 1

# Option 3 : Si curl disponible
curl -f http://localhost:3000/ >/dev/null || exit 1
```

### Test Manuel

```bash
# Depuis votre Pi 5, tester le healthcheck manuellement
docker exec supabase-rest wget --spider http://localhost:3000/

# Si succès :
# Connecting to localhost:3000 (127.0.0.1:3000)
# remote file exists

# Si échec :
# wget: can't connect to remote host (127.0.0.1): Connection refused
```

---

## 🚀 Après le Fix : Services Suivants

Une fois PostgREST **healthy**, les services dépendants vont démarrer :

1. ✅ **Storage** (dépend de `rest`)
2. ✅ **Kong** (dépend de `auth`, `rest`, `realtime`, `storage`, `meta`)
3. ✅ **Studio** (dépend de `kong`)

---

## 📝 Commandes Copy-Paste Complètes

### Fix Rapide (3 minutes)

```bash
#!/bin/bash
# Fix PostgREST Healthcheck - Copier-Coller Complet

cd ~/stacks/supabase || exit 1

# Arrêter services
echo "🛑 Arrêt des services..."
docker compose down

# Backup
echo "💾 Backup docker-compose.yml..."
cp docker-compose.yml docker-compose.yml.backup-$(date +%Y%m%d_%H%M%S)

# Fix healthchecks (remplacer nc par wget)
echo "🔧 Correction des healthchecks..."
sed -i 's|timeout 5 nc -z localhost \([0-9]*\) || exit 1|wget --no-verbose --tries=1 --spider http://localhost:\1/ || exit 1|g' docker-compose.yml

# Vérifier changements
echo "✅ Healthchecks corrigés:"
grep "wget.*spider" docker-compose.yml | wc -l
echo " healthchecks modifiés"

# Redémarrer
echo "🚀 Redémarrage des services..."
docker compose up -d

# Attendre
echo "⏳ Attente 2 minutes pour stabilisation..."
sleep 120

# Vérifier
echo "📊 Statut final:"
docker compose ps

echo ""
echo "✅ Fix terminé ! Vérifiez que tous les services sont 'healthy'"
```

Enregistrer dans un fichier et exécuter :

```bash
# Créer le script
nano ~/fix-healthcheck.sh

# Copier le contenu ci-dessus, puis:
chmod +x ~/fix-healthcheck.sh
./fix-healthcheck.sh
```

---

## 🎯 Résultat Final Attendu

Après le fix, tous les services doivent être **healthy** :

```bash
cd ~/stacks/supabase
docker compose ps
```

```
NAME                    STATUS                 PORTS
supabase-auth           Up 5 minutes (healthy)
supabase-db             Up 5 minutes (healthy)
supabase-edge-functions Up 5 minutes (healthy)  0.0.0.0:54321->9000/tcp
supabase-imgproxy       Up 5 minutes (healthy)
supabase-kong           Up 5 minutes (healthy)  0.0.0.0:8001->8000/tcp
supabase-meta           Up 5 minutes (healthy)
supabase-realtime       Up 5 minutes (healthy)
supabase-rest           Up 5 minutes (healthy)  ← HEALTHY NOW!
supabase-storage        Up 5 minutes (healthy)
supabase-studio         Up 5 minutes (healthy)  0.0.0.0:3000->3000/tcp
```

### Test Connectivité

```bash
# Studio accessible
curl -I http://localhost:3000
# HTTP/1.1 200 OK

# API Gateway accessible
curl -I http://localhost:8001
# HTTP/1.1 200 OK

# PostgREST accessible via Kong
curl http://localhost:8001/rest/v1/
# {"code":"PGRST000","details":null,"hint":null,"message":"relation \"public.\" does not exist"}
# ^ C'est NORMAL (pas de tables encore)
```

---

## 💡 Prévention Future

### Pour éviter ce problème dans le futur

1. **Utiliser `wget` ou `curl`** dans les healthchecks (pas `nc`)
2. **Tester les healthchecks manuellement** avant déploiement
3. **Vérifier les outils disponibles** dans chaque image Docker

### Template Healthcheck Universel

```yaml
# Pour services HTTP (API, Web)
healthcheck:
  test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:PORT/ || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 90s

# Pour PostgreSQL
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 60s
```

---

<p align="center">
  <strong>✅ Fix PostgREST Healthcheck Complété !</strong>
</p>

<p align="center">
  <a href="../README.md">← Retour Index</a> •
  <a href="Quick-Fixes.md">Autres Fixes Rapides →</a>
</p>
