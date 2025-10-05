# ⚙️ Installation - Home Assistant

> **Objectif** : Déployer Home Assistant sur Docker pour prendre le contrôle de sa maison connectée.

---

## 📋 Prérequis

- **Docker et Docker Compose** installés.
- **Matériel spécifique (optionnel mais recommandé)** : Une clé USB Zigbee (comme la ConBee II ou Sonoff) ou Z-Wave pour communiquer avec des appareils qui n'utilisent pas le Wi-Fi.

---

## 🚀 Installation avec Docker Compose

C'est la méthode recommandée pour une installation flexible sur un serveur où d'autres services tournent déjà.

### 1. Docker Compose

Créez un fichier `docker-compose.yml` avec le contenu suivant :

```yaml
# [Contenu à compléter : service docker-compose pour Home Assistant]
version: '3'
services:
  homeassistant:
    container_name: homeassistant
    image: "ghcr.io/home-assistant/home-assistant:stable"
    volumes:
      - ./data:/config
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped
    privileged: true # Nécessaire pour certaines intégrations, notamment Z-Wave/Zigbee
    network_mode: host # La méthode la plus simple pour la découverte réseau
```

### Notes importantes sur la configuration :

- **`network_mode: host`** : C'est la configuration la plus simple car elle permet à Home Assistant de voir tous les appareils sur votre réseau local sans configuration complexe. Le conteneur partagera l'IP de votre machine hôte.
- **`privileged: true`** : Donne des permissions étendues au conteneur. C'est souvent nécessaire pour qu'il puisse accéder directement au matériel, comme les clés USB (Zigbee, Z-Wave, Bluetooth).
- **Volume `./data:/config`** : C'est ici que toute votre configuration, vos automatisations et vos données seront stockées. **Sauvegardez ce dossier régulièrement !**

### 2. Lancement

```bash
docker-compose up -d
```

Home Assistant va démarrer. Le premier démarrage peut prendre plusieurs minutes car il doit s'initialiser.

---

## ✅ Configuration Initiale

1. **Accédez à l'interface web** : Ouvrez votre navigateur et allez sur `http://<IP_de_votre_serveur>:8123`.

2. **Créez un compte propriétaire** : La première étape est de créer le compte principal. Ce compte aura tous les droits sur l'instance.

3. **Nommez votre maison** : Donnez un nom à votre maison et définissez son emplacement. L'emplacement est important pour les automatisations basées sur le lever/coucher du soleil et la météo.

4. **Découverte** : Home Assistant vous montrera ensuite tous les appareils qu'il a automatiquement découverts sur votre réseau. Vous pouvez les configurer immédiatement ou le faire plus tard.

---

## 🔌 Passer une clé USB (Zigbee/Z-Wave) au conteneur

Si vous n'utilisez pas `network_mode: host` ou `privileged: true`, vous devrez passer manuellement le périphérique USB.

1. **Trouvez le chemin de la clé USB** :
   ```bash
   ls -l /dev/serial/by-id/
   ```
   Cela vous donnera un chemin stable, par exemple `/dev/serial/by-id/usb-dresden_elektronik_ingenieurtechnik_GmbH_ConBee_II_DE123456-if00`.

2. **Modifiez votre `docker-compose.yml`** pour ajouter la section `devices` :

   ```yaml
   services:
     homeassistant:
       # ... autres configurations
       devices:
         - /dev/serial/by-id/VOTRE_CLE_USB:/dev/ttyACM0
   ```

---

## 🆘 Troubleshooting

- **Impossible d'accéder à l'interface web** : Assurez-vous que le conteneur est bien démarré (`docker ps`). Si vous n'utilisez pas `network_mode: host`, vérifiez que vous avez bien mappé le port (`ports: - "8123:8123"`).
- **Appareils non découverts** : La découverte automatique (zeroconf, mDNS) peut être bloquée si le conteneur n'est pas sur le réseau `host`. C'est la raison pour laquelle ce mode est recommandé pour débuter.
- **Clé Zigbee/Z-Wave non reconnue** : Vérifiez que le chemin du périphérique est correct et que le conteneur a les permissions nécessaires (`privileged` ou le bon groupe d'utilisateurs).

[Contenu à compléter avec d'autres problèmes courants]
