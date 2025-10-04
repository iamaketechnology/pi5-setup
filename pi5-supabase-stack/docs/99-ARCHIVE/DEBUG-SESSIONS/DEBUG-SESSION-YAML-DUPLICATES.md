# SESSION DE DEBUGGING YAML DUPLICATES - 15 SEPTEMBRE 2025

## CONTEXTE
Après intégration des corrections Auth/Realtime, nouveau problème identifié : doublons de clés YAML dans docker-compose.yml causant échec validation et blocage script Week2.

## PROBLÈME IDENTIFIÉ

### ❌ ERREURS YAML DÉTECTÉES
```
line 126: mapping key "SECRET_KEY_BASE" already defined at line 106
line 133: mapping key "SEED_SELF_HOST" already defined at line 121
```

### 🔍 ANALYSE TECHNIQUE

**Validation bloquée :**
```bash
docker compose config
# Exit code: 1 (échec validation YAML)
```

**Script bloqué à :**
```
[SUPABASE] 🔍 Validation syntaxe YAML docker-compose.yml...
[SUPABASE]    Variables critiques :
[SUPABASE]      POSTGRES_VERSION=15-alpine
[SUPABASE]      POSTGRES_PASSWORD length=25
[SUPABASE]      JWT_SECRET length=40
[SUPABASE]      LOCAL_IP=192.168.1.73
# ← BLOCAGE ICI
```

## SOURCE DES DOUBLONS

### 🔍 SERVICE REALTIME - SECTION ENVIRONMENT

**Ligne 876 ✅ (correcte) :**
```yaml
environment:
  # CORRECTION INTÉGRÉE: Variables encryption Realtime
  SECRET_KEY_BASE: ${SECRET_KEY_BASE}
  # ...
  SEED_SELF_HOST: "true"
```

**Ligne 896 ❌ (doublon 1) :**
```yaml
  # Service config
  PORT: 4000
  API_JWT_SECRET: ${JWT_SECRET}
  SECRET_KEY_BASE: ${JWT_SECRET}  # ← DOUBLON avec ligne 876
```

**Ligne 904 ❌ (doublon 2) :**
```yaml
  # Configuration pour self-hosted
  SEED_SELF_HOST: "true"  # ← DOUBLON avec ligne 891
```

### 📋 DIAGNOSTIC COMPLET

#### 1. **SECRET_KEY_BASE - Double définition**
- **Première définition (ligne 876)** : `SECRET_KEY_BASE: ${SECRET_KEY_BASE}` ✅
  - Utilise variable d'environnement générée (64 chars hex)
  - Correcte pour encryption Realtime

- **Deuxième définition (ligne 896)** : `SECRET_KEY_BASE: ${JWT_SECRET}` ❌
  - Redéfinit avec JWT_SECRET au lieu de SECRET_KEY_BASE
  - Cause confusion et erreur YAML

#### 2. **SEED_SELF_HOST - Double définition**
- **Première définition (ligne 891)** : `SEED_SELF_HOST: "true"` ✅
  - Dans section Runtime Elixir
  - Positionnement logique

- **Deuxième définition (ligne 904)** : `SEED_SELF_HOST: "true"` ❌
  - Dans section "Configuration pour self-hosted"
  - Redondante et cause erreur YAML

## HISTORIQUE D'INTÉGRATION

### 🔄 COMMENT LES DOUBLONS SONT APPARUS

1. **Template Docker-Compose initial** : Avait `SECRET_KEY_BASE: ${JWT_SECRET}`
2. **Correction Realtime ajoutée** : `SECRET_KEY_BASE: ${SECRET_KEY_BASE}` (ligne 876)
3. **Template original maintenu** : `SECRET_KEY_BASE: ${JWT_SECRET}` (ligne 896)
4. **Résultat** : Deux définitions conflictuelles

### 🎯 ERREUR DE MERGE/INTÉGRATION

Le problème vient de l'intégration incomplète des corrections Realtime :
- ✅ **Ajout** des nouvelles variables encryption (lignes 876+)
- ❌ **Suppression** des anciennes définitions redondantes (lignes 896+)

## MÉTHODE DE RÉSOLUTION

### 📋 DIAGNOSTIC ÉTAPES

#### 1. **Identification erreurs**
```bash
docker compose config 2>&1 | grep -E "already defined|mapping key"
```

#### 2. **Localisation doublons**
```bash
grep -n "SECRET_KEY_BASE" docker-compose.yml
grep -n "SEED_SELF_HOST" docker-compose.yml
```

#### 3. **Analyse contexte**
- Quelle définition est logiquement correcte ?
- Quelle définition utilise les bonnes variables ?
- Quel positionnement dans le YAML est approprié ?

### 🔧 CORRECTION APPLIQUÉE

#### **Suppression lignes redondantes :**

**Avant (service realtime) :**
```yaml
environment:
  SECRET_KEY_BASE: ${SECRET_KEY_BASE}  # ligne 876 ✅
  SEED_SELF_HOST: "true"              # ligne 891 ✅
  # ...
  SECRET_KEY_BASE: ${JWT_SECRET}      # ligne 896 ❌ DOUBLON
  # ...
  SEED_SELF_HOST: "true"              # ligne 904 ❌ DOUBLON
```

**Après (service realtime) :**
```yaml
environment:
  SECRET_KEY_BASE: ${SECRET_KEY_BASE}  # ligne 876 ✅
  SEED_SELF_HOST: "true"              # ligne 891 ✅
  # ...
  # Lignes 896 et 904 supprimées
```

