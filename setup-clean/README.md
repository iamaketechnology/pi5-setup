# 🥧 Pi 5 Setup Clean - Base de Départ Corrigée

**Version finale corrigée avec tous les problèmes résolus**

## 📁 Structure Organisée

```
pi5-setup-clean/
├── README.md                                    # Ce fichier
├── docs/                                       # Documentation complète
│   ├── PI5-SUPABASE-ISSUES-COMPLETE.md        # Issues Pi 5 documentées
│   └── installation-guide.md                   # Guide pas-à-pas
├── scripts/                                    # Scripts principaux
│   ├── setup-week1-enhanced-final.sh          # Week 1 - Docker & base
│   ├── setup-week2-supabase-final.sh          # Week 2 - Supabase stack
│   └── pi5-complete-reset.sh                  # Reset complet du système
└── utils/                                      # Scripts utilitaires
    ├── diagnostics/                            # Outils de diagnostic
    │   └── diagnose-deep.sh                   # Diagnostic approfondi
    └── fixes/                                 # Corrections spécifiques
        └── fix-remaining-issues.sh            # Fix problèmes résiduels
```

## 🚀 Installation Rapide

### Étape 1 : Download
```bash
git clone https://github.com/your-repo/pi5-setup-clean.git
cd pi5-setup-clean
chmod +x scripts/*.sh utils/**/*.sh
```

### Étape 2 : Week 1 (Docker & Base)
```bash
sudo ./scripts/setup-week1-enhanced-final.sh
```

### Étape 3 : Week 2 (Supabase Stack)
```bash
sudo ./scripts/setup-week2-supabase-final.sh
```

## ✅ Correctifs Intégrés

### 🔧 Week 1 - Docker & Base
- ✅ Page size 16KB → 4KB automatique
- ✅ Docker daemon.json corrigé (sans storage-opts deprecated)
- ✅ Portainer sur port 8080 (évite conflit Kong 8000)
- ✅ Optimisations RAM 16GB Pi 5
- ✅ Sécurité UFW + Fail2ban

### 🔧 Week 2 - Supabase Stack
- ✅ Variables mots de passe unifiées (POSTGRES_PASSWORD unique)
- ✅ supabase-vector désactivé (incompatible ARM64 16KB)
- ✅ Utilisateurs PostgreSQL complets (service_role, etc.)
- ✅ Healthchecks optimisés pour Pi 5 ARM64
- ✅ Memory limits augmentées (512MB-1GB)

## 🆘 Reset Complet

Si problème, reset total :
```bash
sudo ./scripts/pi5-complete-reset.sh
# Redémarrer
sudo reboot
# Reprendre Week 1
```

## 📊 État Final Attendu

Après installation complète :

```
✅ Docker + Portainer (port 8080)
✅ Supabase Studio (port 3000)
✅ Supabase API (port 8001)
✅ PostgreSQL (port 5432)
✅ Edge Functions (port 54321)
✅ Page size 4096 bytes
✅ RAM 16GB optimisée
```

## 🔗 Accès Services

```
Studio Supabase : http://IP-PI5:3000
API Supabase    : http://IP-PI5:8001
Portainer       : http://IP-PI5:8080
```

## 📚 Documentation

- `docs/PI5-SUPABASE-ISSUES-COMPLETE.md` : Tous les problèmes Pi 5 documentés
- `docs/installation-guide.md` : Guide détaillé pas-à-pas

## ⚡ Commandes Utiles

```bash
# État Docker
docker ps
docker compose ps

# Diagnostic complet
sudo ./utils/diagnostics/diagnose-deep.sh

# Fix problèmes résiduels
sudo ./utils/fixes/fix-remaining-issues.sh

# Page size
getconf PAGESIZE  # Doit être 4096

# RAM usage
free -h
```

**🎯 Cette structure intègre TOUS les correctifs identifiés pour une installation Pi 5 Supabase parfaite !**