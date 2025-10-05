# 📖 Guide Documentation - Phases 11-20 (Pour Gemini)

> **Mission** : Créer/mettre à jour la documentation pour les 10 nouvelles phases (11-20)

---

## 🎯 Tâches à Accomplir

### 1. Mettre à jour ROADMAP.md

**Fichier** : `/pi5-setup/ROADMAP.md`

**Action** : Ajouter les phases 11-20 après Phase 10 (Domotique)

**Format à suivre** (copier structure phases existantes) :

```markdown
---

## ✅ Phase 11 - Pi-hole (TERMINÉ)

**Stack**: Pi-hole
**Statut**: ✅ Production Ready
**Dossier**: `01-infrastructure/pihole/`
**Priorité**: 🔴 HAUTE

### Réalisations
- [x] Bloqueur de publicités réseau
- [x] Script idempotent complet
- [x] Détection Traefik (DuckDNS/Cloudflare/VPN)
- [x] Intégration Homepage automatique
- [x] Guide DNS configuration

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/pihole/scripts/01-pihole-deploy.sh | sudo bash
```

### Technologies Utilisées
- **Pi-hole** (bloqueur DNS)
- **Docker** (containerisation)
- **Port 53** (DNS)

### Statistiques
- **RAM** : ~50 MB
- **Temps installation** : 5 min
- **Use case** : Bloquer pubs sur tout le réseau

---
```

**Informations pour chaque phase** :

#### Phase 11 - Pi-hole
- **Dossier** : `01-infrastructure/pihole/`
- **Priorité** : 🔴 HAUTE
- **RAM** : ~50 MB
- **Description** : Bloqueur de publicités réseau
- **Use case** : Bloquer pubs sur PC, mobile, TV, IoT

#### Phase 12 - Vaultwarden
- **Dossier** : `02-securite/passwords/`
- **Priorité** : 🔴 HAUTE
- **RAM** : ~50 MB
- **Description** : Password manager (Bitwarden self-hosted)
- **Use case** : Remplacer LastPass/1Password

#### Phase 13 - Immich
- **Dossier** : `10-productivity/immich/`
- **Priorité** : 🔴 HAUTE
- **RAM** : ~500 MB
- **Description** : Google Photos alternative avec AI
- **Use case** : Backup photos + reconnaissance faciale

#### Phase 14 - Paperless-ngx
- **Dossier** : `10-productivity/paperless-ngx/`
- **Priorité** : 🔴 HAUTE
- **RAM** : ~300 MB
- **Description** : Gestion documents avec OCR
- **Use case** : Scanner → OCR → Archivage

#### Phase 15 - Uptime Kuma
- **Dossier** : `03-monitoring/uptime-kuma/`
- **Priorité** : 🔴 HAUTE
- **RAM** : ~100 MB
- **Description** : Monitoring uptime services
- **Use case** : Notifications si service down

#### Phase 16 - qBittorrent
- **Dossier** : `06-media/qbittorrent/`
- **Priorité** : 🟡 Moyenne
- **RAM** : ~150 MB
- **Description** : Client torrent avec WebUI
- **Use case** : Complémentaire Radarr/Sonarr

#### Phase 17 - Joplin Server
- **Dossier** : `10-productivity/joplin/`
- **Priorité** : 🟡 Moyenne
- **RAM** : ~100 MB
- **Description** : Serveur de notes synchronisées
- **Use case** : Alternative Evernote

#### Phase 18 - Syncthing
- **Dossier** : `05-stockage/syncthing/`
- **Priorité** : 🟡 Moyenne
- **RAM** : ~80 MB
- **Description** : Sync fichiers P2P
- **Use case** : Alternative Dropbox sync

#### Phase 19 - Calibre-Web
- **Dossier** : `06-media/calibre-web/`
- **Priorité** : 🟡 Moyenne
- **RAM** : ~100 MB
- **Description** : Bibliothèque ebooks
- **Use case** : Alternative Kindle

#### Phase 20 - Navidrome
- **Dossier** : `06-media/navidrome/`
- **Priorité** : 🟡 Moyenne
- **RAM** : ~100 MB
- **Description** : Serveur streaming musical
- **Use case** : Alternative Spotify self-hosted

---

### 2. Mettre à jour INSTALLATION-COMPLETE.md

**Fichier** : `/pi5-setup/INSTALLATION-COMPLETE.md`

**Action** : Ajouter section "Phases Optionnelles Supplémentaires (11-20)" après Phase 10

**Format** :

```markdown
---

