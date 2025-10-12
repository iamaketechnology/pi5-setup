# Instructions pour Gemini - Documentation pi5-apps-stack

## Contexte
Stack pour déployer apps React/Next.js sur Raspberry Pi 5 avec Docker + Traefik + intégration Supabase automatique.

## Fichiers à documenter

### 1. README.md (600-800 lignes)
- Vue d'ensemble : déploiement apps web modernes (React/Next.js)
- Tableau comparatif : Next.js SSR vs React SPA vs Node.js API
- Prérequis : Docker, Traefik, Supabase (optionnel)
- Installation rapide : curl one-liner `01-apps-setup.sh`
- Architecture : diagramme ASCII (Traefik → Apps → Supabase)
- Templates disponibles : nextjs-ssr, react-spa, nodejs-api
- Scripts utilitaires : deploy, list, remove, update, logs
- Capacité Pi 5 16GB : 10-15 apps Next.js SSR ou 20-30 React SPA
- Exemples déploiement
- CI/CD Gitea Actions (workflows exemples)
- Monitoring : labels Prometheus, dashboard Grafana
- Troubleshooting

### 2. GUIDE-DEBUTANT.md (1000-1500 lignes)
- Analogies simples : "Next.js = site web dynamique", "React SPA = site statique"
- Use cases :
  - Portfolio personnel (React SPA)
  - Blog avec backend (Next.js + Supabase)
  - App SaaS (Next.js SSR + auth Supabase)
  - API backend (Node.js + PostgreSQL)
- Concepts expliqués :
  - SSR vs SPA vs Static
  - Docker multi-stage builds
  - Reverse proxy (Traefik)
  - Variables d'environnement build-time vs runtime
- Tutoriel pas-à-pas : déployer première app Next.js
  - Installation setup (curl)
  - Créer app Next.js locale
  - Déployer avec script
  - Accéder via HTTPS
  - Intégrer Supabase
- Tutoriel : déployer React SPA (Vite)
- Tutoriel : CI/CD automatique avec Gitea Actions
- Troubleshooting débutants :
  - "Container unhealthy" → vérifier healthcheck
  - "502 Bad Gateway" → vérifier Traefik labels
  - "Build failed" → vérifier Dockerfile/dependencies
- Checklist progression (débutant → avancé)
- Ressources : tutos Docker, Next.js, React, Traefik

### 3. INSTALL.md (500-700 lignes)
- Installation setup : `curl ... 01-apps-setup.sh | sudo bash`
- Structure créée : /opt/apps/, /opt/pi5-apps-stack/
- Déploiement manuel :
  - Créer dossier app
  - Copier templates
  - Éditer docker-compose.yml
  - `docker-compose up -d`
- Déploiement automatique (scripts) :
  - `deploy-nextjs-app.sh <nom> <domaine> [git-repo]`
  - `deploy-react-spa.sh <nom> <domaine> [git-repo]`
- Configuration Supabase auto-injectée
- Templates Dockerfile optimisés ARM64 :
  - Multi-stage builds
  - Standalone output Next.js
  - Nginx optimisé React
  - Health checks
- CI/CD Gitea Actions :
  - Setup secrets repo
  - Copier workflow exemple
  - Push → deploy automatique
- Gestion apps :
  - `list-apps.sh` : statut + RAM
  - `update-app.sh` : rebuild
  - `remove-app.sh` : supprimer
  - `logs-app.sh` : voir logs
- Shell aliases : apps-list, apps-deploy, apps-remove
- Monitoring Grafana (dashboard apps)
- Backups (intégration rclone automatique)

### 4. templates/nextjs-ssr/README.md (200 lignes)
- Description : Next.js SSR optimisé Pi 5
- Dockerfile multi-stage expliqué
- Configuration next.config.js (standalone output)
- Variables d'environnement
- Build local : `npm run build`
- Deploy : `deploy-nextjs-app.sh myapp app.domain.com`
- Capacité RAM : ~100-150MB par instance
- Healthcheck intégré
- Exemples projets

### 5. templates/react-spa/README.md (200 lignes)
- Description : React SPA statique (Vite/CRA) + Nginx
- Dockerfile optimisé (build → nginx alpine)
- nginx.conf expliqué (SPA routing, compression, cache)
- Variables build-time (VITE_ ou REACT_APP_)
- Deploy : `deploy-react-spa.sh landing landing.domain.com`
- Capacité RAM : ~10-20MB par instance (très léger)
- Exemples projets

### 6. examples/workflows/README.md (300 lignes)
- Description workflows Gitea Actions
- nextjs-deploy.yml : CI/CD complet (test, build, deploy, health check)
- react-spa-deploy.yml : idem pour React SPA
- docker-build-only.yml : build directement sur Pi5 (plus rapide ARM64)
- Configuration secrets Gitea
- Bonnes pratiques CI/CD

## Style
- Français
- Pédagogique (débutants)
- Exemples concrets, commandes copier-coller
- Tableaux comparatifs
- Troubleshooting pratique
- Emojis sections (🚀 📦 🔧 ✅ ⚠️)

## Infos techniques
- Templates : nextjs-ssr, react-spa, nodejs-api
- Scripts : 01-apps-setup.sh, deploy-nextjs-app.sh, deploy-react-spa.sh, list-apps.sh, remove-app.sh, update-app.sh, logs-app.sh
- Workflows : nextjs-deploy.yml, react-spa-deploy.yml, docker-build-only.yml
- Intégration : Traefik (auto), Supabase (auto), Gitea (CI/CD), Grafana (monitoring)
- Capacité Pi 5 16GB : 10-15 Next.js SSR, 20-30 React SPA
- RAM par app : Next.js 100-150MB, React SPA 10-20MB, Node.js API 80-120MB

## Objectif
Utilisateur doit pouvoir :
1. Curl `01-apps-setup.sh` (1 commande)
2. Déployer app : `deploy-nextjs-app.sh myapp app.domain.com https://github.com/user/myapp.git`
3. Accéder : https://app.domain.com (HTTPS auto via Traefik)
4. App connectée Supabase (credentials auto-injectés)
5. CI/CD : copier workflow → git push → deploy auto

Version : 1.0.0
