# 📧 Guide Configuration DNS OVH pour Mailu

> **Guide pas-à-pas pour configurer les DNS records OVH requis par Mailu**

---

## 📋 Table des Matières

1. [Prérequis](#prérequis)
2. [Records à Configurer](#records-à-configurer)
3. [Procédure Détaillée](#procédure-détaillée)
4. [Vérification](#vérification)
5. [Troubleshooting](#troubleshooting)

---

## 🎯 Prérequis

- Domaine enregistré chez OVH
- Accès à l'interface OVH (Manager)
- IP publique du serveur Mailu
- Script Mailu lancé (affiche les DNS à configurer)

---

## 📊 Records à Configurer

| Priority | Type | Nom | Valeur | Exemple |
|----------|------|-----|--------|---------|
| **1** | A | mail.votredomaine.com | IP_SERVEUR | 82.65.55.248 |
| **2** | MX | votredomaine.com | mail.votredomaine.com | Priorité 10 |
| **3** | TXT (SPF) | votredomaine.com | v=spf1 mx -all | - |
| **4** | TXT (DMARC) | _dmarc.votredomaine.com | v=DMARC1; p=quarantine; rua=... | - |
| **5** | TXT (DKIM) | dkim._domainkey.votredomaine.com | [Fourni après install] | - |

---

## 📝 Procédure Détaillée

### 0️⃣ Accès à la Zone DNS

1. Connectez-vous à l'interface OVH : https://www.ovh.com/manager/
2. **Web Cloud** → **Noms de domaine** → Sélectionnez votre domaine
3. Onglet **Zone DNS**
4. Cliquez sur **Ajouter une entrée**

---

### 1️⃣ A Record (IPv4)

**Objectif** : Pointer `mail.votredomaine.com` vers l'IP du serveur.

#### Interface OVH

```
Type de champ : A

Sous-domaine : mail
  (résultat : mail.votredomaine.com)

TTL : Par défaut

Cible : 82.65.55.248
  (remplacez par VOTRE IP serveur)
```

#### Résultat Final

```
mail.iamaketechnology.fr. IN A 82.65.55.248
```

#### Validation

Cliquez sur **Suivant** → **Valider**

---

### 2️⃣ MX Record (Mail Exchange)

**Objectif** : Indiquer que `mail.votredomaine.com` reçoit les emails.

#### Interface OVH

```
Type de champ : MX

Sous-domaine : [LAISSER VIDE]
  (pour configurer le domaine racine)

TTL : Par défaut

Priorité : 10

Cible : mail.iamaketechnology.fr.
  (avec le POINT FINAL)
```

#### Résultat Final

```
iamaketechnology.fr. IN MX 10 mail.iamaketechnology.fr.
```

#### Validation

Cliquez sur **Suivant** → **Valider**

---

### ⚠️ CRITIQUE : Supprimer les Anciens MX OVH

**AVANT DE CONTINUER**, supprimez les anciens MX OVH :

1. Dans **Zone DNS**, filtrez par type **MX**
2. Supprimez ces 3 records :
   ```
   ❌ MX 1 mx1.mail.ovh.net
   ❌ MX 5 mx2.mail.ovh.net
   ❌ MX 100 mx3.mail.ovh.net
   ```

**Pourquoi ?** Si vous gardez les anciens MX avec priorité 1, OVH recevra TOUS les emails au lieu de votre serveur !

3. Cliquez sur l'icône **Poubelle** à droite de chaque record
4. Confirmez la suppression

**Résultat attendu** : Un seul MX record pointant vers `mail.votredomaine.com`

---

### 3️⃣ SPF Record (Sender Policy Framework)

**Objectif** : Autoriser uniquement votre serveur MX à envoyer des emails.

#### Interface OVH

```
Type de champ : SPF ou TXT

Sous-domaine : [LAISSER VIDE]

TTL : Par défaut

❌ Autoriser l'IP de votredomaine.fr ? → NON

✅ Autoriser les serveurs MX ? → OUI

❌ Autoriser tous les serveurs se terminant par... ? → NON

Autres serveurs (a:, mx:, ptr:, ip4:, ip6:) : [LAISSER VIDE]

Include : [LAISSER VIDE]
  ⚠️ SURTOUT PAS "mx.ovh.com" !

Tous les hôtes décrits ? → "Oui, je suis sûr" (pour -all)
  OU "Oui, mais utiliser le safe mode" (pour ~all)
```

#### Résultat Final

**Strict (recommandé)** :
```
iamaketechnology.fr. IN TXT "v=spf1 mx -all"
```

**Souple** :
```
iamaketechnology.fr. IN TXT "v=spf1 mx ~all"
```

**Différence** :
- `-all` = **rejette** les emails non autorisés (recommandé)
- `~all` = **marque comme suspect** mais accepte

#### Validation

Vérifiez que le champ généré est `v=spf1 mx -all` → **Valider**

---

### 4️⃣ DMARC Record (Domain-based Message Authentication)

**Objectif** : Politique de traitement des emails non conformes.

#### Interface OVH

```
Type de champ : DMARC ou TXT

Sous-domaine : _dmarc
  (résultat : _dmarc.votredomaine.com)

TTL : Par défaut

Version : DMARC1

Règle pour le domaine : quarantine
  (mise en quarantaine des emails suspects)

Pourcentage des messages filtrés : 100
  (ou laisser vide = 100%)

URI de création de rapports globaux : mailto:admin@votredomaine.com
  (email pour recevoir les rapports)

Règle pour les sous-domaines : quarantine

Mode d'alignement pour SPF : Relaxed
```

#### Résultat Final

```
_dmarc.iamaketechnology.fr. IN TXT "v=DMARC1;p=quarantine;pct=100;rua=mailto:admin@iamaketechnology.fr;sp=quarantine;aspf=r;"
```

#### Validation

Cliquez sur **Suivant** → **Valider**

---

### 5️⃣ DKIM Record (DomainKeys Identified Mail)

**⚠️ À FAIRE APRÈS l'installation Mailu !**

#### Génération DKIM

Après installation Mailu, récupérez la clé DKIM :

```bash
ssh pi@pi5.local
cd ~/stacks/mailu
docker compose exec admin flask mailu config-export --format=dkim
```

**Sortie exemple** :
```
dkim._domainkey.iamaketechnology.fr. 600 IN TXT "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4..."
```

#### Interface OVH

```
Type de champ : TXT

Sous-domaine : dkim._domainkey

TTL : Par défaut

Cible : v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4...
  (COPIER LA SORTIE COMPLÈTE de la commande)
```

#### Résultat Final

```
dkim._domainkey.iamaketechnology.fr. IN TXT "v=DKIM1; k=rsa; p=MIGfMA0..."
```

#### Validation

Cliquez sur **Suivant** → **Valider**

---

## ✅ Checklist Finale

Avant de continuer l'installation Mailu, vérifiez :

- [ ] **A Record** : mail.votredomaine.com → IP_SERVEUR
- [ ] **MX Record** : votredomaine.com → mail.votredomaine.com (priorité 10)
- [ ] **MX OVH supprimés** : Plus de mx1.mail.ovh.net, mx2.mail.ovh.net, mx3.mail.ovh.net
- [ ] **SPF** : v=spf1 mx -all
- [ ] **DMARC** : v=DMARC1;p=quarantine;rua=mailto:...
- [ ] **DKIM** : À faire après installation

---

## 🔍 Vérification DNS

### Via Terminal

```bash
# Vérifier A record
dig mail.iamaketechnology.fr +short
# Résultat attendu : 82.65.55.248

# Vérifier MX record
dig MX iamaketechnology.fr +short
# Résultat attendu : 10 mail.iamaketechnology.fr.

# Vérifier SPF
dig TXT iamaketechnology.fr +short | grep spf
# Résultat attendu : "v=spf1 mx -all"

# Vérifier DMARC
dig TXT _dmarc.iamaketechnology.fr +short
# Résultat attendu : "v=DMARC1;p=quarantine..."
```

### Via Outils en Ligne

- **MX Toolbox** : https://mxtoolbox.com/SuperTool.aspx
- **DNS Checker** : https://dnschecker.org
- **DMARC Analyzer** : https://dmarcian.com/dmarc-inspector/

---

## 🛠️ Troubleshooting

### Problème 1 : "Propagation DNS lente"

**Symptôme** : Les DNS ne se mettent pas à jour immédiatement.

**Solution** :
- Attendre 5-30 minutes pour propagation
- Max 24h pour propagation mondiale
- Vérifier avec `dig` depuis plusieurs localisations

---

### Problème 2 : "MX pointe vers OVH"

**Symptôme** : `dig MX` retourne `mx1.mail.ovh.net`

**Solution** :
1. Vérifier que les anciens MX OVH sont bien supprimés
2. Attendre propagation DNS (5-30 min)
3. Vider cache DNS local :
   ```bash
   # Mac
   sudo dscacheutil -flushcache

   # Linux
   sudo systemd-resolve --flush-caches
   ```

---

### Problème 3 : "SPF contient include:mx.ovh.com"

**Symptôme** : `dig TXT` retourne `v=spf1 include:mx.ovh.com`

**Solution** :
1. Supprimer l'ancien record SPF OVH
2. Recréer avec `v=spf1 mx -all` uniquement
3. Attendre propagation

---

### Problème 4 : "DKIM invalide"

**Symptôme** : Emails marqués comme spam malgré DKIM.

**Solution** :
1. Vérifier que la clé DKIM est complète (très longue chaîne)
2. Pas d'espaces dans le TXT record
3. Regénérer DKIM si nécessaire :
   ```bash
   docker compose exec admin flask mailu admin admin iamaketechnology.fr --mode=dkim
   ```

---

## 📚 Ressources

- **Documentation Mailu** : https://mailu.io/master/
- **OVH Guides DNS** : https://docs.ovh.com/fr/domains/
- **RFC SPF** : https://tools.ietf.org/html/rfc7208
- **RFC DMARC** : https://tools.ietf.org/html/rfc7489
- **RFC DKIM** : https://tools.ietf.org/html/rfc6376

---

## 🎯 Prochaines Étapes

Une fois tous les DNS configurés :

1. Retournez au terminal où le script Mailu attend
2. Tapez `y` pour continuer l'installation
3. Attendez la fin de l'installation (~20-30 min)
4. Ajoutez le record DKIM (étape 5)
5. Testez l'envoi/réception d'emails

---

**Version** : 1.0.0
**Date** : 2025-10-21
**Auteur** : PI5-SETUP Project
**Testé avec** : OVH Manager (2025), Mailu 2.0

---

[← Retour Guide Mailu](../README.md) | [Troubleshooting Email →](TROUBLESHOOTING.md)
