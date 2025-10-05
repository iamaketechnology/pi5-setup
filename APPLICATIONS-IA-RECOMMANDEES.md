# 🤖 Applications IA Recommandées pour Raspberry Pi 5

> **Recherche effectuée** : Janvier 2025
> **Cible** : Raspberry Pi 5 (16GB RAM) ARM64

---

## 🎯 Top Applications IA Compatibles

### 🔴 PRIORITÉ HAUTE (Production Ready 2025)

#### 1. **Ollama + Open WebUI** - LLM Local
**Catégorie** : LLM Self-Hosted
**Priorité** : 🔴 HAUTE
**RAM** : ~2-4 GB (selon modèle)
**Difficulté** : ⭐⭐ (Modérée)

**Pourquoi** :
- ✅ **100% ARM64 compatible** (natif Raspberry Pi 5)
- ✅ **Interface Web moderne** (type ChatGPT)
- ✅ **Modèles optimisés Pi** : TinyLlama, Phi-3, DeepSeek-Coder
- ✅ **Performance acceptable** : 3-5 tokens/sec sur Pi 5
- ✅ **Communauté active** 2025 (guides récents)

**Modèles recommandés Pi 5** :
- `tinyllama:1.1b` → Ultra-rapide, questions simples
- `phi3:3.8b` → Meilleur équilibre qualité/vitesse
- `deepseek-coder:1.3b` → Spécialisé code
- `qwen2.5-coder:3b` → Code + raisonnement

**Use cases** :
- Chat privé (alternative ChatGPT)
- Génération code
- Résumés documents
- Q&A sur docs locales

**Sources** :
- https://github.com/ollama/ollama
- https://github.com/open-webui/open-webui
- Tutoriels 2025 : pimylifeup.com, itsfoss.com

---

#### 2. **n8n** - Automatisation Workflows + IA
**Catégorie** : Automatisation No-Code
**Priorité** : 🔴 HAUTE
**RAM** : ~200 MB
**Difficulté** : ⭐⭐ (Modérée)

**Pourquoi** :
- ✅ **ARM64 natif** (Docker officiel)
- ✅ **500+ intégrations** (API, services, IA)
- ✅ **Workflows visuels** (drag & drop)
- ✅ **Intégration IA** : OpenAI, Anthropic, Ollama local
- ✅ **Guides Pi 5 officiels** 2025

**Use cases** :
- Automatiser avec IA (ex: OCR docs → résumé → email)
- Webhooks + IA (trigger → analyse → action)
- ETL data avec enrichissement IA
- Chatbots personnalisés

**Intégrations IA natives** :
- OpenAI (GPT-4, DALL-E)
- Anthropic (Claude)
- Ollama (local)
- Hugging Face
- Pinecone (vector DB)

**Sources** :
- https://n8n.io/
- https://github.com/n8n-io/n8n

---

#### 3. **Whisper + Piper** (Home Assistant)
**Catégorie** : Voice Assistant
**Priorité** : 🔴 HAUTE (si domotique)
**RAM** : ~300 MB
**Difficulté** : ⭐⭐⭐ (Avancée)

**Pourquoi** :
- ✅ **Speech-to-Text** : Whisper (OpenAI) optimisé Pi
- ✅ **Text-to-Speech** : Piper (voix naturelles)
- ✅ **100% local** (privacy)
- ✅ **Intégré Home Assistant** (Phase 10 déjà installée)
- ✅ **Performance Pi 5** : <1s reconnaissance (Speech-to-Phrase)

**Use cases** :
- Assistant vocal maison ("Allume salon")
- Contrôle vocal domotique
- Notifications vocales
- Transcription audio → texte

**Performance Pi 5** :
- Whisper (petit modèle) : ~8s
- Speech-to-Phrase : <1s ⭐
- Piper TTS : 1.6s audio/sec

**Sources** :
- https://www.home-assistant.io/voice_control/
- ESPHome 2025.5.0+ (support natif)

---

### 🟡 PRIORITÉ MOYENNE (Expérimental/Avancé)

