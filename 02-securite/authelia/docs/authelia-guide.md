# 🎓 Guide Débutant - Sécurité Centralisée

## C'est Quoi ?

### SSO (Single Sign-On) - Un Seul Mot de Passe pour Tout

Imaginez que vous avez **un seul trousseau de clés** pour ouvrir votre maison, votre voiture, votre bureau et votre garage. C'est exactement ce qu'est le SSO : **un seul mot de passe pour accéder à tous vos services**.

Au lieu d'avoir :
- Un mot de passe pour Grafana
- Un autre pour Portainer
- Un autre pour Home Assistant
- Et encore un autre pour chaque service...

Vous avez **UN SEUL mot de passe** qui ouvre tout !

### 2FA (Authentification à Deux Facteurs) - La Double Vérification

Le 2FA, c'est comme **un portier de boîte de nuit** :
1. **Première vérification** : Il vérifie votre carte d'identité (votre mot de passe)
2. **Deuxième vérification** : Il vérifie que vous êtes bien sur la liste (le code de votre téléphone)

C'est aussi comme **un badge d'entreprise + code PIN** :
- Le badge prouve que vous avez le droit d'entrer
- Le code PIN prouve que c'est bien VOUS qui utilisez le badge

**Pourquoi c'est important ?** Même si quelqu'un vole votre mot de passe, il ne pourra pas entrer sans le code de votre téléphone !

## Pourquoi Authelia ?

### Protéger Vos Dashboards Sensibles

Vos services contiennent des **informations critiques** :

- **Grafana** = Toutes les données de performance de votre serveur (CPU, mémoire, disque...)
- **Portainer** = Contrôle total de tous vos conteneurs Docker
- **Home Assistant** = Contrôle de votre maison (lumières, caméras, alarmes...)

**Sans protection**, n'importe qui sur votre réseau pourrait :
- Voir vos statistiques
- Arrêter vos services
- Modifier vos configurations

### Les Avantages d'Authelia

✅ **Un seul mot de passe à retenir** au lieu de 10 ou 20
✅ **Sécurité renforcée** avec le 2FA obligatoire
✅ **Gestion centralisée** : un seul endroit pour gérer tous les accès
✅ **Protection automatique** : ajoutez un nouveau service, il est automatiquement protégé

## Comment Ça Marche ?

### Le Workflow (Flux de Connexion)

Voici ce qui se passe quand vous essayez d'accéder à un service protégé :

```
┌─────────────────────────────────────────────────────────────┐
│                    WORKFLOW AUTHELIA                        │
└─────────────────────────────────────────────────────────────┘

1. Vous tapez : http://grafana.local
                         ↓
2. Authelia intercepte : "Halte ! Qui êtes-vous ?"
                         ↓
3. Vous entrez votre mot de passe
                         ↓
4. Authelia demande : "Code 2FA SVP"
                         ↓
5. Vous entrez le code de votre téléphone (123456)
                         ↓
6. Authelia : "OK, vous pouvez passer !"
                         ↓
7. Vous accédez à Grafana

```

### Explication Étape par Étape

1. **Vous demandez l'accès** : Comme sonner à la porte d'une maison
2. **Authelia intercepte** : Le portier vient vous voir
3. **Vous vous identifiez** : Vous montrez votre carte d'identité (mot de passe)
4. **Vérification 2FA** : Le portier demande un code secret
5. **Vous donnez le code** : Code à 6 chiffres de votre téléphone
6. **Accès accordé** : La porte s'ouvre
7. **Vous entrez** : Vous utilisez le service normalement

## Configuration Première Fois

### Étape 1 : Se Connecter à Authelia