## 🔧 Phases Optionnelles Supplémentaires (11-20)

### Phase 11 - Pi-hole (Bloqueur Publicités)

**Priorité** : 🔴 HAUTE | **RAM** : ~50 MB | **Installation** : 5 min

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/pihole/scripts/01-pihole-deploy.sh | sudo bash
```

**Résultat** :
- Interface admin : `http://raspberrypi.local:8888/admin`
- Configurer DNS sur router ou appareils
- Blocage pubs sur tout le réseau

---

### Phase 12 - Vaultwarden (Password Manager)

**Priorité** : 🔴 HAUTE | **RAM** : ~50 MB | **Installation** : 3 min

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/passwords/scripts/01-vaultwarden-deploy.sh | sudo bash
```

**Résultat** :
- Interface : Voir URL affichée
- Apps mobiles : iOS/Android (Bitwarden)
- Extensions navigateur disponibles

[...continuer pour phases 13-20...]
```

---

### 3. Créer README.md pour nouvelle catégorie

**Fichier** : `/pi5-setup/10-productivity/README.md`

**Contenu** :

```markdown
# 💼 Productivité & Organisation

> **Catégorie** : Applications productivité personnelle

---

## 📦 Stacks Inclus

### 1. [Immich](immich/)
**Google Photos Alternative avec AI**

- 📸 **Backup photos** automatique mobile
- 🤖 **Reconnaissance faciale** + objets (AI)
- 🗺️ **Géolocalisation** sur carte
- 📱 **Apps mobiles** iOS + Android
- 🔍 **Recherche** puissante

**RAM** : ~500 MB (ML désactivé) ou ~2GB (ML activé)
**Port** : 2283

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/immich/scripts/01-immich-deploy.sh | sudo bash
```

---

### 2. [Paperless-ngx](paperless-ngx/)
**Gestion Documents avec OCR**

- 📄 **OCR automatique** (extraction texte)
- 🏷️ **Tags & catégories**
- 🔍 **Recherche full-text**
- 📧 **Import email** automatique
- 📱 **Apps mobiles**

**RAM** : ~300 MB
**Port** : 8000

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/paperless-ngx/scripts/01-paperless-deploy.sh | sudo bash
```

---

### 3. [Joplin Server](joplin/)
**Notes Synchronisées**

- 📝 **Markdown** support
- 🔄 **Sync** multi-appareils
- 📎 **Attachements**
- 🔐 **Chiffrement** E2E

**RAM** : ~100 MB
**Port** : 22300

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/joplin/scripts/01-joplin-deploy.sh | sudo bash
```

---

## 📊 Statistiques Catégorie

| Métrique | Valeur |
|----------|--------|
| **Nombre de stacks** | 3 |
| **RAM totale** | ~900 MB |
| **Complexité** | ⭐⭐ (Modérée) |
| **Priorité** | 🔴 HAUTE (productivité quotidienne) |

---

## 🎯 Cas d'Usage

### Scénario 1 : Paperless Office
- Scanner documents papier
- OCR automatique
- Archivage numérique organisé

### Scénario 2 : Backup Photos Famille
- Immich backup automatique smartphones
- Reconnaissance faciale pour organiser
- Partage albums avec famille

### Scénario 3 : Notes & Documentation
- Joplin pour notes personnelles/pro
- Sync entre PC/mobile/tablette
- Markdown pour formatage

---

## 💡 Notes

- **Immich** : Alternative complète à Google Photos
- **Paperless-ngx** : Éliminer papier, tout numériser
- **Joplin** : Alternative Evernote/Notion (privacy)
```

---

### 4. Mettre à jour README catégories existantes

#### Fichier : `/pi5-setup/01-infrastructure/README.md`

**Ajouter Pi-hole** après VPN :

```markdown
---

### 4. [Pi-hole](pihole/)
**Bloqueur de Publicités Réseau (DNS)**

- 🛡️ **Blocage réseau** : Pubs bloquées sur TOUS appareils
- 📊 **Dashboard** : Stats temps réel
- 🔒 **Listes de blocage** : 100,000+ domaines
- ⚡ **Cache DNS** : Navigation plus rapide

