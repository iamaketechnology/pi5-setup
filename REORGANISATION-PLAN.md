# 📁 Plan de Réorganisation pi5-setup v4.0 → v5.0

## 🎯 Objectif

Réorganiser le projet pi5-setup par **catégories thématiques** pour une meilleure lisibilité et maintenance.

---

## 🗂️ Nouvelle Structure

```
pi5-setup/
│
├── 01-infrastructure/          # 🛡️ Infrastructure & Réseau
│   ├── supabase/              # PostgreSQL + PostgREST + Storage
│   ├── traefik/               # Reverse Proxy + HTTPS + Let's Encrypt
│   └── vpn-wireguard/         # VPN WireGuard
│
├── 02-securite/               # 🔐 Sécurité & Authentification
│   └── authelia/              # SSO + 2FA
│
├── 03-monitoring/             # 📊 Monitoring & Observabilité
│   └── prometheus-grafana/    # Métriques + Dashboards + Alerting
│
├── 04-developpement/          # 💻 Développement & CI/CD
│   └── gitea/                 # Git + Actions + Packages
│
├── 05-stockage/               # 📦 Stockage & Cloud Personnel
│   └── filebrowser-nextcloud/ # Gestionnaire fichiers + Cloud
│
├── 06-media/                  # 🎬 Média & Divertissement
│   └── jellyfin-arr/          # Serveur média + Sonarr/Radarr/Prowlarr
│
├── 07-domotique/              # 🏠 Domotique & IoT
│   └── homeassistant/         # Home Assistant + Node-RED + MQTT + Zigbee2MQTT
│
├── 08-interface/              # 🎛️ Interface & Dashboard
│   └── homepage/              # Dashboard centralisé
│
├── 09-backups/                # 💾 Sauvegardes & Disaster Recovery
│   └── restic-offsite/        # Backups chiffrés offsite
│
└── common/                    # 🔧 Scripts communs (inchangé)
    └── scripts/
```

---

## 🔄 Mapping Ancien → Nouveau

| Ancien nom | Nouveau chemin | Catégorie |
|------------|----------------|-----------|
| `pi5-supabase-stack` | `01-infrastructure/supabase` | Infrastructure |
| `pi5-traefik-stack` | `01-infrastructure/traefik` | Infrastructure |
| `pi5-vpn-stack` | `01-infrastructure/vpn-wireguard` | Infrastructure |
| `pi5-auth-stack` | `02-securite/authelia` | Sécurité |
| `pi5-monitoring-stack` | `03-monitoring/prometheus-grafana` | Monitoring |
| `pi5-gitea-stack` | `04-developpement/gitea` | Développement |
| `pi5-storage-stack` | `05-stockage/filebrowser-nextcloud` | Stockage |
| `pi5-media-stack` | `06-media/jellyfin-arr` | Média |
| `pi5-homeassistant-stack` | `07-domotique/homeassistant` | Domotique |
| `pi5-homepage-stack` | `08-interface/homepage` | Interface |
| `pi5-backup-offsite-stack` | `09-backups/restic-offsite` | Backups |

---

## 📝 Fichiers à Mettre à Jour

### Documentation principale
- [ ] `ROADMAP.md` - Mettre à jour tous les chemins
- [ ] `INSTALLATION-COMPLETE.md` - Mettre à jour les curl
- [ ] `PROJET-COMPLET-RESUME.md` - Mettre à jour les références
- [ ] `HEBERGER-SITE-WEB.md` - Mettre à jour exemples
- [ ] Tous les `README.md` de chaque stack

### Scripts
- [ ] Vérifier que les scripts utilisent `SCRIPT_DIR` correctement
- [ ] Tester que `common/scripts/lib.sh` fonctionne avec nouvelle structure

---

## ✅ Avantages

1. **Organisation claire** : Regroupement par fonction métier
2. **Scalabilité** : Facile d'ajouter de nouvelles apps dans bonne catégorie
3. **Navigation intuitive** : `01-`, `02-`, etc. pour ordre logique
4. **Noms explicites** : Plus besoin de préfixe `pi5-`
5. **Maintenance** : Facilite la localisation des stacks

---

## 🚀 Plan d'Exécution

1. ✅ Créer ce document de planification
2. ⏳ Créer la nouvelle arborescence de dossiers
3. ⏳ Déplacer les stacks existants
4. ⏳ Mettre à jour toute la documentation
5. ⏳ Tester que tous les scripts fonctionnent
6. ⏳ Créer script de migration pour utilisateurs existants
7. ⏳ Commit + Push version 5.0

---

## 🔧 Script de Migration (pour utilisateurs existants)

Les utilisateurs ayant déjà installé pi5-setup pourront exécuter :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/migrate-to-v5.sh | bash
```

Ce script :
- Détecte les anciennes installations
- Crée des symlinks pour compatibilité
- Met à jour les références dans Homepage
- Préserve toutes les données utilisateur
