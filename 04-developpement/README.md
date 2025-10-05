# 💻 Développement & CI/CD

> **Catégorie** : Outils de développement et intégration continue

---

## 📦 Stacks Inclus

### 1. [Gitea](gitea/)
**Git Self-Hosted + CI/CD (GitHub Alternative)**

**Fonctionnalités** :
- 📦 **Git** : Repos privés/publics illimités
- 🔄 **CI/CD** : Gitea Actions (compatible GitHub Actions)
- 📋 **Issues** : Gestion tickets + milestones
- 🔀 **Pull Requests** : Code review + merge
- 📦 **Packages** : Docker registry + NPM/Maven/PyPI
- 🪝 **Webhooks** : Intégrations automatiques
- 👥 **Organizations** : Teams + permissions granulaires

**RAM** : ~450 MB
**Ports** : 3000 (HTTP), 222 (SSH)

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/01-gitea-deploy.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/02-runners-setup.sh | sudo bash
```

**Accès** :
- Web : `http://raspberrypi.local:3000`
- SSH : `ssh git@raspberrypi.local -p 222`

---

## 🎯 Cas d'Usage

### CI/CD Automatique
**Exemple** : Build + Deploy automatique sur push

```yaml
# .gitea/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: npm run build
      - name: Deploy
        run: scp -r dist/* pi@raspberrypi.local:/var/www/
```

### Docker Registry Privé
**Exemple** : Héberger vos images Docker

```bash
# Tag
docker tag mon-app:latest raspberrypi.local:3000/mon-app:latest

# Push
docker push raspberrypi.local:3000/mon-app:latest
```

---

## 📊 Statistiques Catégorie

| Métrique | Valeur |
|----------|--------|
| **Nombre de stacks** | 1 |
| **RAM totale** | ~450 MB |
| **Complexité** | ⭐⭐ (Modérée) |
| **Priorité** | 🟡 **OPTIONNEL** (utile pour développeurs) |
| **Ordre installation** | Phase 5 (après infrastructure) |

---

## 🔗 Liens Utiles

- [Gitea Docs](https://docs.gitea.io/) - Documentation officielle
- [Gitea Actions](https://docs.gitea.io/en-us/actions/) - CI/CD
- [HEBERGER-SITE-WEB.md](../HEBERGER-SITE-WEB.md) - Déployer vos apps

---

## 💡 Notes

- **Gitea** = GitHub self-hosted (0€/mois vs 10€/mois GitHub Pro)
- **Actions runners** permettent d'exécuter CI/CD directement sur le Pi
- Compatible avec repos GitHub (import/export facile)
- Base de données : PostgreSQL (via Supabase)
