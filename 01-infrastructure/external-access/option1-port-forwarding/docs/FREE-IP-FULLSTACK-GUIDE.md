# 🔷 Guide : Obtenir une IP Full-Stack chez Free

> **Problème** : Impossible d'ouvrir les ports 80/443 sur Freebox (champs en rouge)
> **Solution** : Demander une IP Full-Stack (gratuite) pour accéder à tous les ports

---

## 🎯 Pourquoi ce guide ?

### Le problème des IP partagées

Free (et certains autres FAI) partagent parfois les adresses IP publiques entre plusieurs abonnés. Résultat :

- ❌ **Plage de ports limitée** : Vous ne pouvez ouvrir que les ports 16384-32767 (ou 32768-49151)
- ❌ **Ports 80/443 bloqués** : Impossible de configurer HTTPS avec Let's Encrypt
- ❌ **Champs en rouge** : L'interface Freebox refuse d'enregistrer port 80 ou 443

### La solution : IP Full-Stack

Free propose gratuitement une **IP Full-Stack** (dédiée, non partagée) qui vous donne :

- ✅ **Accès à TOUS les ports** (1-65535)
- ✅ **Configuration HTTPS standard** (ports 80/443)
- ✅ **Compatibilité Let's Encrypt** (certificats SSL automatiques)
- ✅ **IP fixe** (bonus : l'IP ne change plus)

**Coût** : 🆓 **100% Gratuit** (inclus dans l'abonnement)
**Durée** : ⏱️ 2 minutes de demande + 30 minutes d'activation

---

## 🚀 Procédure Complète (5 étapes)

### Étape 1 : Vérifier si vous avez une IP partagée

#### Méthode rapide : Tester l'ouverture de port

1. Allez sur http://mafreebox.freebox.fr
2. **Paramètres de la Freebox** → **Gestion des ports**
3. Essayez de créer une règle avec **port 80**

**Résultat** :
- ❌ **Champ rouge** → Vous avez une IP partagée (continuez ce guide)
- ✅ **Champ vert** → Vous avez déjà une IP Full-Stack (ce guide n'est pas nécessaire)

---

### Étape 2 : Demander l'IP Full-Stack

#### 2.1 - Connexion à votre espace Free

Ouvrez votre navigateur et allez sur :

🔗 **https://subscribe.free.fr/login/**

**Identifiants** :
- Identifiant Free : (8 chiffres - voir courrier Free ou espace client)
- Mot de passe : (votre mot de passe espace client)

#### 2.2 - Navigation vers IP Full-Stack

Une fois connecté :

1. Cliquez sur l'onglet **"Ma Freebox"**
2. Section **"Fonctionnalités"** ou **"Paramètres Internet"**
3. Cherchez **"Demander une adresse IP fixe V4 full-stack"**
4. Cliquez sur le bouton **"Activer"** ou **"Demander"**

**Captures d'écran typiques** :

```
┌─────────────────────────────────────────────┐
│ Ma Freebox                                  │
├─────────────────────────────────────────────┤
│ 📡 Paramètres Internet                      │
│                                             │
│ IP actuelle : 88.162.xxx.xxx (partagée)    │
│                                             │
│ [Demander une IP fixe V4 full-stack]       │
│                                             │
│ ℹ️  Gratuit - Activation sous 30 minutes   │
└─────────────────────────────────────────────┘
```

#### 2.3 - Confirmation

Après validation, vous verrez un message du type :

```
✅ L'adresse IP 82.65.xxx.xxx vous a été attribuée.
   Redémarrez votre Freebox dans environ 30 minutes.
```

**Notez cette IP** : Elle sera votre IP publique fixe définitive.

---

### Étape 3 : Attendre l'activation (30 minutes)

**Durée** : ~20-30 minutes

Pendant ce temps, Free configure votre nouvelle IP dans leurs systèmes.

**Que faire pendant l'attente ?** ☕
- Prendre un café
- Lire la documentation Traefik : [traefik-setup.md](../../traefik-setup.md)
- Préparer votre domaine DuckDNS (si pas déjà fait)

**Ne PAS faire** :
- ❌ Redémarrer la Freebox maintenant (attendez les 30 minutes)
- ❌ Modifier d'autres paramètres Internet

---

### Étape 4 : Redémarrer la Freebox (OBLIGATOIRE)

**Après 30 minutes**, redémarrez votre Freebox pour activer la nouvelle IP :

#### Méthode 1 : Via l'interface web (recommandée)

1. Allez sur http://mafreebox.freebox.fr
2. **Système** (icône engrenage en haut à droite)
3. **Redémarrer la Freebox**
4. Confirmez

**Durée** : 2-3 minutes (voyants de la box vont clignoter)

#### Méthode 2 : Débrancher/rebrancher

1. Débranchez l'alimentation de la Freebox Server (boîtier noir)
2. Attendez 10 secondes
3. Rebranchez
4. Attendez que tous les voyants soient fixes (~2-3 minutes)

---

### Étape 5 : Vérifier l'activation

#### 5.1 - Vérifier votre nouvelle IP publique

```bash
curl https://api.ipify.org
```

**Résultat attendu** : L'IP doit correspondre à celle annoncée par Free (82.65.xxx.xxx)

#### 5.2 - Tester l'ouverture de port 80/443

Retournez sur http://mafreebox.freebox.fr

1. **Paramètres de la Freebox** → **Gestion des ports**
2. Créez une règle de test :
   - **IP destination** : 192.168.1.XXX (votre Pi)
   - **Port de début** : 80
   - **Port de fin** : 80
   - **Port de destination** : 80
   - **Protocole** : TCP

**Résultat** :
- ✅ **Champ vert et sauvegarde OK** → IP Full-Stack activée ! 🎉
- ❌ **Toujours rouge** → Voir troubleshooting ci-dessous

---

## 🎉 Résultat Final

### Avant (IP partagée)

```
╔════════════════════════════════════════════╗
║ ❌ Ports disponibles : 32768-49151         ║
║ ❌ Port 80/443 : BLOQUÉS                   ║
║ ❌ HTTPS Let's Encrypt : IMPOSSIBLE        ║
║ ❌ IP publique : Partagée (change souvent) ║
╚════════════════════════════════════════════╝
```

### Après (IP Full-Stack)

```
╔════════════════════════════════════════════╗
║ ✅ Ports disponibles : 1-65535 (TOUS)     ║
║ ✅ Port 80/443 : ACCESSIBLES               ║
║ ✅ HTTPS Let's Encrypt : FONCTIONNEL       ║
║ ✅ IP publique : Dédiée et FIXE            ║
╚════════════════════════════════════════════╝
```

**Vous pouvez maintenant** :
- ✅ Configurer Port Forwarding 80/443
- ✅ Utiliser Let's Encrypt pour HTTPS automatique
- ✅ Accéder à votre Pi via `https://monpi.duckdns.org`

---

## 🆘 Troubleshooting

### Problème 1 : "Le port 80 est toujours rouge après 30 minutes"

**Causes possibles** :
1. Freebox pas redémarrée
2. Activation pas encore effective (attendre 5-10 minutes de plus)
3. Cache DNS/réseau

**Solutions** :
```bash
# Vérifier votre IP publique actuelle
curl https://api.ipify.org

# Comparer avec l'IP annoncée par Free
# Si différente → Redémarrer à nouveau la Freebox

# Vider cache réseau (sur votre Mac/PC)
# Mac : Relancer le navigateur
# PC : ipconfig /flushdns
```

---

### Problème 2 : "La demande échoue sur le site Free"

**Message** : "Vous avez déjà une IP Full-Stack"

**Solution** : Vérifiez votre configuration actuelle
1. Espace Free → Ma Freebox → Paramètres Internet
2. Regardez le type d'IP indiqué
3. Si déjà "Full-Stack", le problème vient d'ailleurs (voir problème 3)

---

### Problème 3 : "J'ai l'IP Full-Stack mais port 80 toujours rouge"

**Cause possible** : Règle UPnP conflictuelle ou bug interface

**Solutions** :

#### Solution A : Vider les règles UPnP IGD
1. Freebox OS → **Paramètres de la Freebox**
2. **Mode avancé** (en haut à droite)
3. Section **Redirections de ports**
4. Onglet **IGD** (UPnP)
5. Supprimer toutes les règles automatiques pour ports 80/443

#### Solution B : Utiliser l'API Freebox (avancé)
```bash
# Documentation API Freebox
# https://dev.freebox.fr/sdk/os/

# Requiert configuration OAuth
# Voir : https://mafreebox.freebox.fr/api_version
```

#### Solution C : Mode bridge + routeur externe
Si vraiment bloqué, envisager :
- Mode bridge sur Freebox
- Routeur externe (TP-Link, etc.) pour gérer le NAT

---

### Problème 4 : "Je ne trouve pas la section IP Full-Stack"

**Interfaces différentes selon modèle Freebox** :

#### Freebox Revolution/Delta/Pop
- Espace Free → **Ma Freebox** → **Mes Services** → IP Full-Stack

#### Freebox Mini 4K
- Souvent déjà en Full-Stack par défaut

#### Freebox Crystal (ancienne)
- Peut ne pas supporter Full-Stack (upgrade recommandé)

**Vérification générale** :
```bash
# Depuis votre Pi, testez un port < 16384
curl -I http://VOTRE-IP-PUBLIQUE:8080

# Si connexion → Vous avez Full-Stack
# Si refusé → IP partagée
```

---

## 📊 Comparaison IP Partagée vs Full-Stack

| Critère | IP Partagée | IP Full-Stack |
|---------|-------------|---------------|
| **Coût** | Inclus | Inclus (gratuit) |
| **Ports accessibles** | 16384-65535 (~50%) | 1-65535 (100%) |
| **Port 80 (HTTP)** | ❌ Bloqué | ✅ Accessible |
| **Port 443 (HTTPS)** | ❌ Bloqué | ✅ Accessible |
| **Let's Encrypt** | ❌ Impossible | ✅ Fonctionnel |
| **IP fixe** | ❌ Change parfois | ✅ Fixe définitif |
| **Délai activation** | Immédiat | ~30 minutes |
| **Reverse proxy** | ⚠️ Ports alternatifs | ✅ Standard (80/443) |

**Recommandation** : 🏆 **Demandez toujours l'IP Full-Stack** si vous faites du self-hosting sérieux.

---

## ❓ FAQ

### Q1 : Est-ce vraiment gratuit ?

**R:** Oui, 100% gratuit et inclus dans tous les abonnements Freebox (fibre + ADSL).

---

### Q2 : Puis-je revenir en arrière ?

**R:** Oui, vous pouvez recontacter Free pour repasser en IP partagée, mais ce n'est généralement pas souhaitable.

---

### Q3 : Mon IP fixe peut-elle changer ?

**R:** En théorie non, mais Free peut la changer dans de rares cas :
- Maintenance infrastructure majeure
- Déménagement de votre ligne
- Résiliation/réabonnement

**Conseil** : Utilisez DuckDNS qui mettra automatiquement à jour le DNS si l'IP change.

---

### Q4 : IPv6 Full-Stack aussi ?

**R:** L'IP Full-Stack V4 concerne uniquement IPv4. Pour IPv6, vous avez déjà un préfixe /56 dédié par défaut chez Free.

---

### Q5 : Cela affecte-t-il mes autres services ?

**R:** Non, tous vos services (TV, téléphone, Internet) continuent de fonctionner normalement.

---

### Q6 : Puis-je demander une IP Full-Stack sur une ligne 4G Free ?

**R:** Non, les box 4G utilisent du CGNAT (Carrier-Grade NAT) et n'ont pas d'IP Full-Stack disponible.

**Alternative** : Utilisez Tailscale (Option 3) ou Cloudflare Tunnel (Option 2) qui fonctionnent derrière CGNAT.

---

## 🔗 Ressources Utiles

### Documentation officielle Free
- **Espace Abonné** : https://subscribe.free.fr
- **Assistance Free** : https://www.free.fr/assistance/
- **Forum Freebox** : https://forum.universfreebox.com/
- **API Freebox** : https://dev.freebox.fr/sdk/os/

### Outils de test
- **Test IP publique** : https://api.ipify.org ou https://ifconfig.me
- **Test ports ouverts** : https://www.yougetsignal.com/tools/open-ports/
- **DNS Lookup** : https://mxtoolbox.com/DNSLookup.aspx

### Guides complémentaires
- **Configuration DuckDNS** : [../guides/DUCKDNS-SETUP.md](../guides/DUCKDNS-SETUP.md)
- **Setup Port Forwarding** : [../../scripts/01-traefik-deploy-duckdns.sh](../../scripts/01-traefik-deploy-duckdns.sh)
- **Troubleshooting Traefik** : [../../docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)

---

## 📝 Checklist de vérification finale

Après avoir suivi ce guide, vérifiez :

- [ ] IP publique correspond à celle annoncée par Free
- [ ] Port 80 configurable sur Freebox (champ vert)
- [ ] Port 443 configurable sur Freebox (champ vert)
- [ ] Règles de redirection créées (80 et 443 → IP Pi)
- [ ] DuckDNS résout vers la bonne IP publique
- [ ] Test externe : `curl -I http://VOTRE-IP-PUBLIQUE`
- [ ] Traefik déployé et HTTPS fonctionnel
- [ ] Certificat Let's Encrypt généré automatiquement

**Si tous les points sont cochés** : ✅ **Configuration réussie !**

---

## 🎓 Pour aller plus loin

Maintenant que vous avez votre IP Full-Stack :

1. **Configurez Traefik** : [../../../traefik/traefik-setup.md](../../../traefik/traefik-setup.md)
2. **Sécurisez votre Pi** : [../../../security/hardening-guide.md](../../../security/hardening-guide.md)
3. **Configurez backups** : [../../../backup/backup-automation.md](../../../backup/backup-automation.md)
4. **Monitoring** : [../../../monitoring/setup-guide.md](../../../monitoring/setup-guide.md)

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-01-XX
**Testé sur** : Freebox Revolution, Delta, Pop
**Auteur** : [@votre-username](https://github.com/votre-username)

---

**🎉 Félicitations !** Vous avez maintenant une IP Full-Stack et pouvez utiliser les ports standards pour votre self-hosting !
