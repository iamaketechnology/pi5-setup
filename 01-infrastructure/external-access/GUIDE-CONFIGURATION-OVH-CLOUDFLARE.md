# 🌐 Guide Configuration DNS OVH → Cloudflare Tunnel

**Domaine**: `iamaketechnology.fr`
**Objectif**: Exposer tes services Raspberry Pi sur Internet via sous-domaines
**Durée**: 10-15 minutes

---

## 📋 Prérequis

✅ Domaine OVH actif (`iamaketechnology.fr`)
✅ Zone DNS créée sur OVH
✅ Cloudflare Tunnel créé sur le Pi5 (via wizard)
✅ Tunnel ID obtenu (fourni par le script d'installation)

---

## 🎯 Architecture Finale

```
Internet
  ↓
iamaketechnology.fr (OVH DNS)
  ↓
Cloudflare CDN (proxy + SSL/TLS)
  ↓
Cloudflare Tunnel (sur Pi5)
  ↓
Services Docker (Certidoc, Supabase, Portainer, etc.)
```

**Sous-domaines prévus**:
- `certidoc.iamaketechnology.fr` → Certidoc (port 9000)
- `studio.iamaketechnology.fr` → Supabase Studio (port 3000)
- `api.iamaketechnology.fr` → Supabase API (port 8000)
- `portainer.iamaketechnology.fr` → Portainer (port 9000)
- `n8n.iamaketechnology.fr` → n8n (port 5678)
- Tous les futurs services via `*.iamaketechnology.fr`

---

## 📝 Étape 1 : Récupérer l'ID du Tunnel Cloudflare

Après avoir lancé le wizard Cloudflare sur le Pi5, tu vas obtenir un **Tunnel ID** (format: `abc123def-456g-789h-012i-jklmnopqrstu`).

### Sur ton Pi5, exécute:

```bash
ssh pi@pi5.local
sudo cloudflared tunnel list
```

**Exemple de sortie**:
```
ID                                   NAME                CREATED
abc123def-456g-789h-012i-jklmnopqrstu pi5-generic-tunnel  2025-10-20T20:00:00Z
```

📌 **Note bien le Tunnel ID** (première colonne) - tu en auras besoin pour la configuration DNS.

**Alternative**: Le script d'installation affiche aussi le Tunnel ID dans le résumé final.

---

## 🌍 Étape 2 : Configuration DNS sur OVH

### 2.1 Accéder à la Zone DNS OVH

1. Connecte-toi sur **https://www.ovh.com/manager/**
2. Va dans **"Web Cloud"** → **"Noms de domaine"**
3. Clique sur **`iamaketechnology.fr`**
4. Clique sur l'onglet **"Zone DNS"**

### 2.2 Supprimer les enregistrements par défaut (si présents)

OVH crée parfois des enregistrements par défaut qui peuvent entrer en conflit. **Supprime ces enregistrements** s'ils existent:

| Type | Nom | Cible | Action |
|------|-----|-------|--------|
| A | @ | 0.0.0.0 ou IP OVH | ❌ Supprimer |
| AAAA | @ | :: ou IPv6 OVH | ❌ Supprimer |
| MX | @ | mx.ovh.net | ⚠️ Garder si tu utilises email OVH |

**⚠️ Important**: Si tu utilises les emails OVH (@iamaketechnology.fr), **garde les enregistrements MX**!

### 2.3 Ajouter le Wildcard CNAME vers Cloudflare

Clique sur **"Ajouter une entrée"** et choisis **"CNAME"**:

| Champ | Valeur |
|-------|--------|
| **Sous-domaine** | `*` |
| **Cible** | `<TUNNEL-ID>.cfargotunnel.com` |
| **TTL** | `300` (5 minutes) |

**Exemple concret** (remplace `<TUNNEL-ID>` par ton vrai Tunnel ID):
```
Sous-domaine: *
Cible: abc123def-456g-789h-012i-jklmnopqrstu.cfargotunnel.com
TTL: 300
```

✅ Clique sur **"Valider"**

### 2.4 Ajouter l'enregistrement pour le domaine racine

Clique sur **"Ajouter une entrée"** et choisis **"CNAME"**:

| Champ | Valeur |
|-------|--------|
| **Sous-domaine** | `@` (vide = domaine racine) |
| **Cible** | `<TUNNEL-ID>.cfargotunnel.com` |
| **TTL** | `300` |

✅ Clique sur **"Valider"**

### 2.5 Résultat final dans la Zone DNS OVH

Tu dois avoir ces 2 enregistrements actifs:

```
Type    Nom    Cible                                          TTL
CNAME   *      abc123def-456g-789h-012i-jklmnopqrstu.cfargotunnel.com   300
CNAME   @      abc123def-456g-789h-012i-jklmnopqrstu.cfargotunnel.com   300
```

### 2.6 Sauvegarder les modifications

⚠️ **OVH peut demander de "Rafraîchir" la zone DNS** - clique sur le bouton en haut à droite.

---

## ⏱️ Étape 3 : Attendre la Propagation DNS

Les modifications DNS peuvent prendre **5 à 30 minutes** pour se propager.

### Vérifier la propagation

Depuis ton terminal (Mac ou Pi):

```bash
# Vérifier le wildcard
nslookup certidoc.iamaketechnology.fr

# Vérifier le domaine racine
nslookup iamaketechnology.fr
```

**Résultat attendu** (après propagation):
```
Non-authoritative answer:
certidoc.iamaketechnology.fr  canonical name = abc123def-456g-789h-012i-jklmnopqrstu.cfargotunnel.com
```

Si tu vois ton **Tunnel ID Cloudflare** dans la réponse → ✅ **DNS configuré correctement!**

### Outils de vérification en ligne

- **https://dnschecker.org/** → Saisir `certidoc.iamaketechnology.fr` (vérifier depuis plusieurs localisations)
- **https://mxtoolbox.com/DNSLookup.aspx** → Vérifier les enregistrements CNAME

---

## 🔧 Étape 4 : Configurer les Applications dans le Tunnel

Maintenant que le DNS est configuré, ajoute tes services au tunnel Cloudflare.

### Sur ton Pi5, exécute:

```bash
ssh pi@pi5.local
cd /root/stacks/cloudflare-tunnel-generic
# OU le répertoire où le tunnel a été installé
```

### Ajouter Certidoc

```bash
sudo bash scripts/02-add-app-to-tunnel.sh \
  --name certidoc \
  --hostname certidoc.iamaketechnology.fr \
  --service certidoc-frontend:9000
```

### Ajouter Supabase Studio

```bash
sudo bash scripts/02-add-app-to-tunnel.sh \
  --name studio \
  --hostname studio.iamaketechnology.fr \
  --service supabase-studio:3000
```

### Ajouter Supabase API

```bash
sudo bash scripts/02-add-app-to-tunnel.sh \
  --name api \
  --hostname api.iamaketechnology.fr \
  --service supabase-kong:8000
```

### Ajouter Portainer

```bash
sudo bash scripts/02-add-app-to-tunnel.sh \
  --name portainer \
  --hostname portainer.iamaketechnology.fr \
  --service portainer:9000
```

### Ajouter n8n

```bash
sudo bash scripts/02-add-app-to-tunnel.sh \
  --name n8n \
  --hostname n8n.iamaketechnology.fr \
  --service n8n:5678
```

### Lister toutes les apps configurées

```bash
sudo bash scripts/04-list-tunnel-apps.sh
```

---

## 🧪 Étape 5 : Tester l'Accès HTTPS

Après 5-10 minutes de propagation DNS, teste tes services:

### Depuis ton navigateur

```
https://certidoc.iamaketechnology.fr
https://studio.iamaketechnology.fr
https://api.iamaketechnology.fr
https://portainer.iamaketechnology.fr
https://n8n.iamaketechnology.fr
```

✅ **Tu devrais voir tes applications** avec **SSL/TLS automatique** (cadenas vert) fourni par Cloudflare!

### Depuis le terminal (curl)

```bash
# Tester Certidoc
curl -I https://certidoc.iamaketechnology.fr

# Résultat attendu:
# HTTP/2 200
# server: cloudflare
```

---

## 🔒 Étape 6 : Configuration Sécurité (Optionnel mais Recommandé)

### 6.1 Activer le Proxy Cloudflare (Orange Cloud)

Par défaut, les CNAME sont en **"DNS Only"** (gris). Pour bénéficier de:
- Protection DDoS
- Cache CDN
- SSL/TLS automatique
- Firewall

**Tu dois activer le proxy Orange Cloud** sur Cloudflare Dashboard:

1. Va sur **https://dash.cloudflare.com/**
2. Ajoute `iamaketechnology.fr` (si pas déjà fait via le tunnel)
3. Dans **DNS → Records**, clique sur les enregistrements et active **"Proxied"** (nuage orange)

### 6.2 Configurer le Mode SSL/TLS

Dans Cloudflare Dashboard → **SSL/TLS → Overview**:

- **Mode recommandé**: `Full (strict)` si ton Pi5 a SSL/TLS activé
- **Mode simple**: `Flexible` si ton Pi5 utilise HTTP uniquement

Pour Cloudflare Tunnel, utilise **`Full (strict)`** car le tunnel crée automatiquement une connexion chiffrée.

### 6.3 Activer HSTS (HTTP Strict Transport Security)

Dans Cloudflare Dashboard → **SSL/TLS → Edge Certificates**:

- Active **"Always Use HTTPS"** ✅
- Active **"HSTS"** ✅
  - Max Age: `6 months`
  - Include subdomains: ✅
  - Preload: ✅

---

## 🛠️ Dépannage

### Problème 1: "DNS_PROBE_FINISHED_NXDOMAIN"

**Cause**: DNS pas encore propagé ou mal configuré

**Solution**:
1. Vérifie que les CNAME sont bien configurés sur OVH
2. Attends 15-30 minutes supplémentaires
3. Flush le cache DNS local:
   ```bash
   # Mac
   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

   # Windows
   ipconfig /flushdns

   # Linux
   sudo systemd-resolve --flush-caches
   ```

### Problème 2: "ERR_SSL_VERSION_OR_CIPHER_MISMATCH"

**Cause**: SSL/TLS mal configuré sur Cloudflare

**Solution**:
- Va dans Cloudflare Dashboard → SSL/TLS
- Change le mode vers `Flexible` temporairement
- Teste l'accès
- Repasse en `Full (strict)` après avoir vérifié que le tunnel fonctionne

### Problème 3: "502 Bad Gateway"

**Cause**: Le service Docker n'est pas accessible ou le nom du container est incorrect

**Solution**:
1. Vérifie que le container tourne:
   ```bash
   ssh pi@pi5.local
   docker ps | grep certidoc
   ```
2. Vérifie les logs du tunnel:
   ```bash
   docker logs cloudflared-tunnel
   ```
3. Vérifie le nom du service dans la config:
   ```bash
   cat /root/stacks/cloudflare-tunnel-generic/config/config.yml
   ```

### Problème 4: Wildcard ne fonctionne pas

**Cause**: OVH peut avoir des restrictions sur les wildcards CNAME

**Solution alternative**: Créer des enregistrements CNAME individuels pour chaque sous-domaine:

```
CNAME   certidoc   abc123def-456g-789h-012i-jklmnopqrstu.cfargotunnel.com
CNAME   studio     abc123def-456g-789h-012i-jklmnopqrstu.cfargotunnel.com
CNAME   api        abc123def-456g-789h-012i-jklmnopqrstu.cfargotunnel.com
CNAME   portainer  abc123def-456g-789h-012i-jklmnopqrstu.cfargotunnel.com
CNAME   n8n        abc123def-456g-789h-012i-jklmnopqrstu.cfargotunnel.com
```

---

## 📊 Résumé de la Configuration

| Service | Sous-domaine | Container Docker | Port |
|---------|-------------|------------------|------|
| **Certidoc** | certidoc.iamaketechnology.fr | certidoc-frontend | 9000 |
| **Supabase Studio** | studio.iamaketechnology.fr | supabase-studio | 3000 |
| **Supabase API** | api.iamaketechnology.fr | supabase-kong | 8000 |
| **Portainer** | portainer.iamaketechnology.fr | portainer | 9000 |
| **n8n** | n8n.iamaketechnology.fr | n8n | 5678 |

---

## 🎉 Félicitations!

Tes services Raspberry Pi sont maintenant accessibles depuis Internet avec:

✅ **SSL/TLS automatique** (HTTPS avec cadenas vert)
✅ **Protection DDoS** via Cloudflare
✅ **Cache CDN** pour performances optimales
✅ **Sous-domaines illimités** via wildcard
✅ **Pas d'ouverture de ports** sur ta box Internet
✅ **IP publique masquée** (sécurité renforcée)

---

## 📚 Ressources Utiles

- **Cloudflare Tunnel Docs**: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
- **OVH Zone DNS**: https://www.ovh.com/manager/
- **DNS Checker**: https://dnschecker.org/
- **SSL Labs Test**: https://www.ssllabs.com/ssltest/

---

## 🆘 Besoin d'Aide?

Si tu rencontres des problèmes:

1. Vérifie les logs du tunnel:
   ```bash
   ssh pi@pi5.local
   docker logs -f cloudflared-tunnel
   ```

2. Liste les apps configurées:
   ```bash
   sudo bash /root/stacks/cloudflare-tunnel-generic/scripts/04-list-tunnel-apps.sh
   ```

3. Teste la connectivité Cloudflare:
   ```bash
   sudo cloudflared tunnel info pi5-generic-tunnel
   ```

4. Ouvre une issue sur GitHub: https://github.com/iamaketechnology/pi5-setup/issues

---

**Version**: 1.0.0
**Dernière mise à jour**: 2025-10-20
**Auteur**: PI5-SETUP Project
