# 🟢 Semaine 1 – Configuration de base Raspberry Pi 5

🎯 **Objectif** : Transformer un **Raspberry Pi 5 (16 Go)** en **mini-serveur sécurisé et optimisé**, avec **Docker + Portainer** pour gérer les conteneurs.

---

## ✅ Étape 1 – Préparer la microSD (sur Mac/PC)

1. **Installer Raspberry Pi Imager**
2. **Choisir** :
   - Device → *Raspberry Pi 5*
   - OS → *Raspberry Pi OS Lite (64-bit)*
   - Storage → carte microSD (≥32GB recommandé)
3. **Dans ⚙️ (options avancées)** :
   - Hostname : `pi5.local`
   - Enable SSH ✔
   - Username : `pi`
   - Password : mot de passe fort
   - Wi-Fi : SSID + mot de passe (si pas Ethernet)
   - Locale : `Europe/Paris`, clavier `fr`
4. **Flash** → insérer la carte → démarrer le Pi

---

## ✅ Étape 2 – Connexion en SSH

Depuis ton Mac/PC :

```bash
ssh pi@pi5.local
```

👉 Si ça échoue, utilise l'IP trouvée sur ta box :

```bash
ssh pi@192.168.X.XX
```

---

## ✅ Étape 3 – Mise à jour de l'OS

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

Reconnecte-toi ensuite :

```bash
ssh pi@pi5.local
```

⚠️ Si Debian demande `initramfs.conf (Y/I/N/O/D/Z)` → choisis **Y** (prendre la version mainteneur)

---

## ✅ Étape 4 – Installation automatisée optimisée Pi 5

### 📥 Téléchargement et exécution

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week1/setup-week1.sh -o setup-week1.sh \
&& chmod +x setup-week1.sh \
&& sudo MODE=beginner ./setup-week1.sh
```

### 🎛️ Options de configuration

**Mode débutant (par défaut)** :
```bash
sudo MODE=beginner ./setup-week1.sh
```

**Mode avancé avec optimisations** :
```bash
sudo MODE=pro GPU_MEM_SPLIT=256 ENABLE_I2C=yes ./setup-week1.sh
```

**Configuration SSH personnalisée** :
```bash
sudo MODE=pro SSH_PORT=2222 ./setup-week1.sh
```

### 🔧 Variables disponibles

| Variable | Défaut | Description |
|----------|---------|-------------|
| `MODE` | `beginner` | `beginner` ou `pro` (durcissement SSH) |
| `GPU_MEM_SPLIT` | `128` | Mémoire GPU en MB (64-512) |
| `ENABLE_I2C` | `no` | Activer interface I2C (`yes`/`no`) |
| `ENABLE_SPI` | `no` | Activer interface SPI (`yes`/`no`) |
| `SSH_PORT` | `22` | Port SSH personnalisé |
| `LOG_FILE` | `/var/log/pi5-setup-week1.log` | Fichier de log |

---

## ✅ Étape 5 – Ce que le script installe

### 🔒 **Sécurité**
- **UFW** : Pare-feu configuré (SSH, Portainer, HTTP/HTTPS)
- **Fail2ban** : Protection anti-bruteforce SSH (12h de ban)
- **Mises à jour automatiques** : Sécurité uniquement
- **SSH durci** (mode pro) : Authentification par clé uniquement

### 🐳 **Docker optimisé Pi 5**
- **Docker CE** + **Compose v2** (plugin)
- **Configuration daemon** : Logs limités, overlay2, ulimits optimisés
- **Portainer** : Interface web sur port 9000

### 🚀 **Optimisations Pi 5**
- **Vérifications système** : Architecture ARM64, RAM, espace disque
- **GPU memory split** : Configurable (défaut 128MB)
- **Swappiness réduit** : vm.swappiness=10 pour usage serveur
- **Limites fichiers** : 65536 pour Docker
- **Support I2C/SPI** : Activation optionnelle

### 📊 **Outils de monitoring**
- **htop, iotop, ncdu, tree** : Surveillance système
- **Logging complet** : Toutes actions sauvées dans `/var/log/pi5-setup-week1.log`

---

## ✅ Étape 6 – Vérifications post-installation

### Reconnexion utilisateur Docker
```bash
exit
ssh pi@pi5.local
```

### Tests de fonctionnement
```bash
# Docker fonctionne
docker run --rm hello-world

# Services de sécurité actifs
sudo ufw status
sudo fail2ban-client status

# Informations système
htop                    # Monitoring temps réel
df -h                   # Espace disque
free -h                 # Mémoire
```

---

## ✅ Étape 7 – Configurer Portainer

### Accès interface web
Ouvre dans ton navigateur :
- **HTTP** : http://192.168.X.XX:9000
- **HTTPS** : https://192.168.X.XX:9443

### Premier démarrage
Si message *"New installation timed out"* :
```bash
docker restart portainer
```

👉 **Crée un compte admin**, choisis **"Local environment"**

---

## ✅ Vérifications finales & monitoring

### État des services
```bash
# Services systemd
sudo systemctl status docker
sudo systemctl status fail2ban

# Conteneurs Docker
docker ps
docker stats

# Logs système
tail -f /var/log/pi5-setup-week1.log
```

### Surveillance ressources Pi 5
```bash
# CPU et mémoire temps réel
htop

# I/O disque temps réel
sudo iotop

# Espace disque par répertoire
ncdu /
```

---

## 📊 Résultats attendus

**À la fin de cette étape, ton Pi 5 sera :**

✅ **Système optimisé**
- OS à jour avec optimisations Pi 5 spécifiques
- 16GB RAM correctement détectés et optimisés
- GPU memory split configuré

✅ **Sécurisé**
- Pare-feu UFW actif avec règles restrictives
- Fail2ban protégeant SSH
- Mises à jour sécurité automatiques

✅ **Docker prêt**
- Docker CE avec optimisations ARM64
- Portainer fonctionnel pour gestion web
- Utilisateur `pi` dans le groupe docker

✅ **Monitoring**
- Outils de surveillance installés
- Logs détaillés de l'installation
- Métriques système accessibles

---

## 🚀 Prochaine étape

**Semaine 2 : Supabase Self-hosted**
- PostgreSQL optimisé Pi 5
- Supabase Studio + Auth + Realtime
- pgAdmin pour gestion base de données
- Configuration réseau avancée

```bash
# Prochaine commande (semaine 2)
sudo ./setup-week2.sh
```

---

## 🛠️ Dépannage

### Problèmes courants

**Docker : permission denied**
```bash
# Vérifier groupe docker
groups
# Si 'docker' absent :
sudo usermod -aG docker $USER && exit && ssh pi@pi5.local
```

**Portainer inaccessible**
```bash
# Redémarrer le conteneur
docker restart portainer
# Vérifier les ports
sudo netstat -tlnp | grep :9000
```

**Espace disque insuffisant**
```bash
# Nettoyer Docker
docker system prune -af
# Vérifier l'espace
df -h
```

**SSH connection refused**
```bash
# Vérifier le service
sudo systemctl status ssh
# Vérifier les règles UFW
sudo ufw status numbered
```

### Logs et diagnostic
```bash
# Log complet installation
cat /var/log/pi5-setup-week1.log

# Logs Docker
sudo journalctl -u docker.service

# Logs système
sudo journalctl -f
```