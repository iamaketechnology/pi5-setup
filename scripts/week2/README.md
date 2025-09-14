# 🚀 Week 2 - Supabase Installation Améliorée

Installation Supabase optimisée pour Raspberry Pi 5 avec **TOUS les fixes intégrés** automatiquement.

## 🎯 Nouvelle Approche

### ✅ **setup-week2-improved.sh** - Installation One-Shot
**Intègre automatiquement tous les fixes découverts :**

- ✅ **Port 8001 par défaut** (évite conflit Portainer)
- ✅ **Variables .env correctes** (API_EXTERNAL_URL, mots de passe séparés)
- ✅ **docker-compose.yml avec ${VARIABLES}** (pas de valeurs hardcodées)
- ✅ **Kong 3.0.0** (sans plugin request-id)
- ✅ **Utilisateurs PostgreSQL créés automatiquement**
- ✅ **Validation et tests intégrés**

### ✅ **clean-and-restart.sh** - Redémarrage Propre
Pour effacer complètement l'installation actuelle et recommencer :

```bash
# Nettoyage complet + réinstallation optimisée
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week2/clean-and-restart.sh -o clean.sh && chmod +x clean.sh && sudo MODE=beginner ./clean.sh
```

## 🚀 Installation Recommandée

### Option 1 : Nettoyage Complet + Installation Améliorée

```bash
# RECOMMANDÉ : Repart à zéro avec la version optimisée
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week2/clean-and-restart.sh -o clean.sh && chmod +x clean.sh && sudo MODE=beginner ./clean.sh
```

### Option 2 : Installation Améliorée Directe

```bash
# Installation améliorée (si pas d'installation Supabase existante)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week2/setup-week2-improved.sh -o setup.sh && chmod +x setup.sh && sudo MODE=beginner ./setup.sh
```

## 🔍 Comparaison des Approches

| Aspect | Ancienne Version | **Version Améliorée** |
|--------|------------------|----------------------|
| **Port API** | ❌ 8000 (conflit Portainer) | ✅ 8001 (sans conflit) |
| **Variables** | ❌ Hardcodées | ✅ ${} depuis .env |
| **API_EXTERNAL_URL** | ❌ Manquant | ✅ Présent automatiquement |
| **Users PostgreSQL** | ❌ À créer manuellement | ✅ Créés automatiquement |
| **Kong Version** | ❌ 2.8.1 + plugin issues | ✅ 3.0.0 optimisé |
| **Validation** | ❌ Manuelle | ✅ Automatique |
| **Debug** | ❌ Scripts séparés | ✅ Intégré + utils |

## 📋 Scripts Utilitaires Inclus

Après installation, dans `~/stacks/supabase/scripts/` :

```bash
./supabase-health.sh      # 🏥 Vérifier santé complète
./supabase-restart.sh     # 🔄 Redémarrage propre
./supabase-logs.sh auth   # 📋 Logs d'un service
```

## 🧪 Validation Automatique

Le script amélioré teste automatiquement :
- ✅ **Connectivité** : Studio, API, PostgreSQL
- ✅ **Variables** : Propagation correcte aux conteneurs
- ✅ **Services** : État et santé des conteneurs
- ✅ **Utilisateurs** : Authentification PostgreSQL

## 🔧 Configuration Avancée

```bash
# Installation avec ports personnalisés
API_PORT=8002 STUDIO_PORT=3001 sudo MODE=beginner ./setup-week2-improved.sh

# Mode pro avec optimisations
sudo MODE=pro ./setup-week2-improved.sh
```

## 🆘 Si Problèmes Persistent

1. **Utilise clean-and-restart.sh** - Résout 99% des cas
2. **Scripts debug individuels** - Disponibles dans [DEBUG-SCRIPTS.md](../../docs/DEBUG-SCRIPTS.md)
3. **Logs détaillés** - Dans `/var/log/pi5-setup-week2-improved.log`

## 📊 Résultat Attendu

Après installation réussie :
- 🎨 **Studio** : http://192.168.1.73:3000
- 🔌 **API** : http://192.168.1.73:8001
- ⚡ **Edge Functions** : http://192.168.1.73:54321
- 🗄️ **PostgreSQL** : localhost:5432

**Tous les services UP sans redémarrage !** 🎉