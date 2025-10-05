# 📦 Stockage & Cloud Personnel

> **Catégorie** : Gestion fichiers et cloud self-hosted

---

## 📦 Stacks Inclus

### 1. [FileBrowser + Nextcloud](filebrowser-nextcloud/)

#### 🗂️ FileBrowser (Léger)
**Gestionnaire de fichiers web simple**

- 📁 Upload/download fichiers
- 📝 Éditeur de texte intégré
- 🔍 Recherche
- 👥 Multi-utilisateurs
- 📱 Interface mobile responsive

**RAM** : ~50 MB
**Port** : 8082

---

#### ☁️ Nextcloud (Complet)
**Cloud personnel (Google Drive / Dropbox alternative)**

- 📁 Sync fichiers (desktop + mobile)
- 📝 Office en ligne (Collabora/OnlyOffice)
- 📅 Calendrier + Contacts (CalDAV/CardDAV)
- 💬 Chat + Visio (Nextcloud Talk)
- 📧 Email (Mail app)
- 🔐 Chiffrement end-to-end
- 🔌 1000+ apps disponibles

**RAM** : ~500 MB (selon apps installées)
**Port** : 8081

---

## 📊 Comparaison

| Critère | FileBrowser | Nextcloud |
|---------|-------------|-----------|
| **RAM** | ~50 MB | ~500 MB |
| **Complexité** | ⭐ Facile | ⭐⭐⭐ Avancée |
| **Fonctionnalités** | Basique | Complètes |
| **Apps mobiles** | ❌ Non | ✅ iOS + Android |
| **Sync desktop** | ❌ Non | ✅ Win/Mac/Linux |
| **Office en ligne** | ❌ Non | ✅ Oui |
| **Cas d'usage** | Accès fichiers simple | Cloud complet |

---

## 🚀 Installation

**FileBrowser uniquement** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/01-filebrowser-deploy.sh | sudo bash
```

**Nextcloud (recommandé)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/02-nextcloud-deploy.sh | sudo bash
```

---

## 🎯 Cas d'Usage

### FileBrowser : Partage fichiers simple
- Hébergement fichiers pour équipe
- Backup accessible web
- Partage de fichiers volumineux

### Nextcloud : Cloud complet
- Remplacement Google Drive / Dropbox
- Sync photos smartphone
- Collaboration documents
- Calendrier partagé famille/équipe

---

## 📊 Statistiques Catégorie

| Métrique | Valeur |
|----------|--------|
| **Nombre de stacks** | 1 (2 options) |
| **RAM totale** | 50 MB (FileBrowser) ou 500 MB (Nextcloud) |
| **Complexité** | ⭐ à ⭐⭐⭐ |
| **Priorité** | 🟢 **OPTIONNEL** |
| **Ordre installation** | Phase 7 |

---

## 💡 Notes

- **FileBrowser** : Parfait si vous voulez juste un accès web à vos fichiers
- **Nextcloud** : Si vous voulez remplacer Google Drive/Dropbox complètement
- **Économies** : ~120€/an (vs Dropbox Plus 2TB)
- Les deux utilisent le même dossier `/home/pi/data/storage`
