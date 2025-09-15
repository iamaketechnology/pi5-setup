# SESSION DE DEBUGGING REALTIME - 15 SEPTEMBRE 2025

## CONTEXTE
Résolution en temps réel du problème Realtime après application du script `SOLUTION-IMMEDIATE-REALTIME.sh`.

## CHRONOLOGIE DE LA SESSION

### 1. ÉTAT INITIAL (19h00)
- Realtime en boucle de redémarrage : `Restarting (1) 7 seconds ago`
- Erreur confirmée : `crypto_one_time(:aes_128_ecb, nil, ...)` - clé encryption `nil`

### 2. APPLICATION DU SCRIPT FIX (19h00-19h05)
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/SOLUTION-IMMEDIATE-REALTIME.sh -o SOLUTION-IMMEDIATE-REALTIME.sh
chmod +x SOLUTION-IMMEDIATE-REALTIME.sh
sudo ./SOLUTION-IMMEDIATE-REALTIME.sh
```

**Résultats du script :**
- ✅ DB_ENC_KEY généré : `3844e02769078c57` (16 chars exactement)
- ✅ SECRET_KEY_BASE généré : `a20db7f055897fe816175ddce666d3d98a105f9c8c52c44b271d224165d7dd2e` (64 chars)
- ⚠️ Erreurs YAML détectées : doublons dans docker-compose.yml
  - `line 117: mapping key "DB_IP_VERSION" already defined at line 107`
  - `line 117: mapping key "DB_IP_VERSION" already defined at line 107`

### 3. CORRECTION DES DOUBLONS (19h05-19h10)
```bash
# Suppression des lignes dupliquées
sed -i '117d;224d' docker-compose.yml

# Vérification DB_ENC_KEY présent
grep -A 10 -B 5 "DB_ENC_KEY" docker-compose.yml
```

**Résultat :** DB_ENC_KEY bien présent dans docker-compose.yml mais doublons ERL_AFLAGS détectés.

### 4. NOUVELLE ERREUR IDENTIFIÉE (19h10)
Après correction doublons et redémarrage :
```
Runtime terminating during boot ({#{message=><<"APP_NAME not available">>
```

**Analyse :** L'erreur a évolué :
- ❌ Avant : `crypto_one_time` avec clé `nil`
- ❌ Maintenant : `APP_NAME not available` au runtime boot

### 5. DIAGNOSTIC VARIABLES D'ENVIRONNEMENT (19h15)
```bash
grep -E "DB_ENC_KEY|SECRET_KEY_BASE" .env
# Résultat : Variables bien présentes dans .env
DB_ENC_KEY=3844e02769078c57
SECRET_KEY_BASE=a20db7f055897fe816175ddce666d3d98a105f9c8c52c44b271d224165d7dd2e

docker exec supabase-realtime env | grep -E "DB_ENC_KEY|SECRET_KEY_BASE"
# Résultat : Impossible - conteneur en restart loop
```

### 6. NETTOYAGE COMPLET TENTÉ (19h15)
```bash
# Tentative de nettoyage des doublons supplémentaires
sed -i '/realtime:/,/kong:/{
  /ERL_AFLAGS.*-proto_dist inet_tcp/d
  /APP_NAME: supabase_realtime/d
  /DNS_NODES: ""/d
  /SEED_SELF_HOST: "true"/d
}' docker-compose.yml

# Redémarrage complet
docker compose down
docker compose up -d
```

**Résultat :** Même erreur persiste - `APP_NAME not available`

### 7. CORRUPTION YAML DÉTECTÉE (19h20)
Tentative d'ajout APP_NAME cause erreur YAML :
```bash
sed -i '/realtime:/,/environment:/{
  /environment:/a\
      APP_NAME: supabase_realtime
}' docker-compose.yml

