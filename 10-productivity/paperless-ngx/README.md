# Paperless-ngx - Gestion Documents + OCR

> **DMS (Document Management System)** avec OCR automatique et archivage intelligent

**Version** : Latest (ARM64 compatible)
**RAM** : ~300MB
**Installation** : 5-10 min
**Niveau** : Débutant

---

## 🎯 Qu'est-ce que Paperless-ngx ?

**Système de gestion documentaire** avec :
- 📄 **OCR automatique** (PDF, images → texte searchable)
- 🏷️ **Tags & métadonnées** (auto-détection)
- 🔍 **Recherche full-text** instantanée
- 📧 **Import email** automatique
- 📱 **Scanner mobile** (apps iOS/Android)
- 📊 **Tableaux de bord** (stats, échéances)
- 🔐 **Versioning** (historique modifications)

**Use Case** : Dématérialiser factures, contrats, documents administratifs

---

## 🚀 Installation

### 📋 Choix de la Méthode

Ce repository propose **2 méthodes d'installation** :

| Méthode | Script | Avantages | Recommandé Pour |
|---------|--------|-----------|-----------------|
| **Custom** | [01-paperless-deploy.sh](scripts/01-paperless-deploy.sh) | Config simplifiée, intégration Pi5-setup | 🟢 Débutants |
| **Official + Wrapper** | [01-paperless-deploy-official.sh](scripts/01-paperless-deploy-official.sh) | Script upstream + intégration Traefik/Homepage | 🔵 Avancés |

**Les 2 méthodes donnent le même résultat** ✅

---

### Option 1 : Script Custom (Recommandé)

**Installation complète en 1 commande** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/paperless-ngx/scripts/01-paperless-deploy.sh | sudo bash
```

**Durée** : ~5 min

**Ce que fait le script** :
- ✅ Crée docker-compose.yml (PostgreSQL + Redis + Webserver)
- ✅ Génère .env sécurisé (credentials auto)
- ✅ Détecte scénario Traefik (DuckDNS/Cloudflare/VPN)
- ✅ Configure OCR français + anglais
- ✅ Démarre tous les services
- ✅ Ajoute à Homepage dashboard
- ✅ Affiche credentials

---

### Option 2 : Script Officiel + Wrapper

**Utilise le script officiel Paperless-ngx** (ARM64 testé upstream) :

```bash
# 1. Installation officielle
bash -c "$(curl -L https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/main/install-paperless-ngx.sh)"

# 2. Wrapper intégration (Traefik + Homepage + Backups)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/paperless-ngx/scripts/01-paperless-deploy-official.sh | sudo bash
```

**Durée** : ~10 min

**Avantages** :
- ✅ Script officiel maintenu par équipe Paperless-ngx
- ✅ Dernière version stable
- ✅ + Intégration Traefik/Homepage/Backups

---

## 📱 Applications Mobiles

### iOS : Paperless Mobile

1. **Télécharger** : [App Store - Paperless Mobile](https://apps.apple.com/app/paperless-mobile/id1621253729)
2. **Server URL** :
   - DuckDNS : `https://docs.monpi.duckdns.org`
   - Cloudflare : `https://docs.mondomaine.fr`
   - Local : `http://raspberrypi.local:8000`
3. **Credentials** : Voir résumé installation
4. **Scanner** : Prendre photo → OCR auto → Upload

### Android : Paperless Mobile

