# 🏠 Phase 10 - Domotique & Maison Connectée

> **Transformez votre Raspberry Pi 5 en hub domotique complet**

**Version** : 1.0
**Statut** : ✅ Production Ready
**RAM Totale** : ~630 MB (configuration recommandée)

---

## 📋 Vue d'Ensemble

Cette phase vous permet d'installer des **applications domotique** pour contrôler votre maison :

| Application | Description | RAM | Script |
|-------------|-------------|-----|--------|
| **🏠 Home Assistant** | Hub domotique #1 mondial | 500 MB | 01-homeassistant-deploy.sh |
| **🔀 Node-RED** | Automatisations visuelles | 100 MB | 02-nodered-deploy.sh |
| **📡 MQTT Broker** | Messagerie IoT | 30 MB | 03-mqtt-deploy.sh |
| **📶 Zigbee2MQTT** | Passerelle Zigbee | 80 MB | 04-zigbee2mqtt-deploy.sh ⚠️ |

⚠️ = Nécessite matériel supplémentaire (dongle Zigbee USB)

---

## 🚀 Installation Rapide (Recommandé Débutant)

### Configuration "Maison Connectée Minimale" (~630 MB)

```bash
# 1. Home Assistant (hub central)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homeassistant-stack/scripts/01-homeassistant-deploy.sh | sudo bash

# 2. MQTT Broker (pour appareils IoT)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homeassistant-stack/scripts/03-mqtt-deploy.sh | sudo bash

# 3. Node-RED (automatisations visuelles)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homeassistant-stack/scripts/02-nodered-deploy.sh | sudo bash
```

**Temps total** : ~10 minutes

**Accès** :
- Home Assistant : `http://raspberrypi.local:8123`
- Node-RED : `http://raspberrypi.local:1880`
- MQTT : Port `1883`

---

## 🏠 Home Assistant

### Qu'est-ce que Home Assistant ?

**Home Assistant** est le hub domotique **#1 mondial** (open source) :
- ✅ **2000+ intégrations** : Philips Hue, Xiaomi, Sonoff, Google Home, Alexa, IKEA, etc.
- ✅ **Interface moderne** : Dashboard personnalisable (mobile + desktop)
- ✅ **Automatisations visuelles** : Si mouvement détecté → Allumer lumières
- ✅ **Notifications** : Push mobile, email, Discord, Telegram
- ✅ **Graphiques historiques** : Température, consommation énergie, etc.
- ✅ **Commande vocale** : Compatible Google Assistant, Alexa, Siri
- ✅ **100% local** : Fonctionne sans Internet (privacy)

### Installation

```bash
# Méthode 1 : Curl one-liner (recommandé)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homeassistant-stack/scripts/01-homeassistant-deploy.sh | sudo bash

# Méthode 2 : Git clone
cd ~/pi5-setup/pi5-homeassistant-stack/scripts
sudo ./01-homeassistant-deploy.sh
```

**Temps** : ~5 min | **RAM** : ~500 MB

### Premier Démarrage

1. Ouvrir `http://raspberrypi.local:8123`
2. Créer compte admin
3. Configurer localisation (France)
4. Découverte automatique appareils réseau

### Intégrations Populaires

**Ajouter intégrations** : Menu → Paramètres → Appareils et services → Ajouter intégration

| Catégorie | Intégrations |
|-----------|--------------|
| **Lumières** | Philips Hue, IKEA Tradfri, Yeelight, Lifx |
| **Capteurs** | Xiaomi Aqara, Sonoff, Shelly |
| **Caméras** | Surveillance IP (ONVIF, RTSP) |
| **Média** | Spotify, Chromecast, Plex, Kodi |
| **Assistants** | Google Home, Alexa |
| **Notifications** | Mobile App, Email, Discord, Telegram |
| **Météo** | OpenWeatherMap, Met.no |
| **IoT** | MQTT, ESPHome, Tasmota |

### Exemple Automatisation

```yaml
alias: Allumer lumières au coucher soleil
trigger:
  - platform: sun
    event: sunset
    offset: "-00:30:00"  # 30 min avant
action:
  - service: light.turn_on
    target:
      entity_id: light.salon
    data:
      brightness: 80
```

### Accès HTTPS (via Traefik)

Si Traefik installé (Phase 2), Home Assistant est automatiquement accessible en HTTPS :

- **DuckDNS** : `https://monpi.duckdns.org/homeassistant`
- **Cloudflare** : `https://home.mondomaine.com`
- **VPN** : `https://home.pi.local`

