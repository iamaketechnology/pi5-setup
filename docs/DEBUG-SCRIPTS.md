# 🛠️ Scripts de Debug - Pi 5 Setup

Cette page liste tous les scripts de debug individuels disponibles pour diagnostiquer et résoudre les problèmes courants lors de l'installation sur Raspberry Pi 5.

## 🚀 Scripts de Diagnostic Rapide

### 📊 Diagnostic Complet
```bash
# Vérification santé complète de Supabase (RECOMMANDÉ EN PREMIER)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/check-supabase-health.sh -o health.sh && chmod +x health.sh && ./health.sh
```
**Quand l'utiliser** : Toujours en premier ! Donne un aperçu complet de l'état de ton installation Supabase.

### 🔍 État des Services
```bash
# Analyse détaillée de tous les services Docker
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/check-services-status.sh -o status.sh && chmod +x status.sh && ./status.sh
```
**Quand l'utiliser** : Quand des services redémarrent ou ne fonctionnent pas correctement.

### 🌐 Test Connectivité API
```bash
# Test de tous les endpoints Supabase
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/test-api-connectivity.sh -o test-api.sh && chmod +x test-api.sh && ./test-api.sh
```
**Quand l'utiliser** : Pour vérifier que toutes les APIs sont accessibles et fonctionnelles.

---

## 📋 Index des Scripts Debug

