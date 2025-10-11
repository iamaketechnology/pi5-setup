# 📚 Guide Débutant - Authelia

> **Pour qui ?** Débutants en authentification et sécurité d'accès.
> **Durée de lecture** : 10 minutes
> **Niveau** : Débutant (aucune connaissance préalable requise)

---

## 🤔 C'est quoi Authelia ?

### En une phrase
**Authelia = Un portail de connexion unique et sécurisé pour protéger vos applications web.**

### Analogie simple
Imaginez Authelia comme le garde de sécurité à l'entrée d'un immeuble de bureaux. Au lieu de montrer votre badge à chaque porte (chaque application), vous le montrez une seule fois au garde (Authelia), qui vérifie qui vous êtes et vous donne ensuite un pass pour accéder à tous les étages (applications) autorisés.

---

## 🎯 À quoi ça sert concrètement ?

### Use Cases (Exemples d'utilisation)

#### 1. **Sécuriser l'accès à vos services auto-hébergés**
Vous hébergez des services comme Grafana, Portainer, ou Nextcloud et vous ne voulez pas qu'ils soient exposés publiquement.
```
Authelia fait :
✅ Ajoute une page de connexion devant ces services.
✅ Force l'authentification à deux facteurs (2FA).
✅ Empêche les accès non autorisés.
```

#### 2. **Centraliser la gestion des utilisateurs**
Vous avez plusieurs utilisateurs pour différentes applications et vous en avez marre de gérer les mots de passe partout.
```
Authelia fait :
✅ Gère tous les utilisateurs et mots de passe en un seul endroit.
✅ Permet aux utilisateurs d'avoir un seul mot de passe pour tout.
```

---

## 🧩 Les Composants (Expliqués simplement)

### 1. **Portail d'Authentification** - Le Garde
**C'est quoi ?** C'est la page web où vous entrez votre nom d'utilisateur et votre mot de passe. C'est le point d'entrée unique pour tous vos services protégés.

**Pourquoi c'est important ?** C'est le cœur du système qui vérifie votre identité. Il peut aussi demander un deuxième facteur (comme un code sur votre téléphone) pour plus de sécurité.

### 2. **Fichiers de Configuration (YAML)** - Les Règles du Garde
**C'est quoi ?** Ce sont des fichiers texte où vous écrivez les règles. Par exemple : "L'utilisateur 'admin' peut accéder à Grafana, mais 'invite' ne peut accéder qu'à Homepage."

**Tu peux** :
- Définir les utilisateurs et leurs mots de passe.
- Configurer l'authentification à deux facteurs.
- Lister les domaines et sous-domaines à protéger.
- Définir des règles d'accès complexes.

---

## 🚀 Comment l'utiliser ? (Pas à pas)

### Étape 1 : Définir un utilisateur

1. **Ouvrir le fichier `users_database.yml`** :
   C'est là que la liste des utilisateurs est stockée.

2. **Ajouter un nouvel utilisateur** :
   ```yaml
   users:
     john:
       displayname: "John Doe"
       password: "VOTRE_HASH_DE_MOT_DE_PASSE"
       email: john.doe@example.com
       groups:
         - admins
         - dev
   ```
   **Note** : Ne mettez jamais de mot de passe en clair ! Utilisez la commande fournie par Authelia pour "hasher" votre mot de passe.

### Étape 2 : Protéger une nouvelle application

1. **Ouvrir votre fichier de configuration de Traefik** (ou autre reverse proxy).
2. **Ajouter le "middleware" Authelia** à votre service.
   ```yaml
   http:
     routers:
       mon-app:
         rule: "Host(`mon-app.domaine.com`)"
         service: "service-mon-app"
         entryPoints:
           - "websecure"
         middlewares:
           - "authelia@docker" # C'est cette ligne qui active la protection !
   ```
3. **Redémarrer Traefik** pour appliquer les changements.
4. **Résultat** : En allant sur `mon-app.domaine.com`, vous serez redirigé vers le portail Authelia avant de pouvoir accéder à l'application.

---

## 🆘 Problèmes Courants

### "Too many redirects" (Trop de redirections)

**Cause** : Souvent un problème de configuration entre Authelia et le reverse proxy (Traefik, Nginx). Les cookies ne sont pas correctement partagés entre les domaines.

**Vérifications** :
1. **Configuration du domaine de session** dans `configuration.yml` :
   ```yaml
   session:
     domain: "domaine.com" # Doit être le domaine parent de vos services
   ```
2. **Assurez-vous que tous vos services sont bien sur des sous-domaines** du domaine de session. (ex: `app1.domaine.com`, `app2.domaine.com`)

---

## 📚 Ressources pour Débutants

- **Documentation Officielle Authelia** : [https://www.authelia.com/](https://www.authelia.com/)
- **Intégration avec Traefik** : [https://www.authelia.com/integration/proxies/traefik/](https://www.authelia.com/integration/proxies/traefik/)

🎉 **Bonne sécurisation !**