## PRÉVENTION FUTURE

### 🛠️ BONNES PRATIQUES TEMPLATE DOCKER-COMPOSE

#### 1. **Validation continue**
```bash
# Après chaque modification template
docker compose config > /dev/null || echo "YAML invalide"
```

#### 2. **Détection doublons automatique**
```bash
# Vérifier doublons dans environment sections
awk '/environment:/,/^[[:space:]]*[^[:space:]]/ {if(/^[[:space:]]*[^[:space:]]*:/) print $1}' docker-compose.yml | sort | uniq -d
```

#### 3. **Structure modulaire**
```yaml
# Grouper variables par fonction logique
environment:
  # === Database ===
  DB_HOST: db
  DB_PASSWORD: ${POSTGRES_PASSWORD}

  # === Encryption ===
  SECRET_KEY_BASE: ${SECRET_KEY_BASE}
  DB_ENC_KEY: ${DB_ENC_KEY}

  # === Runtime ===
  SEED_SELF_HOST: "true"
```

### 📋 CHECKLIST INTÉGRATION

Avant push modifications template docker-compose.yml :

- [ ] **Validation YAML** : `docker compose config`
- [ ] **Détection doublons** : Vérifier clés dupliquées
- [ ] **Test variables** : Toutes variables .env définies
- [ ] **Cohérence logique** : Variables utilisent bonnes sources
- [ ] **Documentation** : Commenter sections complexes

## CORRECTION SCRIPT WEEK2

### 🎯 MODIFICATIONS APPORTÉES

**Fichier :** `setup-week2-supabase-final.sh`

**Lignes supprimées :**
```bash
# Ligne 896 (dans service realtime)
SECRET_KEY_BASE: ${JWT_SECRET}

# Ligne 904 (dans service realtime)
SEED_SELF_HOST: "true"
```

**Version :** `2.2-port-fix` → `2.3-yaml-duplicates-fix`

### 📊 RÉSULTAT VALIDATION

**Avant correction :**
```bash
docker compose config
# line 126: mapping key "SECRET_KEY_BASE" already defined at line 106
# line 133: mapping key "SEED_SELF_HOST" already defined at line 121
# Exit code: 1
```

**Après correction :**
```bash
docker compose config > /dev/null
# Exit code: 0 ✅
```

## LEÇONS APPRISES

### ❌ APPROCHES FRAGILES

1. **Intégration additive sans nettoyage**
   - Ajouter nouvelles variables sans supprimer anciennes
   - Assumer que Docker ignorera doublons

2. **Validation partielle**
   - Tester génération .env mais pas docker-compose.yml
   - Validation YAML seulement en fin de script

3. **Templates complexes sans structure**
   - Mélanger variables logiquement différentes
   - Pas de séparation claire des sections

### ✅ APPROCHES ROBUSTES

1. **Intégration replace plutôt qu'add**
   - Identifier et supprimer anciennes définitions
   - Intégrer nouvelles variables avec nettoyage

2. **Validation continue**
   - Tester docker compose config après chaque modification
   - Bloquer génération si YAML invalide

3. **Structure modulaire**
   - Grouper variables par fonction logique
   - Documenter chaque section du template

## OUTILS DE DIAGNOSTIC

### 🔍 SCRIPTS UTILES

**Détection doublons environment :**
```bash
#!/bin/bash
# detect_yaml_duplicates.sh
grep -n "^[[:space:]]*[^[:space:]#]*:" docker-compose.yml | \
  awk -F: '{print $3}' | sort | uniq -c | \
  awk '$1 > 1 {print "DOUBLON: " $2 " (" $1 " occurrences)"}'
```

**Validation complète :**
```bash
#!/bin/bash
# validate_compose.sh
echo "=== Variables manquantes ==="
docker compose config --quiet 2>&1 | grep "not set"

echo "=== Doublons YAML ==="
docker compose config 2>&1 | grep "already defined"

echo "=== Validation finale ==="
docker compose config > /dev/null && echo "✅ YAML valide" || echo "❌ YAML invalide"
```

## STATUS FINAL

### ✅ RÉSOLUTION COMPLÈTE

- **Doublons supprimés** : SECRET_KEY_BASE et SEED_SELF_HOST
- **YAML validé** : `docker compose config` fonctionne
- **Script déblocage** : Week2 peut continuer l'installation
- **Prévention intégrée** : Correction automatique dans script

### 🚀 IMPACT

**Installation Week2 :**
- Plus de blocage à la validation YAML
- Génération docker-compose.yml propre
- Variables environment cohérentes

**Maintenance future :**
- Template docker-compose sans doublons
- Validation YAML systématique
- Documentation des sections critiques

---

## 🎯 CONCLUSION

**Durée debugging :** 30 minutes identification + correction
**Problème résolu :** Doublons YAML bloquant validation docker-compose
**Solution appliquée :** Suppression lignes redondantes + validation intégrée
**Statut :** CORRIGÉ - Script Week2 v2.3 opérationnel

### 📋 PROCHAINES INSTALLATIONS

Les futures installations Week2 bénéficient maintenant de :
- Template docker-compose.yml sans doublons
- Variables environment cohérentes
- Validation YAML qui ne bloque plus
- Installation fluide jusqu'au bout

**Correction intégrée dans script Week2 v2.3-yaml-duplicates-fix**