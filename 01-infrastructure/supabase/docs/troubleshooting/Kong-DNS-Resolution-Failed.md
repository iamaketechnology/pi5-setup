# 🔧 Troubleshooting: Kong DNS Resolution Failed

## 🚨 Symptômes

Après avoir exécuté le script `fix-cors-complete.sh`, ton application reçoit l'erreur suivante :

```
{
  "message": "name resolution failed"
}
```

Dans les logs de Kong (`sudo docker logs supabase-kong`) tu vois :

```
[error] DNS resolution failed: dns server error: 3 name error.
Tried: ["(short)auth:(na) - cache-miss","auth:1 - cache-miss/..."]
```

## 🔍 Diagnostic

Ce problème se produit quand Kong ne peut plus résoudre les noms DNS des services Docker (`auth`, `rest`, `storage`, etc.) sur le réseau `supabase_network`.

### Vérifier le problème

```bash
# Depuis le Pi, tester si Kong peut résoudre "auth"
sudo docker exec supabase-kong nslookup auth

# Si tu vois "NXDOMAIN", c'est confirmé
```

## 🛠️ Solution Rapide : Reboot

La solution la plus simple et fiable est de **redémarrer le Raspberry Pi**.

### Étapes

```bash
# 1. Se connecter au Pi
ssh pi@pi5.local

# 2. Redémarrer
sudo reboot

# 3. Attendre ~1 minute

# 4. Vérifier que les services sont OK
ssh pi@pi5.local "cd ~/stacks/supabase && sudo docker compose ps"
```

**Tous les services devraient être (healthy).**

## ✅ Vérification CORS Après Reboot

Une fois le Pi redémarré, teste la preflight request CORS :

```bash
curl -v -X OPTIONS http://192.168.1.74:8001/auth/v1/signup \
  -H "Origin: http://localhost:8080" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type,authorization,apikey,x-client-info,x-supabase-api-version" \
  2>&1 | grep -E "(< HTTP|< Access-Control)"
```

**Résultat attendu :**
```
< HTTP/1.1 200 OK
< Access-Control-Allow-Origin: http://localhost:8080
< Access-Control-Allow-Credentials: true
< Access-Control-Allow-Headers: Accept,Accept-Language,Content-Language,Content-Type,Authorization,apikey,x-client-info,x-supabase-api-version
< Access-Control-Allow-Methods: GET,POST,PUT,PATCH,DELETE,OPTIONS
```

## 📱 Tester ton Application

1. **Ouvre ton application** : `http://localhost:8080`
2. **Ouvre la console développeur** (F12)
3. **Essaie de créer un compte** (signup)
4. **Vérifie** : Plus d'erreur CORS ! ✅

## 🔧 Solutions Alternatives (Si Reboot Impossible)

### Option 1 : Restart Complet Docker

```bash
# Arrêter tous les containers
cd ~/stacks/supabase
sudo docker compose down

# Redémarrer le daemon Docker
sudo systemctl restart docker

# Redémarrer Supabase
sudo docker compose up -d

# Attendre que tout soit healthy
sleep 30
sudo docker compose ps
```

### Option 2 : Recréer le Réseau Docker

```bash
# Arrêter Supabase
cd ~/stacks/supabase
sudo docker compose down

# Supprimer le réseau
sudo docker network rm supabase_network

# Redémarrer (le réseau sera recréé)
sudo docker compose up -d
```

### Option 3 : Modifier kong.yml pour utiliser des IPs

⚠️ **Non recommandé** - Les IPs changent à chaque redémarrage Docker

```bash
# Trouver l'IP du service auth
sudo docker inspect supabase-auth | grep IPAddress

# Modifier kong.yml pour utiliser l'IP
# url: http://172.18.0.4:9999/  # Au lieu de http://auth:9999/
```

## 📚 Pourquoi Ça Arrive ?

Ce problème est une **limitation connue de Kong en mode declarative** avec Docker :

1. Kong charge `kong.yml` au démarrage
2. Kong met en cache les résolutions DNS
3. Si Kong redémarre plusieurs fois (comme pendant le développement)
4. Le cache DNS peut se corrompre
5. Docker DNS (127.0.0.11) ne répond plus correctement

**Sources** :
- [Kong Issue #7417](https://github.com/Kong/kong/issues/7417) - DNS resolution failed without default gateway
- [Kong Issue #6309](https://github.com/Kong/kong/issues/6309) - Blips of DNS resolution failures

## ✅ Prévention

Pour éviter ce problème à l'avenir :

1. **Ne redémarre Kong qu'une seule fois** après avoir modifié `kong.yml`
2. **Utilise `docker compose down && docker compose up -d`** au lieu de `restart`
3. **Reboot le Pi** après avoir modifié la config CORS (recommandé)

## 🎯 Checklist de Résolution

- [ ] Vérifier que Kong a bien des erreurs DNS dans les logs
- [ ] Redémarrer le Raspberry Pi (`sudo reboot`)
- [ ] Attendre 1-2 minutes
- [ ] Vérifier que tous les services Supabase sont (healthy)
- [ ] Tester la preflight OPTIONS request
- [ ] Tester le signup depuis ton application
- [ ] ✅ CORS fonctionne !

---

**Dernière mise à jour** : 2025-10-10
**Version du script** : fix-cors-complete.sh v1.3.0
