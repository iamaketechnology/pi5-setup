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
