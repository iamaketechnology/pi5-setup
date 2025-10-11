# 📚 Guide Débutant - Gitea Stack

> **Pour qui ?** Débutants en Git et CI/CD (Intégration Continue)
> **Durée de lecture** : 20 minutes
> **Niveau** : Débutant (connaissance basique de Git recommandée)

---

## 🤔 C'est Quoi Gitea ?

### En une phrase
**Gitea = GitHub hébergé chez toi sur ton Raspberry Pi (léger, rapide, gratuit).**

### Analogie simple
Imagine que **GitHub** est comme un grand hôtel 5 étoiles où tu loues une chambre pour ranger ton code :
- C'est confortable, mais **tu paies** pour les chambres privées
- Tu dépends de **leurs règles** (conditions d'utilisation)
- Ils peuvent **voir** ce que tu stockes (même en privé)

**Gitea**, c'est comme **construire ta propre maison** :
- Tout est **à toi** (contrôle total)
- **Gratuit** (sauf l'électricité de ton Pi, ~2€/an)
- **Privé** réellement (personne ne peut accéder à tes données)
- Tu peux inviter qui tu veux (amis, collègues, famille)

---

## 🎯 À Quoi Ça Sert Concrètement ?

### Use Cases (Exemples d'utilisation)

#### 1. **Développeur Freelance - Projets Clients Privés**
Tu travailles sur 5 projets clients en parallèle :
```
Gitea fait :
✅ Héberger tous les projets en privé (GitHub gratuit = 1 seul privé)
✅ Gérer les versions du code (Git)
✅ Tracker les bugs et features (Issues)
✅ Documenter les projets (Wiki intégré)
✅ Déployer automatiquement sur push (CI/CD)
```

**Exemple concret** :
- Projet Client A : Site e-commerce → Push sur `main` = déploiement auto sur serveur client
- Projet Client B : API Node.js → Tests automatiques à chaque commit
- Projet Client C : Application React → Build automatique + notifications Discord

---

#### 2. **Startup en Phase Prototype**
Ton équipe de 3 personnes développe une app :
```
Gitea fait :
✅ Code partagé entre développeurs
✅ Revue de code (Pull Requests)
✅ Gestion des tâches (Issues + Milestones)
✅ Releases versionnées (v1.0.0, v1.1.0, etc.)
✅ CI/CD gratuit (tests + déploiement auto)
```

**Économie** :
- GitHub Team : 4$ x 3 users x 12 mois = **144$/an**
- Gitea sur Pi5 : **0$/an** (+ électricité ~2€/an)

---

#### 3. **Étudiant - Portfolio et Projets Universitaires**
Tu as 10+ projets scolaires et personnels :
```
Gitea fait :
✅ Backup automatique de tous tes projets
✅ Historique complet (jamais perdre de code)
✅ Démo facile pour recruteurs (URLs propres)
✅ Collaboration sur projets de groupe
```

**Exemple workflow** :
1. Tu codes ton TP sur ton laptop
2. `git push` → Sauvegarde automatique sur ton Pi
3. Le prof demande le rendu → Tu donnes un lien vers ton Gitea (propre, professionnel)
4. Bonus : Workflow CI qui vérifie que le code compile avant chaque push

---

#### 4. **Amateur - Backup et Synchronisation**
Tu bricolles du code le weekend :
```
Gitea fait :
✅ Backup de tes scripts (Python, Bash, etc.)
✅ Sync entre plusieurs machines (desktop, laptop, Pi)
✅ Miroir de tes repos GitHub (backup au cas où)
✅ Hébergement de documentation (Markdown)
```

**Use case** :
- Tu as un script domotique qui contrôle tes lumières
- Stocké sur Gitea → Historique de toutes les versions
- Si tu casses quelque chose → `git revert` et tout marche à nouveau

---

#### 5. **Famille - Projets Collaboratifs**
Ton ado apprend à coder, ton conjoint fait du web design :
```
Gitea fait :
✅ Chacun son compte utilisateur
✅ Projets personnels privés
✅ Projets partagés (famille/team)
✅ Apprentissage Git en environnement safe
```

---

## 🆚 Pourquoi Gitea vs GitHub/GitLab ?

### Gitea vs GitHub

| Critère | GitHub (Gratuit) | Gitea (Self-Hosted) |
|---------|------------------|---------------------|
| **Prix** | Gratuit (limité) | 0€ (sauf électricité ~2€/an) |
| **Repos privés** | Illimités (depuis 2019) | Illimités |
| **Collaborateurs privés** | Illimités | Illimités |
| **CI/CD gratuit** | 2000 minutes/mois | Illimité (ton Pi) |
| **Stockage** | 1 GB repos + 500 MB packages | Limité par ton disque (100GB+ facile) |
| **Vitesse LAN** | ~50-100 Mbps (Internet) | ~1000 Mbps (réseau local) |
| **Contrôle données** | Microsoft contrôle tout | Tu contrôles 100% |
| **Vie privée** | Scan automatique du code | Aucun scan externe |
| **Disponibilité** | Dépend Internet + status GitHub | Fonctionne sans Internet (local) |
| **Packages Docker** | 500 MB gratuit | Illimité |

**Gitea est meilleur si** :
- ✅ Tu veux le contrôle complet de tes données
- ✅ Tu as besoin de CI/CD illimité gratuit
- ✅ Tu veux tester/expérimenter sans limites
- ✅ Tu veux apprendre l'administration Git

**GitHub est meilleur si** :
- ✅ Tu veux contribuer à l'open source (écosystème)
- ✅ Tu as besoin de visibilité publique (portfolio)
- ✅ Tu ne veux pas gérer un serveur
- ✅ Tu travailles avec des gens qui utilisent déjà GitHub

**L'idéal** : Les deux !
- GitHub pour projets open source publics
- Gitea pour projets privés/expérimentation

---

### Gitea vs GitLab

| Critère | GitLab (Self-Hosted) | Gitea |
|---------|----------------------|-------|
| **RAM requise** | 4-8 GB minimum | 300-500 MB |
| **Installation** | Complexe (1h+) | Simple (5 min) |
| **Performance Pi** | Très lent (pas recommandé) | Rapide et fluide |
| **Complexité** | Énorme (CI/CD/Registry/etc.) | Simple, épuré |
| **Démarrage** | 30-60 secondes | 2-3 secondes |

**Verdict** : Sur un Raspberry Pi, Gitea gagne haut la main (GitLab est trop lourd).

---

## 🧩 Comment Ça Marche ?

### Architecture Simple

```
┌─────────────────────────────────────────────────────────────┐
│                     TOI (Développeur)                        │
│                                                              │
│  💻 Laptop/Desktop                                          │
│  ├─ Code dans VSCode                                        │
│  ├─ git add .                                               │
│  ├─ git commit -m "Fix bug"                                 │
│  └─ git push                                                │
└────────────────────┬────────────────────────────────────────┘
                     │ (SSH ou HTTPS)
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              🏠 GITEA (Sur ton Raspberry Pi)                │
│                                                              │
│  📦 Stockage Git                                            │
│  ├─ Repositories (projets)                                  │
│  ├─ Issues (bugs/features)                                  │
│  ├─ Pull Requests (revue code)                              │
│  └─ Wiki (documentation)                                    │
│                                                              │
│  🤖 Gitea Actions (CI/CD)                                   │
│  ├─ Détecte le push                                         │
│  ├─ Lance les tests automatiques                            │
│  ├─ Build le projet                                         │
│  └─ Déploie si tests OK                                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              🚀 DÉPLOIEMENT AUTOMATIQUE                     │
│                                                              │
│  ✅ Site web mis à jour                                     │
│  ✅ Docker image créée                                      │
│  ✅ Notification envoyée                                    │
│  ✅ Backup effectué                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 📖 Les Concepts Git Essentiels

### 1. Repository (Repo) 📦
**C'est quoi ?** Un dossier qui contient :
- Ton code
- L'historique complet de tous les changements
- Les branches (versions parallèles)

**Analogie** : Comme un classeur avec toutes les versions successives d'un document Word, mais automatique.

**Exemple** :
```bash
# Créer un nouveau repo
mkdir mon-projet
cd mon-projet
git init  # Transforme le dossier en repo Git

# Ajouter des fichiers
echo "print('Hello')" > app.py
git add app.py
git commit -m "Premier commit"
```

---

### 2. Commit 💾
**C'est quoi ?** Une sauvegarde instantanée de ton projet à un moment T.

**Analogie** : Comme une photo de ton code. Tu peux toujours revenir à cette "photo" plus tard.

**Exemple** :
```bash
# Modifier un fichier
echo "print('Hello World')" > app.py

# Voir ce qui a changé
git status
# → app.py modifié

# Sauvegarder le changement
git add app.py
git commit -m "Ajouter Hello World"
```

**Résultat** : Tu as maintenant 2 commits (2 versions de ton projet).

---

### 3. Branch (Branche) 🌿
**C'est quoi ?** Une version parallèle de ton projet pour tester des choses sans casser la version principale.

**Analogie** : Comme un brouillon. Tu testes une nouvelle feature dans le brouillon, et si ça marche, tu la copies dans le document final.

**Exemple** :
```bash
# Créer une branche pour une nouvelle feature
git branch nouvelle-feature
git checkout nouvelle-feature
# ou en une commande : git checkout -b nouvelle-feature

# Développer la feature
echo "def calculer(): return 2+2" >> app.py
git commit -am "Ajouter fonction calculer"

# Revenir à la branche principale
git checkout main

# Fusionner la feature
git merge nouvelle-feature
```

**Branches courantes** :
- `main` ou `master` : Version stable principale
- `develop` : Version de développement
- `feature/nom` : Nouvelle fonctionnalité
- `fix/bug` : Correction de bug

---

### 4. Push / Pull 🔄
**C'est quoi ?**
- **Push** : Envoyer tes commits locaux vers Gitea
- **Pull** : Récupérer les commits de Gitea vers ton PC

**Analogie** : Comme Dropbox/Google Drive, mais pour du code avec historique complet.

**Exemple** :
```bash
# Envoyer tes changements locaux vers Gitea
git push origin main

# Récupérer les changements d'un collègue depuis Gitea
git pull origin main
```

---

### 5. Pull Request (PR) / Merge Request 🔀
**C'est quoi ?** Demander à quelqu'un de vérifier ton code avant de le fusionner dans la branche principale.

**Analogie** : Comme soumettre un devoir à un prof pour relecture avant publication finale.

**Workflow** :
1. Tu crées une branche `feature/login`
2. Tu développes la fonctionnalité login
3. Tu push la branche sur Gitea
4. Tu ouvres une Pull Request dans l'interface Gitea
5. Ton collègue revoit le code, commente
6. Tu corriges selon les retours
7. Il approuve → Merge dans `main`

---

### 6. Issues (Tickets) 🐛
**C'est quoi ?** Un système de tickets pour suivre bugs et features à développer.

**Exemple d'utilisation** :
```
Issue #1 : Bug - Login ne fonctionne pas sur Firefox
Issue #2 : Feature - Ajouter mode sombre
Issue #3 : Amélioration - Optimiser les requêtes SQL
```

**Dans chaque issue** :
- Description du problème/feature
- Assignation à un développeur
- Labels (bug, feature, urgent, etc.)
- Commentaires et discussions
- Milestones (version cible : v1.0, v2.0, etc.)

---

## 🤖 Gitea Actions (CI/CD) - Le Robot Automatique

### C'est Quoi CI/CD ?

**CI** = Continuous Integration (Intégration Continue)
**CD** = Continuous Deployment (Déploiement Continu)

**Analogie simple** :
Imagine que tu as un **robot assistant** qui :
1. **Surveille** ton code 24/7
2. **Teste** automatiquement à chaque changement
3. **Déploie** si tout est OK
4. **T'alerte** si quelque chose casse

**Sans CI/CD** :
```
1. Tu codes
2. Tu push sur Gitea
3. Tu testes manuellement (30 min)
4. Tu déploies manuellement sur le serveur (15 min)
5. Tu vérifies que ça marche (10 min)
6. Total : 55 minutes par déploiement
```

**Avec CI/CD** :
```
1. Tu codes
2. Tu push sur Gitea
3. 🤖 Le robot fait tout automatiquement (2 min)
4. Tu reçois une notification : "✅ Déployé avec succès"
5. Total : 2 minutes
```

---

### Comment Ça Marche ?

#### 1. Workflow = Recette de Cuisine

Un **workflow** est un fichier YAML qui dit au robot quoi faire.

**Exemple simple** (`.gitea/workflows/hello.yml`) :
```yaml
name: Hello World

# Quand déclencher le robot ?
on:
  push:  # À chaque push
    branches:
      - main  # Sur la branche main

# Que doit faire le robot ?
jobs:
  dire-bonjour:
    runs-on: ubuntu-latest  # Environnement Linux
    steps:
      - name: Afficher message
        run: echo "Bonjour depuis Gitea Actions !"
```

**Résultat** :
- Tu push du code → Le robot affiche "Bonjour depuis Gitea Actions !"

---

#### 2. Triggers (Déclencheurs)

**Quand le robot se réveille ?**

```yaml
# À chaque push
on: push

# Seulement sur main
on:
  push:
    branches:
      - main

# Sur Pull Request
on: pull_request

# Tous les jours à 2h du matin (backup)
on:
  schedule:
    - cron: '0 2 * * *'

# Manuellement (bouton dans Gitea UI)
on: workflow_dispatch
```

---

#### 3. Exemple Réel : Tests Automatiques

**Workflow Node.js** (`.gitea/workflows/test.yml`) :
```yaml
name: Tests Automatiques

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      # Étape 1 : Récupérer le code
      - name: Checkout code
        uses: actions/checkout@v4

      # Étape 2 : Installer Node.js
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      # Étape 3 : Installer dépendances
      - name: Install dependencies
        run: npm install

      # Étape 4 : Lancer les tests
      - name: Run tests
        run: npm test

      # Étape 5 : Notifier si succès
      - name: Notify success
        if: success()
        run: echo "✅ Tests OK !"
```

**Ce qui se passe** :
1. Tu push du code
2. Le robot récupère ton code
3. Il installe Node.js
4. Il installe tes dépendances (`npm install`)
5. Il lance les tests (`npm test`)
6. Si tests OK → ✅
7. Si tests échouent → ❌ (tu reçois une notification)

---

#### 4. Exemple Avancé : Déploiement Automatique

**Workflow de déploiement** :
```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Build l'application
      - name: Build
        run: npm run build

      # Déployer via SSH
      - name: Deploy to server
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd /var/www/mon-app
            git pull
            npm install
            pm2 restart mon-app

      # Notifier sur Discord
      - name: Discord notification
        run: |
          curl -X POST ${{ secrets.DISCORD_WEBHOOK }} \
            -H 'Content-Type: application/json' \
            -d '{"content":"✅ Déployé en production !"}'
```

**Résultat** :
- Push sur `main` → Build automatique → Déploiement → Notification Discord

---

## 🚀 Installation Pas-à-Pas

### Prérequis
- Raspberry Pi 5 avec Docker installé
- 15 minutes de temps
- Connexion SSH au Pi

---

### Étape 1 : Installer Gitea (1 commande)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-gitea-stack/scripts/01-gitea-deploy.sh | sudo bash
```

**Ce que fait le script** :
1. Télécharge Gitea (version ARM64 optimisée)
2. Configure la base de données PostgreSQL
3. Crée les dossiers nécessaires
4. Lance Gitea dans Docker
5. Configure les sauvegardes automatiques

**Durée** : ~5 minutes

---

### Étape 2 : Premier Login

1. **Ouvre ton navigateur** :
   ```
   http://IP_DU_PI:3000
   ```
   (Remplace `IP_DU_PI` par l'IP de ton Pi, ex: `192.168.1.100:3000`)

2. **Configuration initiale** (première visite uniquement) :
   - Type de base de données : **PostgreSQL** (pré-configuré)
   - Titre du site : "Mon Gitea" (ou ce que tu veux)
   - Créer un compte admin :
     - Nom d'utilisateur : `admin` (ou ton pseudo)
     - Email : `ton@email.com`
     - Mot de passe : (choisis un mot de passe fort)
   - Cliquer "Installer Gitea"

3. **Connecte-toi** avec ton compte admin

**C'est fait !** Tu as maintenant Gitea opérationnel.

---

### Étape 3 : Ajouter une Clé SSH

**Pourquoi ?** Pour push/pull sans taper ton mot de passe à chaque fois.

#### A. Générer une clé SSH (si tu n'en as pas)

**Sur ton PC/Mac** :
```bash
# Générer la clé
ssh-keygen -t ed25519 -C "ton@email.com"

# Appuyer sur Entrée 3 fois (accepter defaults)

# Afficher la clé publique
cat ~/.ssh/id_ed25519.pub
```

**Résultat** : Une ligne comme `ssh-ed25519 AAAA...xyz ton@email.com`

---

#### B. Ajouter la clé dans Gitea

1. Dans Gitea → Clic sur ton **avatar** (en haut à droite)
2. **Paramètres** → **Clés SSH / GPG**
3. Clic **Ajouter une clé**
4. Coller la clé publique (ligne copiée plus haut)
5. Donner un nom : "Mon Laptop"
6. Clic **Ajouter une clé**

**Tester** :
```bash
ssh -T git@IP_DU_PI -p 222
# → "Hi username! You've successfully authenticated..."
```

---

### Étape 4 : Créer ton Premier Repo

1. **Dans Gitea** → Clic **+** (en haut à droite) → **Nouveau dépôt**
2. **Remplir** :
   - Nom : `mon-premier-projet`
   - Description : "Test Gitea"
   - Visibilité : Privé
   - Initialiser avec README : ✅ Coché
3. Clic **Créer le dépôt**

**C'est fait !** Tu as ton premier repo sur Gitea.

---

### Étape 5 : Cloner et Pusher

#### A. Cloner le repo sur ton PC

```bash
# Remplace IP_DU_PI et username
git clone ssh://git@IP_DU_PI:222/username/mon-premier-projet.git

cd mon-premier-projet
```

---

#### B. Faire des changements

```bash
# Créer un fichier
echo "# Mon Premier Projet" > README.md
echo "print('Hello Gitea')" > app.py

# Voir les changements
git status

# Ajouter les fichiers
git add .

# Commit
git commit -m "Ajouter README et app.py"

# Push vers Gitea
git push
```

---

#### C. Vérifier dans Gitea

1. Recharge la page de ton repo dans Gitea
2. Tu vois maintenant `README.md` et `app.py`
3. Clic sur "Commits" → Tu vois l'historique

**Félicitations !** Tu as fait ton premier cycle Git complet.

---

### Étape 6 : Installer un Runner (pour CI/CD)

**C'est quoi ?** Le "robot" qui exécute les workflows.

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-gitea-stack/scripts/02-runners-setup.sh | sudo bash
```

**Ce que fait le script** :
1. Installe Gitea Act Runner (compatible GitHub Actions)
2. Configure le runner pour ton Gitea
3. Enregistre le runner automatiquement
4. Lance le runner en service Docker

**Durée** : ~3 minutes

**Vérifier** :
1. Dans Gitea → Paramètres du repo → Actions → Runners
2. Tu dois voir 1 runner actif (pastille verte)

---

### Étape 7 : Créer ton Premier Workflow

#### A. Créer le fichier workflow

```bash
cd mon-premier-projet

# Créer le dossier
mkdir -p .gitea/workflows

# Créer le workflow
cat > .gitea/workflows/hello.yml << 'EOF'
name: Hello World

on: push

jobs:
  hello:
    runs-on: ubuntu-latest
    steps:
      - name: Dire bonjour
        run: |
          echo "======================================"
          echo "🤖 Bonjour depuis Gitea Actions !"
          echo "======================================"
          echo "Repo: ${{ github.repository }}"
          echo "Branch: ${{ github.ref_name }}"
          echo "Commit: ${{ github.sha }}"
EOF
```

---

#### B. Push le workflow

```bash
git add .gitea/workflows/hello.yml
git commit -m "Ajouter workflow Hello World"
git push
```

---

#### C. Voir le workflow en action

1. Dans Gitea → Ton repo → Onglet **Actions**
2. Tu vois le workflow "Hello World" en cours d'exécution (⏳)
3. Clic dessus pour voir les logs en temps réel
4. Après ~30 secondes → ✅ Terminé

**Tu viens de lancer ton premier workflow CI/CD !**

---

## 🎯 Cas d'Usage Réels

### 1. Développeur Freelance - Projets Clients Privés

**Besoin** : Héberger 10 projets clients en privé.

**Solution** :
```
Gitea
├── client-a/site-ecommerce
├── client-b/api-backend
├── client-c/app-mobile
├── ...
└── client-j/dashboard
```

**Workflow CI/CD** :
- Push sur `main` → Tests auto → Déploiement auto sur serveur client
- Notification Discord quand déploiement OK
- Backup quotidien automatique vers cloud

**Économie** :
- GitHub Team (requis pour plusieurs collaborateurs sur privé) : 48$/an
- Gitea : 0$/an

---

### 2. Startup - Collaboration en Équipe

**Besoin** : 3 développeurs, 1 designer, 1 PM.

**Workflow** :
1. **Développeur** crée une branche `feature/login`
2. Code la fonctionnalité login
3. Push → Tests auto (Gitea Actions)
4. Ouvre une Pull Request
5. **Designer** revoit l'UI dans la PR
6. **PM** valide la feature
7. **Lead Dev** merge → Auto-déploiement en staging
8. Quand tout OK → Merge dans `main` → Prod

**Issues tracking** :
- Bugs : Issue #1, #2, #3...
- Features : Issue avec label "enhancement"
- Milestones : v1.0 (10 issues), v1.1 (5 issues)

---

### 3. Étudiant - Portfolio et Projets

**Besoin** : Héberger projets universitaires et personnels.

**Avantages** :
- Tous les projets en un endroit
- Historique complet (prof peut voir l'évolution)
- Workflow CI qui vérifie compilation avant chaque push (pas de rendu cassé)
- Wiki pour documenter les projets

**Exemple** :
- Projet TP Java → Workflow qui compile + teste
- Projet perso Python → Workflow qui déploie sur Render/Heroku auto
- Stage : rapport Latex → Workflow qui compile PDF à chaque commit

---

### 4. Hobbyiste - Scripts Domotique

**Besoin** : Gérer scripts domotique (Home Assistant, etc.).

**Repos** :
```
gitea
├── home-assistant-config  # Configuration HA
├── python-scripts        # Scripts custom
├── esphome-devices       # Config ESPHome
└── automation-backups    # Backups automatiques
```

**Workflow CI/CD** :
- Push config Home Assistant → Validation YAML
- Si OK → Redémarrage auto de HA
- Backup quotidien vers cloud (rclone)

---

### 5. Miroir GitHub - Backup Automatique

**Besoin** : Sauvegarder tous tes repos GitHub sur ton Pi.

**Solution** : Workflow qui mirror automatiquement.

```yaml
name: Mirror GitHub Repos

on:
  schedule:
    - cron: '0 3 * * *'  # Tous les jours à 3h
  workflow_dispatch:

jobs:
  mirror:
    runs-on: ubuntu-latest
    steps:
      - name: Mirror repos
        run: |
          # Liste des repos GitHub à mirror
          REPOS=(
            "username/repo1"
            "username/repo2"
            "username/repo3"
          )

          for repo in "${REPOS[@]}"; do
            git clone --mirror https://github.com/$repo.git
            cd $repo.git
            git push --mirror git@gitea:$repo.git
            cd ..
          done
```

**Résultat** : Tous tes repos GitHub sont backupés sur ton Pi chaque nuit.

---

## 📝 Créer Son Premier Repo - Guide Visuel

### 1. Créer le Repo dans Gitea

**Interface Gitea** :
```
[+] Nouveau dépôt

┌─────────────────────────────────────────┐
│ Propriétaire : admin              [▼]   │
│ Nom du dépôt : mon-app                  │
│ Description  : Application web de test  │
│                                         │
│ Visibilité   : ○ Public  ● Privé       │
│                                         │
│ ☑ Initialiser le dépôt                 │
│   ☑ Ajouter .gitignore : Node          │
│   ☑ Ajouter une licence : MIT          │
│   ☑ Ajouter README                     │
│                                         │
│           [Créer le dépôt]             │
└─────────────────────────────────────────┘
```

---

### 2. Cloner en Local

```bash
# Terminal
cd ~/projets
git clone ssh://git@192.168.1.100:222/admin/mon-app.git
cd mon-app

# Tu as maintenant :
mon-app/
├── .gitignore
├── LICENSE
└── README.md
```

---

### 3. Développer

```bash
# Créer structure projet
mkdir src
cat > src/app.js << 'EOF'
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.send('Hello Gitea!');
});

app.listen(3000, () => {
  console.log('Server on http://localhost:3000');
});
EOF

cat > package.json << 'EOF'
{
  "name": "mon-app",
  "version": "1.0.0",
  "scripts": {
    "start": "node src/app.js",
    "test": "echo 'Tests OK'"
  },
  "dependencies": {
    "express": "^4.18.0"
  }
}
EOF
```

---

### 4. Commit et Push

```bash
# Voir ce qui a changé
git status
# → Fichiers non suivis : src/app.js, package.json

# Ajouter tout
git add .

# Commit
git commit -m "Ajouter serveur Express basique"

# Push vers Gitea
git push origin main
```

---

### 5. Voir dans Gitea UI

**Recharge la page Gitea** :
```
Fichiers :
├── src/
│   └── app.js
├── .gitignore
├── LICENSE
├── package.json
└── README.md

Commits : 2 commits
├── [commit 2] Ajouter serveur Express basique  (il y a 1 minute)
└── [commit 1] Initial commit                    (il y a 10 minutes)
```

---

### 6. Créer une Issue

**Dans Gitea → Issues → Nouvelle Issue** :
```
Titre : Ajouter endpoint /api/users

Description :
Créer un endpoint GET /api/users qui retourne
la liste des utilisateurs en JSON.

Exemple réponse :
{
  "users": [
    {"id": 1, "name": "Alice"},
    {"id": 2, "name": "Bob"}
  ]
}

Labels : enhancement, backend
Milestone : v1.1
Assigné : admin
```

---

### 7. Créer une Branche pour la Feature

```bash
# Créer branche depuis l'issue
git checkout -b feature/api-users

# Développer
cat > src/api.js << 'EOF'
module.exports = {
  getUsers: () => [
    {id: 1, name: 'Alice'},
    {id: 2, name: 'Bob'}
  ]
};
EOF

# Modifier app.js pour ajouter le endpoint
# (code modifié...)

# Commit
git add .
git commit -m "Ajouter endpoint /api/users (closes #1)"

# Push la branche
git push origin feature/api-users
```

---

### 8. Créer une Pull Request

**Dans Gitea → Pull Requests → Nouvelle Pull Request** :
```
De : feature/api-users
Vers : main

Titre : Ajouter endpoint /api/users

Description :
Implémente l'issue #1.

Changements :
- Nouveau fichier src/api.js
- Endpoint GET /api/users dans app.js
- Tests ajoutés

[Créer la Pull Request]
```

---

### 9. Revue de Code

**Collègue/Toi-même** :
1. Voir le code changé (diff visuel)
2. Commenter des lignes spécifiques :
   ```
   > "Ligne 12 : Pourquoi pas async/await ?"
   > "OK pour moi, LGTM!"
   ```
3. Approuver ou Demander changements

---

### 10. Merge

**Quand approuvé** :
```
[Fusionner la Pull Request]
  ● Créer un commit de fusion
  ○ Squash et fusionner
  ○ Rebase et fusionner

[Confirmer la fusion]
```

**Résultat** :
- La branche `feature/api-users` est fusionnée dans `main`
- L'issue #1 est automatiquement fermée (`closes #1` dans le commit)
- Workflow CI/CD se déclenche automatiquement

---

## 🤖 CI/CD Simplifié - Premiers Pas

### Workflow 1 : Hello World (Déjà vu)

```yaml
# .gitea/workflows/hello.yml
name: Hello World
on: push
jobs:
  hello:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Hello Gitea Actions!"
```

**Résultat** : Affiche un message à chaque push.

---

### Workflow 2 : Tests Node.js

```yaml
# .gitea/workflows/test.yml
name: Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm install

      - name: Run tests
        run: npm test

      - name: Notify success
        if: success()
        run: echo "✅ Tous les tests passent !"
```

**Résultat** : Tests automatiques à chaque push/PR.

---

### Workflow 3 : Build Docker Image

```yaml
# .gitea/workflows/docker.yml
name: Build Docker Image

on:
  push:
    tags:
      - 'v*.*.*'  # Sur tags de version (v1.0.0, etc.)

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT

      - name: Build image
        run: |
          docker build -t mon-app:${{ steps.version.outputs.VERSION }} .
          docker tag mon-app:${{ steps.version.outputs.VERSION }} mon-app:latest

      - name: Push to registry
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker push mon-app:${{ steps.version.outputs.VERSION }}
          docker push mon-app:latest
```

**Résultat** : Créer un tag Git `v1.0.0` → Docker image `mon-app:1.0.0` buildée et pushée automatiquement.

---

### Workflow 4 : Déployer Edge Function Supabase

```yaml
# .gitea/workflows/deploy-function.yml
name: Deploy Supabase Edge Function

on:
  push:
    branches: [main]
    paths:
      - 'functions/**'  # Seulement si fichiers dans functions/ changent

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Deno
        uses: denoland/setup-deno@v1
        with:
          deno-version: v1.x

      - name: Deploy to Supabase
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_PROJECT_ID: ${{ secrets.SUPABASE_PROJECT_ID }}
        run: |
          # Installer Supabase CLI
          curl -fsSL https://raw.githubusercontent.com/supabase/cli/main/install.sh | sh

          # Se connecter
          supabase login --token $SUPABASE_ACCESS_TOKEN

          # Déployer toutes les functions
          supabase functions deploy --project-ref $SUPABASE_PROJECT_ID

      - name: Notify Discord
        if: success()
        run: |
          curl -X POST ${{ secrets.DISCORD_WEBHOOK }} \
            -H 'Content-Type: application/json' \
            -d '{"content":"✅ Edge Functions déployées en production!"}'
```

**Résultat** : Push modifications dans `functions/` → Auto-déploiement vers Supabase + notification Discord.

---

### Workflow 5 : Backup Automatique

```yaml
# .gitea/workflows/backup.yml
name: Backup to Cloud

on:
  schedule:
    - cron: '0 2 * * *'  # Tous les jours à 2h
  workflow_dispatch:     # Manuel aussi

jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Tout l'historique

      - name: Install rclone
        run: |
          curl https://rclone.org/install.sh | sudo bash

      - name: Configure rclone
        env:
          RCLONE_CONFIG: ${{ secrets.RCLONE_CONFIG }}
        run: |
          mkdir -p ~/.config/rclone
          echo "$RCLONE_CONFIG" > ~/.config/rclone/rclone.conf

      - name: Backup to R2
        run: |
          REPO_NAME=$(basename $GITHUB_REPOSITORY)
          DATE=$(date +%Y-%m-%d)

          # Créer archive
          git bundle create ${REPO_NAME}-${DATE}.bundle --all

          # Upload vers Cloudflare R2
          rclone copy ${REPO_NAME}-${DATE}.bundle r2:backups/gitea/

      - name: Cleanup old backups
        run: |
          # Garder seulement 30 derniers jours
          rclone delete r2:backups/gitea/ --min-age 30d
```

**Résultat** : Backup quotidien automatique de ton repo vers Cloudflare R2.

---

## ❓ Questions Fréquentes

### 1. "C'est compliqué à utiliser ?"

**Non !** L'interface est quasi-identique à GitHub.

Si tu sais utiliser GitHub, tu sais utiliser Gitea.

**Différences principales** :
- URL différente (ton Pi au lieu de github.com)
- Workflows dans `.gitea/workflows/` (au lieu de `.github/workflows/`)
- Sinon : pareil

---

### 2. "Combien ça coûte ?"

**Gratuit à 100%.**

Coûts réels :
- Électricité Pi5 : ~0.15€/mois (~2€/an)
- Domaine (optionnel) : 8-12€/an
- Total : ~10€/an maximum

**Vs GitHub Team** : 48$/an/utilisateur

---

### 3. "Combien de RAM ça consomme ?"

**Gitea** : 300-500 MB RAM (léger)

**Comparaison** :
- GitLab : 4-8 GB RAM (impossible sur Pi)
- GitHub Enterprise : 14 GB minimum
- Gitea : 300-500 MB

**Sur Pi5 8GB** : Tu peux faire tourner :
- Gitea (500 MB)
- Supabase (2 GB)
- Traefik (100 MB)
- Monitoring (1 GB)
- **Total : ~4 GB utilisés, 4 GB libres**

---

### 4. "C'est compatible avec GitHub Actions ?"

**Oui à 95%.**

Gitea Actions utilise la même syntaxe que GitHub Actions.

**Compatible** :
- `actions/checkout@v4` ✅
- `actions/setup-node@v4` ✅
- `docker/build-push-action@v5` ✅
- Secrets ✅
- Cron ✅
- Matrix builds ✅

**Différences** :
- Pas de GitHub-hosted runners (normal, c'est self-hosted)
- Pas de GitHub Environments (feature GitHub spécifique)
- Quelques actions GitHub-spécifiques peuvent ne pas marcher

**Astuce** : 95% des workflows GitHub fonctionnent sans changement.

---

### 5. "Puis-je inviter des collaborateurs ?"

**Oui !** Gestion utilisateurs complète.

**Créer un utilisateur** :
1. En tant qu'admin → Administration du site
2. Comptes utilisateurs → Créer un compte
3. Remplir email/username/password
4. Utilisateur créé

**Inviter sur un repo** :
1. Ton repo → Paramètres → Collaborateurs
2. Ajouter collaborateur
3. Choisir permissions (Lecture / Écriture / Admin)

**Organisations** :
Tu peux créer des organisations (comme sur GitHub) :
- Organisation "MonEntreprise"
  - Équipe "Backend" (3 développeurs)
  - Équipe "Frontend" (2 développeurs)
  - Équipe "Design" (1 designer)

---

### 6. "Mes données sont-elles sécurisées ?"

**Oui, plus que sur GitHub.**

**Avantages sécurité** :
- Données chez toi (pas sur serveurs Microsoft)
- Aucun scan externe automatique
- Contrôle total accès physique
- Backup où tu veux

**Recommandations** :
- Activer authentification 2FA (TOTP)
- Utiliser clés SSH (pas passwords)
- Backup réguliers (automatisés)
- Mettre à jour Gitea régulièrement

---

### 7. "Puis-je avoir des repos publics ?"

**Oui.**

Tu peux mixer repos publics et privés :
- Projets open source → Publics
- Projets clients → Privés
- Expérimentations → Privés
- Portfolio → Publics

**Attention** : Repos publics = lisibles par quiconque a accès à ton Gitea (si exposé sur Internet).

---

### 8. "Puis-je utiliser Gitea ET GitHub ?"

**Absolument !** C'est même recommandé.

**Stratégie optimale** :
```
GitHub :
  - Projets open source publics
  - Contributions à des projets existants
  - Portfolio visible

Gitea (chez toi) :
  - Projets clients privés
  - Expérimentations/tests
  - Backup de tes repos GitHub
  - Apprentissage CI/CD illimité
```

**Mirror automatique** :
Tu peux configurer un workflow qui sync GitHub ↔ Gitea automatiquement.

---

### 9. "Que se passe-t-il si mon Pi plante ?"

**Backup = crucial.**

**Solutions** :
1. **Backup automatique quotidien** (workflow ci-dessus)
   - Vers cloud (R2, B2, etc.)
   - Vers NAS local
   - Vers disque externe USB

2. **Git est distribué** :
   - Chaque développeur a une copie complète
   - Si Pi mort → Clone depuis un laptop → Restaure

3. **Haute disponibilité (avancé)** :
   - 2 Pi en cluster
   - Réplication PostgreSQL
   - (Overkill pour la plupart des cas)

**Recommandation débutant** :
- Backup quotidien vers cloud (gratuit avec Cloudflare R2 ou Backblaze B2)
- Workflow automatique (déjà fourni dans exemples)

---

### 10. "Puis-je héberger des gros repos (plusieurs GB) ?"

**Oui, mais...**

**Git n'est pas fait pour** :
- Fichiers binaires énormes (videos, ISOs, etc.)
- Assets qui changent souvent (builds, node_modules)

**Git est fait pour** :
- Code source (texte)
- Fichiers de configuration
- Documentation
- Images (dans la limite du raisonnable)

**Solutions pour gros fichiers** :
- **Git LFS** (Large File Storage) : Supporte fichiers 100MB+
- **Stockage séparé** : Assets sur S3/R2, code sur Git

**Taille recommandée** :
- Repo < 1 GB : Parfait
- Repo 1-5 GB : OK avec Git LFS
- Repo > 5 GB : Repenser l'architecture (séparer code/assets)

---

## 🎓 Scénarios Réels Détaillés

### Scénario 1 : Développeur Freelance

**Contexte** :
- 3 clients actifs
- 5-8 projets en parallèle
- Besoin de CI/CD pour auto-déployer

**Setup Gitea** :
```
Organisations :
  ├── client-acme
  │   ├── website-corporate
  │   ├── api-backend
  │   └── admin-dashboard
  ├── client-startup-xyz
  │   └── mobile-app-backend
  └── personnel
      ├── portfolio
      └── scripts-utils
```

**Workflows utilisés** :
1. **Tests auto** sur chaque PR
2. **Déploiement staging** sur push `develop`
3. **Déploiement prod** sur tag `v*`
4. **Backup quotidien** vers R2
5. **Notification Discord** sur déploiement

**Avantages** :
- Tous les clients dans 1 interface
- CI/CD illimité gratuit (vs 2000 min/mois GitHub)
- Contrôle total données clients
- Coût : 0€ vs 48$/an GitHub Team

---

### Scénario 2 : Équipe Startup (4 personnes)

**Contexte** :
- 1 Product Manager
- 2 Développeurs backend
- 1 Développeur frontend
- MVP en cours de développement

**Organisation Gitea** :
```
Organisation : startup-mvp
  ├── Équipe Backend (2 devs)
  │   ├── api-backend
  │   └── database-migrations
  └── Équipe Frontend (1 dev)
      └── web-app
```

**Workflow de développement** :
1. **PM** crée des Issues (features, bugs)
2. **Dev** s'assigne une issue
3. Crée branche `feature/issue-42`
4. Code + commit (référence issue : "fixes #42")
5. Push → Tests auto (CI)
6. Ouvre PR
7. **Autre dev** revoit le code
8. Merge → Auto-déploiement staging
9. **PM** teste staging
10. Si OK → Merge main → Prod

**Milestones** :
- v0.1 (MVP) : 20 issues
- v0.2 (Beta) : 15 issues
- v1.0 (Launch) : 30 issues

**Avantages** :
- Workflow professionnel
- Coût : 0€ (vs 192$/an GitHub Team pour 4 users)
- Apprentissage collaboration Git

---

### Scénario 3 : Étudiant en Informatique

**Contexte** :
- 5 cours avec projets de code
- Projets personnels
- Stage en entreprise

**Repos Gitea** :
```
gitea
  ├── cours/
  │   ├── algo-avancee (TP Java)
  │   ├── web-dev (Projet Node.js)
  │   ├── bd-relationnelles (SQL)
  │   └── projet-integration (Équipe 4)
  ├── perso/
  │   ├── mon-site-portfolio
  │   └── bot-discord
  └── stage/
      └── rapport-latex
```

**Workflows CI/CD** :

**TP Java** :
```yaml
# Compile + teste à chaque push
on: push
jobs:
  test:
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
      - run: javac Main.java
      - run: java Main
```

**Rapport LaTeX** :
```yaml
# Compile PDF à chaque commit
on: push
jobs:
  build:
    steps:
      - uses: actions/checkout@v4
      - uses: xu-cheng/latex-action@v2
        with:
          root_file: rapport.tex
      - uses: actions/upload-artifact@v4
        with:
          name: rapport.pdf
```

**Avantages** :
- Jamais perdre de code (historique complet)
- Prof peut voir progression (commits)
- Rendu professionnel (pas de ZIP par email)
- Apprentissage Git/CI/CD (compétence recherchée)

---

### Scénario 4 : Hobbyiste Domotique

**Contexte** :
- Home Assistant configuré
- Scripts Python custom
- Devices ESPHome

**Repos** :
```
gitea
  ├── home-assistant-config
  │   ├── configuration.yaml
  │   ├── automations.yaml
  │   └── scripts/
  ├── esphome-devices
  │   ├── bedroom-light.yaml
  │   └── garage-door.yaml
  └── python-scripts
      ├── energy-monitor.py
      └── presence-detection.py
```

**Workflow : Validation Config**
```yaml
name: Validate Home Assistant Config

on:
  push:
    paths:
      - '**.yaml'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate YAML
        run: |
          pip install yamllint
          yamllint *.yaml

      - name: Check HA config
        uses: frenck/action-home-assistant@v1
        with:
          path: "."

      - name: Notify if broken
        if: failure()
        run: |
          curl -X POST ${{ secrets.NTFY_URL }} \
            -d "⚠️ Config Home Assistant cassée !"
```

**Workflow : Auto-Restart HA**
```yaml
name: Deploy to Home Assistant

on:
  push:
    branches: [main]

jobs:
  deploy:
    steps:
      - name: Restart HA
        run: |
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.HA_TOKEN }}" \
            http://homeassistant.local:8123/api/services/homeassistant/restart
```

**Avantages** :
- Config versionée (rollback facile si ça casse)
- Validation auto avant déploiement
- Backup automatique
- Collaboration si plusieurs dans le foyer

---

## 💻 Commandes Git Utiles

### Commandes Quotidiennes

```bash
# Cloner un repo
git clone ssh://git@gitea:222/user/repo.git

# Voir l'état
git status

# Voir les changements
git diff

# Ajouter fichiers
git add fichier.js          # 1 fichier
git add .                   # Tout

# Commit
git commit -m "Message"

# Push
git push

# Pull (récupérer changements)
git pull

# Voir historique
git log
git log --oneline           # Compact
git log --graph --oneline   # Visuel
```

---

### Branches

```bash
# Créer branche
git branch nouvelle-feature

# Changer de branche
git checkout nouvelle-feature

# Créer + changer (raccourci)
git checkout -b nouvelle-feature

# Lister branches
git branch

# Fusionner branche
git checkout main
git merge nouvelle-feature

# Supprimer branche
git branch -d nouvelle-feature
```

---

### Annuler des Changements

```bash
# Annuler changements non commités
git checkout -- fichier.js

# Annuler dernier commit (garde les changements)
git reset --soft HEAD~1

# Annuler dernier commit (supprime les changements)
git reset --hard HEAD~1

# Revenir à un commit précis
git reset --hard abc1234

# Créer commit inverse (safe)
git revert abc1234
```

---

### Stash (Mettre de côté)

```bash
# Mettre changements de côté
git stash

# Lister stashs
git stash list

# Récupérer le stash
git stash pop

# Appliquer sans supprimer
git stash apply
```

---

### Tags (Versions)

```bash
# Créer tag
git tag v1.0.0

# Tag avec message
git tag -a v1.0.0 -m "Version 1.0.0"

# Push tags
git push --tags

# Lister tags
git tag
```

---

### Remote (Distant)

```bash
# Voir remotes
git remote -v

# Ajouter remote
git remote add origin ssh://git@gitea:222/user/repo.git

# Changer URL remote
git remote set-url origin ssh://git@gitea:222/user/new-repo.git

# Supprimer remote
git remote remove origin
```

---

## 🔧 Workflows Exemples Prêts à l'Emploi

### 1. Tests Node.js Complet

```yaml
name: Tests Node.js

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18, 20, 22]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - run: npm ci
      - run: npm run lint
      - run: npm test
      - run: npm run build
```

---

### 2. Build Image Docker Multi-Arch

```yaml
name: Docker Build Multi-Arch

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            myapp:latest
            myapp:${{ steps.version.outputs.VERSION }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

### 3. Déploiement Supabase Edge Function

```yaml
name: Deploy Edge Function

on:
  push:
    branches: [main]
    paths: ['functions/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: denoland/setup-deno@v1

      - name: Install Supabase CLI
        run: |
          curl -fsSL https://raw.githubusercontent.com/supabase/cli/main/install.sh | sh
          echo "$HOME/.supabase/bin" >> $GITHUB_PATH

      - name: Deploy functions
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_PROJECT_ID: ${{ secrets.SUPABASE_PROJECT_ID }}
        run: |
          supabase login --token $SUPABASE_ACCESS_TOKEN
          supabase functions deploy --project-ref $SUPABASE_PROJECT_ID

      - name: Notify Discord
        if: success()
        run: |
          curl -X POST "${{ secrets.DISCORD_WEBHOOK }}" \
            -H "Content-Type: application/json" \
            -d "{\"content\":\"✅ Edge Functions déployées\"}"
```

---

### 4. Backup Automatique Vers Cloud

```yaml
name: Backup to Cloudflare R2

on:
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:

jobs:
  backup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install rclone
        run: curl https://rclone.org/install.sh | sudo bash

      - name: Configure rclone
        run: |
          mkdir -p ~/.config/rclone
          cat > ~/.config/rclone/rclone.conf << EOF
          [r2]
          type = s3
          provider = Cloudflare
          access_key_id = ${{ secrets.R2_ACCESS_KEY_ID }}
          secret_access_key = ${{ secrets.R2_SECRET_ACCESS_KEY }}
          endpoint = https://${{ secrets.R2_ACCOUNT_ID }}.r2.cloudflarestorage.com
          EOF

      - name: Create bundle
        run: |
          REPO=$(basename $GITHUB_REPOSITORY)
          DATE=$(date +%Y-%m-%d)
          git bundle create ${REPO}-${DATE}.bundle --all

      - name: Upload to R2
        run: |
          REPO=$(basename $GITHUB_REPOSITORY)
          DATE=$(date +%Y-%m-%d)
          rclone copy ${REPO}-${DATE}.bundle r2:backups/gitea/${REPO}/

      - name: Cleanup old backups (keep 30 days)
        run: |
          REPO=$(basename $GITHUB_REPOSITORY)
          rclone delete r2:backups/gitea/${REPO}/ --min-age 30d
```

---

### 5. Notification Multi-Canaux

```yaml
name: Multi-Channel Notifications

on:
  push:
    branches: [main]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Discord Notification
        run: |
          curl -X POST "${{ secrets.DISCORD_WEBHOOK }}" \
            -H "Content-Type: application/json" \
            -d "{
              \"embeds\": [{
                \"title\": \"📦 New commit\",
                \"description\": \"${{ github.event.head_commit.message }}\",
                \"color\": 3066993,
                \"author\": {
                  \"name\": \"${{ github.actor }}\"
                }
              }]
            }"

      - name: ntfy.sh Notification
        run: |
          curl -X POST "https://ntfy.sh/${{ secrets.NTFY_TOPIC }}" \
            -H "Title: Git Push" \
            -H "Priority: default" \
            -H "Tags: git,rocket" \
            -d "${{ github.actor }} pushed to ${{ github.repository }}"

      - name: Gotify Notification
        run: |
          curl -X POST "${{ secrets.GOTIFY_URL }}/message?token=${{ secrets.GOTIFY_TOKEN }}" \
            -F "title=Git Push" \
            -F "message=${{ github.event.head_commit.message }}" \
            -F "priority=5"
