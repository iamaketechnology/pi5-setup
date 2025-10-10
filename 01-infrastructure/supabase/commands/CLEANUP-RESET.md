# 🧹 Nettoyage et Réinitialisation - Guide Simple

> **Commandes pour nettoyer, réinitialiser ou revenir en arrière proprement**

---

## 🎯 Table des Matières

1. [Arrêter Supabase](#1-arrêter-supabase)
2. [Supprimer tout Supabase](#2-supprimer-tout-supabase)
3. [Nettoyer Docker](#3-nettoyer-docker)
4. [Réinitialisation complète](#4-réinitialisation-complète)
5. [Réinstallation propre](#5-réinstallation-propre)

---

## 1. Arrêter Supabase

### Arrêt simple (sans supprimer)

```bash
cd ~/stacks/supabase
docker-compose down
```

### Arrêt + suppression volumes (⚠️ perd les données)

```bash
cd ~/stacks/supabase
docker-compose down -v
```

---

## 2. Supprimer tout Supabase

### ⚠️ Attention: Supprime TOUTES les données!

```bash
# 1. Arrêter services
cd ~/stacks/supabase
docker-compose down -v

# 2. Supprimer dossier Supabase
cd ~
rm -rf ~/stacks/supabase

# 3. Supprimer images Docker
docker rmi $(docker images | grep supabase | awk '{print $3}')
```

**Résultat:** Supabase complètement supprimé

---

## 3. Nettoyer Docker

### Nettoyage léger (images non utilisées)

```bash
docker system prune -f
```

### Nettoyage complet (⚠️ supprime TOUT)

```bash
# Arrêter tous les containers
docker stop $(docker ps -aq)

# Supprimer containers, images, volumes, networks
docker system prune -a --volumes -f
```

**Résultat:** Docker nettoyé, ~10-20 GB libérés

---

## 4. Réinitialisation Complète

### Option A: Garder Docker (+ rapide)

```bash
# 1. Supprimer Supabase
cd ~/stacks/supabase
docker-compose down -v
rm -rf ~/stacks/supabase

# 2. Nettoyer Docker
docker system prune -a --volumes -f

# 3. Prêt pour réinstallation
# Passez à l'étape 5
```

### Option B: Supprimer Docker aussi (+ propre)

```bash
# 1. Supprimer Supabase
cd ~/stacks/supabase
docker-compose down -v
rm -rf ~/stacks/supabase

# 2. Désinstaller Docker
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io
sudo apt-get autoremove -y
sudo rm -rf /var/lib/docker
sudo rm -rf /etc/docker

# 3. Supprimer Portainer
sudo rm -rf /portainer

# 4. Redémarrer
sudo reboot
```

**Résultat:** Système comme neuf, prêt pour réinstallation complète

---

## 5. Réinstallation Propre

### Après réinitialisation complète

```bash
# 1. Cloner le repo (si pas déjà fait)
cd ~
git clone https://github.com/iamaketechnology/pi5-setup.git

# 2. Installation prérequis
cd ~/pi5-setup/01-infrastructure/supabase/scripts
sudo ./01-prerequisites-setup.sh

# 3. Redémarrer obligatoire
sudo reboot

# 4. Installation Supabase (après reboot)
cd ~/pi5-setup/01-infrastructure/supabase/scripts
sudo ./02-supabase-deploy.sh

# 5. Vérifier
docker ps
```

**Durée totale:** ~30 minutes

---

## 🎯 Scénarios Courants

### "Je veux recommencer l'installation"

```bash
# Solution rapide (10 min)
cd ~/stacks/supabase
docker-compose down -v
rm -rf ~/stacks/supabase
cd ~/pi5-setup/01-infrastructure/supabase/scripts
sudo ./02-supabase-deploy.sh
```

### "Supabase ne démarre plus"

```bash
# Redémarrage propre
cd ~/stacks/supabase
docker-compose down
docker-compose up -d

# Si ça ne marche pas:
docker-compose down -v
docker-compose up -d
```

### "Libérer de l'espace disque"

```bash
# Nettoyer logs Docker (gros!)
sudo journalctl --vacuum-time=7d
docker system prune -a -f

# Vérifier espace
df -h
```

### "Revenir à une version antérieure"

```bash
# 1. Sauvegarder données actuelles
cd ~/stacks/supabase
docker-compose exec postgres pg_dumpall -U postgres > ~/backup.sql

# 2. Arrêter et supprimer
docker-compose down -v
rm -rf ~/stacks/supabase

# 3. Checkout version antérieure
cd ~/pi5-setup
git log --oneline  # Trouver le commit
git checkout <commit-hash>

# 4. Réinstaller
cd 01-infrastructure/supabase/scripts
sudo ./02-supabase-deploy.sh

# 5. Restaurer données (optionnel)
docker-compose exec postgres psql -U postgres < ~/backup.sql
```

---

## 🆘 Commandes d'Urgence

### Tout est cassé, je veux repartir à zéro

```bash
# 1. Tout arrêter
docker stop $(docker ps -aq)

# 2. Tout supprimer
docker system prune -a --volumes -f
sudo rm -rf ~/stacks/supabase

# 3. Redémarrer
sudo reboot

# 4. Après reboot, réinstaller
cd ~/pi5-setup/01-infrastructure/supabase/scripts
sudo ./02-supabase-deploy.sh
```

### Plus d'espace disque

```bash
# Nettoyer logs
sudo journalctl --vacuum-size=100M

# Nettoyer Docker
docker system prune -a --volumes -f

# Nettoyer apt cache
sudo apt-get clean
sudo apt-get autoclean

# Vérifier
df -h
du -sh ~ | sort -h | tail -10
```

### Kernel page size cassé (16KB → 4KB)

```bash
# Revenir au kernel standard
sudo rpi-update

# Redémarrer
sudo reboot

# Vérifier page size
getconf PAGE_SIZE
# Doit afficher: 4096

# Si 16384: relancer fix
cd ~/pi5-setup/01-infrastructure/supabase/scripts
sudo ./01-prerequisites-setup.sh
sudo reboot
```

---

## 📋 Checklist de Vérification

### Après nettoyage

- [ ] `docker ps` → Aucun container
- [ ] `df -h` → Espace disque libéré
- [ ] `~/stacks/supabase` → N'existe pas

### Après réinstallation

- [ ] `docker ps` → 9 containers healthy
- [ ] `http://IP:3000` → Studio accessible
- [ ] `curl http://localhost:8000/rest/v1/` → API répond

---

## 💡 Conseils

### Avant de supprimer

```bash
# TOUJOURS sauvegarder d'abord!
cd ~/stacks/supabase
docker-compose exec postgres pg_dumpall -U postgres > ~/backup-$(date +%Y%m%d).sql

# Vérifier backup
ls -lh ~/backup-*.sql
```

### Restaurer un backup

```bash
# 1. Démarrer Supabase
cd ~/stacks/supabase
docker-compose up -d

# 2. Attendre 30 secondes
sleep 30

# 3. Restaurer
docker-compose exec postgres psql -U postgres < ~/backup-20251006.sql
```

---

## 🎯 Résumé des Commandes Critiques

| Action | Commande | Danger |
|--------|----------|--------|
| **Arrêter** | `docker-compose down` | 🟢 Safe |
| **Arrêter + supprimer volumes** | `docker-compose down -v` | 🟡 Perd données |
| **Supprimer Supabase** | `rm -rf ~/stacks/supabase` | 🟠 Supprime tout |
| **Nettoyer Docker** | `docker system prune -a --volumes -f` | 🔴 Supprime images |
| **Reset complet** | Voir [Section 4](#4-réinitialisation-complète) | 🔴 Tout refaire |

---

<p align="center">
  <strong>🧹 Guide de Nettoyage Supabase Pi</strong><br>
  <em>Simple • Clair • Sans risque (si vous sauvegardez!)</em>
</p>