#### 4. **LocalAI**
**Catégorie** : Alternative OpenAI Self-Hosted
**Priorité** : 🟡 Moyenne
**RAM** : ~1-3 GB
**Difficulté** : ⭐⭐⭐ (Avancée)

**Pourquoi** :
- ✅ **Drop-in OpenAI replacement** (API compatible)
- ✅ **Multi-modal** : Texte, Images, Audio
- ✅ **ARM64 support** (Docker arm64 disponible)
- ⚠️ **Performance variable** sur Pi 5
- ⚠️ **Moins optimisé qu'Ollama** pour Pi

**Avantages vs Ollama** :
- API OpenAI-compatible (code existant fonctionne)
- Support image generation (Stable Diffusion)
- Audio transcription

**Sources** :
- https://github.com/mudler/LocalAI

---

#### 5. **Tabby** (Code Completion)
**Catégorie** : AI Code Assistant
**Priorité** : 🟡 Moyenne
**RAM** : ~500 MB
**Difficulté** : ⭐⭐⭐ (Avancée)

**Pourquoi** :
- ✅ **Self-hosted Copilot** alternative
- ✅ **ARM64 Docker** disponible
- ✅ **VSCode extension**
- ⚠️ **Modèles légers requis** pour Pi

**Modèles compatibles Pi** :
- CodeGPT DeepSeek-Coder 1.3B
- StarCoder 1B/3B quantized

**Alternative** : Continue.dev + Ollama (plus flexible)

**Sources** :
- https://github.com/TabbyML/tabby
- https://www.tabbyml.com/

---

## 📊 Comparaison Applications IA

| Application | Type | RAM | Performance Pi 5 | Priorité | Complexité |
|-------------|------|-----|------------------|----------|------------|
| **Ollama + Open WebUI** | LLM Chat | 2-4 GB | ⭐⭐⭐⭐ Excellente | 🔴 HAUTE | ⭐⭐ |
| **n8n** | Automatisation | 200 MB | ⭐⭐⭐⭐⭐ Parfaite | 🔴 HAUTE | ⭐⭐ |
| **Whisper + Piper** | Voice | 300 MB | ⭐⭐⭐⭐ Bonne | 🔴 HAUTE | ⭐⭐⭐ |
| **LocalAI** | Multi-modal | 1-3 GB | ⭐⭐⭐ Moyenne | 🟡 Moyenne | ⭐⭐⭐ |
| **Tabby** | Code AI | 500 MB | ⭐⭐ Limitée | 🟡 Moyenne | ⭐⭐⭐ |

---

## 🎯 Recommandations par Use Case

### Use Case 1 : Développeur
**Stack recommandée** :
1. **Ollama** + `deepseek-coder:1.3b` (génération code)
2. **n8n** (automatisation CI/CD + IA)
3. **Continue.dev VSCode extension** → Ollama backend

**Workflow** :
- Continue.dev pour autocomplétion temps réel
- Ollama pour générer fonctions complexes
- n8n pour automatiser tests + déploiement

---

### Use Case 2 : Productivité Personnelle
**Stack recommandée** :
1. **Ollama** + `phi3:3.8b` (chat général)
2. **Open WebUI** (interface)
3. **n8n** (automatiser tâches répétitives)

**Exemples automatisations** :
- Email → Résumé IA → Notification
- Documents scannés → OCR → Classification IA
- Veille tech → Résumé quotidien

---

### Use Case 3 : Maison Connectée + Voice
**Stack recommandée** :
1. **Home Assistant** (Phase 10 déjà installée)
2. **Whisper + Piper** (voice assistant)
3. **n8n** (automatisations complexes)
4. **Ollama** (NLP pour commandes avancées)

**Workflow** :
- "Dis-moi la météo" → Whisper → HA → Piper
- Analyse pattern consommation → Ollama → suggestions
- Automatisations vocales intelligentes

---

## 🚀 Phases Proposées (21-25)

### Phase 21 - Ollama + Open WebUI (LLM)
**Dossier** : `11-intelligence-artificielle/ollama/`
**Priorité** : 🔴 HAUTE
**Installation** : ~10 min