```

---

## 🚀 Pour Aller Plus Loin

### 1. Webhooks - Intégrations Externes

**C'est quoi ?** Gitea envoie une requête HTTP quand un événement se produit.

**Cas d'usage** :
- Notification Discord/Slack à chaque push
- Déclencher deploy externe
- Mettre à jour un dashboard

**Configuration** :
1. Repo → Paramètres → Webhooks
2. Ajouter Webhook
3. URL : `https://discord.com/api/webhooks/...`
4. Événements : Push, PR, Issues
5. Secret : (optionnel, sécurité)

**Exemple Discord** :
```
URL: https://discord.com/api/webhooks/123456/abcdef
Content Type: application/json
Secret: (laisser vide)
Événements: Push, Pull Request
```

---

### 2. Docker Registry - Héberger Tes Images

**Activer le registry** :
```bash
# Dans docker-compose de Gitea, ajouter :
environment:
  - GITEA__packages__ENABLED=true
```

**Utiliser** :
```bash
# Login
docker login gitea.local:3000

# Tag image
docker tag mon-app:latest gitea.local:3000/username/mon-app:latest

# Push
docker push gitea.local:3000/username/mon-app:latest

# Pull
docker pull gitea.local:3000/username/mon-app:latest
```

**Avantages** :
- Héberger tes images Docker privées
- Gratuit et illimité
- Intégré à Gitea (même auth)

