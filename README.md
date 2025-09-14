# 🏗️ Pi 5 Development Server Setup

**Transformez votre Raspberry Pi 5 (16GB) en serveur de développement complet avec stack moderne auto-hébergé**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Pi5 Compatible](https://img.shields.io/badge/Pi5-16GB-green.svg)](https://www.raspberrypi.org/products/raspberry-pi-5/)
[![ARM64](https://img.shields.io/badge/ARM64-Native-blue.svg)](https://en.wikipedia.org/wiki/AArch64)

## 🎯 Vue d'Ensemble

Installation progressive en 6 semaines pour créer un **mini data center** sur Pi 5 avec :
- 🐳 **Conteneurisation** native ARM64
- 🗄️ **Base de données** temps réel (Supabase)
- 🔒 **Sécurité** renforcée (UFW, Fail2ban, HTTPS)
- 🌐 **Accès externe** sécurisé
- ☁️ **Cloud personnel** (Nextcloud, stockage)
- 📺 **Multimédia** & IoT intégrés

## 🚀 Installation Rapide

### Week 1 - Base Docker & Sécurité
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week1/setup-week1.sh -o setup-week1.sh \
&& chmod +x setup-week1.sh \
&& sudo MODE=beginner ./setup-week1.sh
```

### Week 2 - Supabase Stack Complet
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week2/setup-week2.sh -o setup-week2.sh \
&& chmod +x setup-week2.sh \
&& sudo MODE=beginner ./setup-week2.sh
```

## 📂 Structure du Repository

```
pi5-setup/
├── 📁 scripts/
│   ├── 📁 week1/           # Scripts Week 1 (Docker, sécurité)
│   ├── 📁 week2/           # Scripts Week 2 (Supabase)
│   └── 📁 debug/           # Scripts débogage individuels
├── 📁 docs/                # Documentation complète
│   ├── WEEK1.md           # Guide détaillé Week 1
│   ├── WEEK2.md           # Guide détaillé Week 2
│   ├── COMMANDS-REFERENCE.md  # Référence commandes
│   └── TROUBLESHOOTING.md     # Solutions problèmes
├── 📁 examples/           # Configurations et exemples
└── 📁 .github/            # Templates GitHub
```

## 🗓️ Roadmap Progressive

| Week | Objectif | Services Déployés | Durée |
|------|----------|------------------|-------|
| **1** | 🏗️ **Base Serveur** | Docker, Portainer, UFW, Fail2ban | ~45min |
| **2** | 🗄️ **Supabase Stack** | PostgreSQL, Auth, Realtime, Studio | ~60min |
| **3** | 🌐 **HTTPS & Externe** | Caddy, Cloudflare, certificats | ~45min |
| **4** | 👥 **Dev Collaboratif** | Gitea, VS Code Server, CI/CD | ~60min |
| **5** | ☁️ **Cloud Personnel** | Nextcloud, MinIO, backups | ~75min |
| **6** | 📺 **Multimédia & IoT** | Jellyfin, Pi-hole, Home Assistant | ~90min |

## 🎯 Fonctionnalités Principales

### ✅ Week 1 - Serveur Sécurisé
- 🐳 **Docker** optimisé ARM64
- 🖥️ **Portainer** interface web
- 🔒 **UFW** firewall configuré
- 🛡️ **Fail2ban** protection SSH
- 📊 **Monitoring** système

### ✅ Week 2 - Supabase Complet
- 🗄️ **PostgreSQL 15** avec pgvector
- 🔐 **Authentication** complète
- ⚡ **Realtime** WebSockets
- 📁 **Storage** gestion fichiers
- 🎨 **Studio** interface web
- 🔧 **pgAdmin** (mode pro)
- 📱 **Edge Functions** serverless

## 🔧 Spécificités Pi 5

### Support ARM64 Natif
- ✅ **Images Docker** spécialement sélectionnées ARM64
- ✅ **Page size 16KB** support automatique
- ✅ **Optimisations mémoire** pour 16GB RAM
- ✅ **GPU split** configuré (128MB par défaut)

### Configuration Automatique
- 🔍 **Détection matériel** automatique
- 📏 **Page size** adapté (4KB/16KB)
- 🚀 **Installation orchestrée** multi-phases
- 🔄 **Redémarrage intelligent** si nécessaire

## 🛠️ Scripts de Débogage

Outils individuels pour résoudre les problèmes :

```bash
# Diagnostic complet
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/check-supabase-health.sh -o health.sh && chmod +x health.sh && ./health.sh

# Corriger conflits ports
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/debug-port-conflict.sh -o debug.sh && chmod +x debug.sh && sudo ./debug.sh

# Test APIs complètes
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/test-supabase-api.sh -o test.sh && chmod +x test.sh && ./test.sh
```

[📖 **Guide complet débogage**](docs/DEBUG-SCRIPTS.md)

## 📚 Documentation

### Guides Détaillés
- 📘 [**Week 1**](docs/WEEK1.md) - Installation base Docker
- 📗 [**Week 2**](docs/WEEK2.md) - Stack Supabase complet
- 📋 [**Référence Commandes**](docs/COMMANDS-REFERENCE.md) - Toutes les commandes
- 🔧 [**Troubleshooting**](docs/TROUBLESHOOTING.md) - Solutions problèmes

### Pour Développeurs
- 🏗️ [**Architecture**](docs/CLAUDE.md) - Structure projet
- 🐛 [**Bug Reports**](.github/ISSUE_TEMPLATE/bug_report.md) - Signaler problèmes
- 💡 [**Feature Requests**](.github/ISSUE_TEMPLATE/feature_request.md) - Nouvelles idées

## 🌟 Résultats Attendus

### Après Week 2
- 🎨 **Studio Supabase** : `http://pi5.local:3000`
- 🔌 **API REST** : `http://pi5.local:8001/rest/v1/`
- 🔐 **Auth API** : `http://pi5.local:8001/auth/v1/`
- 📁 **Storage API** : `http://pi5.local:8001/storage/v1/`
- ⚡ **Edge Functions** : `http://pi5.local:54321/functions/v1/`

### Performance Optimisée Pi 5
- 💾 **~4GB RAM** utilisés sur 16GB disponibles
- 🚀 **Services ARM64** natifs pour performance maximale
- 🔧 **Configuration adaptée** 16KB page size
- 📊 **Monitoring intégré** ressources

## 🤝 Contribution

1. 🍴 Fork le repository
2. 🌿 Créer une branche feature (`git checkout -b feature/nouvelle-fonctionnalite`)
3. ✅ Commit les changements (`git commit -am 'Add: nouvelle fonctionnalité'`)
4. 📤 Push la branche (`git push origin feature/nouvelle-fonctionnalite`)
5. 🔄 Créer une Pull Request

## 📄 License

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🆘 Support

- 🐛 [**Issues GitHub**](https://github.com/iamaketechnology/pi5-setup/issues) - Bugs et problèmes
- 💬 [**Discussions**](https://github.com/iamaketechnology/pi5-setup/discussions) - Questions et idées
- 📧 **Email** : Support via issues GitHub uniquement

---

**🎯 Transformez votre Pi 5 en serveur de développement professionnel !** 🚀