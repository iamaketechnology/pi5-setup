# 🏠 Phase 10 - Domotique & Maison Connectée (OPTIONNEL)

> **Transformez votre Raspberry Pi 5 en hub domotique complet**

**Temps installation** : 15-30 min par stack
**RAM totale** : ~500 MB - 1.5 GB selon configuration
**Niveau** : Intermédiaire à Avancé

---

## 📋 Vue d'Ensemble

Cette phase optionnelle vous permet d'ajouter des **applications domotique** pour contrôler votre maison :

| Application | Description | RAM | Difficulté | Recommandé |
|-------------|-------------|-----|------------|------------|
| **Home Assistant** | Hub domotique tout-en-un | ~500 MB | ⭐⭐⭐ | ✅ Débutants |
| **Node-RED** | Automatisations visuelles | ~100 MB | ⭐⭐ | ✅ Complémentaire |
| **MQTT Broker** | Messagerie IoT (Mosquitto) | ~30 MB | ⭐ | ✅ Essentiel IoT |
| **Zigbee2MQTT** | Passerelle Zigbee (Sonoff, Philips Hue, etc.) | ~80 MB | ⭐⭐⭐ | ⚠️ Nécessite dongle |
| **Scrypted** | NVR + caméras (surveillance) | ~300 MB | ⭐⭐⭐ | ⚠️ Avancé |
| **ESPHome** | Firmware ESP32/ESP8266 custom | ~50 MB | ⭐⭐⭐⭐ | ⚠️ DIY experts |

**Recommandation débutant** : **Home Assistant** seul suffit pour 90% des besoins !

---

## 🚀 Option 1 : Home Assistant (Recommandé)

### Qu'est-ce que Home Assistant ?

**Home Assistant** est le hub domotique **#1 mondial** (open source) :
- ✅ **2000+ intégrations** : Philips Hue, Xiaomi, Sonoff, Google Home, Alexa, IKEA, etc.
- ✅ **Interface moderne** : Dashboard personnalisable (mobile + desktop)
- ✅ **Automatisations visuelles** : Si mouvement détecté → Allumer lumières
- ✅ **Notifications** : Push mobile, email, Discord, Telegram
- ✅ **Graphiques historiques** : Température, consommation énergie, etc.
- ✅ **Commande vocale** : Compatible Google Assistant, Alexa, Siri
- ✅ **100% local** : Fonctionne sans Internet (privacy)

### Installation Home Assistant

#### Méthode 1 : Docker Compose (Recommandé)

**Créer le stack** :

```bash
# Créer répertoire
sudo mkdir -p /home/pi/stacks/homeassistant
cd /home/pi/stacks/homeassistant

# Créer docker-compose.yml
sudo tee docker-compose.yml > /dev/null <<'EOF'
version: '3.8'

services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    privileged: true
    network_mode: host
    volumes:
      - /home/pi/stacks/homeassistant/config:/config
      - /etc/localtime:/etc/localtime:ro
    environment:
      - TZ=Europe/Paris
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.homeassistant.rule=Host(`home.pi.local`) || PathPrefix(`/homeassistant`)"
      - "traefik.http.services.homeassistant.loadbalancer.server.port=8123"
EOF

# Créer répertoire config
sudo mkdir -p config

# Démarrer
sudo docker compose up -d

# Voir logs
sudo docker compose logs -f
```

**Accès** :
- **Local** : `http://raspberrypi.local:8123`
- **Traefik** (si configuré) : `https://home.pi.local` ou `https://home.votredomaine.com`

**Premier démarrage** (~2 min) :
1. Ouvrir `http://raspberrypi.local:8123`
2. Créer compte admin
3. Configurer localisation (France)
4. Découverte automatique appareils réseau

**RAM** : ~500 MB

---

#### Configuration Home Assistant

**Ajouter vos appareils** :

1. **Menu → Paramètres → Appareils et services → Ajouter intégration**
2. Rechercher votre marque (Philips Hue, Xiaomi, Sonoff, etc.)
3. Suivre les instructions (généralement auto-découverte)

**Intégrations populaires** :
- **Philips Hue** : Ampoules connectées
- **Xiaomi Mi Home** : Capteurs, interrupteurs, caméras
- **Sonoff** : Relais WiFi DIY
- **Google Home** / **Alexa** : Commande vocale
- **MQTT** : Appareils IoT custom
- **Météo** : Prévisions locales
- **Spotify** : Contrôle musique
- **Calendrier Google** : Automatisations basées agenda

