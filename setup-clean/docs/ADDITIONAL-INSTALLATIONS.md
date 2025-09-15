# 🛠️ Installations supplémentaires recommandées - Week 1 & 2

## 📋 Vue d'ensemble

Après avoir installé les composants essentiels (Week 1: Docker, sécurité) et Supabase (Week 2), voici les outils complémentaires utiles pour optimiser votre Raspberry Pi 5.

## 🔧 Week 1 - Outils système supplémentaires

### 📊 Monitoring avancé

```bash
# Outils de surveillance système
sudo apt update
sudo apt install -y \
  btop \
  glances \
  nmon \
  dstat \
  iftop \
  nethogs \
  tree \
  curl \
  wget \
  git \
  vim \
  nano \
  unzip \
  zip

# Monitoring Docker spécialisé
sudo apt install -y ctop
```

**Utilisation :**
- `btop` - Monitoring moderne et coloré
- `glances` - Vue d'ensemble système web
- `ctop` - Monitoring Docker en temps réel
- `iftop` - Trafic réseau par connexion
- `nethogs` - Utilisation réseau par processus

### 🌡️ Monitoring température Pi 5

```bash
# Script de surveillance température
cat > ~/temp_monitor.sh << 'EOF'
#!/bin/bash
while true; do
  temp=$(vcgencmd measure_temp | cut -d= -f2)
  freq=$(vcgencmd measure_clock arm | cut -d= -f2)
  echo "$(date): Temp=$temp, CPU Freq=$((freq/1000000))MHz"
  sleep 30
done
EOF

chmod +x ~/temp_monitor.sh

# Lancer en arrière-plan
nohup ~/temp_monitor.sh > ~/temp.log &
```

### 🔐 Outils de sécurité additionnels

```bash
# Scan de ports et sécurité
sudo apt install -y \
  nmap \
  fail2ban-client \
  ufw-extras \
  rkhunter \
  chkrootkit

# Configuration scan sécurité
sudo rkhunter --propupd
```

### 📡 Outils réseau

```bash
# Utilitaires réseau avancés
sudo apt install -y \
  net-tools \
  traceroute \
  mtr \
  dig \
  whois \
  tcpdump \
  wireshark-common

# Test de connectivité
sudo apt install -y speedtest-cli
```

### 💾 Gestion des disques

```bash
# Outils de gestion disque
sudo apt install -y \
  smartmontools \
  hdparm \
  parted \
  gparted \
  rsync \
  rclone

# Monitoring santé SSD/SD
sudo smartctl -a /dev/mmcblk0
```

## 🗄️ Week 2 - Outils base de données

### 🐘 PostgreSQL client

```bash
# Client PostgreSQL pour administration
sudo apt install -y postgresql-client

# Test de connexion
psql -h localhost -p 5432 -U postgres -d postgres
```

### 📊 Outils d'administration DB

```bash
# pgAdmin (interface web PostgreSQL)
sudo apt install -y python3-pip
pip3 install pgadmin4

# DBeaver (alternative via Java)
# Ou utiliser Supabase Studio qui est déjà installé
```

### 📝 Éditeurs et IDE

```bash
# Éditeurs avancés
sudo apt install -y \
  code \
  vim-gtk3 \
  emacs \
  micro

# Extensions VSCode utiles pour Supabase
code --install-extension ms-vscode.vscode-json
code --install-extension ms-python.python
code --install-extension bradlc.vscode-tailwindcss
```

## 🌐 Services web additionnels

### 🔒 Certificats SSL (préparation Week 3)

```bash
# Certbot pour Let's Encrypt
sudo apt install -y certbot python3-certbot-nginx

# Préparation des certificats auto-signés
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/pi5.key \
  -out /etc/ssl/certs/pi5.crt \
  -subj "/C=FR/ST=Local/L=Home/O=Pi5/CN=$(hostname -I | awk '{print $1}')"
```

### 📊 Grafana + Prometheus (monitoring avancé)

```bash
# Installation Grafana
sudo apt install -y software-properties-common
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

sudo apt update
sudo apt install -y grafana

# Démarrer Grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

# Accès : http://PI_IP:3001 (admin/admin)
```

### 🔄 Portainer Agent (gestion Docker avancée)

```bash
# Déjà installé avec le script Week 1, mais ajout d'agents
docker run -d -p 9001:9001 \
  --name portainer_agent \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  portainer/agent:latest
```

## 📱 Applications utiles

### 🌐 Serveur web léger

```bash
# Nginx pour servir des fichiers statiques
sudo apt install -y nginx

# Configuration basique
sudo systemctl enable nginx
sudo systemctl start nginx

# Test : http://PI_IP (page par défaut)
```

### 📁 Gestionnaire de fichiers web

```bash
# Filebrowser - Interface web pour fichiers
curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# Configuration
filebrowser config init --port 8080 --address 0.0.0.0 --root /home/pi

# Démarrer
nohup filebrowser &

# Accès : http://PI_IP:8080 (admin/admin)
```

### 🔄 Backup automatique

```bash
# Script de sauvegarde automatique
cat > ~/backup_supabase.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/pi/backups"
DATE=$(date +%Y%m%d_%H%M)

mkdir -p $BACKUP_DIR

# Backup PostgreSQL
docker exec supabase-db pg_dump -U postgres -d postgres > $BACKUP_DIR/supabase_$DATE.sql

# Backup volumes
sudo tar -czf $BACKUP_DIR/volumes_$DATE.tar.gz /home/pi/stacks/supabase/volumes/

# Nettoyer les anciens backups (garder 7 jours)
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup terminé : $DATE"
EOF

chmod +x ~/backup_supabase.sh

# Automatiser avec cron (tous les jours à 2h)
echo "0 2 * * * /home/pi/backup_supabase.sh >> /home/pi/backup.log 2>&1" | crontab -
```

