#!/usr/bin/env bash
#
# Whisper + Piper Voice Assistant - Phase 23
# Speech-to-Text + Text-to-Speech pour Home Assistant
#
# Pré-requis : Phase 10 - Home Assistant installé
#
# Sources :
# - Wyoming Protocol : https://github.com/rhasspy/wyoming
# - Whisper : https://github.com/rhasspy/wyoming-faster-whisper
# - Piper : https://github.com/rhasspy/piper
#
# Ce script est IDEMPOTENT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
source "${PROJECT_ROOT}/common-scripts/lib.sh"

HA_STACK_DIR="${HOME}/stacks/homeassistant"

check_homeassistant() {
    if [[ ! -d "${HA_STACK_DIR}" ]]; then
        log_error "Home Assistant non installé !"
        log_warn "Installer d'abord Phase 10 : Home Assistant"
        exit 1
    fi

    if ! docker ps | grep -q "homeassistant"; then
        log_error "Home Assistant non démarré"
        log_warn "Démarrer : cd ${HA_STACK_DIR} && docker-compose up -d"
        exit 1
    fi

    log_success "Home Assistant détecté ✓"
}

add_voice_services() {
    local compose_file="${HA_STACK_DIR}/docker-compose.yml"

    # Vérifier si déjà présent
    if grep -q "whisper:" "${compose_file}"; then
        log_info "Services voice déjà configurés"
        return
    fi

    log_info "Ajout services Whisper + Piper..."

    # Backup
    cp "${compose_file}" "${compose_file}.backup-voice"

    # Ajouter services
    cat >> "${compose_file}" <<'EOF'

  whisper:
    image: rhasspy/wyoming-faster-whisper:latest
    container_name: ha-whisper
    restart: unless-stopped
    volumes:
      - ./whisper-data:/data
    ports:
      - "10300:10300"
    command: --model tiny --language fr
    environment:
      - TZ=Europe/Paris

  piper:
    image: rhasspy/wyoming-piper:latest
    container_name: ha-piper
    restart: unless-stopped
    volumes:
      - ./piper-data:/data
    ports:
      - "10200:10200"
    command: --voice fr_FR-siwis-medium
    environment:
      - TZ=Europe/Paris
EOF

    log_success "Services ajoutés au docker-compose.yml"
}

restart_services() {
    log_info "Redémarrage stack Home Assistant..."
    cd "${HA_STACK_DIR}"
    docker-compose up -d

    sleep 20
    log_success "Services démarrés !"
}

create_integration_guide() {
    cat > "${HA_STACK_DIR}/VOICE-ASSISTANT-SETUP.md" <<'EOF'
# 🎤 Configuration Voice Assistant

## Services Installés

✅ **Whisper** (Speech-to-Text) - Port 10300
✅ **Piper** (Text-to-Speech) - Port 10200

---

## 🔧 Configuration Home Assistant

### 1. Ajouter Intégrations

1. Ouvrir Home Assistant : http://raspberrypi.local:8123
2. **Settings** → **Devices & Services**
3. Cliquer **Add Integration**

#### Ajouter Whisper
- Rechercher "Wyoming Protocol"
- Host : `whisper`
- Port : `10300`
- Nom : "Whisper STT"

#### Ajouter Piper
- Rechercher "Wyoming Protocol"
- Host : `piper`
- Port : `10200`
- Nom : "Piper TTS"

---

### 2. Créer Assistant Vocal

1. **Settings** → **Voice Assistants**
2. Cliquer **Add Assistant**
3. Nom : "Assistant Maison"
4. **Conversation agent** : Home Assistant
5. **Speech-to-text** : Whisper STT
6. **Text-to-speech** : Piper TTS
7. Langue : Français
8. **Enregistrer**

---

### 3. Tester

#### Via Interface
1. Cliquer icône micro (en haut à droite)
2. Parler : "Allume le salon"
3. Home Assistant devrait répondre vocalement

#### Via Automation
```yaml
automation:
  - alias: "Test Voice"
    trigger:
      - platform: state
        entity_id: binary_sensor.motion_salon
        to: 'on'
    action:
      - service: tts.speak
        data:
          entity_id: media_player.salon
          message: "Mouvement détecté dans le salon"
```

---

## 🎛️ Modèles Disponibles

### Whisper (STT)
- `tiny` ⭐ - Rapide (~8s sur Pi 5), FR correct
- `base` - Plus précis, plus lent (~15s)
- `small` - Meilleur FR, très lent Pi 5

### Piper (TTS)
- `fr_FR-siwis-medium` ⭐ - Voix féminine naturelle
- `fr_FR-upmc-medium` - Voix masculine
- `fr_FR-siwis-low` - Plus rapide, qualité moindre

**Changer modèle** :
Éditer `docker-compose.yml` → section `command`

---

## 📊 Performance Pi 5

| Service | Modèle | Temps | RAM |
|---------|--------|-------|-----|
| Whisper | tiny | ~8s | ~200MB |
| Whisper | base | ~15s | ~400MB |
| Piper | medium | ~1.6s/sec | ~100MB |

---

## 🔊 ESPHome Satellite (Optionnel)

Pour micro/haut-parleur physique :

1. Acheter ESP32-S3 (~10€)
2. Flasher ESPHome avec config voice
3. Connecter à Home Assistant
4. Assistant vocal physique !

Guide : https://www.home-assistant.io/voice_control/thirteen-usd-voice-remote/

---

## ⚠️ Troubleshooting

### Whisper lent
- Utiliser modèle `tiny` au lieu de `base`
- Considérer Speech-to-Phrase (alternative plus rapide)

### Piper ne parle pas
- Vérifier media_player configuré
- Tester TTS manuellement dans Developer Tools

### Intégration non détectée
- Vérifier ports : `docker ps | grep whisper`
- Logs : `docker logs ha-whisper`

---

## 📚 Ressources

- HA Voice : https://www.home-assistant.io/voice_control/
- Wyoming Protocol : https://github.com/rhasspy/wyoming
- Whisper Models : https://github.com/openai/whisper
- Piper Voices : https://rhasspy.github.io/piper-samples/
EOF

    log_success "Guide créé : ${HA_STACK_DIR}/VOICE-ASSISTANT-SETUP.md"
}

main() {
    print_header "Whisper + Piper - Voice Assistant"

    log_info "Installation Phase 23 - Voice Assistant..."
    echo ""

    check_homeassistant
    add_voice_services
    restart_services
    create_integration_guide

    echo ""
    print_section "Voice Assistant Installé !"
    echo ""
    echo "🎤 Services actifs :"
    echo "   - Whisper (STT) : port 10300"
    echo "   - Piper (TTS)   : port 10200"
    echo ""
    echo "📋 Configuration Home Assistant :"
    echo "   cat ${HA_STACK_DIR}/VOICE-ASSISTANT-SETUP.md"
    echo ""
    echo "🔧 Prochaines étapes :"
    echo "   1. Ouvrir Home Assistant"
    echo "   2. Ajouter intégrations Wyoming Protocol"
    echo "   3. Créer Assistant Vocal"
    echo "   4. Tester avec icône micro !"
    echo ""
    echo "📊 RAM : ~300 MB"
    echo ""

    log_success "Installation terminée !"
}

main "$@"