- [🐳 Scripts Docker](#-scripts-docker)
- [⚙️ Scripts Supabase](#️-scripts-supabase)
- [🔧 Scripts Kong](#-scripts-kong)
- [🌐 Scripts Réseau](#-scripts-réseau)
- [💾 Scripts Système](#-scripts-système)

---

## 🐳 Scripts Docker

### debug-docker-permissions.sh
**Problème** : Permission denied lors des commandes Docker
**Quand l'utiliser** : Erreur "permission denied" avec les commandes docker
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-docker-permissions.sh -o debug-docker-permissions.sh && chmod +x debug-docker-permissions.sh && sudo ./debug-docker-permissions.sh
```

### debug-docker-cleanup.sh
**Problème** : Nettoyage conteneurs échoue avec "no configuration file provided"
**Quand l'utiliser** : Quand docker compose down échoue et qu'il faut nettoyer manuellement
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-docker-cleanup.sh -o debug-docker-cleanup.sh && chmod +x debug-docker-cleanup.sh && sudo ./debug-docker-cleanup.sh
```

---

## ⚙️ Scripts Supabase

### debug-page-size.sh
**Problème** : Page Size 16KB causant des crashes jemalloc
**Quand l'utiliser** : Erreur "Unsupported system page size" dans les logs
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-page-size.sh -o debug-page-size.sh && chmod +x debug-page-size.sh && sudo ./debug-page-size.sh
```

### debug-supabase-services.sh
**Problème** : Services Supabase ne démarrent pas
**Quand l'utiliser** : Quand docker compose ps montre des services "Exited" ou en erreur
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-supabase-services.sh -o debug-supabase-services.sh && chmod +x debug-supabase-services.sh && ./debug-supabase-services.sh
```

### debug-port-conflict.sh
**Problème** : Port 8000 déjà utilisé par Kong
**Quand l'utiliser** : Erreur "Bind failed: port is already allocated"
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-port-conflict.sh -o debug-port-conflict.sh && chmod +x debug-port-conflict.sh && sudo ./debug-port-conflict.sh
```

### check-supabase-health.sh
**Problème** : Vérification complète de l'état Supabase
**Quand l'utiliser** : TOUJOURS EN PREMIER ! Diagnostic général complet
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/check-supabase-health.sh -o check-supabase-health.sh && chmod +x check-supabase-health.sh && ./check-supabase-health.sh
```

### test-supabase-api.sh
**Problème** : Tests complets des API Supabase
**Quand l'utiliser** : Pour vérifier que toutes les fonctionnalités Supabase marchent
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/test-supabase-api.sh -o test-supabase-api.sh && chmod +x test-supabase-api.sh && ./test-supabase-api.sh
```

### fix-supabase-studio.sh
**Problème** : Studio inaccessible
**Quand l'utiliser** : Quand http://pi5.local:3000 ne répond pas
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/fix-supabase-studio.sh -o fix-supabase-studio.sh && chmod +x fix-supabase-studio.sh && ./fix-supabase-studio.sh
```

### restart-supabase.sh
**Problème** : Redémarrage propre de tous les services
**Quand l'utiliser** : Quand plusieurs services dysfonctionnent ou après une modification
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/restart-supabase.sh -o restart-supabase.sh && chmod +x restart-supabase.sh && ./restart-supabase.sh
```

---

## 🔧 Scripts Kong

### fix-kong-plugin-error.sh
**Problème** : Erreur "request-id plugin not installed" dans Kong
**Quand l'utiliser** : Quand Kong redémarre en boucle avec des erreurs de plugin
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/fix-kong-plugin-error.sh -o fix-kong.sh && chmod +x fix-kong.sh && ./fix-kong.sh
```

### check-kong-logs.sh
**Problème** : Diagnostic détaillé des logs Kong
**Quand l'utiliser** : Pour analyser pourquoi Kong ne fonctionne pas correctement
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/check-kong-logs.sh -o kong-logs.sh && chmod +x kong-logs.sh && ./kong-logs.sh
```

### fix-port-conflict-manual.sh
**Problème** : Conflit port 8000 entre Kong et Portainer
**Quand l'utiliser** : Erreur "port already allocated" lors du démarrage
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/fix-port-conflict-manual.sh -o fix-port.sh && chmod +x fix-port.sh && ./fix-port.sh
```

### fix-config-missing.sh
**Problème** : Variables de configuration Supabase manquantes (API_EXTERNAL_URL, mots de passe)
**Quand l'utiliser** : Services redémarrent avec erreurs "required key missing" ou "password authentication failed"
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/fix-config-missing.sh -o fix-config.sh && chmod +x fix-config.sh && ./fix-config.sh
```

### fix-url-mismatch.sh
**Problème** : URLs localhost au lieu de l'IP réelle dans la configuration
**Quand l'utiliser** : Services ne communiquent pas entre eux, APIs non accessibles depuis le réseau
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/fix-url-mismatch.sh -o fix-urls.sh && chmod +x fix-urls.sh && ./fix-urls.sh
```

---

## 🌐 Scripts Réseau

### debug-network-connectivity.sh
**Problème** : Problèmes de connectivité réseau
**Quand l'utiliser** : Impossible d'accéder aux interfaces web depuis un autre appareil
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-network-connectivity.sh -o debug-network-connectivity.sh && chmod +x debug-network-connectivity.sh && ./debug-network-connectivity.sh
```

### debug-ufw-rules.sh
**Problème** : Configuration firewall UFW
**Quand l'utiliser** : Ports bloqués ou règles firewall mal configurées
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-ufw-rules.sh -o debug-ufw-rules.sh && chmod +x debug-ufw-rules.sh && sudo ./debug-ufw-rules.sh
```

---

## 💾 Scripts Système

### debug-system-resources.sh
**Problème** : Vérification ressources système (RAM, CPU, disque)
**Quand l'utiliser** : Pi5 lent, manque de mémoire ou d'espace disque
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-system-resources.sh -o debug-system-resources.sh && chmod +x debug-system-resources.sh && ./debug-system-resources.sh
```

### debug-pi5-temperature.sh
**Problème** : Surveillance température Pi 5
**Quand l'utiliser** : Pi5 qui chauffe ou performance dégradée
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-pi5-temperature.sh -o debug-pi5-temperature.sh && chmod +x debug-pi5-temperature.sh && ./debug-pi5-temperature.sh
```

### debug-cmdline-fix.sh
**Problème** : Correction fichier cmdline.txt malformé
**Quand l'utiliser** : Pi5 ne boot pas après modification du page size
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-cmdline-fix.sh -o debug-cmdline-fix.sh && chmod +x debug-cmdline-fix.sh && sudo ./debug-cmdline-fix.sh
```

---

## 🚀 Utilisation Rapide

### Téléchargement Groupé
```bash
# Télécharger tous les scripts debug essentiels
mkdir -p ~/debug-scripts
cd ~/debug-scripts

# Scripts Docker
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-docker-permissions.sh -o debug-docker-permissions.sh
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-docker-cleanup.sh -o debug-docker-cleanup.sh

# Scripts Supabase
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-port-conflict.sh -o debug-port-conflict.sh
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/check-supabase-health.sh -o check-supabase-health.sh
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/restart-supabase.sh -o restart-supabase.sh

# Rendre tous exécutables
chmod +x *.sh
```

### Diagnostic Complet
```bash
# Exécuter diagnostic système complet
./debug-system-resources.sh
./debug-network-connectivity.sh
./check-supabase-health.sh
```

---

---

## 🎯 Guide d'Utilisation - Ordre Recommandé

### 1️⃣ **En cas de problème général**
```bash
# TOUJOURS commencer par ça !
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/check-supabase-health.sh -o health.sh && chmod +x health.sh && ./health.sh
```

### 2️⃣ **Si des services redémarrent**
```bash
# Analyser les services en détail
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/check-services-status.sh -o status.sh && chmod +x status.sh && ./status.sh
```

### 3️⃣ **Si Kong pose problème**
```bash
# Diagnostic Kong spécifique
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/check-kong-logs.sh -o kong.sh && chmod +x kong.sh && ./kong.sh
```

### 4️⃣ **Test final**
```bash
# Tester toutes les APIs
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/test-api-connectivity.sh -o test.sh && chmod +x test.sh && ./test.sh
```

## 📝 Notes d'Utilisation

**🎯 Règles importantes** :
1. **Toujours commencer** par le diagnostic complet (check-supabase-health.sh)
2. **Lire les messages** "Quand l'utiliser" pour chaque script
3. **Télécharger** le script avant exécution avec `curl -fsSL`
4. **Exécuter** avec `sudo` uniquement si indiqué

**🔍 En cas de problème persistant** :
1. Vérifier les **logs** : `/var/log/pi5-setup-*.log`
2. Exécuter le **diagnostic système** complet
3. Consulter la **documentation de dépannage** : [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
4. Vérifier la **référence des commandes** : [COMMANDS-REFERENCE.md](./COMMANDS-REFERENCE.md)

**💡 Astuce** : Les scripts incluent des recommandations automatiques basées sur ce qu'ils détectent !

---

*Scripts mis à jour régulièrement selon les problèmes rencontrés sur le terrain.*