**Exemple automatisation** :
```yaml
# Dans Configuration → Automatisations → Créer

alias: Allumer lumières au coucher soleil
trigger:
  - platform: sun
    event: sunset
    offset: "-00:30:00"  # 30 min avant coucher soleil
action:
  - service: light.turn_on
    target:
      entity_id: light.salon
    data:
      brightness: 80
```

---

### Intégration Traefik (HTTPS)

Si vous avez **Traefik installé** (Phase 2) :

**Scénario DuckDNS (path-based)** :
```yaml
# Ajouter labels dans docker-compose.yml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.homeassistant.rule=PathPrefix(`/homeassistant`)"
  - "traefik.http.routers.homeassistant.entrypoints=websecure"
  - "traefik.http.services.homeassistant.loadbalancer.server.port=8123"
```
→ Accès : `https://monpi.duckdns.org/homeassistant`

**Scénario Cloudflare (subdomain)** :
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.homeassistant.rule=Host(`home.mondomaine.com`)"
  - "traefik.http.routers.homeassistant.entrypoints=websecure"
  - "traefik.http.routers.homeassistant.tls.certresolver=cloudflare"
  - "traefik.http.services.homeassistant.loadbalancer.server.port=8123"
```
→ Accès : `https://home.mondomaine.com`

**Redémarrer** :
```bash
sudo docker compose down && sudo docker compose up -d
```

---

## 🔌 Option 2 : Node-RED (Automatisations Visuelles)

**Node-RED** est un outil d'automatisation **par flux visuels** (drag & drop) :
- ✅ **Complémentaire à Home Assistant** : Automatisations complexes
- ✅ **Interface visuelle** : Pas de code (ou presque)
- ✅ **Intégrations** : MQTT, HTTP, Webhooks, Base de données, etc.

### Installation Node-RED

```bash
# Créer répertoire
sudo mkdir -p /home/pi/stacks/nodered
cd /home/pi/stacks/nodered

# Créer docker-compose.yml
sudo tee docker-compose.yml > /dev/null <<'EOF'
version: '3.8'

services:
  nodered:
    image: nodered/node-red:latest
    container_name: nodered
    restart: unless-stopped
    ports:
      - "1880:1880"
    volumes:
      - /home/pi/stacks/nodered/data:/data
    environment:
      - TZ=Europe/Paris
    user: "1000:1000"
EOF

# Créer répertoire data
sudo mkdir -p data
sudo chown -R 1000:1000 data

# Démarrer
sudo docker compose up -d
```

**Accès** : `http://raspberrypi.local:1880`

**RAM** : ~100 MB

**Exemple flux** :
1. Ouvrir Node-RED
2. Glisser-déposer nœuds : `mqtt in` → `switch` → `http request` → `debug`
3. Configurer : Si température > 25°C → Envoyer notification Telegram

---

## 📡 Option 3 : MQTT Broker (Mosquitto)

**MQTT** est le protocole standard pour **IoT** (Internet of Things).

**Utilité** :
- ✅ Communication entre appareils IoT (ESP32, Sonoff, Tasmota, etc.)
- ✅ Léger et rapide
- ✅ Publier/Souscrire (pub/sub)

### Installation Mosquitto

```bash
# Créer répertoire
sudo mkdir -p /home/pi/stacks/mqtt
cd /home/pi/stacks/mqtt

# Créer config
sudo tee mosquitto.conf > /dev/null <<'EOF'
listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
EOF

# Créer docker-compose.yml
sudo tee docker-compose.yml > /dev/null <<'EOF'
version: '3.8'

services:
  mosquitto:
    image: eclipse-mosquitto:latest
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto.conf:/mosquitto/config/mosquitto.conf
      - ./data:/mosquitto/data
      - ./log:/mosquitto/log
EOF

# Créer répertoires
sudo mkdir -p data log

# Démarrer
sudo docker compose up -d
```

**Accès** : Port **1883** (MQTT)

**Tester** :
```bash
# Installer client MQTT
sudo apt-get install -y mosquitto-clients

# Publier message
mosquitto_pub -h localhost -t "test/topic" -m "Hello MQTT"

# Souscrire à topic
mosquitto_sub -h localhost -t "test/topic"
```

**RAM** : ~30 MB

---

## 📶 Option 4 : Zigbee2MQTT (Passerelle Zigbee)

**Zigbee2MQTT** permet de contrôler des appareils **Zigbee** (sans hub propriétaire) :
- ✅ **Philips Hue** : Ampoules, interrupteurs (sans Hue Bridge)
- ✅ **IKEA Tradfri** : Ampoules, télécommandes
- ✅ **Sonoff** : Capteurs, relais Zigbee
- ✅ **Xiaomi Aqara** : Capteurs température, mouvement, portes

