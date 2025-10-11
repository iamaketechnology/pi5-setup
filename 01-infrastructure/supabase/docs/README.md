# 📚 Documentation Supabase sur Raspberry Pi 5

> **Guide complet pour installer, configurer et maintenir Supabase sur Raspberry Pi 5**

---

## 🎯 Nouveauté v3.48 - Support Multi-Scénarios

**Installation Intelligente** - Le script de déploiement supporte maintenant 3 scénarios :

1. **📦 Installation Vierge** - Supabase complet pour nouveaux projets
2. **🔄 Migration Cloud** - Scripts automatiques pour migrer depuis Supabase Cloud
3. **🏢 Multi-Applications** - Plusieurs instances isolées sur le même Pi

📖 **Documentation complète** : [CHANGELOG-MULTI-SCENARIO-v3.48.md](../CHANGELOG-MULTI-SCENARIO-v3.48.md)

---

## 📖 Navigation Documentation

👉 **[📚 INDEX COMPLET](../DOCUMENTATION-INDEX.md)** - ⭐ **Navigation complète de toute la documentation !**

L'index complet permet de :
- **Rechercher par problème** (403 errors, Edge Functions 503, RLS, etc.)
- **Naviguer par parcours** (Débutant, Migration, Multi-apps)
- **Voir tous les documents** (35+ fichiers organisés)

---

## 🚀 Par où commencer?

### 🟢 Installation (Première fois)

**[📖 Guide d'Installation Complet](INSTALLATION-GUIDE.md)**
- Installation depuis zéro
- Configuration système
- Déploiement Supabase
- Vérification post-installation

### 🟡 Démarrage Rapide (Si déjà installé)

**[⚡ Quick Start](getting-started/Quick-Start.md)**
- Commandes essentielles
- Accès Studio
- Tests rapides

---

## 📂 Structure de la Documentation

```
docs/
├── README.md                           # ⭐ Vous êtes ici
├── INSTALLATION-GUIDE.md               # Guide installation complet
├── edge-functions-router.md            # Router Edge Functions (v3.47+)
│
├── 📘 getting-started/                 # Démarrage
│   └── Quick-Start.md                  # Guide rapide
│
├── 📗 guides/                          # Guides utilisateur
│   ├── Connexion-Application.md        # Connecter une app
│   └── EDGE-FUNCTIONS-DEPLOYMENT.md    # Déployer Edge Functions (v3.47+)
│
├── 🔧 troubleshooting/                 # Dépannage
│   ├── Known-Issues-Pi5.md             # Problèmes connus Pi5
│   ├── PostgREST-Fix.md                # Fix API REST
│   ├── Kong-DNS-Resolution-Failed.md   # Fix Kong 503 (v3.47)
│   └── EDGE-FUNCTIONS-FAT-ROUTER.md    # Pattern Fat Router (v3.47)
│
├── 🔄 maintenance/                     # Maintenance
│   └── Automation.md                   # Automatisation backups
│
└── 📋 reference/                       # Référence
    └── Commands.md                     # Toutes les commandes
```

---

## 📖 Guides par Catégorie

### 🏁 Démarrage

- **[Quick Start](getting-started/Quick-Start.md)**
  - Démarrer/arrêter Supabase
  - Accéder à Studio
  - Tests de base

### 🔗 Utilisation

- **[Connecter une Application](guides/Connexion-Application.md)**
  - Configuration client Supabase
  - Variables d'environnement
  - Exemples de code

- **[Déployer Edge Functions](guides/EDGE-FUNCTIONS-DEPLOYMENT.md)** ⭐ v3.47+
  - Pattern Fat Router expliqué
  - Déploiement automatisé
  - Testing et validation

- **[Router Edge Functions](edge-functions-router.md)**
  - Documentation technique du router
  - Architecture interne

### 🔧 Dépannage

- **[Problèmes Connus Pi5](troubleshooting/Known-Issues-Pi5.md)**
  - Problèmes spécifiques ARM64
  - Solutions testées
  - Workarounds

- **[Fix API REST (PostgREST)](troubleshooting/PostgREST-Fix.md)**
  - Healthcheck qui échoue
  - Configuration Kong
  - Tests API

- **[Fix Kong DNS (503 Errors)](troubleshooting/Kong-DNS-Resolution-Failed.md)** ⭐ v3.47
  - Edge Functions 503 Service Unavailable
  - Network alias 'functions'
  - Résolution DNS Kong

- **[Pattern Fat Router](troubleshooting/EDGE-FUNCTIONS-FAT-ROUTER.md)** ⭐ v3.47
  - Pourquoi Fat Router ?
  - Self-hosted vs Cloud
  - Implementation complète

### 🔄 Maintenance

- **[Automatisation](maintenance/Automation.md)**
  - Backups automatiques
  - Rotation logs
  - Monitoring
  - Updates

### 📋 Référence

- **[Toutes les Commandes](reference/Commands.md)**
  - Docker Compose
  - Maintenance
  - Diagnostic
  - Backup/Restore

---

## 🆘 Problèmes Courants?

| Problème | Solution | Version |
|----------|----------|---------|
| **Studio ne charge pas** | [Quick Start](getting-started/Quick-Start.md) | All |
| **API REST 403 Forbidden** | [📚 INDEX](../DOCUMENTATION-INDEX.md#jai-une-erreur-403-forbidden-sur-mes-apis) → Fix RLS | v3.45+ |
| **Edge Functions 503** | [Kong DNS Fix](troubleshooting/Kong-DNS-Resolution-Failed.md) | v3.47+ |
| **Edge Functions "Hello undefined!"** | [Fat Router Pattern](troubleshooting/EDGE-FUNCTIONS-FAT-ROUTER.md) | v3.47+ |
| **Kong crash** | [Known Issues Pi5](troubleshooting/Known-Issues-Pi5.md) | All |
| **Connexion app** | [Guide Connexion](guides/Connexion-Application.md) | All |
| **Migration Cloud → Pi** | [📚 INDEX](../DOCUMENTATION-INDEX.md#comment-migrer-depuis-supabase-cloud-) | v3.48+ |
| **Multi-applications** | [📚 INDEX](../DOCUMENTATION-INDEX.md#comment-avoir-plusieurs-instances-supabase-) | v3.48+ |
| **Backups** | [Automation](maintenance/Automation.md) | All |

---

## 💬 Support

- **Migration Cloud → Pi:** [../migration/](../migration/)
- **GitHub Issues:** [pi5-setup/issues](https://github.com/iamaketechnology/pi5-setup/issues)

---

<p align="center">
  <strong>📚 Documentation Supabase Raspberry Pi 5</strong><br>
  <em>Installation • Configuration • Maintenance</em>
</p>