## 🔧 Optimisations système Pi 5

### ⚡ Overclocking sécurisé

```bash
# Configuration overclocking modéré
sudo nano /boot/firmware/config.txt

# Ajouter ces lignes :
# arm_freq=2400
# gpu_freq=750
# over_voltage=6
# temp_limit=75

# Redémarrer et tester
sudo reboot
```

### 💾 Optimisation mémoire

```bash
# Configuration swap optimisée
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile

# Modifier :
# CONF_SWAPSIZE=4096

sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

### 🌡️ Gestion thermique

```bash
# Ventilateur automatique (si ventilateur PWM connecté)
cat > /etc/systemd/system/fan-control.service << 'EOF'
[Unit]
Description=Pi Fan Control
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /home/pi/fan_control.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Script de contrôle ventilateur
cat > ~/fan_control.py << 'EOF'
import RPi.GPIO as GPIO
import time
import subprocess

FAN_PIN = 18  # GPIO 18 pour ventilateur PWM
GPIO.setmode(GPIO.BCM)
GPIO.setup(FAN_PIN, GPIO.OUT)
fan = GPIO.PWM(FAN_PIN, 1000)
fan.start(0)

try:
    while True:
        temp = float(subprocess.check_output("vcgencmd measure_temp", shell=True).decode().split('=')[1].split('°')[0])

        if temp < 50:
            fan.ChangeDutyCycle(0)
        elif temp < 60:
            fan.ChangeDutyCycle(30)
        elif temp < 70:
            fan.ChangeDutyCycle(60)
        else:
            fan.ChangeDutyCycle(100)

        time.sleep(10)
except KeyboardInterrupt:
    fan.stop()
    GPIO.cleanup()
EOF

sudo systemctl enable fan-control
sudo systemctl start fan-control
```

## 📚 Outils de développement

### 🐍 Python et environnements

```bash
# Python avec packages utiles
sudo apt install -y \
  python3-pip \
  python3-venv \
  python3-dev \
  build-essential

# Packages Python pour Supabase
pip3 install \
  supabase \
  psycopg2-binary \
  fastapi \
  uvicorn \
  requests \
  python-dotenv
```

### 📱 Node.js et npm

```bash
# Node.js via NodeSource
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# Packages globaux utiles
sudo npm install -g \
  @supabase/cli \
  pm2 \
  http-server \
  live-server \
  typescript
```

### 🔧 Git configuration

```bash
# Configuration Git globale
git config --global user.name "Votre Nom"
git config --global user.email "votre@email.com"
git config --global init.defaultBranch main

# Clés SSH pour GitHub
ssh-keygen -t ed25519 -C "votre@email.com"
cat ~/.ssh/id_ed25519.pub
# Copier cette clé dans GitHub Settings > SSH Keys
```

## 🔍 Vérification des installations

### ✅ Script de vérification

```bash
# Script pour vérifier toutes les installations
cat > ~/check_installations.sh << 'EOF'
#!/bin/bash

echo "=== Vérification des installations Pi 5 ==="
echo

echo "🐳 Docker:"
docker --version
docker compose version

echo "🗄️ PostgreSQL Client:"
psql --version

echo "📊 Monitoring Tools:"
which btop && echo "✅ btop installé"
which glances && echo "✅ glances installé"
which ctop && echo "✅ ctop installé"

echo "🌐 Services actifs:"
sudo systemctl is-active docker
sudo systemctl is-active nginx 2>/dev/null || echo "nginx non installé"
sudo systemctl is-active grafana-server 2>/dev/null || echo "grafana non installé"

echo "🔥 Température CPU:"
vcgencmd measure_temp

echo "💾 Espace disque:"
df -h / | tail -1

echo "🧠 Mémoire:"
free -h | grep Mem

echo "🔧 Supabase Services:"
cd /home/pi/stacks/supabase && docker compose ps || echo "Supabase non installé"

echo
echo "=== Vérification terminée ==="
EOF

chmod +x ~/check_installations.sh
~/check_installations.sh
```

## 🚀 Prochaines étapes

### 📋 Week 3 - Accès externe
- Reverse proxy (Nginx/Traefik)
- Certificats SSL
- DNS dynamique
- VPN/Tunnel

### 📋 Week 4 - Développement
- Git server local
- CI/CD avec Gitea/Jenkins
- IDE distant (code-server)

### 📋 Week 5 - Cloud personnel
- NextCloud
- Syncthing
- Media server

### 📋 Week 6 - IoT et automatisation
- Home Assistant
- MQTT broker
- Node-RED

## 💡 Conseils d'optimisation

### 🔋 Économie d'énergie
```bash
# Désactiver WiFi/Bluetooth si Ethernet utilisé
echo 'dtoverlay=disable-wifi' | sudo tee -a /boot/firmware/config.txt
echo 'dtoverlay=disable-bt' | sudo tee -a /boot/firmware/config.txt
```

### 📈 Performance réseau
```bash
# Optimisations TCP
echo 'net.core.rmem_max = 16777216' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 16777216' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 🗄️ Stockage optimisé
```bash
# Mount options optimisées pour SSD
sudo nano /etc/fstab
# Ajouter : ,noatime,nodiratime aux options de mount
```

---

**🎯 Avec ces installations supplémentaires, votre Pi 5 devient une véritable station de développement et serveur personnel !**

Installez selon vos besoins et continuez avec Week 3 pour l'accès externe sécurisé.