docker compose up -d realtime
# Erreur : yaml: line 95: did not find expected key
```

## PROBLÈMES IDENTIFIÉS

### 1. DOCKER-COMPOSE.YML CORROMPU
- Erreurs YAML à la ligne 95
- Doublons multiples de variables d'environnement
- Structure indentation cassée

### 2. VARIABLES PRÉSENTES MAIS NON TRANSMISES
- Variables dans .env : ✅ Présentes
- Variables dans docker-compose.yml : ❓ Partiellement/malformées
- Variables dans conteneur : ❌ Non reçues

### 3. PROGRESSION DES ERREURS
1. **crypto_one_time nil** → Clé encryption manquante
2. **APP_NAME not available** → Variable environnement manquante
3. **YAML syntax error** → Configuration corrompue

## ACTIONS TENTÉES

### ✅ RÉUSSIES
- Génération clés encryption correctes (DB_ENC_KEY 16 chars, SECRET_KEY_BASE 64 chars)
- Identification et suppression doublons basiques
- Variables ajoutées au fichier .env

### ❌ ÉCHOUÉES
- Correction structure docker-compose.yml
- Transmission variables au conteneur Realtime
- Suppression complète doublons

## PROCHAINES ÉTAPES RECOMMANDÉES

### OPTION 1 : RÉPARATION DOCKER-COMPOSE.YML
1. Diagnostiquer corruption YAML ligne 95
2. Corriger manuellement la structure
3. Vérifier syntaxe avec `docker compose config`

### OPTION 2 : RÉGÉNÉRATION PROPRE
1. Sauvegarder .env avec clés générées
2. Télécharger docker-compose.yml propre
3. Réintégrer variables dans structure saine

### OPTION 3 : RESTART COMPLET AVEC FIXES INTÉGRÉS
1. Nettoyer installation complètement
2. Relancer script Week2 avec corrections préventives

## LEÇONS APPRISES

### SCRIPT AUTOMATIQUE LIMITATIONS
- Sed avec structures YAML complexes = fragile
- Doublons multiples difficiles à gérer automatiquement
- Vérification syntaxe YAML nécessaire après chaque modification

### ORDRE DE RÉSOLUTION
1. ✅ Identification erreur racine (crypto_one_time nil)
2. ✅ Génération clés correctes
3. ❌ Transmission propre au conteneur (bloqué par corruption YAML)

## DIAGNOSTIC YAML CORRUPTION (19h30)

### PROBLÈME IDENTIFIÉ - INDENTATION INCORRECTE
```yaml
environment:
    APP_NAME: supabase_realtime    # ← 4 espaces (incorrect)
  DB_IP_VERSION: ipv4              # ← 2 espaces (correct)
```

**Cause :** `APP_NAME` ajouté avec 4 espaces au lieu de 2, cassant la structure YAML.

### SOLUTION APPLIQUÉE
```bash
# Correction indentation APP_NAME
sed -i 's/^        APP_NAME: supabase_realtime$/      APP_NAME: supabase_realtime/' docker-compose.yml

# Vérification syntaxe
docker compose config > /dev/null
```

### RÉSOLUTION YAML CORRUPTION (19h35-19h40)

**Problème détecté :** Indentations incorrectes multiples
```yaml
# INCORRECT (8 espaces)
environment:
        APP_NAME: supabase_realtime  # Ligne 104 et 213
      DB_ENC_KEY: ${DB_ENC_KEY}      # 6 espaces (correct)

# CORRECT (6 espaces uniformes)
environment:
      APP_NAME: supabase_realtime
      DB_ENC_KEY: ${DB_ENC_KEY}
```

**Occurrences trouvées :**
```bash
grep -n "APP_NAME" docker-compose.yml
104:      APP_NAME: supabase_realtime  # Section realtime
213:        APP_NAME: supabase_realtime  # Section kong (8 espaces)
```

**Correction appliquée :**
```bash
sed -i 's/^        APP_NAME:/      APP_NAME:/' docker-compose.yml
docker compose config > /dev/null  # ✅ Aucune erreur
```

## ANALYSE : COMMENT L'ERREUR A ÉTÉ INTRODUITE

### 1. SCRIPT AUTOMATIQUE DÉFAILLANT
Le script `SOLUTION-IMMEDIATE-REALTIME.sh` utilisait cette commande problématique :
```bash
sed -i '/realtime:/,/environment:/{
  /environment:/a\
      APP_NAME: supabase_realtime    # ← Ajoute avec 4 espaces après "a\"
}' docker-compose.yml
```

**Problème :** `sed` avec `a\` ajoute le texte tel quel, sans respecter l'indentation contextuelle.

### 2. INDENTATION INCONSISTANTE
Le docker-compose.yml avait déjà une structure :
```yaml
environment:        # 4 espaces base
  VAR1: value      # 6 espaces (4+2)
  VAR2: value      # 6 espaces (4+2)
```

Mais `sed` a ajouté :
```yaml
environment:        # 4 espaces base
    APP_NAME: val   # 8 espaces (4+4) ← INCORRECT
  VAR1: value       # 6 espaces ← CORRECT