**Composants** :
- Ollama (serveur LLM)
- Open WebUI (interface web)
- Modèles pré-téléchargés optimisés Pi

**Script inclura** :
- Détection RAM (8GB min requis)
- Téléchargement modèles recommandés
- Configuration optimisée ARM64
- Intégration Traefik + Homepage

---

### Phase 22 - n8n Workflows IA
**Dossier** : `11-intelligence-artificielle/n8n/`
**Priorité** : 🔴 HAUTE
**Installation** : ~5 min

**Composants** :
- n8n (workflow engine)
- PostgreSQL (DB workflows)
- Intégration Ollama (optionnel)

**Templates inclus** :
- Résumé emails quotidien
- OCR + classification documents
- Chatbot Telegram/Discord

---

### Phase 23 - Whisper + Piper (Voice)
**Dossier** : `07-domotique/homeassistant/voice/`
**Priorité** : 🟡 Moyenne
**Installation** : ~15 min

**Composants** :
- Whisper (STT)
- Piper (TTS)
- Wyoming Protocol
- Intégration Home Assistant

**Pré-requis** : Phase 10 (Home Assistant)

---

### Phase 24 - LocalAI (Optionnel)
**Dossier** : `11-intelligence-artificielle/localai/`
**Priorité** : 🟢 Basse
**Installation** : ~10 min

**Use case** : Alternative si API OpenAI-compatible requise

---

### Phase 25 - Tabby Code Assistant (Optionnel)
**Dossier** : `11-intelligence-artificielle/tabby/`
**Priorité** : 🟢 Basse
**Installation** : ~8 min

**Use case** : Code completion self-hosted (alternative Copilot)

---

## 💾 Estimation RAM Totale

**Stack IA Complète (Phases 21-23)** :
- Ollama + Open WebUI : ~3 GB (modèle phi3:3.8b chargé)
- n8n : ~200 MB
- Whisper + Piper : ~300 MB
- **Total** : ~3.5 GB

**Pi 5 16GB** :
- Phases 1-20 : ~5.5 GB
- Phases IA 21-23 : ~3.5 GB
- **Total** : ~9 GB / 16 GB (56%)
- **Marge restante** : ~7 GB ✅

---

## ⚠️ Notes Importantes

### Performance Pi 5 avec IA
1. **Modèles < 7B paramètres** recommandés
2. **Quantization Q4/Q5** (GGUF) pour vitesse
3. **SSD obligatoire** (non SD card) pour swapping
4. **Dissipateur thermique** conseillé (charge CPU élevée)
5. **Alimentation 5A** (27W) recommandée

### Alternatives Cloud (si Pi insuffisant)
- **Ollama remote** : Pi 5 → serveur dédié LLM
- **n8n cloud** : Version hosted (gratuit 5000 exec/mois)
- **Continue.dev** : API OpenAI/Anthropic

---

## 🔗 Ressources

**Documentation officielle** :
- Ollama : https://ollama.ai/
- Open WebUI : https://docs.openwebui.com/
- n8n : https://docs.n8n.io/
- Home Assistant Voice : https://www.home-assistant.io/voice_control/

**Guides Raspberry Pi 5 (2025)** :
- https://pimylifeup.com/raspberry-pi-ollama/
- https://wagnerstechtalk.com/pi5-llm/
- https://itsfoss.com/llms-for-raspberry-pi/

**Communautés** :
- r/LocalLLaMA (Reddit)
- r/selfhosted
- Home Assistant Forums

---

## ✅ Recommandation Finale

**Pour commencer (Phases essentielles)** :
1. ✅ **Phase 21 - Ollama + Open WebUI** (LLM local)
2. ✅ **Phase 22 - n8n** (automatisation IA)

**Si domotique installée (Phase 10)** :
3. ✅ **Phase 23 - Whisper + Piper** (voice assistant)

**Total investissement** :
- RAM : ~3.5 GB
- Temps installation : ~30 min
- Complexité : ⭐⭐ Modérée

🚀 **Prêt à transformer ton Pi 5 en serveur IA local !**
