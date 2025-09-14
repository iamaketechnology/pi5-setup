# 🔧 Guide de Dépannage Pi 5 - Solutions aux Problèmes Rencontrés

Ce document répertorie tous les problèmes rencontrés lors de la configuration du Raspberry Pi 5 et leurs solutions testées.

---

## 📋 Index des Problèmes

- [🐳 Problèmes Docker](#-problèmes-docker)
- [⚙️ Problèmes Supabase](#️-problèmes-supabase)
- [🔒 Problèmes de Permissions](#-problèmes-de-permissions)
- [💾 Problèmes de Mémoire/Stockage](#-problèmes-de-mémoirestockage)
- [🌐 Problèmes Réseau](#-problèmes-réseau)

---

## 🐳 Problèmes Docker

### ❌ Problème : "Permission denied" lors des commandes Docker
**Symptôme** :
```bash
docker: permission denied while trying to connect to the Docker daemon socket
```

**Cause** : L'utilisateur n'est pas dans le groupe `docker`

**Solution** :
```bash
# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER

# Se reconnecter ou recharger les groupes
newgrp docker

# Vérifier que c'est corrigé
groups | grep docker
```

**Status** : ⏳ En attente de confirmation

---

### ❌ Problème : Nettoyage conteneurs échoue avec "no configuration file provided"
**Symptôme** :
```bash
cd ~/stacks/supabase
sudo docker compose down
# ERROR: no configuration file provided: not found
```

**Cause** : Le fichier `docker-compose.yml` est absent mais des conteneurs persistent

**Solution** :
```bash
# Arrêter tous les conteneurs Supabase manuellement
sudo docker ps -a --filter 'name=supabase' -q | xargs -r sudo docker stop
sudo docker ps -a --filter 'name=supabase' -q | xargs -r sudo docker rm

# Alternative : arrêter TOUS les conteneurs si nécessaire
sudo docker stop $(sudo docker ps -q) 2>/dev/null || true

# Nettoyage complet
sudo docker system prune -af
sudo docker volume prune -f
```

**Status** : ✅ **RÉSOLU**

---

## ⚙️ Problèmes Supabase

### ❌ Problème : Page Size 16KB causant des crashes jemalloc
**Symptôme** :
```
<jemalloc>: Unsupported system page size
```

**Cause** : Pi 5 utilise par défaut un page size de 16KB, incompatible avec Supabase

**Solution** :
```bash
# Vérifier page size actuel
getconf PAGE_SIZE

# Si 16384, corriger dans /boot/firmware/cmdline.txt
sudo cp /boot/firmware/cmdline.txt /boot/firmware/cmdline.txt.backup
sudo sed -i 's/$/ kernel_address=0xc00000/' /boot/firmware/cmdline.txt

# REDÉMARRAGE OBLIGATOIRE
sudo reboot

# Vérifier après reboot
getconf PAGE_SIZE  # Doit afficher 4096
```

**Status** : ⏳ En attente de confirmation

---

### ❌ Problème : Erreur de syntaxe dans les commandes de nettoyage
**Symptôme** :
```bash
-bash: dans: command not found
-bash: nécessaire: command not found
```

**Cause** : Caractères spéciaux français dans les commentaires copiés-collés

**Solution** :
- **Éviter** de copier-coller les commentaires français
- Exécuter **uniquement** les commandes sur une ligne :
```bash
sudo docker ps -a --filter 'name=supabase' -q | xargs -r sudo docker stop
sudo docker ps -a --filter 'name=supabase' -q | xargs -r sudo docker rm
sudo docker system prune -af
```

**Status** : ✅ **RÉSOLU**

---

## 🔒 Problèmes de Permissions

### ❌ Problème : Erreur 400/404 lors du téléchargement depuis GitHub
**Symptôme** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week2.sh -o setup-week2.sh
# ERROR: curl: (22) The requested URL returned error: 400

wget https://github.com/iamaketechnology/pi5-setup/raw/main/setup-week2.sh -O setup-week2.sh
# ERROR: 404 Not Found
```

**Cause** : URL incorrecte ou commande mal formatée (caractères spéciaux, retours ligne)

**Solution** : Créer le script manuellement sur le Pi
```bash
# Créer le script orchestrateur localement
cat > setup-week2.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# === ORCHESTRATEUR Week 2 - Version locale ===
MODE="${MODE:-beginner}"
LOG_FILE="${LOG_FILE:-/var/log/pi5-setup-week2-orchestrator.log}"

log()  { echo -e "\033[1;36m[ORCHESTRATOR]\033[0m $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*" | tee -a "$LOG_FILE"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo MODE=beginner ./setup-week2.sh"
    exit 1
  fi
  touch "$LOG_FILE"
  chmod 644 "$LOG_FILE"
  log "=== Pi 5 Supabase Orchestrator Week 2 - $(date) ==="
}

detect_current_phase() {
  log "🔍 Détection phase actuelle…"

  CURRENT_PAGE_SIZE=$(getconf PAGE_SIZE)
  log "Page size détecté: $CURRENT_PAGE_SIZE"

  if [[ "$CURRENT_PAGE_SIZE" == "4096" ]]; then
    ok "✅ Page size correct (4KB) - Compatible Supabase"
  elif [[ "$CURRENT_PAGE_SIZE" == "16384" ]]; then
    warn "⚠️ Page size problématique (16KB) - Correction nécessaire"
    log "→ Ajout de 'kernel_address=0xc00000' requis dans /boot/firmware/cmdline.txt"
    log "→ Redémarrage obligatoire après correction"
  else
    warn "Page size inattendu: $CURRENT_PAGE_SIZE"
  fi
}

main() {
  require_root
  detect_current_phase

  echo ""
  echo "==================== PROCHAINES ÉTAPES ===================="
  echo "1. Vérifier page size ci-dessus"
  echo "2. Si 16KB, suivre les instructions de correction"
  echo "3. Installation complète Supabase en cours de développement"
  echo "=========================================================="
}

main "$@"
EOF

# Rendre exécutable et lancer
chmod +x setup-week2.sh
sudo MODE=beginner ./setup-week2.sh
```

**Status** : ✅ **RÉSOLU**

---

### ❌ Problème : Installation Week 1 incomplète causant des conflits
**Symptôme** :
```bash
[ERROR] Page size déjà configuré mais pas actif. Redémarrage Pi 5 requis !
[ERROR] ❌ Phase 1 échouée
```

**Cause** : Installation Week 1 interrompue ayant laissé des configurations partielles

**Solution** : Nettoyage complet et redémarrage
```bash
# Nettoyage complet Pi 5
sudo docker stop $(sudo docker ps -q) 2>/dev/null || true
sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true
sudo docker system prune -af && sudo docker volume prune -f
sudo rm -rf ~/stacks/ /opt/stacks/ 2>/dev/null || true
rm -f ~/setup-week*.sh 2>/dev/null || true
sudo rm -f /var/log/pi5-setup*.log /tmp/pi5-*.state 2>/dev/null || true
sudo cp /boot/firmware/cmdline.txt.backup /boot/firmware/cmdline.txt 2>/dev/null || true
sudo ufw --force reset
sudo reboot
```

**Status** : ✅ **RÉSOLU** - Nettoyage réussi, 180MB récupérés

---

## 💾 Problèmes de Mémoire/Stockage

### ❌ Problème : Fichier cmdline.txt malformé (paramètres collés)
**Symptôme** :
```bash
cat /boot/firmware/cmdline.txt
# Affiche: ...cfg80211.ieee80211_regdom=FRkernel_address=0xc00000
# (pas d'espace entre FR et kernel_address)
getconf PAGE_SIZE  # Affiche toujours 16384
```

**Cause** : Script d'ajout de paramètre qui n'ajoute pas d'espace avant le nouveau paramètre

**Solution** : Restaurer le backup et réappliquer proprement
```bash
# Restaurer backup original
sudo cp /boot/firmware/cmdline.txt.backup.20250914_113531 /boot/firmware/cmdline.txt

# Ajouter proprement avec espace
sudo sed -i 's/$/ kernel_address=0xc00000/' /boot/firmware/cmdline.txt

# Vérifier format correct
cat /boot/firmware/cmdline.txt

# Redémarrer
sudo reboot
```

**Status** : ❌ **ÉCHEC** - Page size 16KB non modifiable sur ce Pi 5

**SOLUTION RECOMMANDÉE** : Utiliser des images Docker compatibles 16KB
```bash
# Au lieu de modifier le système, adapter les images Docker
# PostgreSQL compatible 16KB
postgres:15-alpine          # Natif ARM64 + 16KB support
arm64v8/postgres:15-alpine  # Version explicite ARM64

# Images Supabase alternatives
timescale/timescaledb:latest-pg15  # PostgreSQL optimisé ARM64
postgrest/postgrest:v12.2.0        # Compatible 16KB
supabase/gotrue:v2.177.0          # Fonctionne sur 16KB
```

**Avantages** :
- ✅ Solution immédiate sans risquer le système
- ✅ Images optimisées spécifiquement pour ARM64
- ✅ Performance potentiellement meilleure
- ✅ Documentation et support plus fiables

**Solution alternative** : Recréer le fichier sur UNE SEULE ligne
```bash
# IMPORTANT: cmdline.txt doit être sur UNE SEULE ligne
sudo bash -c 'echo "console=serial0,115200 console=tty1 root=PARTUUID=64e7d188-02 rootfstype=ext4 fsck.repair=yes rootwait cfg80211.ieee80211_regdom=FR kernel_address=0xc00000" > /boot/firmware/cmdline.txt'

# Vérifier format (doit être 1 ligne)
cat /boot/firmware/cmdline.txt
wc -l /boot/firmware/cmdline.txt  # Doit afficher "1"

# Redémarrer
sudo reboot
```

---

## 🌐 Problèmes Réseau

### ❌ Problème : [À DOCUMENTER]
**Symptôme** :
**Cause** :
**Solution** :
**Status** : ⏳ En attente

---

## 🛠️ Commandes Utiles de Diagnostic

### Docker
```bash
# État des conteneurs
docker ps -a

# Logs d'un conteneur
docker logs CONTAINER_NAME

# Utilisation des ressources
docker stats --no-stream

# Nettoyage complet
docker system prune -af && docker volume prune -f
```

### Système Pi 5
```bash
# Page size actuel
getconf PAGE_SIZE

# RAM disponible
free -h

# Espace disque
df -h

# Architecture
uname -m

# Température CPU
vcgencmd measure_temp
```

### Réseau
```bash
# IP locale
hostname -I

# Ports ouverts
sudo netstat -tlnp

# Test connectivité
curl -I http://localhost:PORT
```

---

## 📝 Notes pour Débutants

**🎯 Règles importantes** :
1. **Toujours** sauvegarder avant de modifier des fichiers système
2. **Redémarrer** obligatoire après modification de `/boot/firmware/cmdline.txt`
3. **Copier une ligne à la fois** pour éviter les erreurs de syntaxe
4. **Vérifier** les prérequis avant chaque installation

**🔍 Avant de demander de l'aide** :
1. Noter le **message d'erreur exact**
2. Indiquer la **commande qui a échoué**
3. Vérifier les **logs** (`/var/log/pi5-setup-*.log`)
4. Tester les **commandes de diagnostic**

---

*Ce document est mis à jour au fur et à mesure des problèmes rencontrés et résolus.*