**Prérequis** : **Dongle Zigbee USB** (~15-25€)
- [Sonoff Zigbee 3.0 USB Dongle Plus](https://itead.cc/product/sonoff-zigbee-3-0-usb-dongle-plus/) (~20€)
- [CC2531 Sniffer](https://www.amazon.fr/dp/B07TF6KDL2) (~15€)
- ConBee II (~40€)

### Installation Zigbee2MQTT

```bash
# Trouver le dongle USB
ls /dev/ttyUSB* /dev/ttyACM*
# Exemple résultat : /dev/ttyUSB0

# Créer répertoire
sudo mkdir -p /home/pi/stacks/zigbee2mqtt
cd /home/pi/stacks/zigbee2mqtt

# Créer docker-compose.yml
sudo tee docker-compose.yml > /dev/null <<'EOF'
version: '3.8'

services:
  zigbee2mqtt:
    image: koenkk/zigbee2mqtt:latest
    container_name: zigbee2mqtt
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./data:/app/data
      - /run/udev:/run/udev:ro
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0  # Adapter selon votre dongle
    environment:
      - TZ=Europe/Paris
    depends_on:
      - mosquitto  # Si MQTT Broker installé
EOF

# Créer configuration
sudo mkdir -p data
sudo tee data/configuration.yaml > /dev/null <<'EOF'
homeassistant: true
permit_join: true
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://mosquitto:1883  # Si MQTT local
frontend:
  port: 8080
serial:
  port: /dev/ttyUSB0
EOF

# Démarrer
sudo docker compose up -d
```

**Accès** : `http://raspberrypi.local:8080`

**Appairer appareils** :
1. Ouvrir interface Zigbee2MQTT
2. Activer "Permit join" (mode appairage)
3. Appuyer sur bouton reset de l'appareil Zigbee
4. Appareil apparaît dans la liste

**RAM** : ~80 MB

---

## 📹 Option 5 : Scrypted (Caméras Surveillance)

**Scrypted** est un NVR (Network Video Recorder) moderne pour **caméras IP** :
- ✅ Compatible HomeKit, Google Home, Alexa
- ✅ Détection mouvement, visages
- ✅ Enregistrement continu ou sur événement
- ✅ Live stream dans Home Assistant

**Prérequis** : Caméras IP (ONVIF, RTSP)

### Installation Scrypted

```bash
# Créer répertoire
sudo mkdir -p /home/pi/stacks/scrypted
cd /home/pi/stacks/scrypted

# Créer docker-compose.yml
sudo tee docker-compose.yml > /dev/null <<'EOF'
version: '3.8'

services:
  scrypted:
    image: koush/scrypted:latest
    container_name: scrypted
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./volume:/server/volume
    environment:
      - TZ=Europe/Paris
EOF

# Démarrer
sudo docker compose up -d
```

**Accès** : `http://raspberrypi.local:10443`

**RAM** : ~300 MB

---

## 🛠️ Option 6 : ESPHome (DIY ESP32/ESP8266)

**ESPHome** permet de créer des **capteurs/actionneurs custom** avec ESP32/ESP8266 :
- ✅ Firmware sans code (YAML)
- ✅ Intégration Home Assistant automatique
- ✅ Capteurs température, humidité, mouvement, etc.

**Prérequis** : Carte ESP32/ESP8266 (~3-10€)

### Installation ESPHome

```bash
# Créer répertoire
sudo mkdir -p /home/pi/stacks/esphome
cd /home/pi/stacks/esphome

# Créer docker-compose.yml
sudo tee docker-compose.yml > /dev/null <<'EOF'
version: '3.8'

services:
  esphome:
    image: esphome/esphome:latest
    container_name: esphome
    restart: unless-stopped
    ports:
      - "6052:6052"
    volumes:
      - ./config:/config
    environment:
      - TZ=Europe/Paris
    privileged: true
EOF

# Démarrer
sudo docker compose up -d
```

**Accès** : `http://raspberrypi.local:6052`

**RAM** : ~50 MB

---

## 📊 Comparaison Stacks Domotique

| Stack | Utilité | RAM | Matériel Requis | Difficulté | Complémentaire |
|-------|---------|-----|-----------------|------------|----------------|
| **Home Assistant** | Hub central | 500 MB | Aucun | ⭐⭐⭐ | Base essentielle |
| **Node-RED** | Automatisations | 100 MB | Aucun | ⭐⭐ | + Home Assistant |
| **Mosquitto** | MQTT Broker | 30 MB | Aucun | ⭐ | + IoT devices |
| **Zigbee2MQTT** | Passerelle Zigbee | 80 MB | Dongle Zigbee (~20€) | ⭐⭐⭐ | + Appareils Zigbee |
| **Scrypted** | Caméras NVR | 300 MB | Caméras IP | ⭐⭐⭐⭐ | + Home Assistant |
| **ESPHome** | DIY ESP32 | 50 MB | ESP32/ESP8266 (~5€) | ⭐⭐⭐⭐ | + Électronique |

**Total RAM** (toutes domotique) : ~1.1 GB

---

## 🎯 Configuration Recommandée Débutant

### Setup "Maison Connectée Minimale" (~600 MB RAM)

```bash
# 1. Home Assistant (hub central)
cd /home/pi/stacks/homeassistant
sudo docker compose up -d

# 2. MQTT Broker (pour appareils IoT)
cd /home/pi/stacks/mqtt
sudo docker compose up -d

# 3. Node-RED (automatisations avancées)
cd /home/pi/stacks/nodered
sudo docker compose up -d
```

**Accès** :
- Home Assistant : `http://raspberrypi.local:8123`
- Node-RED : `http://raspberrypi.local:1880`
- MQTT : Port 1883

**Intégration** :
1. Dans Home Assistant → Paramètres → Intégrations → MQTT
2. Serveur : `mosquitto` (ou IP locale)
3. Port : 1883

**RAM totale** : ~630 MB (500 + 30 + 100)

---

## 🔧 Intégration avec pi5-setup

### Homepage Widget (Optionnel)

Ajouter Home Assistant au dashboard Homepage :

```bash
# Éditer config Homepage
sudo nano /home/pi/stacks/homepage/config/services.yaml
```

**Ajouter** :
```yaml
- Domotique:
    - Home Assistant:
        href: http://raspberrypi.local:8123
        description: Hub domotique
        icon: home-assistant.png
        widget:
          type: homeassistant
          url: http://homeassistant:8123
          key: YOUR_LONG_LIVED_TOKEN

    - Node-RED:
        href: http://raspberrypi.local:1880
        description: Automatisations
        icon: node-red.png
```

**Obtenir token Home Assistant** :
1. Home Assistant → Profil (bas gauche)
2. Créer "Long-Lived Access Token"
3. Copier dans widget Homepage

---

## 🎛️ Gestion RAM avec Stack Manager

**Voir consommation domotique** :
```bash
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh ram
```

**Arrêter stacks domotique temporairement** :
```bash
# Libérer ~1 GB RAM
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop homeassistant
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop scrypted
```

**Configuration boot** :
```bash
# Démarrage auto Home Assistant seulement
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh enable homeassistant
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh disable scrypted
```

---

## 📚 Ressources

### Documentation Officielle
- [Home Assistant](https://www.home-assistant.io/docs/)
- [Node-RED](https://nodered.org/docs/)
- [Zigbee2MQTT](https://www.zigbee2mqtt.io/)
- [ESPHome](https://esphome.io/)

### Communautés
- [r/homeassistant](https://reddit.com/r/homeassistant)
- [r/nodered](https://reddit.com/r/nodered)
- [Forum Home Assistant FR](https://forum.hacf.fr/)

### Matériel Recommandé
- **Dongle Zigbee** : [Sonoff Dongle Plus](https://itead.cc/product/sonoff-zigbee-3-0-usb-dongle-plus/) (~20€)
- **Ampoules** : Philips Hue, IKEA Tradfri, Yeelight
- **Capteurs** : Xiaomi Aqara (température, mouvement, porte)
- **ESP32** : [Amazon](https://www.amazon.fr/s?k=esp32) (~5-10€)

---

## ✅ Checklist Domotique

- [ ] Home Assistant installé et accessible
- [ ] Compte admin créé
- [ ] Localisation configurée (France)
- [ ] Intégrations ajoutées (Hue, Xiaomi, etc.)
- [ ] Première automatisation créée
- [ ] MQTT Broker installé (si appareils IoT)
- [ ] Node-RED installé (si automatisations complexes)
- [ ] Dongle Zigbee configuré (si appareils Zigbee)
- [ ] Widget Homepage ajouté
- [ ] Démarrage auto configuré avec Stack Manager

---

**Votre Raspberry Pi 5 est maintenant un hub domotique complet ! 🏠🎉**

**Question ?** Consultez la [documentation Home Assistant](https://www.home-assistant.io/docs/) ou ouvrez une [issue GitHub](https://github.com/iamaketechnology/pi5-setup/issues).
