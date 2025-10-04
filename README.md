# 🖥️ Raspberry Pi 5 - Serveur de Développement Complet

> **Transformez votre Raspberry Pi 5 en serveur de développement et personnel tout-en-un**

Ce repository fournit des scripts d'installation automatisés et une documentation complète pour déployer des solutions self-hosted sur Raspberry Pi 5 (ARM64).

**Vision :** Un serveur unique pour tous vos besoins de développement, hébergement personnel et services en ligne.

---

## 🎯 Philosophie du Projet

### Pourquoi Self-Hosted sur Pi 5 ?

- 🔒 **Contrôle Total** - Vos données, votre infrastructure
- 💰 **Économique** - Pas d'abonnements mensuels cloud
- ⚡ **Performant** - Pi 5 16GB = 40% plus rapide que Pi 4
- 🌱 **Écologique** - Consommation ~10W (vs serveur cloud)
- 📚 **Éducatif** - Apprenez DevOps, infrastructure, Docker

### Architecture Cible

```
Raspberry Pi 5 (16GB)
├── 🗄️  Backend-as-a-Service (Supabase)
├── 🐙 Git Self-Hosted (Gitea) [Coming Soon]
├── 📊 Monitoring (Grafana/Prometheus) [Coming Soon]
├── 🌐 Reverse Proxy SSL (Traefik/Caddy) [Coming Soon]
├── 💾 Cloud Storage (Nextcloud) [Coming Soon]
├── 🔐 VPN (WireGuard) [Coming Soon]
└── 🤖 CI/CD (Gitea Actions/Drone) [Coming Soon]
```

---

## 📦 Stacks Disponibles

### ✅ [Supabase Stack](pi5-supabase-stack/) - **Production Ready v3.36**

**Backend-as-a-Service complet**

**Services inclus :**
- PostgreSQL 15 + pgvector, pgjwt, extensions
- Auth (GoTrue) - Authentification JWT
- REST API (PostgREST) - API automatique
- Realtime - WebSockets & subscriptions
- Storage - Fichiers & images
- Studio UI - Interface d'administration
- Edge Functions - Runtime Deno serverless
- Kong API Gateway - Routing & sécurité

**Use Cases :**
- Backend pour applications web/mobile
- Base de données relationnelle performante
- Auth utilisateurs clé-en-main
- API REST sans code
- Temps réel (chat, notifications)

**Installation :** 45 minutes | **RAM utilisée :** ~4-6GB

[📖 Documentation Complète →](pi5-supabase-stack/README.md)

---

### 🔜 Stacks à Venir

#### 🐙 Gitea Stack [Planned]
Git self-hosted avec UI moderne
- Repositories privés illimités
- Pull requests, issues, wiki
- CI/CD intégré (Gitea Actions)
- Alternative à GitHub/GitLab

#### 📊 Monitoring Stack [Planned]
Observabilité complète
- Grafana - Dashboards & visualisation
- Prometheus - Métriques time-series
- Loki - Logs centralisés
- Uptime Kuma - Monitoring services

