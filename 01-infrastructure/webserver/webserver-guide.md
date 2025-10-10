# 🎓 Guide Débutant : Héberger un Site Web sur Raspberry Pi 5

> **De zéro à votre premier site en ligne en 30 minutes**

**Public** : Débutants complets, aucune connaissance préalable requise
**Niveau** : ⭐ Facile
**Temps** : 30 minutes - 2 heures selon votre projet

---

## 📖 Table des Matières

1. [Comprendre les Concepts](#-comprendre-les-concepts)
2. [Choisir Son Serveur Web](#-choisir-son-serveur-web)
3. [Installation Pas-à-Pas](#-installation-pas-à-pas)
4. [Mettre Votre Site en Ligne](#-mettre-votre-site-en-ligne)
5. [Rendre Votre Site Accessible](#-rendre-votre-site-accessible)
6. [Exemples Pratiques](#-exemples-pratiques)
7. [Problèmes Courants](#-problèmes-courants)

---

## 🧠 Comprendre les Concepts

### Qu'est-ce qu'un Serveur Web ?

**Analogie : Le Restaurant**

Imaginez un restaurant :
- **Votre site web** = Le menu et les plats
- **Le serveur web (Nginx/Caddy)** = Le serveur qui apporte les plats
- **Le navigateur (Chrome/Firefox)** = Le client qui mange

Quand quelqu'un visite votre site :
1. Son navigateur (client) demande une page
2. Le serveur web trouve le fichier
3. Le serveur web envoie le fichier au navigateur
4. Le navigateur affiche la page

**C'est tout !** Un serveur web est juste un programme qui envoie des fichiers.

### HTTP vs HTTPS

**Analogie : Lettre par la poste**

- **HTTP** = Carte postale
  - Tout le monde peut lire le contenu
  - Gratuit et simple
  - OK pour sites publics

- **HTTPS** = Lettre dans enveloppe scellée
  - Contenu chiffré (sécurisé)
  - Nécessite un certificat SSL
  - Obligatoire pour : login, paiements, données personnelles

**Bonne nouvelle** : Caddy fait HTTPS automatiquement gratuitement !

### Nginx vs Caddy

**Analogie : Voiture Manuelle vs Automatique**

| Nginx | Caddy |
|-------|-------|
| 🏎️ **Voiture de course** | 🚗 **Voiture moderne** |
| Plus rapide | Plus simple |
| Configuration manuelle | Configuration automatique |
| Pas d'HTTPS auto | HTTPS automatique |
| Pour experts | Pour débutants |

**Notre recommandation débutant** : Commencez avec **Caddy** !

---

## 🎯 Choisir Son Serveur Web

### Scénario 1 : Débutant, Premier Site

**✅ Utilisez Caddy**

**Pourquoi ?**
- Configuration en 3 lignes
- HTTPS automatique
- Fonctionne en 5 minutes

**Exemple** : Portfolio personnel, blog, site vitrine

```bash
# Une seule commande !
sudo DOMAIN=monsite.com EMAIL=moi@email.com \
     curl -fsSL https://raw.githubusercontent.com/.../01-caddy-deploy.sh | sudo bash
```

### Scénario 2 : Vous Avez Déjà Traefik

**✅ Utilisez Nginx**

**Pourquoi ?**
- Traefik gère déjà HTTPS
- Nginx = plus rapide
- Configuration optimisée

**Exemple** : Vous avez suivi le guide PI5-SETUP et Supabase/Traefik sont installés

```bash
# Nginx
curl -fsSL https://raw.githubusercontent.com/.../01-nginx-deploy.sh | sudo bash

# Puis intégration Traefik
curl -fsSL https://raw.githubusercontent.com/.../02-integrate-traefik.sh | sudo bash
```

### Scénario 3 : Site Local (Pas Internet)

**✅ Nginx ou Caddy, au choix**

**Exemple** : Dashboard personnel, documentation interne

```bash
# Nginx sur port 8080
sudo NGINX_PORT=8080 \
     /path/to/01-nginx-deploy.sh

# OU Caddy sur port 9000 (sans HTTPS)
sudo CADDY_PORT=9000 \
     /path/to/01-caddy-deploy.sh
```

---

## 🚀 Installation Pas-à-Pas

### Prérequis

1. **Raspberry Pi 5** allumé et connecté à Internet
2. **SSH activé** (ou écran/clavier)
3. **500 MB de RAM disponible**
4. **Connexion Internet** (pour télécharger Docker images)

### Vérification Prérequis

```bash
# SSH dans votre Pi
ssh pi@raspberrypi.local

# Vérifier RAM disponible
free -h
# Doit montrer > 500M "available"

# Vérifier Docker installé
docker --version
# Si erreur, installer Docker d'abord
```

---

### Installation Caddy (Recommandé Débutant)

#### Étape 1 : Décider du Mode

**Mode A : Avec Domaine (HTTPS automatique)**

Vous avez besoin de :
- ✅ Un nom de domaine (ex: `monsite.com`)
- ✅ DNS configuré (A record pointant vers votre IP publique)
- ✅ Ports 80 et 443 ouverts sur votre box Internet

**Mode B : Local Seulement (HTTP)**

Vous voulez :
- ✅ Accès uniquement sur votre réseau local
- ✅ Pas de configuration DNS
- ✅ Simple et rapide

#### Étape 2 : Lancer l'Installation

**Mode A : Avec Domaine**

```bash
# Remplacez par VOTRE domaine et email
sudo DOMAIN=monsite.com \
     EMAIL=moi@gmail.com \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/webserver/scripts/01-caddy-deploy.sh)
```

**Ce qui se passe** :
1. Script télécharge Caddy (image Docker ARM64)
2. Crée la structure de fichiers
3. Génère une page d'accueil par défaut
4. Démarre Caddy
5. Obtient certificat SSL (Let's Encrypt)

**Durée** : 3-5 minutes

**Mode B : Local**

```bash
# Port 9000 (ou choisissez le vôtre)
sudo CADDY_PORT=9000 \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/webserver/scripts/01-caddy-deploy.sh)
```

**Durée** : 2 minutes

#### Étape 3 : Vérifier que Ça Marche

**Mode A** : Ouvrez `https://monsite.com` dans votre navigateur
**Mode B** : Ouvrez `http://raspberrypi.local:9000`

**Vous devriez voir** : Une page d'accueil bleue avec "Caddy fonctionne !"

✅ **Félicitations !** Votre serveur web est en ligne !

---

### Installation Nginx (Alternative)

#### Étape 1 : Lancer l'Installation

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/webserver/scripts/01-nginx-deploy.sh | sudo bash
```

**Ce qui se passe** :
1. Télécharge Nginx + PHP-FPM (ARM64)
2. Crée configuration optimisée
3. Génère page d'accueil
4. Démarre les services

**Durée** : 3-5 minutes

#### Étape 2 : Vérifier

Ouvrez `http://raspberrypi.local:8080`

**Vous devriez voir** : Page d'accueil violette avec "Nginx fonctionne !"

#### Étape 3 : Ajouter HTTPS (Optionnel, via Traefik)

```bash
# Installer Traefik d'abord (choisir un scénario)
curl -fsSL https://raw.githubusercontent.com/.../01-traefik-deploy-duckdns.sh | sudo bash

# Puis intégrer Nginx
curl -fsSL https://raw.githubusercontent.com/.../02-integrate-traefik.sh | sudo bash
```

Le script vous demandera :
- Quel sous-domaine ou path utiliser
- Validation de la configuration

Après : `https://monpi.duckdns.org/www` fonctionne avec HTTPS !

---

## 📂 Mettre Votre Site en Ligne

### Où Sont Mes Fichiers ?

**Caddy** : `/home/pi/stacks/caddy/sites/mysite/`
**Nginx** : `/home/pi/stacks/webserver/sites/mysite/`

### Méthode 1 : Éditer Directement (Débutant)

```bash
# SSH dans votre Pi
ssh pi@raspberrypi.local

# Aller dans le dossier (Caddy example)
cd /home/pi/stacks/caddy/sites/mysite/

# Éditer avec nano
nano index.html
```

**Modifier le HTML** :
```html
<!DOCTYPE html>
<html>
<head>
    <title>Mon Super Site</title>
</head>
<body>
    <h1>Bienvenue sur mon site !</h1>
    <p>Ceci est mon premier site hébergé sur Raspberry Pi 5.</p>
</body>
</html>
```

**Sauvegarder** : `Ctrl+O`, `Enter`, `Ctrl+X`

**Recharger dans navigateur** : F5

✅ **C'est tout !** Vos modifications sont visibles instantanément.

### Méthode 2 : Upload depuis Votre PC (Intermédiaire)

**Avec FileZilla (Interface graphique)**

1. **Télécharger FileZilla** : https://filezilla-project.org/
2. **Connecter** :
   - Hôte : `sftp://raspberrypi.local`
   - Utilisateur : `pi`
   - Mot de passe : (votre mot de passe Pi)
   - Port : `22`
3. **Naviguer** vers `/home/pi/stacks/caddy/sites/mysite/`
4. **Glisser-déposer** vos fichiers depuis votre PC

**Avec SCP (Ligne de commande)**

```bash
# Depuis votre PC (Mac/Linux)
scp -r mon-site/* pi@raspberrypi.local:/home/pi/stacks/caddy/sites/mysite/

# Windows (avec Git Bash ou WSL)
scp -r mon-site/* pi@raspberrypi.local:/home/pi/stacks/caddy/sites/mysite/
```

### Méthode 3 : Git (Avancé)

```bash
# SSH dans Pi
ssh pi@raspberrypi.local

# Aller dans dossier
cd /home/pi/stacks/caddy/sites/mysite/

# Supprimer index.html par défaut
rm index.html

# Cloner votre repo
git clone https://github.com/vous/votre-site.git .

# Mettre à jour plus tard
git pull
```

---

## 🌍 Rendre Votre Site Accessible

### Option 1 : Réseau Local Seulement (Plus Simple)

**Votre site est accessible sur** :
- `http://raspberrypi.local:8080` (Nginx)
- `http://raspberrypi.local:9000` (Caddy mode local)

**Depuis n'importe quel appareil sur votre WiFi** :
- Téléphone
- Tablette
- Autre PC

**Avantages** :
- ✅ Aucune configuration
- ✅ Gratuit
- ✅ Sécurisé (pas accessible depuis Internet)

**Inconvénients** :
- ❌ Pas accessible hors de chez vous
- ❌ Amis/famille ne peuvent pas voir

### Option 2 : Internet (DuckDNS + Traefik)

**Gratuit, facile, HTTPS automatique**

#### Étape 1 : Créer Compte DuckDNS

1. Aller sur https://www.duckdns.org
2. Login avec Google/GitHub
3. Créer un domaine : `monpi` (gratuit)
4. Vous obtenez : `monpi.duckdns.org`

#### Étape 2 : Ouvrir Ports sur Box Internet

**Trouver interface admin de votre box** :
- Freebox : http://mafreebox.freebox.fr
- Livebox : http://192.168.1.1
- SFR Box : http://192.168.1.1

**Créer redirection de ports** :
- Port externe : `80` → Port interne : `80` → IP Pi
- Port externe : `443` → Port interne : `443` → IP Pi

**Trouver IP de votre Pi** :
```bash
hostname -I
# Ex: 192.168.1.50
```

#### Étape 3 : Installer Traefik

```bash
# Sur votre Pi
curl -fsSL https://raw.githubusercontent.com/.../01-traefik-deploy-duckdns.sh | sudo bash
```

Le script vous demandera :
- **DuckDNS subdomain** : `monpi`
- **DuckDNS token** : (copier depuis duckdns.org)

#### Étape 4 : Intégrer Votre Site

```bash
curl -fsSL https://raw.githubusercontent.com/.../02-integrate-webserver.sh | sudo bash
```

Le script vous demandera :
- **Path** : `www` (ou laissez vide pour racine)

**Résultat** :
- `https://monpi.duckdns.org/www` → Votre site
- `https://monpi.duckdns.org/studio` → Supabase (si installé)

✅ **Votre site est maintenant accessible depuis n'importe où sur Internet !**

### Option 3 : Domaine Personnalisé (Cloudflare)

**Si vous avez un domaine** (ex: `monsite.com`, acheté sur Namecheap, OVH, etc.)

#### Étape 1 : Configurer Cloudflare

1. Créer compte sur https://cloudflare.com (gratuit)
2. Ajouter votre domaine
3. Changer nameservers chez votre registrar
4. Créer API token (voir guide Traefik)

#### Étape 2 : Installer Traefik Cloudflare

```bash
curl -fsSL https://raw.githubusercontent.com/.../01-traefik-deploy-cloudflare.sh | sudo bash
```

#### Étape 3 : Intégrer Site

```bash
curl -fsSL https://raw.githubusercontent.com/.../02-integrate-webserver.sh | sudo bash
```

**Résultat** :
- `https://www.monsite.com` → Votre site
- `https://api.monsite.com` → API si besoin

---

## 💡 Exemples Pratiques

### Exemple 1 : Portfolio Personnel (HTML/CSS/JS)

**Structure** :
```
sites/mysite/
├── index.html
├── style.css
├── script.js
└── images/
    ├── photo.jpg
    └── logo.png
```

**index.html** :
```html
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Jean Dupont - Portfolio</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <header>
        <img src="images/photo.jpg" alt="Jean Dupont">
        <h1>Jean Dupont</h1>
        <p>Développeur Web</p>
    </header>

    <section id="about">
        <h2>À Propos</h2>
        <p>Passionné par le web et le self-hosting sur Raspberry Pi.</p>
    </section>

    <section id="projects">
        <h2>Projets</h2>
        <div class="project">
            <h3>Mon Super Projet</h3>
            <p>Description du projet...</p>
        </div>
    </section>

    <footer>
        <p>© 2025 Jean Dupont - Hébergé sur Raspberry Pi 5</p>
    </footer>

    <script src="script.js"></script>
</body>
</html>
```

**style.css** :
```css
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: Arial, sans-serif;
    line-height: 1.6;
    color: #333;
}

header {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    color: white;
    text-align: center;
    padding: 4rem 2rem;
}

header img {
    border-radius: 50%;
    width: 150px;
    height: 150px;
    object-fit: cover;
    border: 5px solid white;
}

section {
    padding: 2rem;
    max-width: 800px;
    margin: 0 auto;
}

.project {
    background: #f4f4f4;
    padding: 1rem;
    margin: 1rem 0;
    border-left: 4px solid #667eea;
}

footer {
    background: #333;
    color: white;
    text-align: center;
    padding: 1rem;
}
```

**Upload** :
```bash
scp -r portfolio/* pi@raspberrypi.local:/home/pi/stacks/caddy/sites/mysite/
```

### Exemple 2 : Blog Statique (Hugo)

**Sur votre PC** :
```bash
# Installer Hugo
# Mac
brew install hugo

# Linux
sudo apt install hugo

# Windows
choco install hugo-extended

# Créer blog
hugo new site mon-blog
cd mon-blog

# Choisir thème
git init
git submodule add https://github.com/theNewDynamic/gohugo-theme-ananke themes/ananke
echo "theme = 'ananke'" >> hugo.toml

# Créer article
hugo new posts/mon-premier-article.md

# Générer site
hugo

# Upload vers Pi
scp -r public/* pi@raspberrypi.local:/home/pi/stacks/caddy/sites/mysite/
```

### Exemple 3 : Application React

**Sur votre PC** :
```bash
# Créer app React
npx create-react-app mon-app
cd mon-app

# Développer...
# Modifier src/App.js etc.

# Build pour production
npm run build

# Upload vers Pi
scp -r build/* pi@raspberrypi.local:/home/pi/stacks/caddy/sites/mysite/
```

---

## 🐛 Problèmes Courants

### "curl: command not found"

**Solution** :
```bash
sudo apt update
sudo apt install curl
```

### "Permission denied"

**Solution** :
```bash
# Utiliser sudo
sudo curl -fsSL https://... | sudo bash

# Ou corriger ownership
sudo chown -R pi:pi /home/pi/stacks/
```

### "Port 8080 already in use"

**Solution** :
```bash
# Trouver processus
sudo lsof -i :8080

# Arrêter container si c'est Docker
docker stop <container_name>

# Ou changer port
sudo NGINX_PORT=9000 /path/to/script.sh
```

### "502 Bad Gateway" (Nginx + PHP)

**Solution** :
```bash
# Vérifier PHP-FPM
docker logs webserver-php

# Restart
cd /home/pi/stacks/webserver
docker compose restart
```

### "Let's Encrypt failed" (Caddy)

**Causes possibles** :
- ❌ Ports 80/443 pas ouverts sur box Internet
- ❌ DNS pas configuré correctement
- ❌ IP publique changée

**Solutions** :
```bash
# Vérifier DNS
dig monsite.com
# Doit pointer vers votre IP publique

# Vérifier ports
curl https://portchecker.co/check?port=80

# Voir logs Caddy
docker logs caddy-webserver

# Tester mode HTTP d'abord
sudo CADDY_PORT=8080 /path/to/01-caddy-deploy.sh
```

### "Connection refused"

**Solutions** :
```bash
# Vérifier container running
docker ps

# Restart
cd /home/pi/stacks/caddy
docker compose restart

# Vérifier firewall
sudo ufw status
sudo ufw allow 8080/tcp
```

### "Out of memory"

**Solutions** :
```bash
# Voir RAM utilisée
free -h

# Arrêter services non utilisés
docker stop <autres-containers>

# Désactiver PHP si pas utilisé
sudo ENABLE_PHP=no /path/to/01-nginx-deploy.sh
```

---

## 📚 Checklist Progression

### Niveau Débutant ⭐

- [ ] Installer Caddy en mode local
- [ ] Modifier la page index.html
- [ ] Ajouter une image
- [ ] Créer 2-3 pages HTML
- [ ] Lier les pages entre elles
- [ ] Uploader fichiers via SFTP

### Niveau Intermédiaire ⭐⭐

- [ ] Installer Caddy avec domaine (HTTPS)
- [ ] Configurer DuckDNS + Traefik
- [ ] Déployer site React/Vue
- [ ] Configurer virtual hosts (multiple sites)
- [ ] Utiliser Git pour déployer
- [ ] Installer Nginx avec PHP-FPM

### Niveau Avancé ⭐⭐⭐

- [ ] Configurer Cloudflare + Traefik
- [ ] Déployer WordPress
- [ ] Setup CI/CD avec Gitea
- [ ] Load balancing (multiple Pis)
- [ ] Monitoring avec Grafana
- [ ] Optimisation performance

---

## 🎓 Ressources d'Apprentissage

### Apprendre HTML/CSS/JavaScript

- **FreeCodeCamp** : https://www.freecodecamp.org (gratuit)
- **MDN Web Docs** : https://developer.mozilla.org (documentation)
- **Codecademy** : https://www.codecademy.com (interactif)

### Apprendre Docker

- **Docker Documentation** : https://docs.docker.com
- **Play with Docker** : https://labs.play-with-docker.com (navigateur)

### Communautés

- **Reddit** : r/selfhosted, r/raspberry_pi
- **Discord** : Serveurs Raspberry Pi, Self-Hosting
- **Forum** : https://www.raspberrypi.org/forums/

---

## 🎯 Prochaines Étapes

### Vous Avez Votre Site ? Maintenant :

1. **Sécuriser** :
   - ✅ HTTPS activé
   - ✅ Firewall configuré (UFW)
   - ✅ Mises à jour régulières

2. **Optimiser** :
   - ✅ Activer compression (gzip)
   - ✅ Configurer cache
   - ✅ Optimiser images

3. **Monitorer** :
   - ✅ Installer monitoring stack
   - ✅ Configurer alertes
   - ✅ Backup automatique

4. **Étendre** :
   - ✅ Ajouter blog
   - ✅ Créer API
   - ✅ Déployer applications

---

## 💬 Besoin d'Aide ?

**Pas de panique !** Tout le monde débute quelque part.

- **Documentation complète** : [README.md](README.md)
- **Exemples** : [examples/](examples/)
- **Issues GitHub** : https://github.com/iamaketechnology/pi5-setup/issues

---

**Félicitations !** 🎉

Vous savez maintenant héberger un site web sur votre Raspberry Pi 5.

Vous avez appris :
- ✅ Les bases des serveurs web
- ✅ La différence Nginx/Caddy
- ✅ Installation et configuration
- ✅ Upload de fichiers
- ✅ Rendre accessible sur Internet
- ✅ Résolution de problèmes

**Continue d'apprendre, expérimenter et builder !** 🚀

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-10-06

[← Retour README](README.md) | [Exemples →](examples/)