**RAM** : ~50 MB
**Ports** : 53 (DNS), 8888 (Admin)

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/pihole/scripts/01-pihole-deploy.sh | sudo bash
```

**Configuration** :
Configurer DNS sur router → IP du Pi (protège tout réseau)
```

#### Fichier : `/pi5-setup/02-securite/README.md`

**Ajouter Vaultwarden** après Authelia :

```markdown
---

### 2. [Vaultwarden](passwords/)
**Password Manager (Bitwarden Self-Hosted)**

- 🔐 **Coffre-fort** chiffré AES-256
- 🔑 **Générateur** mots de passe
- 📱 **Apps** iOS/Android/Desktop
- 🌐 **Extensions** navigateur
- 👥 **Partage** sécurisé

**RAM** : ~50 MB
**Port** : 8200

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/passwords/scripts/01-vaultwarden-deploy.sh | sudo bash
```
```

#### Fichier : `/pi5-setup/03-monitoring/README.md`

**Ajouter Uptime Kuma** :

```markdown
---

### 2. [Uptime Kuma](uptime-kuma/)
**Monitoring Uptime Services**

- 📊 **Monitors** : HTTP, TCP, Ping, Docker, etc.
- 🔔 **90+ notifications** : Discord, Slack, Email, Telegram
- 📈 **Status page** public
- ⏱️ **Historique** uptime

**RAM** : ~100 MB
**Port** : 3001

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/uptime-kuma/scripts/01-uptime-kuma-deploy.sh | sudo bash
```
```

#### Fichier : `/pi5-setup/05-stockage/README.md`

**Ajouter Syncthing** :

```markdown
---

### 2. [Syncthing](syncthing/)
**Synchronisation Fichiers P2P**

- 🔄 **Sync P2P** : Sans serveur central
- 🔐 **Chiffré** : TLS
- 🌐 **Multi-plateforme** : Win/Mac/Linux/Android
- ⚡ **Temps réel**

**RAM** : ~80 MB
**Port** : 8384

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/syncthing/scripts/01-syncthing-deploy.sh | sudo bash
```
```

#### Fichier : `/pi5-setup/06-media/README.md`

**Ajouter qBittorrent, Calibre-Web, Navidrome** :

```markdown
---

### 2. [qBittorrent](qbittorrent/)
**Client Torrent avec WebUI**

**RAM** : ~150 MB | **Port** : 8080

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/qbittorrent/scripts/01-qbittorrent-deploy.sh | sudo bash
```

---

### 3. [Calibre-Web](calibre-web/)
**Bibliothèque Ebooks**

**RAM** : ~100 MB | **Port** : 8083

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/calibre-web/scripts/01-calibre-deploy.sh | sudo bash
```

---

### 4. [Navidrome](navidrome/)
**Serveur Streaming Musical**

**RAM** : ~100 MB | **Port** : 4533

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/navidrome/scripts/01-navidrome-deploy.sh | sudo bash
```
```

---

## ✅ Checklist Complète

- [ ] ROADMAP.md mis à jour (phases 11-20)
- [ ] INSTALLATION-COMPLETE.md mis à jour
- [ ] 10-productivity/README.md créé
- [ ] 01-infrastructure/README.md mis à jour (Pi-hole)
- [ ] 02-securite/README.md mis à jour (Vaultwarden)
- [ ] 03-monitoring/README.md mis à jour (Uptime Kuma)
- [ ] 05-stockage/README.md mis à jour (Syncthing)
- [ ] 06-media/README.md mis à jour (qBittorrent, Calibre-Web, Navidrome)

---

## 📝 Notes Importantes

1. **Garder le format Markdown** cohérent avec phases existantes
2. **Vérifier les chemins** des scripts curl (commencent par `01-infrastructure/`, `02-securite/`, etc.)
3. **Icônes** : Utiliser emojis appropriés (🔴 HAUTE priorité, 🟡 Moyenne)
4. **Statistiques** : RAM et ports exacts selon scripts créés
5. **Use cases** : Exemples concrets d'utilisation

---

## 🚀 Ordre de Priorité