---

### 3. Repository Templates - Projets Starter

**Créer un template** :
1. Créer un repo "template-nodejs"
2. Ajouter structure de base :
   ```
   template-nodejs/
   ├── .gitea/workflows/test.yml
   ├── .gitignore
   ├── package.json
   ├── README.md
   └── src/
       └── index.js
   ```
3. Repo → Paramètres → Cocher "Template Repository"

**Utiliser** :
1. "+" → Nouveau dépôt
2. Choisir "Depuis un template"
3. Sélectionner "template-nodejs"
4. Nouveau repo avec toute la structure !

**Exemples templates** :
- `template-nodejs` : Node.js + Express + Tests
- `template-python` : Python + pytest + CI
- `template-docker` : Dockerfile + docker-compose + CI

---

### 4. Branch Protection - Règles de Branche

**Protéger la branche main** :
1. Repo → Paramètres → Branches
2. Ajouter règle pour `main`
3. Configurer :
   - ✅ Require pull request before merging
   - ✅ Require status checks to pass (CI doit être ✅)
   - ✅ Require review from 1 person
   - ✅ Restrict who can push (seulement maintainers)

**Résultat** :
- Impossible de push directement sur `main`
- Obligation de passer par PR
- PR doit être approuvée + CI passée
- Qualité du code garantie

