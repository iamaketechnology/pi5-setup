# 🛠️ Scripts de Debug - Pi 5 Setup

Cette page liste tous les scripts de debug individuels disponibles pour diagnostiquer et résoudre les problèmes courants lors de l'installation sur Raspberry Pi 5.

---

## 📋 Index des Scripts Debug

- [🐳 Scripts Docker](#-scripts-docker)
- [⚙️ Scripts Supabase](#️-scripts-supabase)
- [🌐 Scripts Réseau](#-scripts-réseau)
- [💾 Scripts Système](#-scripts-système)

---

## 🐳 Scripts Docker

### debug-docker-permissions.sh
**Problème** : Permission denied lors des commandes Docker
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-docker-permissions.sh -o debug-docker-permissions.sh
chmod +x debug-docker-permissions.sh
sudo ./debug-docker-permissions.sh
```

### debug-docker-cleanup.sh
**Problème** : Nettoyage conteneurs échoue avec "no configuration file provided"
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-docker-cleanup.sh -o debug-docker-cleanup.sh
chmod +x debug-docker-cleanup.sh
sudo ./debug-docker-cleanup.sh
```

---

## ⚙️ Scripts Supabase

### debug-page-size.sh
**Problème** : Page Size 16KB causant des crashes jemalloc
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-page-size.sh -o debug-page-size.sh
chmod +x debug-page-size.sh
sudo ./debug-page-size.sh
```

### debug-supabase-services.sh
**Problème** : Services Supabase ne démarrent pas
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-supabase-services.sh -o debug-supabase-services.sh
chmod +x debug-supabase-services.sh
./debug-supabase-services.sh
```

### debug-port-conflict.sh
**Problème** : Port 8000 déjà utilisé par Kong
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-port-conflict.sh -o debug-port-conflict.sh
chmod +x debug-port-conflict.sh
sudo ./debug-port-conflict.sh
```

### check-supabase-health.sh
**Problème** : Vérification complète de l'état Supabase
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/check-supabase-health.sh -o check-supabase-health.sh
chmod +x check-supabase-health.sh
./check-supabase-health.sh
```

### test-supabase-api.sh
**Problème** : Tests complets des API Supabase
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/test-supabase-api.sh -o test-supabase-api.sh
chmod +x test-supabase-api.sh
./test-supabase-api.sh
```

### fix-supabase-studio.sh
**Problème** : Studio inaccessible
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/fix-supabase-studio.sh -o fix-supabase-studio.sh
chmod +x fix-supabase-studio.sh
./fix-supabase-studio.sh
```

### restart-supabase.sh
**Problème** : Redémarrage propre de tous les services
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/restart-supabase.sh -o restart-supabase.sh
chmod +x restart-supabase.sh
./restart-supabase.sh
```

---

## 🌐 Scripts Réseau

### debug-network-connectivity.sh
**Problème** : Problèmes de connectivité réseau
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-network-connectivity.sh -o debug-network-connectivity.sh
chmod +x debug-network-connectivity.sh
./debug-network-connectivity.sh
```

### debug-ufw-rules.sh
**Problème** : Configuration firewall UFW
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-ufw-rules.sh -o debug-ufw-rules.sh
chmod +x debug-ufw-rules.sh
sudo ./debug-ufw-rules.sh
```

---

## 💾 Scripts Système

### debug-system-resources.sh
**Problème** : Vérification ressources système (RAM, CPU, disque)
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-system-resources.sh -o debug-system-resources.sh
chmod +x debug-system-resources.sh
./debug-system-resources.sh
```

### debug-pi5-temperature.sh
**Problème** : Surveillance température Pi 5
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-pi5-temperature.sh -o debug-pi5-temperature.sh
chmod +x debug-pi5-temperature.sh
./debug-pi5-temperature.sh
```

### debug-cmdline-fix.sh
**Problème** : Correction fichier cmdline.txt malformé
**Utilisation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-cmdline-fix.sh -o debug-cmdline-fix.sh
chmod +x debug-cmdline-fix.sh
sudo ./debug-cmdline-fix.sh
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

## 📝 Notes d'Utilisation

**🎯 Règles importantes** :
1. **Télécharger** le script avant exécution
2. **Vérifier** les permissions avec `chmod +x`
3. **Exécuter** avec `sudo` si nécessaire (indiqué dans chaque section)
4. **Lire** les logs de sortie pour comprendre les corrections

**🔍 En cas de problème persistant** :
1. Vérifier les **logs** : `/var/log/pi5-setup-*.log`
2. Exécuter le **diagnostic système** complet
3. Consulter la **documentation de dépannage** : [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
4. Vérifier la **référence des commandes** : [COMMANDS-REFERENCE.md](./COMMANDS-REFERENCE.md)

---

*Scripts mis à jour régulièrement selon les problèmes rencontrés sur le terrain.*