---

## 🔀 Node-RED

### Qu'est-ce que Node-RED ?

**Node-RED** est un outil d'automatisation **visuel** (drag & drop) :
- ✅ **Interface drag & drop** : Pas besoin de coder
- ✅ **Complémentaire à Home Assistant** : Automatisations complexes
- ✅ **Intégrations** : MQTT, HTTP, Webhooks, Base de données, etc.

### Installation

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homeassistant-stack/scripts/02-nodered-deploy.sh | sudo bash
```

**Temps** : ~3 min | **RAM** : ~100 MB

### Utilisation

1. Ouvrir `http://raspberrypi.local:1880`
2. Glisser-déposer nœuds depuis palette gauche
3. Connecter nœuds (lignes)
4. Deploy (bouton rouge en haut)

### Modules Utiles

**Installer modules** : Menu → Manage palette → Install

- `node-red-contrib-home-assistant-websocket` : Intégration Home Assistant
- `node-red-dashboard` : Dashboard graphique
- `node-red-contrib-telegrambot` : Notifications Telegram

### Exemple Flux

```
[mqtt in] → [switch] → [http request] → [debug]
```

**Si température > 25°C → Envoyer notification Telegram**

---

## 📡 MQTT Broker (Mosquitto)

### Qu'est-ce que MQTT ?

**MQTT** est le protocole standard pour **IoT** (Internet of Things) :
- ✅ Communication entre appareils IoT (ESP32, Sonoff, Tasmota)
- ✅ Léger et rapide
- ✅ Publier/Souscrire (pub/sub)

### Installation

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homeassistant-stack/scripts/03-mqtt-deploy.sh | sudo bash
```

**Temps** : ~2 min | **RAM** : ~30 MB

### Tester MQTT

```bash
# Installer clients MQTT
sudo apt-get install -y mosquitto-clients

# Publier message
mosquitto_pub -h localhost -t "test/topic" -m "Hello MQTT"

# Souscrire à topic
mosquitto_sub -h localhost -t "test/topic"
```

### Intégration Home Assistant

1. Menu → Paramètres → Intégrations → MQTT
2. Serveur : `mosquitto` (ou `raspberrypi.local`)
3. Port : `1883`
4. User/Password : (laisser vide si allow_anonymous)

---

## 📶 Zigbee2MQTT (Optionnel)

### Qu'est-ce que Zigbee2MQTT ?

**Zigbee2MQTT** permet de contrôler des appareils **Zigbee** (sans hub propriétaire) :
- ✅ **Philips Hue** : Ampoules, interrupteurs (sans Hue Bridge !)
- ✅ **IKEA Tradfri** : Ampoules, télécommandes
- ✅ **Xiaomi Aqara** : Capteurs température, mouvement, portes
- ✅ **Sonoff** : Relais, capteurs Zigbee
- ✅ **2000+ appareils** : [Liste complète](https://www.zigbee2mqtt.io/supported-devices/)

### Prérequis

**Matériel requis** : **Dongle Zigbee USB** (~15-25€)

**Dongles recommandés** :
- [Sonoff Zigbee 3.0 USB Dongle Plus](https://itead.cc/product/sonoff-zigbee-3-0-usb-dongle-plus/) (~20€) - **Recommandé**
- [CC2531 Sniffer](https://www.amazon.fr/dp/B07TF6KDL2) (~15€)
- ConBee II (~40€)

### Installation

```bash
# Brancher le dongle Zigbee USB sur le Raspberry Pi

# Installer MQTT d'abord (si pas déjà fait)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homeassistant-stack/scripts/03-mqtt-deploy.sh | sudo bash

# Installer Zigbee2MQTT
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homeassistant-stack/scripts/04-zigbee2mqtt-deploy.sh | sudo bash
```

**Temps** : ~10 min | **RAM** : ~80 MB

### Appairer Appareils

1. Ouvrir `http://raspberrypi.local:8081`
2. Cliquer "Permit join" (mode appairage)
3. Appuyer sur bouton reset de l'appareil Zigbee
4. Appareil apparaît dans la liste

### Intégration Home Assistant

**Automatique via MQTT Discovery** :
- Les appareils appariés apparaissent automatiquement dans Home Assistant
- Menu → Paramètres → Appareils pour les voir

---

## 📊 Comparaison Applications