---

### 5. Code Review Workflow - Revue Professionnelle

**Processus complet** :

1. **Développeur A** :
   ```bash
   git checkout -b feature/login
   # ... code ...
   git push origin feature/login
   ```

2. **Ouvrir PR dans Gitea** :
   - De : `feature/login`
   - Vers : `main`
   - Assigner reviewer : Dev B

3. **Dev B revoit** :
   - Voir le code changé (diff)
   - Commenter des lignes :
     ```
     Ligne 42 : Cette condition peut être simplifiée
     Ligne 58 : Ajouter un test pour ce cas
     ```
   - Statut : Request changes

4. **Dev A corrige** :
   ```bash
   # Corriger selon commentaires
   git commit -am "Fix review comments"
   git push
   ```

5. **Dev B re-revoit** :
   - Changements OK
   - Approve

6. **Merge** :
   - CI passe ✅
   - Review approuvée ✅
   - → Merge autorisé
   - Clic "Merge"

**Avantages** :
- Qualité code améliorée
- Partage de connaissance (toute l'équipe voit le code)
- Moins de bugs en production
- Formation des juniors

---

### 6. Milestones - Gestion de Versions

**Créer milestone** :
1. Repo → Issues → Milestones
2. Nouveau Milestone
3. Titre : "Version 1.0"
4. Description : "Premier release public"
5. Date limite : 2025-12-31

**Assigner issues** :
1. Issue #1 → Milestone "Version 1.0"
2. Issue #2 → Milestone "Version 1.0"
3. ...

**Suivre progression** :
```
Version 1.0 : 45% (9/20 issues)
[████████░░░░░░░░░░░░]
Due : 2025-12-31 (3 mois restants)
```

**Workflow** :
- v1.0 terminé → Tag `v1.0.0` → Release → Docker build auto

---

### 7. Wiki - Documentation Intégrée

**Activer Wiki** :
1. Repo → Paramètres → Features
2. ✅ Enable Wiki

**Structure recommandée** :
```
Wiki
├── Home (accueil)
├── Getting-Started (démarrage rapide)
├── API-Reference (docs API)
├── Configuration (options config)
├── Deployment (déploiement)
└── Troubleshooting (dépannage)
```

**Édition** :
- Directement dans Gitea UI (Markdown)
- Ou cloner le wiki :
  ```bash
  git clone ssh://git@gitea:222/user/repo.wiki.git
  ```

**Avantages** :
- Documentation versionnée (comme le code)
- Collaboratif
- Recherche intégrée
- Markdown avec images

---

## ✅ Checklist Maîtrise Gitea

### Niveau Débutant

- [ ] Je peux créer un repo dans Gitea
- [ ] Je sais cloner un repo en local
- [ ] Je comprends commit/push/pull
- [ ] J'ai créé mon premier workflow CI
- [ ] Je peux voir les logs des workflows

---

### Niveau Intermédiaire

- [ ] Je maîtrise les branches (create, merge)
- [ ] J'ai créé une Pull Request
- [ ] Je sais utiliser les Issues
- [ ] J'ai configuré un workflow avec secrets
- [ ] J'ai mis en place des notifications

---

### Niveau Avancé

- [ ] J'ai configuré branch protection
- [ ] J'utilise les milestones pour gérer les versions
- [ ] J'ai un workflow de déploiement automatique
- [ ] J'ai configuré un Docker registry
- [ ] Je fais du code review avec PRs
- [ ] J'ai mis en place backups automatiques

---

## 📚 Ressources d'Apprentissage

### Documentation Officielle

- **[Gitea Docs](https://docs.gitea.com/)** - Documentation complète
- **[Gitea Actions](https://docs.gitea.com/usage/actions/overview)** - CI/CD
- **[Git Book](https://git-scm.com/book/fr/v2)** - Apprendre Git (français)

---

### Vidéos YouTube

- "Gitea in 5 Minutes" - Techno Tim
- "Self-Hosted GitHub Alternative" - Awesome Open Source
- "Git Tutorial for Beginners" - freeCodeCamp (en français existe)

---

### Tutoriels Interactifs

- **[Learn Git Branching](https://learngitbranching.js.org/?locale=fr_FR)** - Visuel, interactif, français
- **[GitHub Skills](https://skills.github.com/)** - Apprendre PR/Issues (marche pour Gitea)

---

### Communautés

- [Discord Gitea](https://discord.gg/gitea) - Support communautaire
- [GitHub Discussions Gitea](https://github.com/go-gitea/gitea/discussions)
- [r/selfhosted](https://reddit.com/r/selfhosted) - Communauté self-hosting

---

## 🎯 Prochaines Étapes

Une fois à l'aise avec Gitea :

1. **Activer HTTPS avec Traefik** → Voir [Phase 2 Traefik](../../01-infrastructure/traefik/traefik-guide.md)

2. **Ajouter Monitoring** → Voir [Phase 3 Monitoring](../ROADMAP.md#phase-3)

3. **Configurer Backups Offsite** → Voir [Phase 6 Backup](../ROADMAP.md#phase-6)

4. **Intégrer avec Supabase** → Auto-deploy Edge Functions sur push

5. **Ajouter SSO** (Phase 9) → Authentification unique pour tous services

---

**Besoin d'aide ?** Consulte la [documentation complète](./docs/) ou pose tes questions sur le [Discord Gitea](https://discord.gg/gitea) !

🎉 **Bon développement avec Gitea !**