1. **Télécharger** : [Google Play - Paperless Mobile](https://play.google.com/store/apps/details?id=de.astubenbord.paperless_mobile)
2. **Configuration** : Identique iOS

---

## 📊 URLs d'Accès

Selon votre scénario Traefik :

| Scénario | URL Web |
|----------|---------|
| **DuckDNS** | `https://docs.monpi.duckdns.org` |
| **Cloudflare** | `https://docs.mondomaine.fr` |
| **VPN** | `https://docs.pi.local` |
| **Sans Traefik** | `http://raspberrypi.local:8000` |

---

## 📂 Utilisation

### Workflow de Base

```
1. Scanner/Photo document
   ↓
2. Déposer dans ~/data/paperless/consume/
   (ou upload via interface web/app mobile)
   ↓
3. Paperless détecte automatiquement
   ↓
4. OCR + Extraction métadonnées
   - Titre (détecté depuis texte)
   - Date (détecté depuis texte)
   - Correspondant (auto-détecté)
   - Tags (règles auto)
   ↓
5. Archivage avec recherche full-text
```

### Méthodes d'Import

**1. Dossier Consume** (Automatique)
```bash
# Copier PDF/images
cp facture_edf.pdf ~/data/paperless/consume/

# Ou depuis réseau (SMB/NFS)
# Ou scanner réseau → dossier consume
```

**2. Interface Web** (Upload)
- Glisser-déposer fichiers
- Éditer métadonnées manuellement si besoin

**3. App Mobile** (Scanner)
- Prendre photo document
- Traitement OCR mobile
- Upload automatique

**4. Email** (IMAP)
- Configure email account dans settings
- Paperless récupère PDF attachés automatiquement

---

## 🏷️ Organisation

### Tags

**Création automatique** via règles :
```
Exemple règles :
- Si contenu contient "EDF" → Tag "Factures - Électricité"
- Si contenu contient "Salaire" → Tag "Fiches de paie"
- Si contenu contient "Assurance" → Tag "Assurances"
```

**Tags manuels** : Interface web

### Correspondants

**Détection auto** depuis texte :
- EDF, SFR, Orange, etc.
- Créés automatiquement lors premier import

### Types de Documents

**Catégories** :
- Factures
- Contrats
- Documents administratifs
- Fiches de paie
- Relevés bancaires
- etc.

---

## 🔍 Recherche

### Recherche Full-Text

```
# Exemples requêtes
"facture EDF 2024"        # Toutes factures EDF 2024
"contrat assurance"       # Tous contrats assurance
"tag:factures 2024-01"    # Factures janvier 2024
"correspondent:EDF"       # Tous documents EDF
```

### Filtres Avancés

- **Date** : Avant/après/entre
- **Tags** : AND/OR/NOT
- **Correspondants** : Multiple
- **Type document** : Facture, contrat, etc.
- **ASN** (Archive Serial Number) : ID unique

---

## ⚙️ Configuration Post-Installation

### Langues OCR

Par défaut : **Français + Anglais**

**Ajouter langues** :
```bash
cd ~/stacks/paperless  # ou ~/paperless-ngx

# Éditer .env
nano .env
# Changer: PAPERLESS_OCR_LANGUAGE=fra+eng+deu+spa

# Redémarrer
docker-compose restart
```

Langues disponibles : fra, eng, deu, spa, ita, nld, por, rus, etc.

### Règles de Traitement

**Interface Web → Settings → Workflow** :

1. **Matching** : Regex pour détecter type document
2. **Actions** : Tag, correspondant, type auto
3. **Exemples** :
   ```
   Si titre contient "Facture EDF"
   → Tag: "Factures - Électricité"
   → Correspondant: "EDF"
   → Type: "Facture"
   ```

### Email Import

**Settings → Mail** :
- IMAP server (Gmail, Outlook, etc.)
- Username/password
- Règle : "Importer PDF attachés automatiquement"

---

## 💾 Backups

### Backup Automatique (GFS)

Si installé via script officiel + wrapper :

```bash
# Backup manuel
~/bin/backup-paperless.sh

# Automatique : Daily 3h (rotation 7d/4w/12m)
ls -lh ~/backups/paperless/
```

### Backup Manuel

```bash
cd ~/stacks/paperless  # ou ~/paperless-ngx

# Export complet (documents + DB)
docker-compose exec webserver document_exporter ../export/backup_$(date +%Y%m%d)

# Backup database seule
docker-compose exec db pg_dump -U paperless paperless > paperless_backup.sql
```

---

## 🔧 Gestion

### Commandes Utiles

```bash
# Installation custom
cd ~/stacks/paperless

# Installation officielle
cd ~/paperless-ngx

# Logs
docker-compose logs -f webserver

# Redémarrer
docker-compose restart

# Arrêter
docker-compose down

# Mettre à jour
docker-compose pull
docker-compose up -d

# Relancer OCR sur document
docker-compose exec webserver document_renamer

# Reconstruire index recherche
docker-compose exec webserver document_index reindex
```

### Stack Manager

```bash
# Voir RAM Paperless
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh status

# Arrêter (libérer ~300MB)
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop paperless

# Redémarrer
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh start paperless
```

---

## 📈 Ressources

### RAM

- **Paperless webserver** : ~200MB
- **PostgreSQL** : ~50MB
- **Redis** : ~20MB
- **Total** : ~300MB

### Stockage

- **Documents originaux** : `~/data/paperless/media/documents/originals/`
- **Documents archivés (OCR)** : `~/data/paperless/media/documents/archive/`
- **Thumbnails** : `~/data/paperless/media/documents/thumbnails/`
- **Database** : PostgreSQL

**Estimation** : ~500KB par document PDF (original + OCR + thumbnail)

---

## ⚠️ Performance OCR sur ARM64

**OCR sur ARM64 est plus lent que x86_64** :
- ARM64 (Pi 5) : ~20-30s par page
- x86_64 (Intel) : ~5-10s par page

**Solutions** :
- ✅ Laisser tourner en arrière-plan (process asynchrone)
- ✅ Uploader par lots (10-20 docs à la fois)
- ✅ Planifier imports la nuit

**Performance acceptable** pour usage personnel (5-10 docs/jour).

---

## 🆘 Problèmes Courants

### "OCR très lent"

**Normal sur ARM64** (voir ci-dessus).

**Optimisations** :
```bash
# Réduire qualité OCR (plus rapide)
nano .env
# Ajouter: PAPERLESS_OCR_MODE=skip_noarchive

# Restart
docker-compose restart
```

### "Cannot connect to database"

```bash
# Vérifier containers
docker ps | grep paperless

# Logs PostgreSQL
docker-compose logs db

# Redémarrer stack
docker-compose restart
```

### "Consume folder not working"

**Vérifier permissions** :
```bash
sudo chown -R 1000:1000 ~/data/paperless/consume/
```

---

## 📚 Documentation Officielle

- **Site** : https://docs.paperless-ngx.com
- **GitHub** : https://github.com/paperless-ngx/paperless-ngx
- **Forum** : https://github.com/paperless-ngx/paperless-ngx/discussions
- **Reddit** : r/selfhosted (tag paperless)

---

## 🎯 Use Cases

### 🏠 Personnel

- Factures (eau, électricité, internet)
- Documents administratifs
- Fiches de paie
- Relevés bancaires
- Contrats (assurance, location)

### 💼 Professionnel

- Devis clients
- Factures fournisseurs
- Contrats
- Documents RH
- Comptabilité

### 🔒 Compliance & Archivage

- Versioning documents
- Dates échéances (rappels)
- Recherche audit
- Export bulk (compliance)

---

## 🌟 Fonctionnalités Avancées

### Dashboard

- 📊 **Statistiques** : Nombre docs par mois, tags populaires
- 📅 **Échéances** : Documents avec dates importantes
- 🔍 **Recherches sauvegardées** : Queries favorites

### API

**REST API** pour automatisation :
```bash
# Exemple : Upload via API
curl -X POST \
  -H "Authorization: Token YOUR_API_TOKEN" \
  -F "document=@facture.pdf" \
  http://raspberrypi.local:8000/api/documents/post_document/
```

### Workflows

- **Règles conditionnelles** : Si X alors Y
- **Actions automatiques** : Tag, correspondant, type
- **Notifications** : Email quand nouveau doc

---

**📄 Dématérialisez vos documents ! 📄**