| Application | Utilité | RAM | Matériel | Difficulté |
|-------------|---------|-----|----------|------------|
| **Home Assistant** | Hub central | 500 MB | Aucun | ⭐⭐⭐ |
| **Node-RED** | Automatisations | 100 MB | Aucun | ⭐⭐ |
| **Mosquitto** | MQTT Broker | 30 MB | Aucun | ⭐ |
| **Zigbee2MQTT** | Passerelle Zigbee | 80 MB | Dongle Zigbee | ⭐⭐⭐ |

**Total RAM** (toutes apps) : ~710 MB

---

## 🎯 Configurations Recommandées

### Configuration "Débutant" (~500 MB)

```bash
# Home Assistant seulement
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homeassistant-stack/scripts/01-homeassistant-deploy.sh | sudo bash
```

**Suffisant pour** : Contrôler lumières, capteurs, caméras via intégrations natives

### Configuration "Standard" (~630 MB)

```bash
# Home Assistant + MQTT + Node-RED
./01-homeassistant-deploy.sh
./03-mqtt-deploy.sh
./02-nodered-deploy.sh
```

**Suffisant pour** : Tout ci-dessus + appareils IoT (ESP32, Tasmota) + automatisations complexes

### Configuration "Complète" (~710 MB)

```bash
# Tout + Zigbee
./01-homeassistant-deploy.sh
./03-mqtt-deploy.sh
./02-nodered-deploy.sh
./04-zigbee2mqtt-deploy.sh  # Nécessite dongle Zigbee
```

**Suffisant pour** : Maison connectée complète avec appareils Zigbee

---

## 🔧 Gestion RAM avec Stack Manager

### Voir Consommation

```bash
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh status
```

### Arrêter Stacks Domotique

```bash
# Libérer ~710 MB
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop homeassistant
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop nodered
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop mqtt
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop zigbee2mqtt
```

### Configuration Boot

```bash
# Activer démarrage auto Home Assistant
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh enable homeassistant

# Désactiver autres (démarrage manuel quand nécessaire)
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh disable nodered
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh disable zigbee2mqtt
```

---

## 🛠️ Maintenance

### Logs

```bash
# Home Assistant
docker logs homeassistant -f

# Node-RED
docker logs nodered -f

# MQTT
docker logs mosquitto -f
tail -f /home/pi/stacks/mqtt/log/mosquitto.log

# Zigbee2MQTT
docker logs zigbee2mqtt -f
```

### Redémarrer

```bash
docker restart homeassistant
docker restart nodered
docker restart mosquitto
docker restart zigbee2mqtt
```

### Mise à Jour

```bash
cd /home/pi/stacks/homeassistant
docker compose pull
docker compose up -d
```

---

## 📚 Documentation

### Officielle
- [Home Assistant Docs](https://www.home-assistant.io/docs/)
- [Node-RED Docs](https://nodered.org/docs/)
- [Mosquitto Docs](https://mosquitto.org/documentation/)
- [Zigbee2MQTT Docs](https://www.zigbee2mqtt.io/)

### Communautés
- [r/homeassistant](https://reddit.com/r/homeassistant)
- [r/nodered](https://reddit.com/r/nodered)
- [Forum Home Assistant FR](https://forum.hacf.fr/)

### Matériel Recommandé
- **Dongle Zigbee** : [Sonoff Dongle Plus](https://itead.cc/product/sonoff-zigbee-3-0-usb-dongle-plus/) (~20€)
- **Ampoules** : Philips Hue, IKEA Tradfri, Yeelight (~10-30€)
- **Capteurs** : Xiaomi Aqara (température, mouvement, porte) (~10-20€)
- **ESP32** : [Amazon](https://www.amazon.fr/s?k=esp32) (~5-10€) pour DIY

---

## ✅ Checklist

- [ ] Home Assistant installé et accessible
- [ ] Compte admin créé
- [ ] Localisation configurée (France)
- [ ] Première intégration ajoutée (Météo, MQTT, etc.)
- [ ] Première automatisation créée
- [ ] MQTT Broker installé (si appareils IoT)
- [ ] Node-RED installé (si automatisations complexes)
- [ ] Dongle Zigbee configuré (si appareils Zigbee)
- [ ] Widgets Homepage ajoutés
- [ ] Démarrage auto configuré avec Stack Manager

---

**Votre Raspberry Pi 5 est maintenant un hub domotique complet ! 🏠🎉**

**Question ?** Consultez la [documentation Home Assistant](https://www.home-assistant.io/docs/) ou ouvrez une [issue GitHub](https://github.com/iamaketechnology/pi5-setup/issues).
