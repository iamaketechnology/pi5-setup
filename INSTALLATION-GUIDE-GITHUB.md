# 🚀 Pi 5 Supabase Installation Guide - GitHub Links

## 📥 Installation Rapide avec GitHub

### Étape 1 : Cloner le Repository
```bash
cd ~
git clone https://github.com/iamaketechnology/pi5-setup.git
cd pi5-setup/setup-clean
chmod +x scripts/*.sh utils/**/*.sh
```

### Étape 2 : Week 1 - Docker & Base System
```bash
sudo ./scripts/setup-week1-enhanced-final.sh
```

### Étape 3 : Redémarrage Obligatoire
```bash
sudo reboot
```

### Étape 4 : Week 2 - Supabase Stack
```bash
cd ~/pi5-setup/setup-clean
sudo ./scripts/setup-week2-supabase-final.sh
```

## 🔗 Liens GitHub Directs

### 📁 Structure Complète
- **Base Setup Clean** : https://github.com/iamaketechnology/pi5-setup/tree/main/setup-clean

### 📜 Scripts d'Installation
- **Week 1 Enhanced** : https://github.com/iamaketechnology/pi5-setup/blob/main/setup-clean/scripts/setup-week1-enhanced-final.sh
- **Week 2 Supabase** : https://github.com/iamaketechnology/pi5-setup/blob/main/setup-clean/scripts/setup-week2-supabase-final.sh
- **Reset Complet** : https://github.com/iamaketechnology/pi5-setup/blob/main/setup-clean/scripts/pi5-complete-reset.sh

### 📚 Documentation
- **Guide Installation** : https://github.com/iamaketechnology/pi5-setup/blob/main/setup-clean/docs/installation-guide.md
- **Issues Pi 5 Supabase** : https://github.com/iamaketechnology/pi5-setup/blob/main/setup-clean/docs/PI5-SUPABASE-ISSUES-COMPLETE.md

### 🛠️ Utilitaires
- **Diagnostic Complet** : https://github.com/iamaketechnology/pi5-setup/blob/main/setup-clean/utils/diagnostics/diagnose-deep.sh
- **Fix Automatique** : https://github.com/iamaketechnology/pi5-setup/blob/main/setup-clean/utils/fixes/fix-remaining-issues.sh

## 🆘 En Cas de Problème

### Download et Exécution Directe
```bash
# Si problème git, download direct
wget https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/setup-week1-enhanced-final.sh
chmod +x setup-week1-enhanced-final.sh
sudo ./setup-week1-enhanced-final.sh
```

### Diagnostic Automatique
```bash
# Download diagnostic
wget https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/utils/diagnostics/diagnose-deep.sh
chmod +x diagnose-deep.sh
sudo ./diagnose-deep.sh
```

### Fix Problèmes Résiduels
```bash
# Download fix automatique
wget https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/utils/fixes/fix-remaining-issues.sh
chmod +x fix-remaining-issues.sh
sudo ./fix-remaining-issues.sh
```

### Reset Total si Nécessaire
```bash
# Download reset complet
wget https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/pi5-complete-reset.sh
chmod +x pi5-complete-reset.sh
sudo ./pi5-complete-reset.sh
```

## ✅ Vérification Installation

### Commandes de Test
```bash
# Vérifier page size (doit être 4096)
getconf PAGESIZE

# Vérifier Docker
docker --version
docker ps

# Vérifier services Supabase
cd ~/pi5-setup/setup-clean/scripts/../../../stacks/supabase
docker compose ps

# Tester connectivité
curl -I http://localhost:3000  # Studio
curl -I http://localhost:8001  # API
```

### URLs d'Accès
```bash
# Obtenir IP du Pi
IP_PI=$(hostname -I | awk '{print $1}')
echo "Studio Supabase : http://$IP_PI:3000"
echo "API Supabase    : http://$IP_PI:8001"
echo "Portainer       : http://$IP_PI:8080"
```

## 🎯 Correctifs Intégrés

### ✅ Week 1 Enhanced
- Page size 16KB → 4KB automatique
- Docker daemon.json sans options deprecated
- Portainer port 8080 (évite conflit Kong)
- Optimisations RAM 16GB Pi 5
- UFW + Fail2ban sécurisé

### ✅ Week 2 Supabase
- Variables mots de passe unifiées (POSTGRES_PASSWORD unique)
- supabase-vector désactivé (incompatible ARM64 16KB)
- Utilisateurs PostgreSQL complets (service_role, etc.)
- Healthchecks optimisés Pi 5 ARM64
- Memory limits augmentées (512MB-1GB)

## 📞 Support

- **Repository** : https://github.com/iamaketechnology/pi5-setup
- **Issues** : https://github.com/iamaketechnology/pi5-setup/issues
- **Documentation** : https://github.com/iamaketechnology/pi5-setup/tree/main/setup-clean/docs

---

🤖 **Cette installation intègre TOUS les correctifs connus pour Pi 5 + Supabase en 2025 !**