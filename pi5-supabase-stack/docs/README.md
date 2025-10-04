# 📚 Base de Connaissances - Supabase sur Raspberry Pi 5

> **Documentation complète pour installer et maintenir Supabase self-hosted sur Raspberry Pi 5 (ARM64, 16GB RAM)**

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com)
[![Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.com/)
[![ARM64](https://img.shields.io/badge/arch-ARM64-green.svg)](https://www.arm.com/)
[![Supabase](https://img.shields.io/badge/Supabase-Self--Hosted-3ECF8E.svg)](https://supabase.com/)
[![Status](https://img.shields.io/badge/Services-9%2F9%20Healthy-brightgreen.svg)](https://supabase.com/)

---

## 🎯 Vue d'Ensemble

Cette Base de Connaissances (BdC) consolide **toutes les informations** nécessaires pour installer et exploiter un **stack Supabase complet** sur **Raspberry Pi 5** avec architecture **ARM64**.

### 🔑 Points Clés
- ✅ **Installation automatisée** via scripts bash testés
- ✅ **Correctifs ARM64** pour page size 16KB → 4KB
- ✅ **Solutions Auth/Realtime** documentées et intégrées
- ✅ **Optimisations RAM** pour Pi 5 16GB
- ✅ **Troubleshooting complet** avec solutions éprouvées
- ✅ **Recherches 2025** : dernières issues et workarounds
- ✅ **NEW (Oct 2025):** Studio & Edge Functions healthcheck fixes - 9/9 services healthy!

---

## 🚀 Démarrage Rapide

### Installation en 3 Étapes

```bash
# 1. Installation Week 1 (Docker + Base)
sudo ./scripts/01-prerequisites-setup.sh

# 2. Redémarrage obligatoire
sudo reboot

# 3. Installation Week 2 (Supabase Stack)
sudo ./scripts/02-supabase-deploy.sh
```

📖 **Guide détaillé** : [01-Quick-Start.md](01-GETTING-STARTED/01-Quick-Start.md)

---

## 📂 Navigation de la Base de Connaissances

### 🟢 [01-GETTING-STARTED](01-GETTING-STARTED/) - Premiers Pas
Commencez ici si c'est votre première installation.

| Fichier | Description | Temps |
|---------|-------------|-------|
| [00-Prerequisites.md](01-GETTING-STARTED/00-Prerequisites.md) | Matériel, OS, prérequis système | 5min |
| [01-Quick-Start.md](01-GETTING-STARTED/01-Quick-Start.md) | **Installation rapide copy-paste** | 30min |
| [02-Architecture-Overview.md](01-GETTING-STARTED/02-Architecture-Overview.md) | Comprendre le stack Supabase | 10min |

### 🔧 [02-INSTALLATION](02-INSTALLATION/) - Installation Détaillée
Guides pas-à-pas pour chaque phase d'installation.

| Fichier | Description | Temps |
|---------|-------------|-------|
| [Week1-Docker-Setup.md](02-INSTALLATION/Week1-Docker-Setup.md) | Installation Docker, Portainer, sécurité | 45min |
| [Week2-Supabase-Stack.md](02-INSTALLATION/Week2-Supabase-Stack.md) | Installation stack Supabase complet | 60min |
| [Installation-Commands.sh](02-INSTALLATION/Installation-Commands.sh) | **Script commandes bash prêtes** | - |
| [Post-Install-Checklist.md](02-INSTALLATION/Post-Install-Checklist.md) | Validation installation complète | 15min |

### 🥧 [03-PI5-SPECIFIC](03-PI5-SPECIFIC/) - Spécificités Pi 5 ARM64
**Section critique** : tous les problèmes Pi 5 et leurs solutions.

| Fichier | Description | Priorité |
|---------|-------------|----------|
| [ARM64-Compatibility.md](03-PI5-SPECIFIC/ARM64-Compatibility.md) | Compatibilité images Docker ARM64 | 🔴 Haute |
| [Page-Size-Fix.md](03-PI5-SPECIFIC/Page-Size-Fix.md) | **Fix obligatoire 16KB → 4KB** | 🔴 **CRITIQUE** |
| [Memory-Optimization.md](03-PI5-SPECIFIC/Memory-Optimization.md) | Optimisations RAM 16GB | 🟡 Moyenne |
| [Known-Issues-2025.md](03-PI5-SPECIFIC/Known-Issues-2025.md) | **Issues récentes + recherches web** | 🔴 Haute |

### 🛠️ [04-TROUBLESHOOTING](04-TROUBLESHOOTING/) - Dépannage
Solutions aux problèmes courants classés par service.

| Fichier | Description | Cas d'Usage |
|---------|-------------|-------------|
| [Auth-Issues.md](04-TROUBLESHOOTING/Auth-Issues.md) | Erreurs GoTrue, migrations, UUID | Auth en restart loop |
| [Realtime-Issues.md](04-TROUBLESHOOTING/Realtime-Issues.md) | Erreurs Realtime, encryption, WebSocket | Realtime crash/restart |
| [Docker-Issues.md](04-TROUBLESHOOTING/Docker-Issues.md) | Problèmes Docker Compose, images | Containers unhealthy |
| [Database-Issues.md](04-TROUBLESHOOTING/Database-Issues.md) | PostgreSQL, migrations, utilisateurs | DB ne démarre pas |
| [Quick-Fixes.md](04-TROUBLESHOOTING/Quick-Fixes.md) | **Solutions rapides 1-ligne** | Dépannage urgent |

### ⚙️ [05-CONFIGURATION](05-CONFIGURATION/) - Configuration Avancée
Comprendre et optimiser votre installation.

| Fichier | Description | Public |
|---------|-------------|--------|
| [Environment-Variables.md](05-CONFIGURATION/Environment-Variables.md) | Toutes les vars .env expliquées | Tous |
| [Docker-Compose-Explained.md](05-CONFIGURATION/Docker-Compose-Explained.md) | Anatomie docker-compose.yml | Intermédiaire |
| [Security-Hardening.md](05-CONFIGURATION/Security-Hardening.md) | UFW, Fail2ban, SSH, certificats | Production |
| [Performance-Tuning.md](05-CONFIGURATION/Performance-Tuning.md) | Optimisations Pi 5 spécifiques | Avancé |

### 🔄 [06-MAINTENANCE](06-MAINTENANCE/) - Maintenance & Opérations
Tâches de maintenance régulières.

| Fichier | Description | Fréquence |
|---------|-------------|-----------|
| [Backup-Strategies.md](06-MAINTENANCE/Backup-Strategies.md) | Stratégies backup DB + config | Hebdo |
| [Update-Procedures.md](06-MAINTENANCE/Update-Procedures.md) | Mise à jour Supabase/Docker | Mensuel |
| [Monitoring.md](06-MAINTENANCE/Monitoring.md) | Scripts santé, alertes, logs | Quotidien |
| [Reset-Procedures.md](06-MAINTENANCE/Reset-Procedures.md) | Reset complet système | En cas de problème |

### 🚀 [07-ADVANCED](07-ADVANCED/) - Fonctionnalités Avancées
Pour aller plus loin avec votre installation.

| Fichier | Description | Niveau |
|---------|-------------|--------|
| [Custom-Extensions.md](07-ADVANCED/Custom-Extensions.md) | pgvector, extensions PostgreSQL | Avancé |
| [SSL-Reverse-Proxy.md](07-ADVANCED/SSL-Reverse-Proxy.md) | HTTPS avec Caddy/Nginx | Avancé |
| [Multi-Environment.md](07-ADVANCED/Multi-Environment.md) | Dev/Staging/Production | Expert |
| [Migration-Strategies.md](07-ADVANCED/Migration-Strategies.md) | Migration vers/depuis autres BaaS | Expert |

### 📖 [08-REFERENCE](08-REFERENCE/) - Références Techniques
Documentation de référence complète.

| Fichier | Description | Type |
|---------|-------------|------|
| [All-Commands-Reference.md](08-REFERENCE/All-Commands-Reference.md) | **Tous les bash/docker commands** | Référence |
| [All-Ports-Reference.md](08-REFERENCE/All-Ports-Reference.md) | Mapping ports complet | Référence |
| [Service-Dependencies.md](08-REFERENCE/Service-Dependencies.md) | Graphe dépendances services | Diagramme |
| [Glossary.md](08-REFERENCE/Glossary.md) | Termes techniques expliqués | Glossaire |

### 🗃️ [99-ARCHIVE](99-ARCHIVE/) - Archives & Sessions Debug
Documentation historique des sessions de debugging.

| Contenu | Description |
|---------|-------------|
| DEBUG-SESSIONS/ | Sessions debugging Auth, Realtime, YAML |
| 2025-10-04-STUDIO-EDGE-FUNCTIONS-FIX.md | **NEW!** Session complète Studio & Edge Functions fix |

---

## 🔥 Accès Rapide - Problèmes Fréquents

### ❌ "Page size 16384 detected" → DB ne démarre pas
➡️ **Solution** : [Page-Size-Fix.md](03-PI5-SPECIFIC/Page-Size-Fix.md)

### ❌ Auth service en restart loop : "uuid = text operator does not exist"
➡️ **Solution** : [Auth-Issues.md](04-TROUBLESHOOTING/Auth-Issues.md#uuid-operator-missing)

### ❌ Realtime crash : "crypto_one_time bad key"
➡️ **Solution** : [Realtime-Issues.md](04-TROUBLESHOOTING/Realtime-Issues.md#encryption-variables)

### ❌ Studio healthcheck fails with 404 on /api/platform/profile
➡️ **Solution** : [Known-Issues-2025.md](03-PI5-SPECIFIC/Known-Issues-2025.md#6-studio-healthcheck-404-error--résolu-v321) ✅ RÉSOLU v3.21

### ❌ Edge Functions crash loop - container shows help text
➡️ **Solution** : [Known-Issues-2025.md](03-PI5-SPECIFIC/Known-Issues-2025.md#7-edge-functions-crash-loop--résolu-v322) ✅ RÉSOLU v3.22

### ❌ Services unhealthy après installation
➡️ **Solution** : [Quick-Fixes.md](04-TROUBLESHOOTING/Quick-Fixes.md#services-unhealthy)

### ❌ "password authentication failed for user"
➡️ **Solution** : [Database-Issues.md](04-TROUBLESHOOTING/Database-Issues.md#password-mismatch)

---

## 📊 Architecture Déployée

```
┌─────────────────────────────────────────────────────────────┐
│                     RASPBERRY PI 5 (16GB)                   │
│                        ARM64 / aarch64                      │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │   UFW Firewall    │
                    │  (Ports: 3000,    │
                    │   8000, 5432...)  │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Kong API Gateway │
                    │    (Port 8000)    │
                    └─────────┬─────────┘
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
    ┌────▼────┐         ┌────▼────┐         ┌────▼────┐
    │  Auth   │         │  REST   │         │ Realtime│
    │ (GoTrue)│         │(PostgREST)        │ (Phoenix)
    └────┬────┘         └────┬────┘         └────┬────┘
         │                   │                    │
         └───────────────────┼────────────────────┘
                             │
                    ┌────────▼────────┐
                    │   PostgreSQL    │
                    │  (Port 5432)    │
                    │   + pgvector    │
                    └─────────────────┘
```

### Services Inclus
- ✅ **PostgreSQL 15** - Base de données principale
- ✅ **Auth (GoTrue)** - Authentification JWT
- ✅ **REST (PostgREST)** - API REST automatique
- ✅ **Realtime** - WebSockets/Subscriptions
- ✅ **Storage** - Stockage fichiers/images
- ✅ **Studio** - Interface web administration
- ✅ **Kong** - API Gateway
- ✅ **Edge Functions** - Runtime Deno serverless

---

## 🎓 Parcours d'Apprentissage Recommandé

### Débutant
1. [00-Prerequisites.md](01-GETTING-STARTED/00-Prerequisites.md)
2. [01-Quick-Start.md](01-GETTING-STARTED/01-Quick-Start.md)
3. [Post-Install-Checklist.md](02-INSTALLATION/Post-Install-Checklist.md)

### Intermédiaire
1. [02-Architecture-Overview.md](01-GETTING-STARTED/02-Architecture-Overview.md)
2. [Environment-Variables.md](05-CONFIGURATION/Environment-Variables.md)
3. [Docker-Compose-Explained.md](05-CONFIGURATION/Docker-Compose-Explained.md)

### Avancé
1. [Performance-Tuning.md](05-CONFIGURATION/Performance-Tuning.md)
2. [Custom-Extensions.md](07-ADVANCED/Custom-Extensions.md)
3. [SSL-Reverse-Proxy.md](07-ADVANCED/SSL-Reverse-Proxy.md)

---

## 🛡️ Sécurité & Production

### Checklist Sécurité
- [ ] UFW configuré (ports minimaux ouverts)
- [ ] Fail2ban actif (anti brute-force)
- [ ] SSH par clés uniquement (pas de password)
- [ ] Mots de passe forts générés (`.env`)
- [ ] JWT_SECRET unique et complexe
- [ ] SSL/TLS activé (si exposition publique)

📖 **Guide complet** : [Security-Hardening.md](05-CONFIGURATION/Security-Hardening.md)

---

## 📈 Statistiques Projet

- **Scripts** : 15+ scripts bash automatisés
- **Documentation** : 35+ fichiers Markdown
- **Corrections** : 8 bugs majeurs Pi 5 corrigés
- **Temps installation** : ~2h (automatisée)
- **Services déployés** : 12 conteneurs Docker
- **Mémoire utilisée** : ~4GB / 16GB disponibles

---

## 🤝 Contribution & Support

### Signaler un Bug
Ouvrir une issue sur GitHub avec :
- Version Raspberry Pi OS
- Output de `getconf PAGESIZE`
- Logs Docker (`docker compose logs`)

### Améliorer la Documentation
Pull requests bienvenues pour :
- Corrections/clarifications
- Nouvelles sections
- Traductions

---

## 📜 Historique Versions

### v1.0.0 (2025-10-04)
- ✅ Création Base de Connaissances
- ✅ Consolidation docs existantes
- ✅ Recherches web 2025 intégrées
- ✅ Scripts automatisés Week 1 + 2
- ✅ Correctifs Auth/Realtime intégrés

---

## 📞 Ressources Externes

### Documentation Officielle
- [Supabase Docs](https://supabase.com/docs)
- [Supabase Self-Hosting](https://supabase.com/docs/guides/self-hosting)
- [Raspberry Pi OS](https://www.raspberrypi.com/documentation/)

### Issues GitHub Clés
- [#30640](https://github.com/supabase/supabase/issues/30640) - Pi OS 64-bit installation issue
- [#2954](https://github.com/supabase/supabase/issues/2954) - ARM64 Compose support

### Communauté
- [r/Supabase](https://reddit.com/r/Supabase)
- [Supabase Discord](https://discord.supabase.com)
- [Raspberry Pi Forums](https://forums.raspberrypi.com)

---

## ⚖️ Licence

Cette documentation est fournie **AS-IS** à des fins éducatives et de développement.

Les scripts et configurations sont testés sur **Raspberry Pi 5 (16GB)** avec **Raspberry Pi OS 64-bit (Bookworm)**.

---

## 🎉 Prochaines Étapes

Après avoir exploré cette Base de Connaissances :

1. **Installer** : Suivez [01-Quick-Start.md](01-GETTING-STARTED/01-Quick-Start.md)
2. **Valider** : Complétez [Post-Install-Checklist.md](02-INSTALLATION/Post-Install-Checklist.md)
3. **Sécuriser** : Appliquez [Security-Hardening.md](05-CONFIGURATION/Security-Hardening.md)
4. **Monitorer** : Configurez [Monitoring.md](06-MAINTENANCE/Monitoring.md)

---

<p align="center">
  <strong>🚀 Bonne installation et bienvenue dans l'écosystème Supabase self-hosted ! 🚀</strong>
</p>

<p align="center">
  <sub>Créé avec ❤️ pour la communauté Raspberry Pi & Supabase</sub>
</p>
