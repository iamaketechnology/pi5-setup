# 🛠️ Scripts de Débogage Supabase Pi 5

Collection de scripts individuels pour diagnostiquer et résoudre les problèmes d'installation Supabase sur Raspberry Pi 5.

## 📋 Scripts Disponibles

### 🔧 debug-port-conflict.sh
**Résout les conflits de ports pour Kong API Gateway**

```bash
# Télécharger et exécuter
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-port-conflict.sh -o debug-port-conflict.sh
chmod +x debug-port-conflict.sh
sudo ./debug-port-conflict.sh
```

**Fonctions :**
- ✅ Identifie qui utilise le port 8000
- ✅ Arrête tous les conteneurs en conflit
- ✅ Modifie automatiquement les ports (8000 → 8001)
- ✅ Nettoie les réseaux Docker
- ✅ Prépare pour redémarrage

### 🚀 restart-supabase.sh
**Redémarre Supabase après correction des problèmes**

```bash
# Télécharger et exécuter
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/restart-supabase.sh -o restart-supabase.sh
chmod +x restart-supabase.sh
./restart-supabase.sh
```

**Fonctions :**
- ✅ Redémarre les services avec configuration corrigée
- ✅ Attend le démarrage complet (30s)
- ✅ Teste la connectivité des services
- ✅ Affiche les URLs d'accès finales

### 🏥 check-supabase-health.sh
**Diagnostic complet de santé Supabase**

```bash
# Télécharger et exécuter
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/check-supabase-health.sh -o check-supabase-health.sh
chmod +x check-supabase-health.sh
./check-supabase-health.sh
```

**Fonctions :**
- ✅ Vérifie page size et ressources système
- ✅ État détaillé de tous les conteneurs
- ✅ Tests de connectivité pour chaque service
- ✅ Diagnostic PostgreSQL complet
- ✅ Utilisation mémoire par conteneur
- ✅ URLs d'accès et logs

### 🧪 test-supabase-api.sh
**Suite de tests complète des APIs Supabase**

```bash
# Télécharger et exécuter
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/test-supabase-api.sh -o test-supabase-api.sh
chmod +x test-supabase-api.sh
./test-supabase-api.sh
```

**Fonctions :**
- ✅ Test API REST avec clés authentifiées
- ✅ Test création/insertion tables PostgreSQL
- ✅ Test service authentification (Auth)
- ✅ Test service stockage (Storage)
- ✅ Test service temps réel (Realtime)
- ✅ Test Edge Functions
- ✅ Connexion directe PostgreSQL
- ✅ Affichage des clés API

## 🔄 Workflow de Débogage Recommandé

### 1. Problème de Port (Erreur: "port already allocated")
```bash
./debug-port-conflict.sh
./restart-supabase.sh
```

### 2. Services ne Démarrent Pas
```bash
./check-supabase-health.sh
# Analyser les logs affichés
./restart-supabase.sh
```

### 3. APIs Non Accessibles
```bash
./check-supabase-health.sh
./test-supabase-api.sh
# Si nécessaire : ./restart-supabase.sh
```

### 4. Diagnostic Complet
```bash
./check-supabase-health.sh > diagnostic-$(date +%Y%m%d_%H%M).log
./test-supabase-api.sh >> diagnostic-$(date +%Y%m%d_%H%M).log
```

## 📍 URLs d'Accès Post-Debug

Après correction des conflits de ports :

- 🎨 **Studio Supabase** : `http://192.168.X.XX:3000`
- 🔌 **API Gateway** : `http://192.168.X.XX:8001` (port modifié)
- 🔐 **Auth API** : `http://192.168.X.XX:8001/auth/v1/`
- 📁 **Storage API** : `http://192.168.X.XX:8001/storage/v1/`
- ⚡ **Edge Functions** : `http://192.168.X.XX:54321/functions/v1/`

## 🆘 Problèmes Courants

### Page Size 16KB
Les scripts détectent automatiquement et utilisent les images compatibles.

### Mémoire Insuffisante
```bash
# Vérifier utilisation
./check-supabase-health.sh

# Optimiser si nécessaire
sudo docker system prune -af
```

### Logs des Services
```bash
cd ~/stacks/supabase
sudo docker compose logs [service_name]

# Services disponibles : db, auth, rest, realtime, storage, kong, studio, etc.
```

## 🔧 Scripts Complémentaires

Ces scripts complètent l'écosystème principal :
- [Week 1](../week1/) - Installation base Docker
- [Week 2](../week2/) - Installation Supabase orchestrée
- [Documentation](../../docs/) - Guides détaillés

## 📞 Support

Pour les problèmes non couverts :
1. Exécuter `./check-supabase-health.sh > debug.log`
2. Créer une [issue GitHub](https://github.com/iamaketechnology/pi5-setup/issues)
3. Joindre le fichier debug.log