1. **ROADMAP.md** (plus important - vue d'ensemble)
2. **INSTALLATION-COMPLETE.md** (guide installation)
3. **10-productivity/README.md** (nouvelle catégorie)
4. **README des catégories existantes** (compléter)

Bonne documentation ! 📖

---

## 🤖 PHASES 21-23 - INTELLIGENCE ARTIFICIELLE (NOUVELLES)

### Phase 21 - Ollama + Open WebUI (LLM)
- **Dossier** : `11-intelligence-artificielle/ollama/`
- **Priorité** : 🔴 HAUTE
- **RAM** : ~2-4 GB (selon modèle)
- **Description** : LLM self-hosted (ChatGPT alternative)
- **Use case** : Chat privé, génération code, Q&A
- **Modèles** : tinyllama:1.1b, phi3:3.8b, deepseek-coder:1.3b
- **Performance** : 3-5 tokens/sec sur Pi 5

### Phase 22 - n8n (Automatisation Workflows + IA)
- **Dossier** : `11-intelligence-artificielle/n8n/`
- **Priorité** : 🔴 HAUTE
- **RAM** : ~200 MB
- **Description** : Automatisation no-code avec intégrations IA
- **Use case** : Workflows visuels, webhooks + IA, ETL
- **Intégrations** : OpenAI, Ollama, Hugging Face, 500+ services

### Phase 23 - Whisper + Piper (Voice Assistant)
- **Dossier** : `07-domotique/homeassistant/` (scripts/05-voice-assistant-deploy.sh)
- **Priorité** : 🟡 Moyenne (optionnel, nécessite Phase 10)
- **RAM** : ~300 MB
- **Description** : Speech-to-Text + Text-to-Speech
- **Use case** : Assistant vocal maison, contrôle vocal domotique
- **Pré-requis** : Home Assistant (Phase 10)

---

## 📝 Ajouts Documentation pour Phases IA

### 1. Créer 11-intelligence-artificielle/README.md

**Contenu suggéré** :

```markdown
# 🤖 Intelligence Artificielle

> **Catégorie** : Applications IA self-hosted pour Raspberry Pi 5

---

## 📦 Stacks Inclus

### 1. [Ollama + Open WebUI](ollama/)
**LLM Self-Hosted (ChatGPT Alternative)**

- 🤖 **Modèles locaux** : Aucune donnée envoyée cloud
- 💬 **Interface Web** : Type ChatGPT
- 🔧 **API compatible** : OpenAI-like
- 📱 **Modèles optimisés Pi** : TinyLlama, Phi-3, DeepSeek

**RAM** : ~2-4 GB (selon modèle chargé)
**Ports** : 11434 (API), 3000 (WebUI)

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/ollama/scripts/01-ollama-deploy.sh | sudo bash
```

**Modèles recommandés** :
- `phi3:3.8b` ⭐ - Meilleur équilibre
- `tinyllama:1.1b` - Ultra-rapide
- `deepseek-coder:1.3b` - Spécialisé code

---

### 2. [n8n](n8n/)
**Automatisation Workflows + IA**

- 🔄 **Workflows visuels** (drag & drop)
- 🤖 **Intégrations IA** : OpenAI, Ollama, Anthropic
- 📡 **500+ intégrations** : APIs, webhooks, services
- ⚡ **Automatisations complexes**

**RAM** : ~200 MB
**Port** : 5678

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/n8n/scripts/01-n8n-deploy.sh | sudo bash
```

**Use cases** :
- Email → Résumé IA → Notification
- Documents → OCR → Classification IA
- Webhooks + IA pour chatbots

---

## 📊 Statistiques Catégorie

| Métrique | Valeur |
|----------|--------|
| **Nombre de stacks** | 2 (+1 optionnel Voice) |
| **RAM totale** | ~2.2-4.2 GB |
| **Complexité** | ⭐⭐⭐ (Avancée) |
| **Priorité** | 🔴 HAUTE (IA locale) |

---

## 🎯 Cas d'Usage

### Scénario 1 : Développeur
- Ollama avec `deepseek-coder:1.3b`
- n8n pour automatiser CI/CD
- Continue.dev (VSCode) → Ollama backend

### Scénario 2 : Productivité
- Ollama `phi3:3.8b` pour Q&A
- n8n pour automatiser tâches répétitives
- Résumés documents, emails, etc.

### Scénario 3 : Recherche/Analyse
- LLM local pour analyser documents sensibles
- Privacy totale (aucune donnée cloud)
- RAG (Retrieval Augmented Generation) possible

---

## ⚠️ Notes Importantes

### Performance Pi 5
- **8GB RAM minimum** recommandé
- **Modèles < 7B paramètres** pour vitesse acceptable
- **SSD conseillé** (pas SD card)
- **Dissipateur thermique** pour charge CPU élevée

### Alternatives
- **Ollama remote** : Pi 5 → serveur LLM distant
- **n8n cloud** : Version hosted (5000 exec/mois gratuit)
- **APIs externes** : OpenAI, Anthropic (si privacy OK)

---

## 🔗 Ressources

- **Ollama** : https://ollama.ai/
- **Open WebUI** : https://docs.openwebui.com/
- **n8n** : https://docs.n8n.io/
- **Modèles** : https://ollama.com/library
- **Communauté** : r/LocalLLaMA (Reddit)

---

## 💡 Notes

- **100% self-hosted** : Aucune donnée ne quitte votre Pi
- **Privacy maximale** : Idéal données sensibles
- **Coût 0€** : vs APIs payantes (OpenAI, Anthropic)
- **Apprentissage** : Expérimenter IA sans limites
```

---

### 2. Mettre à jour ROADMAP.md

Ajouter après Phase 20 :

```markdown
---

## ✅ Phase 21 - Ollama + Open WebUI (TERMINÉ)

**Stack**: Intelligence Artificielle - LLM
**Statut**: ✅ Production Ready
**Dossier**: `11-intelligence-artificielle/ollama/`
**Priorité**: 🔴 HAUTE

### Réalisations
- [x] Ollama serveur LLM optimisé ARM64
- [x] Open WebUI interface web moderne
- [x] Auto-téléchargement modèles recommandés
- [x] Intégration Traefik + Homepage
- [x] Guide utilisateur complet
- [x] API compatible OpenAI

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/ollama/scripts/01-ollama-deploy.sh | sudo bash
```

### Technologies Utilisées
- **Ollama** (serveur LLM local)
- **Open WebUI** (interface ChatGPT-like)
- **Modèles optimisés** : Phi-3, TinyLlama, DeepSeek

### Statistiques
- **RAM** : ~2-4 GB (selon modèle)
- **Performance** : 3-5 tokens/sec
- **Use case** : Chat privé, code generation, Q&A

---

## ✅ Phase 22 - n8n Workflows IA (TERMINÉ)

**Stack**: Automatisation + IA
**Statut**: ✅ Production Ready
**Dossier**: `11-intelligence-artificielle/n8n/`
**Priorité**: 🔴 HAUTE

### Réalisations
- [x] n8n workflow engine
- [x] PostgreSQL backend
- [x] 500+ intégrations natives
- [x] Intégrations IA (Ollama, OpenAI, etc.)
- [x] Interface drag & drop

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/n8n/scripts/01-n8n-deploy.sh | sudo bash
```

### Statistiques
- **RAM** : ~200 MB
- **Intégrations** : 500+
- **Use case** : Automatisation workflows avec IA

---

## ✅ Phase 23 - Voice Assistant (OPTIONNEL)

**Stack**: Whisper + Piper
**Statut**: ✅ Production Ready
**Dossier**: `07-domotique/homeassistant/`
**Pré-requis**: Phase 10 (Home Assistant)
**Priorité**: 🟡 Moyenne

### Réalisations
- [x] Whisper Speech-to-Text
- [x] Piper Text-to-Speech
- [x] Wyoming Protocol
- [x] Intégration Home Assistant
- [x] Guide configuration complet

### Ce qui fonctionne
```bash
# Pré-requis : Home Assistant installé
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/05-voice-assistant-deploy.sh | sudo bash
```

### Statistiques
- **RAM** : ~300 MB
- **Performance** : <1s reconnaissance (Speech-to-Phrase)
- **Use case** : Assistant vocal maison, contrôle vocal
```

---

## ✅ Checklist Mise à Jour

### Documentation Phases IA
- [ ] 11-intelligence-artificielle/README.md créé
- [ ] ROADMAP.md mis à jour (phases 21-23)
- [ ] INSTALLATION-COMPLETE.md section IA ajoutée
- [ ] APPLICATIONS-IA-RECOMMANDEES.md déjà existant ✅

Bonne documentation des phases IA ! 🤖
