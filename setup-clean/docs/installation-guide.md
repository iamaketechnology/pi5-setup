# 📋 Guide d'Installation Pi 5 Supabase - Pas à Pas

## 🎯 Objectif
Transformer un Raspberry Pi 5 (16GB) en serveur de développement avec Supabase complet.

## ✅ Prérequis

### Matériel
- Raspberry Pi 5 avec 16GB RAM
- Carte SD 64GB+ (Classe 10 minimum)
- Alimentation officielle Pi 5
- Connexion réseau (Ethernet recommandé)

### Système
- Raspberry Pi OS 64-bit (version récente 2024+)
- Utilisateur avec privilèges sudo
- SSH activé (optionnel mais recommandé)

## 📥 Étape 1 : Préparation

### Vérification système
```bash
# Version OS
cat /etc/os-release

# RAM disponible
free -h

# Page size (doit devenir 4096)
getconf PAGESIZE

# Espace disque
df -h
```

### Download du projet
```bash
cd ~
git clone https://github.com/your-repo/pi5-setup-clean.git
cd pi5-setup-clean
chmod +x scripts/*.sh utils/**/*.sh
```

## 🔧 Étape 2 : Week 1 - Fondations

### Lancement automatique
```bash
sudo ./scripts/setup-week1-enhanced-final.sh
```

### Ce qui sera installé
- ✅ Docker + Docker Compose
- ✅ Portainer (interface Docker)
- ✅ UFW Firewall configuré
- ✅ Fail2ban anti-brute force
- ✅ Page size corrigé (16KB → 4KB)
- ✅ Optimisations mémoire Pi 5
- ✅ Outils monitoring (htop, iotop)

### Vérification Week 1
```bash
# Docker fonctionne
docker run --rm hello-world

# Portainer accessible
curl -I http://localhost:8080

# Page size corrigé
getconf PAGESIZE  # Doit afficher 4096

# Services actifs
sudo systemctl status docker
sudo systemctl status ufw
sudo systemctl status fail2ban
```

### **IMPORTANT : Redémarrage obligatoire**
```bash
sudo reboot
```

## 🗄️ Étape 3 : Week 2 - Supabase Stack

### Après redémarrage
```bash
cd ~/pi5-setup-clean
sudo ./scripts/setup-week2-supabase-final.sh
```

### Ce qui sera installé
- ✅ PostgreSQL 15 optimisé Pi 5
- ✅ Supabase Auth service
- ✅ Supabase Studio (interface web)
- ✅ Supabase REST API
- ✅ Realtime service
- ✅ Storage service
- ✅ Kong API Gateway
- ✅ Edge Functions

### Configuration automatique
Le script configure automatiquement :
- Variables d'environnement unifiées
- Mots de passe synchronisés
- Utilisateurs PostgreSQL complets
- Healthchecks optimisés ARM64
- Memory limits adaptées (16GB RAM)

### Vérification Week 2
```bash
# État des services
cd ~/stacks/supabase
docker compose ps

# Tests de connectivité
curl -I http://localhost:3000  # Studio
curl -I http://localhost:8001  # API
curl -I http://localhost:54321  # Edge Functions

# PostgreSQL
docker compose exec db psql -U postgres -c "SELECT version();"
```

## 🎉 Étape 4 : Accès aux Services

### URLs d'accès
Remplacer `IP-PI5` par l'IP de votre Pi :
```
📊 Supabase Studio  : http://IP-PI5:3000
🔌 API Gateway      : http://IP-PI5:8001
⚡ Edge Functions   : http://IP-PI5:54321
🐳 Portainer       : http://IP-PI5:8080
```

### Obtenir l'IP du Pi
```bash
hostname -I | awk '{print $1}'
```

### Première connexion Studio
1. Ouvrir http://IP-PI5:3000
2. Créer un nouveau projet
3. Utiliser les credentials du fichier `.env`

## 🆘 Dépannage

### Services en restart
```bash
# Diagnostic approfondi
sudo ./utils/diagnostics/diagnose-deep.sh

# Fix automatique problèmes courants
sudo ./utils/fixes/fix-remaining-issues.sh
```

### Reset complet si problème
```bash
# Reset total du système
sudo ./scripts/pi5-complete-reset.sh
sudo reboot

# Reprendre installation
sudo ./scripts/setup-week1-enhanced-final.sh
# Après reboot
sudo ./scripts/setup-week2-supabase-final.sh
```

### Erreurs courantes

#### Page size encore 16384
```bash
# Vérifier config.txt
cat /boot/firmware/config.txt | grep kernel

# Doit contenir : kernel=kernel8.img
# Sinon ajouter :
echo "kernel=kernel8.img" | sudo tee -a /boot/firmware/config.txt
sudo reboot
```

#### Docker ne démarre pas
```bash
# Vérifier daemon.json
cat /etc/docker/daemon.json

# Redémarrer Docker
sudo systemctl restart docker
sudo systemctl status docker
```

#### Services Supabase unhealthy
```bash
# Logs détaillés
cd ~/stacks/supabase
docker compose logs auth --tail=20
docker compose logs db --tail=20

# Reset volume database
docker compose down
sudo rm -rf volumes/db/data
docker compose up -d
```

## ✅ Validation Finale

### Checklist complète
- [ ] Page size = 4096 bytes
- [ ] Docker fonctionne
- [ ] Portainer accessible (port 8080)
- [ ] Supabase Studio accessible (port 3000)
- [ ] API Gateway répond (port 8001)
- [ ] PostgreSQL connecté
- [ ] Tous services Docker "healthy"

### Commande de validation totale
```bash
# Script de validation inclus
cd ~/pi5-setup-clean
./utils/diagnostics/diagnose-deep.sh
```

## 🚀 Prochaines Étapes

Après installation réussie :
1. Configuration première base de données via Studio
2. Test des API endpoints
3. Configuration Edge Functions
4. Backup et sauvegarde
5. SSL/TLS avec reverse proxy (Week 3)

## 📞 Support

En cas de problème :
1. Consulter `docs/PI5-SUPABASE-ISSUES-COMPLETE.md`
2. Utiliser les outils de diagnostic fournis
3. Reset complet si nécessaire

**🎯 Cette installation intègre tous les correctifs connus pour Pi 5 + Supabase !**