# 🏠 Domotique & Maison Connectée

> **Catégorie** : Hub domotique et automation IoT

---

## 📦 Stacks Inclus

### 1. [Home Assistant Stack Complet](homeassistant/)

#### 🏠 Home Assistant
**Hub Domotique Central**

- 🔌 **2000+ intégrations** : Philips Hue, Xiaomi, Sonoff, Google Home, Alexa, IKEA, etc.
- 🎨 **Interface moderne** : Dashboard personnalisable (mobile + desktop)
- 🤖 **Automatisations** : Si mouvement détecté → Allumer lumières
- 📱 **Notifications** : Push mobile, email, Discord, Telegram
- 🎤 **Commande vocale** : "Ok Google, allume le salon"
- 🔐 **100% local** : Fonctionne sans Internet (privacy)

**RAM** : ~300 MB
**Port** : 8123

---

#### 🔀 Node-RED
**Automatisations Visuelles (Drag & Drop)**

- 🎨 Interface drag & drop (pas de code)
- 🔄 Automatisations complexes : Si temp > 25°C → Envoyer notification
- 🔌 Complémentaire Home Assistant
- 📡 MQTT, HTTP, WebSocket, etc.

**RAM** : ~100 MB
**Port** : 1880

---

#### 📡 Mosquitto (MQTT Broker)
**Communication IoT**

- 💬 Protocol pub/sub pour IoT
- 🔌 ESP32, Sonoff, Tasmota, ESPHome
- ⚡ Léger (~30 MB RAM)
- 🌐 WebSocket support

**RAM** : ~30 MB
**Ports** : 1883 (MQTT), 9001 (WebSocket)

---

#### 📶 Zigbee2MQTT (Optionnel)
**Contrôle Zigbee Sans Hub Propriétaire**

- 🔓 **Philips Hue** sans Hue Bridge (~80€ économisés)
- 🏠 **IKEA Tradfri** sans passerelle IKEA (~30€ économisés)
- 🏡 **Xiaomi Aqara** sans hub Xiaomi (~50€ économisés)
- 🔌 **2000+ appareils Zigbee** compatibles

**Matériel requis** : Dongle USB Zigbee (~20€)
**RAM** : ~80 MB
**Port** : 8080

**Total économies matériel** : ~160€ ! 💰

---

## 🚀 Installation

**Installation minimale (Home Assistant + MQTT)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/01-homeassistant-deploy.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/03-mqtt-deploy.sh | sudo bash
```

**Installation standard (+ Node-RED)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/02-nodered-deploy.sh | sudo bash
```

**Installation complète (+ Zigbee2MQTT)** :
```bash
# Requis : Dongle USB Zigbee branché
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/04-zigbee2mqtt-deploy.sh | sudo bash
```

---

## 📊 Configurations Recommandées

| Configuration | Apps | RAM | Cas d'usage |
|---------------|------|-----|-------------|
| **Minimale** | HA + MQTT | ~330 MB | Débuter avec quelques appareils Wi-Fi |
| **Standard** | HA + MQTT + Node-RED | ~430 MB | Automatisations avancées |
| **Complète** | HA + MQTT + Node-RED + Zigbee | ~510 MB | Maison complètement automatisée |

---

## 🎯 Exemples Automatisations

### Automation 1 : Détection mouvement
```yaml
# Home Assistant
automation:
  - trigger:
      platform: state
      entity_id: binary_sensor.motion_salon
      to: 'on'
    action:
      service: light.turn_on
      target:
        entity_id: light.salon
```

### Automation 2 : Température élevée
```javascript
// Node-RED
if (msg.payload.temperature > 25) {
  msg.payload = "Température élevée !";
  return msg; // Envoyer notification
}
```

---

## 📊 Statistiques Catégorie

| Métrique | Valeur |
|----------|--------|
| **Nombre de stacks** | 1 (4 composants) |
| **RAM totale** | ~510 MB (config complète) |
| **Complexité** | ⭐⭐⭐ (Avancée) |
| **Priorité** | 🟢 **OPTIONNEL** (domotique) |
| **Ordre installation** | Phase 10 |
| **Économies matériel** | ~160€ (vs hubs propriétaires) |
| **Économies cloud** | ~60€/an (vs Home Assistant Cloud) |

---

## 🔌 Appareils Compatibles

### Wi-Fi (Aucun hub requis)
- Sonoff (relais, ampoules)
- Shelly (interrupteurs muraux)
- Tuya/Smart Life
- TP-Link Kasa

### Zigbee (Avec Zigbee2MQTT)
- Philips Hue (ampoules, strips)
- IKEA Tradfri (ampoules, télécommandes)
- Xiaomi Aqara (capteurs, interrupteurs)
- Sonoff Zigbee

### Z-Wave (Avec Z-Wave USB dongle)
- Fibaro
- Aeotec
- Qubino

---

## 💡 Notes

- **Home Assistant** remplace Google Home / Alexa en mode privacy
- **MQTT** est le standard IoT (ESP32, Tasmota, ESPHome)
- **Zigbee2MQTT** évite les hubs propriétaires (économies + flexibilité)
- Fonctionne 100% local (pas d'Internet requis)
- Compatible Alexa/Google Home si vous voulez garder commande vocale
