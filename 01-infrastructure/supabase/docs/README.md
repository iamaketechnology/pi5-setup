# 📚 Documentation Supabase sur Raspberry Pi 5

> **Guide complet pour installer, configurer et maintenir Supabase sur Raspberry Pi 5**

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
│
├── 📘 getting-started/                 # Démarrage
│   └── Quick-Start.md                  # Guide rapide
│
├── 📗 guides/                          # Guides utilisateur
│   └── Connexion-Application.md        # Connecter une app
│
├── 🔧 troubleshooting/                 # Dépannage
│   ├── Known-Issues-Pi5.md             # Problèmes connus Pi5
│   └── PostgREST-Fix.md                # Fix API REST
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

### 🔧 Dépannage

- **[Problèmes Connus Pi5](troubleshooting/Known-Issues-Pi5.md)**
  - Problèmes spécifiques ARM64
  - Solutions testées
  - Workarounds

- **[Fix API REST (PostgREST)](troubleshooting/PostgREST-Fix.md)**
  - Healthcheck qui échoue
  - Configuration Kong
  - Tests API

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

| Problème | Solution |
|----------|----------|
| **Studio ne charge pas** | [Quick Start](getting-started/Quick-Start.md) |
| **API REST 404** | [PostgREST Fix](troubleshooting/PostgREST-Fix.md) |
| **Kong crash** | [Known Issues Pi5](troubleshooting/Known-Issues-Pi5.md) |
| **Connexion app** | [Guide Connexion](guides/Connexion-Application.md) |
| **Backups** | [Automation](maintenance/Automation.md) |

---

## 💬 Support

- **Migration Cloud → Pi:** [../migration/](../migration/)
- **GitHub Issues:** [pi5-setup/issues](https://github.com/iamaketechnology/pi5-setup/issues)

---

<p align="center">
  <strong>📚 Documentation Supabase Raspberry Pi 5</strong><br>
  <em>Installation • Configuration • Maintenance</em>
</p>