#### 🌐 Reverse Proxy Stack [Planned]
Accès HTTPS sécurisé
- Traefik ou Caddy
- SSL/TLS automatique (Let's Encrypt)
- Routing par domaine/sous-domaine
- Load balancing

#### 💾 Nextcloud Stack [Planned]
Cloud storage personnel
- Stockage fichiers (Drive alternatif)
- Sync multi-devices
- Partage de fichiers
- Apps (calendrier, contacts, notes)

#### 🔐 Security Stack [Planned]
VPN & Sécurité
- WireGuard VPN
- Vaultwarden (password manager)
- Authelia (SSO/2FA)
- Pi-hole (DNS ad-blocking)

#### 🤖 CI/CD Stack [Planned]
Automation & déploiement
- Drone ou Gitea Actions
- Docker registry privé
- Automated testing
- Continuous deployment

---

## 🚀 Installation Rapide

### Prérequis Système

**Configuration initiale du Raspberry Pi :**

```bash
# 1. Flash Raspberry Pi OS 64-bit (Bookworm)
# 2. Configurer SSH, IP statique
# 3. Fixer page size 16KB → 4KB (CRITIQUE)

# Guide complet :
cat pi5-supabase-stack/commands/00-Initial-Raspberry-Pi-Setup.md
```

### Installer Votre Premier Stack (Supabase)

#### 🚀 Installation Directe via SSH (Recommandé)

```bash
# Étape 1 - Prérequis & Infrastructure
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/01-prerequisites-setup.sh | sudo bash
sudo reboot

# Étape 2 - Déploiement Supabase (après reboot)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/02-supabase-deploy.sh | sudo bash
```

**Durée totale :** ~45 minutes | **Niveau :** Débutant

[⚡ Installation Express →](pi5-supabase-stack/INSTALL.md) | [📖 Guide Complet →](pi5-supabase-stack/commands/01-Installation-Quick-Start.md)

---

## 📋 Configuration Matérielle

### Configuration Minimale

| Composant | Spécification |
|-----------|---------------|
| **SBC** | Raspberry Pi 5 (8GB RAM) |
| **OS** | Raspberry Pi OS 64-bit (Bookworm) |
| **Storage** | microSD 32GB Class 10 |
| **Réseau** | WiFi ou Ethernet |
| **Alimentation** | USB-C 27W officielle |

**Use Case :** Développement, apprentissage, projets personnels

### Configuration Recommandée (Production)

| Composant | Spécification |
|-----------|---------------|
| **SBC** | Raspberry Pi 5 (16GB RAM) ⭐ |
| **OS** | Raspberry Pi OS 64-bit (Bookworm) |
| **Storage** | NVMe SSD 128GB+ (HAT PCIe) ⭐ |
| **Réseau** | Ethernet Gigabit ⭐ |
| **Alimentation** | USB-C 27W officielle |
| **Refroidissement** | Ventilateur actif ⭐ |

**Use Case :** Serveur multi-stack, production légère, homelab

### Estimation Ressources par Stack

| Stack | RAM | Storage | CPU Idle |
|-------|-----|---------|----------|
| Supabase | 4-6GB | 8-10GB | 5-10% |
| Gitea | 512MB-1GB | 2GB | 2-5% |
| Monitoring | 2-3GB | 5GB | 5-10% |
| Nextcloud | 1-2GB | Variable | 5-15% |
| Reverse Proxy | 256MB | 1GB | 1-3% |

**Total estimé (tous stacks) :** 8-13GB RAM, 20-30GB storage

---

## 🛠️ Roadmap du Projet

### Phase 1 : Fondations ✅
- [x] Supabase Stack complet
- [x] Documentation complète
- [x] Scripts automatisés Week 1 + 2
- [x] Tous fixes ARM64 Pi 5

### Phase 2 : Infrastructure (Q1 2025)
- [ ] Reverse Proxy Stack (Traefik/Caddy)
- [ ] SSL/TLS automatique
- [ ] Monitoring Stack (Grafana/Prometheus)
- [ ] Centralized logging

### Phase 3 : DevOps (Q2 2025)
- [ ] Gitea Stack (Git self-hosted)
- [ ] CI/CD Stack (Gitea Actions/Drone)
- [ ] Docker Registry privé
- [ ] Automated backups

### Phase 4 : Services (Q2-Q3 2025)
- [ ] Nextcloud Stack (Cloud storage)
- [ ] Security Stack (VPN, Vaultwarden)
- [ ] Media Stack (Jellyfin optionnel)
- [ ] Communication Stack (Matrix/Mattermost optionnel)

### Phase 5 : Optimization (Q3-Q4 2025)
- [ ] Multi-Pi clustering (optionnel)
- [ ] HA (High Availability) setup
- [ ] Performance tuning guides
- [ ] Advanced networking

---

## 📚 Documentation & Support

### 📖 Guides Disponibles

- **[Initial Pi Setup](pi5-supabase-stack/commands/00-Initial-Raspberry-Pi-Setup.md)** - Configuration initiale complète
- **[Quick Start Guide](pi5-supabase-stack/commands/01-Installation-Quick-Start.md)** - Installation rapide
- **[Complete Installation Guide](pi5-supabase-stack/docs/INSTALLATION-GUIDE.md)** - Guide détaillé pas-à-pas
- **[Commands Reference](pi5-supabase-stack/commands/All-Commands-Reference.md)** - Toutes les commandes

### 🆘 Troubleshooting

- [Pi 5 Specific Issues](pi5-supabase-stack/docs/03-PI5-SPECIFIC/Known-Issues-2025.md)
- [Troubleshooting Guides](pi5-supabase-stack/docs/04-TROUBLESHOOTING/)
- [Diagnostic Scripts](pi5-supabase-stack/scripts/utils/)

### 💬 Community & Support

- **Issues GitHub** - Reporter bugs, demander features
- **Discussions GitHub** - Questions, partage d'expérience
- **Wiki** - Guides communautaires

---

## 🤝 Contribution

Ce projet est open-source et accueille les contributions !

### Comment Contribuer ?

1. **Tester sur Pi 5 réel** - Valider les scripts ARM64
2. **Reporter bugs** - Ouvrir issues avec logs détaillés
3. **Améliorer docs** - Clarifications, traductions, exemples
4. **Proposer stacks** - Nouveaux services à ajouter
5. **Partager use cases** - Vos configurations réelles

### Guidelines

- ✅ Tester sur Raspberry Pi 5 ARM64
- ✅ Documenter issues ARM64 spécifiques
- ✅ Scripts automatisés et reproductibles
- ✅ Documentation claire (FR/EN)
- ✅ Commits descriptifs

---

## 📜 Licenses

### Code & Scripts
- **MIT License** - Scripts d'installation, configurations
- Libre utilisation, modification, distribution

### Services Déployés
- **Supabase** - Apache 2.0 License
- **Docker** - Apache 2.0 License
- Voir licenses individuelles par stack

---

## 🎯 Use Cases Réels

### Développeur Full-Stack
- Backend Supabase pour apps web/mobile
- Git privé avec Gitea
- CI/CD automatisé
- Monitoring en temps réel

### Homelab Enthusiast
- Tous services cloud en local
- Contrôle total données
- Apprentissage DevOps/Infrastructure
- Pas de frais cloud mensuels

### Startup MVP
- Backend complet clé-en-main
- Auth + DB + API + Storage
- ~10€/mois électricité vs 100-500€/mois cloud
- Scale possible vers cloud après

### Éducation
- Apprendre Docker, Kubernetes concepts
- Infrastructure as Code
- Networking, reverse proxy
- Database management

---

## 🌟 Pourquoi ce Projet ?

### Le Problème
- Cloud coûte cher pour side-projects
- Vendor lock-in (AWS, GCP, Azure)
- Données personnelles sur serveurs tiers
- Complexité setup multi-services

### La Solution
- **Un Pi 5 = Un serveur complet**
- Scripts automatisés, zero-config
- Documentation exhaustive
- Communauté active
- Open-source, pas de lock-in

### L'Impact
- 💰 **Économie** : ~10€/mois vs 100-500€/mois cloud
- 🎓 **Éducation** : Apprendre en faisant
- 🔒 **Privacy** : Vos données chez vous
- 🌱 **Écologie** : 10W consommation

---

## 🙏 Remerciements

### Projets Open-Source
- [Raspberry Pi Foundation](https://www.raspberrypi.com) - Hardware incroyable
- [Supabase](https://supabase.com) - Firebase alternative open-source
- [Docker](https://www.docker.com) - Containerization
- Communauté ARM64/aarch64

### Contributors
- Tous ceux qui testent, reportent bugs, améliorent docs
- Communauté Raspberry Pi francophone
- Communauté self-hosting

---

<p align="center">
  <strong>🚀 Transformez votre Pi 5 en Serveur Pro ! 🚀</strong>
</p>

<p align="center">
  <sub>Made with ❤️ for developers, homelabbers, and self-hosting enthusiasts</sub>
</p>

<p align="center">
  <sub>⭐ Star le projet si il vous aide ! ⭐</sub>
</p>