1. Ouvrez votre navigateur
2. Allez sur : `http://auth.local` (ou l'URL configurée)
3. Vous verrez la page de connexion Authelia

### Étape 2 : Première Connexion

**Identifiants par défaut** (à changer immédiatement !) :
- Utilisateur : `admin`
- Mot de passe : celui configuré lors de l'installation

### Étape 3 : Activer le 2FA

1. **Cliquez sur "Configuration 2FA"** dans le menu
2. **Scannez le QR Code** avec une application comme :
   - Google Authenticator (iOS/Android)
   - Microsoft Authenticator (iOS/Android)
   - Authy (iOS/Android)

3. **Comment scanner** :
   - Ouvrez l'application sur votre téléphone
   - Cliquez sur "+" ou "Ajouter un compte"
   - Pointez l'appareil photo vers le QR code
   - L'application ajoute automatiquement Authelia

4. **Notez le code de secours** : Si vous perdez votre téléphone, ce code permet de récupérer l'accès

### Étape 4 : Tester la Protection

1. **Déconnectez-vous** d'Authelia
2. **Essayez d'accéder à Grafana** : `http://grafana.local`
3. **Vous êtes redirigé** vers Authelia → C'est normal !
4. **Entrez vos identifiants** + code 2FA
5. **Vous accédez à Grafana** → Protection active ✅

## Scénarios Réels

### Scénario 1 : Protéger Grafana (Dashboard Métriques)

**Contexte** : Grafana affiche les performances de votre serveur (CPU, RAM, température...)

**Sans Authelia** :
- N'importe qui sur votre réseau peut voir ces données
- Risque : Un attaquant sait quand votre serveur est vulnérable

**Avec Authelia** :
- Seuls les utilisateurs autorisés voient les métriques
- Double vérification (mot de passe + 2FA)
- Logs de toutes les connexions

**Configuration** :
```yaml
# Dans traefik/authelia-rules.yml
- domain: grafana.local
  policy: two_factor  # Exige mot de passe + 2FA
```

### Scénario 2 : Portainer (Gestion Docker)

**Contexte** : Portainer permet de démarrer/arrêter/supprimer des conteneurs Docker

**Danger sans protection** :
- Quelqu'un pourrait arrêter tous vos services
- Supprimer vos conteneurs
- Accéder aux logs sensibles

**Avec Authelia** :
- Accès réservé aux administrateurs
- Traçabilité complète (qui a fait quoi)
- Impossible d'accéder sans 2FA

**Configuration** :
```yaml
- domain: portainer.local
  policy: two_factor
  subject: "group:admins"  # Seulement le groupe admins
```

### Scénario 3 : Multi-Utilisateurs (Famille/Équipe)

**Cas d'usage** : Vous voulez que votre famille accède à Home Assistant, mais pas à Portainer

**Solution avec Authelia** :

1. **Créez des groupes** :
   - `admins` : Vous (accès total)
   - `famille` : Votre famille (accès limité)

2. **Définissez les règles** :
```yaml
# Tout le monde peut accéder à Home Assistant
- domain: home.local
  policy: two_factor
  subject: "group:famille"

# Seuls les admins accèdent à Portainer
- domain: portainer.local
  policy: two_factor
  subject: "group:admins"
```

3. **Créez les utilisateurs** :
```yaml
users:
  admin:
    password: "votre_mot_de_passe_hashé"
    groups:
      - admins

  marie:
    password: "mot_de_passe_marie_hashé"
    groups:
      - famille

  lucas:
    password: "mot_de_passe_lucas_hashé"
    groups:
      - famille
```

## Troubleshooting Débutant

### Problème 1 : "Mon 2FA ne Marche Pas"

**Symptômes** : Le code à 6 chiffres est refusé

**Solutions** :

1. **Vérifiez l'heure de votre téléphone** :
   - Le 2FA dépend de l'heure exacte
   - Allez dans Réglages → Date et heure
   - Activez "Heure automatique"

2. **Attendez le prochain code** :
   - Les codes changent toutes les 30 secondes
   - Ne tapez pas le code trop vite (il peut avoir expiré)

3. **Resynchronisez l'application** :
   - Google Authenticator : Réglages → Correction de l'heure
   - Appuyez sur "Synchroniser maintenant"

4. **Code de secours** :
   - Utilisez le code de secours noté lors de l'activation 2FA
   - Réinitialisez ensuite le 2FA

### Problème 2 : "Je Suis Bloqué d'un Service"

**Symptômes** : Authelia bloque l'accès à un service que vous devriez pouvoir utiliser

**Solutions** :

1. **Vérifiez votre groupe** :
   - Vous êtes dans `groupe:famille` mais le service exige `groupe:admins`
   - Demandez à l'admin de vous ajouter au bon groupe

2. **Bypass temporaire** (pour tester) :
```yaml
# Dans authelia-rules.yml
- domain: service-bloque.local
  policy: bypass  # TEMPORAIRE : Accès sans authentification
```

3. **Vérifiez les logs** :
```bash
docker logs authelia
# Cherchez : "Access denied for user X to domain Y"
```

### Problème 3 : "J'ai Oublié Mon Mot de Passe"

**Solutions** :

1. **Reset par l'administrateur** :
   - L'admin peut générer un nouveau hash de mot de passe
   - Il modifie `users_database.yml`

2. **Générer un nouveau hash** :
```bash
docker exec -it authelia authelia crypto hash generate pbkdf2 --password 'nouveau_mot_de_passe'
```

3. **Remplacer dans la config** :
```yaml
users:
  votre_nom:
    password: "$nouveau_hash_généré"
```

4. **Redémarrer Authelia** :
```bash
docker restart authelia
```

### Problème 4 : "Code de Secours Perdu + Téléphone Perdu"

**Situation d'urgence** : Vous ne pouvez plus vous connecter

**Solution radicale** :

1. **Désactivez temporairement le 2FA** :
```yaml
# Dans configuration.yml
default_2fa_method: ""  # Désactive le 2FA
```

2. **Redémarrez Authelia**
3. **Connectez-vous avec juste le mot de passe**
4. **Réactivez le 2FA** et scannez un nouveau QR code
5. **Remettez le 2FA obligatoire** :
```yaml
default_2fa_method: "totp"
```

---

## Aide Rapide

**Commandes Utiles** :

```bash
# Voir les logs en temps réel
docker logs -f authelia

# Redémarrer Authelia
docker restart authelia

# Vérifier la configuration
docker exec authelia authelia validate-config

# Générer un hash de mot de passe
docker exec authelia authelia crypto hash generate pbkdf2 --password 'votre_mdp'
```

**Ressources** :
- Documentation officielle : https://www.authelia.com
- Communauté Discord Authelia : https://discord.authelia.com
- Issues GitHub : https://github.com/authelia/authelia/issues

---

**🎉 Félicitations !** Vous savez maintenant comment utiliser Authelia pour sécuriser vos services avec SSO et 2FA. N'hésitez pas à expérimenter et à poser des questions !