```

### 3. PROPAGATION D'ERREUR
L'erreur s'est propagée dans deux sections :
1. **Section realtime** (ligne 104) : Première insertion incorrecte
2. **Section kong** (ligne 213) : Duplication lors nettoyage doublons

### 4. POURQUOI AVANT ÇA MARCHAIT
- **Script Week2 original** : Génère docker-compose.yml complet d'un coup avec indentation correcte
- **Modifications manuelles** : Respectent structure existante
- **Scripts automatiques sed** : Cassent structure si mal conçus

## LEÇONS APPRISES

### ❌ APPROCHES FRAGILES
```bash
# FRAGILE - Ajoute sans contexte d'indentation
sed -i '/environment:/a\    VAR: value'

# FRAGILE - Assume structure fixe
sed -i '/realtime:/,/environment:/{/environment:/a\      VAR: value}'
```

### ✅ APPROCHES ROBUSTES
```bash
# ROBUSTE - Vérifie structure avant modification
if grep -q "environment:" docker-compose.yml; then
  # Utilise indentation existante détectée
  INDENT=$(grep -A1 "environment:" docker-compose.yml | tail -1 | sed 's/\([[:space:]]*\).*/\1/')
  sed -i "/environment:/a\\${INDENT}VAR: value" docker-compose.yml
fi

# ROBUSTE - Template complet au lieu de modifications
envsubst < docker-compose.template.yml > docker-compose.yml
```

### 🛠️ OUTILS DE VALIDATION
```bash
# Validation YAML après chaque modification
docker compose config > /dev/null || { echo "YAML invalide"; exit 1; }

# Détection indentation
yamllint docker-compose.yml

# Vérification structure
yq eval '.services.realtime.environment' docker-compose.yml
```

## STATUS FINAL YAML (19h40)
- **Erreur ligne 95** : ✅ CORRIGÉE (APP_NAME realtime)
- **Erreur ligne 196** : ✅ CORRIGÉE (APP_NAME kong)
- **Syntaxe YAML** : ✅ VALIDÉE (`docker compose config`)
- **Prochaine action** : Test redémarrage Realtime avec structure corrigée

## RÉSOLUTION FINALE - SUCCÈS COMPLET (19h45)

### ✅ REALTIME OPÉRATIONNEL
```bash
docker ps | grep realtime
# a7701be6dc10   supabase/realtime:v2.30.23   Up 42 seconds

docker exec supabase-realtime env | grep -E "DB_ENC_KEY|APP_NAME|SECRET_KEY_BASE"
# DB_ENC_KEY=3844e02769078c57                    ✅ 16 chars
# SECRET_KEY_BASE=a20db7f055897fe816175ddce...    ✅ 64 chars
# APP_NAME=supabase_realtime                     ✅ Présent
```

### 🔍 LOGS FINAUX - SAINS
```
[warning] [libcluster:fly6pn] dns polling strategy is selected, but query or basename param is invalid
```
**Analyse :** Warnings DNS clustering Elixir - bénins en mode Docker local.

### 📊 PROGRESSION COMPLÈTE
1. ❌ **crypto_one_time(:aes_128_ecb, nil)** → ✅ **DB_ENC_KEY généré (16 chars)**
2. ❌ **APP_NAME not available** → ✅ **Variables transmises correctement**
3. ❌ **YAML corruption ligne 95/196** → ✅ **Indentation corrigée**
4. ❌ **Restart loop continu** → ✅ **Service stable et opérationnel**

## CORRECTION SCRIPT SOLUTION-IMMEDIATE REQUISE

Le script `SOLUTION-IMMEDIATE-REALTIME.sh` doit être corrigé pour éviter future corruption :

### ❌ CODE PROBLÉMATIQUE ACTUEL
```bash
sed -i '/realtime:/,/environment:/{
  /environment:/a\
      APP_NAME: supabase_realtime    # ← Indentation fixe incorrecte
}' docker-compose.yml
```

### ✅ CODE CORRIGÉ REQUIS
```bash
# Détection indentation existante
INDENT=$(grep -A1 "environment:" docker-compose.yml | tail -1 | sed 's/\([[:space:]]*\).*/\1/')
# Ajout avec indentation correcte
sed -i "/environment:/a\\${INDENT}APP_NAME: supabase_realtime" docker-compose.yml
# Validation immédiate
docker compose config > /dev/null || { echo "YAML invalide"; exit 1; }
```

---

## 🎯 RÉSOLUTION COMPLÈTE - 15 SEPTEMBRE 2025 19h45

**Durée totale :** 45 minutes de debugging intensif
**Problème initial :** Realtime restart loop - erreur encryption
**Problème final :** RÉSOLU - Service stable et fonctionnel
**Apprentissages :** Importance validation YAML + indentation contextuelle scripts automatiques

**🏆 SUPABASE WEEK2 INSTALLATION COMPLÈTEMENT OPÉRATIONNELLE**