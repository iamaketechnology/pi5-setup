# Storage Migration Manifests

Ce dossier contiendra les manifests JSON générés lors de vos migrations Storage Cloud → Pi.

**Note** : Ce dossier est vide par défaut. Les manifests seront créés automatiquement lors de l'exécution du script `03-post-migration-storage.js`.

## 📋 Qu'est-ce qu'un Manifest ?

Un **manifest de migration** est un fichier JSON qui documente :
- ✅ Fichiers migrés avec succès
- ❌ Erreurs rencontrées
- 📊 Statistiques (total, succès, durée)
- 📅 Timestamp de la migration

## 🎯 Utilité

### 1. **Traçabilité**
Preuve documentée de la migration réussie pour audit/compliance.

### 2. **Debug**
En cas de problème, retrouver rapidement quels fichiers ont été migrés.

### 3. **Vérification**
Comparer le nombre de fichiers Cloud vs Pi après migration.

### 4. **Rollback**
Liste exacte des fichiers à supprimer si besoin de rollback.

## 📄 Format du Manifest

```json
{
  "timestamp": "2025-10-11T09:41:47.768Z",
  "stats": {
    "total": 13,
    "success": 13,
    "errors": 0,
    "duration": 8
  },
  "files": [
    {
      "bucket": "documents",
      "file": "hash.png",
      "size": 19605,
      "mimetype": "image/png"
    }
  ],
  "errors": []
}
```

## 🔍 Commandes Utiles

### Lister tous les fichiers migrés
```bash
jq -r '.files[] | "\(.bucket)/\(.file)"' storage-migration-*.json
```

### Compter fichiers par bucket
```bash
jq -r '.files[] | .bucket' storage-migration-*.json | sort | uniq -c
```

### Calculer taille totale migrée
```bash
jq -r '.files[] | .size' storage-migration-*.json | awk '{s+=$1} END {print s/1024/1024 " MB"}'
```

### Voir les erreurs (si présentes)
```bash
jq -r '.errors[]' storage-migration-*.json
```

## 🗂️ Nommage

Format : `storage-migration-<timestamp>.json`

Exemple : `storage-migration-1760175707768.json`
- `1760175707768` = Unix timestamp en millisecondes
- Correspond à : 2025-10-11 09:41:47 UTC

## 🧹 Maintenance

**Conservation recommandée** :
- Garder le dernier manifest de chaque migration réussie
- Archiver les anciens après 3 mois
- Supprimer les manifests de migrations test/échecs

**Archivage** :
```bash
mkdir -p archive/
mv storage-migration-$(date +%Y).json archive/
```

---

**Généré par** : [03-post-migration-storage.js](../scripts/03-post-migration-storage.js)
**Documentation** : [MIGRATION-CLOUD-TO-PI.md](../docs/guides/MIGRATION-CLOUD-TO-PI.md)
