# 🌐 Héberger Votre Site Web/Application sur Raspberry Pi 5

> **Guide complet pour déployer vos applications web en local**

---

## 📋 Vue d'Ensemble

Vous avez **3 options principales** pour héberger votre site/app sur le Raspberry Pi 5 :

| Option | Type | Difficulté | Recommandé pour |
|--------|------|------------|-----------------|
| **1. Docker Compose** | Conteneurs | ⭐⭐ | **Applications modernes** (React, Node.js, Python, etc.) |
| **2. Traefik + Docker** | Reverse Proxy | ⭐⭐⭐ | **Multiple sites** avec HTTPS automatique |
| **3. Nginx Direct** | Serveur web classique | ⭐ | **Sites statiques simples** (HTML/CSS/JS) |

**Recommandation** : **Option 2 (Traefik + Docker)** si vous avez déjà installé Traefik (Phase 2), sinon **Option 1 (Docker Compose)**.

---

## 🚀 Option 1 : Docker Compose (Recommandé pour débuter)

### Avantages
- ✅ Isolation complète (pas de conflit avec autres apps)
- ✅ Facile à déployer/supprimer
- ✅ Reproductible (un fichier = toute la config)
- ✅ Support tous langages (Node.js, Python, PHP, Go, Rust, etc.)

### Exemples par Type d'Application

---

### 🟢 Site Statique (HTML/CSS/JS)

**Exemple : Portfolio, landing page, documentation**

**Structure** :
```
~/mon-site/
├── docker-compose.yml
└── public/
    ├── index.html
    ├── styles.css
    └── script.js
```

**docker-compose.yml** :
```yaml
version: '3.8'

services:
  mon-site:
    image: nginx:alpine
    container_name: mon-site-web
    restart: unless-stopped
    ports:
      - "8080:80"  # Port 8080 sur le Pi → port 80 du container
    volumes:
      - ./public:/usr/share/nginx/html:ro
    environment:
      - TZ=Europe/Paris
```

**Déployer** :
```bash
cd ~/mon-site
docker compose up -d
```

**Accès** : `http://raspberrypi.local:8080`

---

### 🔵 Application React/Vue/Angular (SPA)

**Exemple : App React après `npm run build`**

**Structure** :
```
~/mon-app-react/
├── docker-compose.yml
└── build/          # Résultat de npm run build
    ├── index.html
    ├── static/
    └── ...
```

**docker-compose.yml** :
```yaml
version: '3.8'

services:
  mon-app-react:
    image: nginx:alpine
    container_name: mon-app-react
    restart: unless-stopped
    ports:
      - "3000:80"
    volumes:
      - ./build:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    environment:
      - TZ=Europe/Paris
```

**nginx.conf** (pour React Router) :
```nginx
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache assets
    location /static/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

**Déployer** :
```bash
# Sur votre PC : build
npm run build

# Copier vers Pi
scp -r build/ pi@raspberrypi.local:~/mon-app-react/

# Sur Pi : déployer
cd ~/mon-app-react
docker compose up -d
```

**Accès** : `http://raspberrypi.local:3000`

---

### 🟡 Application Node.js (Backend API)

**Exemple : API Express, NestJS, etc.**

**Structure** :
```
~/mon-api-nodejs/
├── docker-compose.yml
├── Dockerfile
├── package.json
├── src/
│   └── index.js
└── .env
```

**Dockerfile** :
```dockerfile
FROM node:20-alpine

WORKDIR /app

# Copier package.json
COPY package*.json ./
RUN npm ci --only=production

# Copier code
COPY . .

# Port
EXPOSE 3000

# Démarrer
CMD ["node", "src/index.js"]
```

**docker-compose.yml** :
```yaml
version: '3.8'

services:
  mon-api:
    build: .
    container_name: mon-api-nodejs
    restart: unless-stopped
    ports:
      - "3001:3000"
    volumes:
      - ./src:/app/src:ro  # Mode dev : hot reload
    environment:
      - NODE_ENV=production
      - PORT=3000
      - DATABASE_URL=${DATABASE_URL}
    env_file:
      - .env
```

**.env** :
```env
DATABASE_URL=postgresql://user:pass@localhost:5432/mydb
API_KEY=your_secret_key
```

**Déployer** :
```bash
cd ~/mon-api-nodejs
docker compose up -d --build
```

**Logs** :
```bash
docker logs mon-api-nodejs -f
```

---

### 🟠 Application Python (Flask/FastAPI/Django)

**Exemple : API FastAPI**

**Structure** :
```
~/mon-api-python/
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
└── app/
    └── main.py
```

**Dockerfile** :
```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Installer dépendances
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier code
COPY app/ ./app/

# Port
EXPOSE 8000

# Démarrer avec uvicorn (FastAPI)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**docker-compose.yml** :
```yaml
version: '3.8'

services:
  mon-api-python:
    build: .
    container_name: mon-api-python
    restart: unless-stopped
    ports:
      - "8000:8000"
    volumes:
      - ./app:/app/app:ro
    environment:
      - PYTHONUNBUFFERED=1
```

**requirements.txt** :
```
fastapi==0.109.0
uvicorn[standard]==0.27.0
```

**app/main.py** :
```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello from Raspberry Pi 5!"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}
```

**Déployer** :
```bash
cd ~/mon-api-python
docker compose up -d --build
```

**Test** :
```bash
curl http://raspberrypi.local:8000
```

---

### 🔴 Application PHP (WordPress, Laravel, etc.)

**Exemple : WordPress**

**docker-compose.yml** :
```yaml
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    container_name: mon-wordpress
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - ./wp-content:/var/www/html/wp-content
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress_password
      WORDPRESS_DB_NAME: wordpress

  db:
    image: mariadb:11
    container_name: wordpress-db
    restart: unless-stopped
    volumes:
      - ./db-data:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress_password
```

**Déployer** :
```bash
mkdir -p ~/wordpress
cd ~/wordpress
# Créer docker-compose.yml (copier ci-dessus)
docker compose up -d
```

**Accès** : `http://raspberrypi.local:8080`

---

## 🔥 Option 2 : Traefik + Docker (Recommandé si Traefik installé)

### Avantages
- ✅ **HTTPS automatique** (Let's Encrypt)
- ✅ **Multiple sites** sur même Pi (subdomains ou paths)
- ✅ **Certificats SSL** automatiques
- ✅ **Load balancing** et haute disponibilité

### Prérequis

**Traefik doit être installé** (Phase 2) :
```bash
# Vérifier si Traefik est installé
docker ps | grep traefik
```

Si pas installé, voir [Phase 2 - Traefik](pi5-traefik-stack/README.md)

---

### Exemple 1 : Site React avec Traefik (DuckDNS)

**Structure** :
```
~/mon-app/
├── docker-compose.yml
└── build/
    └── ...
```

**docker-compose.yml** :
```yaml
version: '3.8'

services:
  mon-app:
    image: nginx:alpine
    container_name: mon-app
    restart: unless-stopped
    volumes:
      - ./build:/usr/share/nginx/html:ro
    networks:
      - traefik-network
    labels:
      - "traefik.enable=true"
      # DuckDNS : Path-based routing
      - "traefik.http.routers.mon-app.rule=PathPrefix(`/mon-app`)"
      - "traefik.http.routers.mon-app.entrypoints=websecure"
      - "traefik.http.routers.mon-app.tls.certresolver=letsencrypt"
      # Middleware : strip /mon-app prefix
      - "traefik.http.middlewares.mon-app-strip.stripprefix.prefixes=/mon-app"
      - "traefik.http.routers.mon-app.middlewares=mon-app-strip"
      - "traefik.http.services.mon-app.loadbalancer.server.port=80"

networks:
  traefik-network:
    external: true
```

**Déployer** :
```bash
cd ~/mon-app
docker compose up -d
```

**Accès** : `https://monpi.duckdns.org/mon-app`

---

### Exemple 2 : API Node.js avec Traefik (Cloudflare)

**docker-compose.yml** :
```yaml
version: '3.8'

services:
  mon-api:
    build: .
    container_name: mon-api
    restart: unless-stopped
    environment:
      - NODE_ENV=production
    networks:
      - traefik-network
    labels:
      - "traefik.enable=true"
      # Cloudflare : Subdomain routing
      - "traefik.http.routers.mon-api.rule=Host(`api.mondomaine.com`)"
      - "traefik.http.routers.mon-api.entrypoints=websecure"
      - "traefik.http.routers.mon-api.tls.certresolver=cloudflare"
      - "traefik.http.services.mon-api.loadbalancer.server.port=3000"

networks:
  traefik-network:
    external: true
```

**Accès** : `https://api.mondomaine.com`

---

### Exemple 3 : Multiple Sites (React + API + Admin)

**docker-compose.yml** :
```yaml
version: '3.8'

services:
  # Frontend React
  frontend:
    image: nginx:alpine
    container_name: mon-frontend
    restart: unless-stopped
    volumes:
      - ./frontend/build:/usr/share/nginx/html:ro
    networks:
      - traefik-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=Host(`app.mondomaine.com`)"
      - "traefik.http.routers.frontend.entrypoints=websecure"
      - "traefik.http.routers.frontend.tls.certresolver=cloudflare"
      - "traefik.http.services.frontend.loadbalancer.server.port=80"

  # Backend API
  backend:
    build: ./backend
    container_name: mon-backend
    restart: unless-stopped
    environment:
      - DATABASE_URL=postgresql://user:pass@postgres:5432/mydb
    networks:
      - traefik-network
      - backend-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.backend.rule=Host(`api.mondomaine.com`)"
      - "traefik.http.routers.backend.entrypoints=websecure"
      - "traefik.http.routers.backend.tls.certresolver=cloudflare"
      - "traefik.http.services.backend.loadbalancer.server.port=3000"

  # Admin Panel
  admin:
    image: nginx:alpine
    container_name: mon-admin
    restart: unless-stopped
    volumes:
      - ./admin/build:/usr/share/nginx/html:ro
    networks:
      - traefik-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.admin.rule=Host(`admin.mondomaine.com`)"
      - "traefik.http.routers.admin.entrypoints=websecure"
      - "traefik.http.routers.admin.tls.certresolver=cloudflare"
      # Protection Authelia (si installé)
      - "traefik.http.routers.admin.middlewares=authelia@file"
      - "traefik.http.services.admin.loadbalancer.server.port=80"

  # Database PostgreSQL
  postgres:
    image: postgres:15-alpine
    container_name: mon-postgres
    restart: unless-stopped
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=mydb
    networks:
      - backend-network

networks:
  traefik-network:
    external: true
  backend-network:
    internal: true
```

**Résultat** :
- Frontend : `https://app.mondomaine.com`
- API : `https://api.mondomaine.com`
- Admin : `https://admin.mondomaine.com` (protégé par Authelia)

---

## 🌍 Option 3 : Nginx Direct (Sites Statiques Simples)

### Avantages
- ✅ Très léger (~10 MB RAM)
- ✅ Performance maximale
- ✅ Simple pour sites statiques

### Installation

```bash
# Installer Nginx
sudo apt-get update
sudo apt-get install -y nginx

# Démarrer
sudo systemctl start nginx
sudo systemctl enable nginx
```

### Héberger Site Statique

**Méthode 1 : Répertoire par défaut**

```bash
# Copier vos fichiers
sudo cp -r ~/mon-site/* /var/www/html/

# Permissions
sudo chown -R www-data:www-data /var/www/html
```

**Accès** : `http://raspberrypi.local`

**Méthode 2 : Site personnalisé**

```bash
# Créer répertoire
sudo mkdir -p /var/www/mon-site

# Copier fichiers
sudo cp -r ~/mon-site/* /var/www/mon-site/

# Configuration Nginx
sudo nano /etc/nginx/sites-available/mon-site
```

**Configuration** :
```nginx
server {
    listen 8080;
    server_name _;

    root /var/www/mon-site;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

**Activer** :
```bash
sudo ln -s /etc/nginx/sites-available/mon-site /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

**Accès** : `http://raspberrypi.local:8080`

---

## 🔧 Connexion avec Base de Données

### PostgreSQL (Recommandé)

**Si Supabase installé** (Phase 1), utiliser PostgreSQL existant :

```bash
# Connexion string
postgresql://postgres:your-super-secret-jwt-token-with-at-least-32-characters-long@localhost:5432/postgres
```

**Créer nouvelle base** :
```bash
docker exec -it supabase-db psql -U postgres

CREATE DATABASE mon_app;
\q
```

**Connexion depuis app** :
```javascript
// Node.js avec pg
const { Pool } = require('pg');

const pool = new Pool({
  host: 'raspberrypi.local',
  port: 5432,
  database: 'mon_app',
  user: 'postgres',
  password: 'your-password'
});
```

---

### MySQL/MariaDB

**Déployer avec Docker Compose** :

```yaml
version: '3.8'

services:
  mysql:
    image: mariadb:11
    container_name: mysql-db
    restart: unless-stopped
    ports:
      - "3306:3306"
    volumes:
      - ./mysql-data:/var/lib/mysql
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: mon_app
      MYSQL_USER: app_user
      MYSQL_PASSWORD: app_password
```

---

### MongoDB

```yaml
version: '3.8'

services:
  mongodb:
    image: mongo:7
    container_name: mongodb
    restart: unless-stopped
    ports:
      - "27017:27017"
    volumes:
      - ./mongo-data:/data/db
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: password
```

---

## 📱 Déploiement Continu (CI/CD)

### Avec Gitea (Phase 5)

**Workflow automatique** : Push code → Build → Deploy sur Pi

**.gitea/workflows/deploy.yml** :
```yaml
name: Deploy to Pi

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build React App
        run: |
          npm ci
          npm run build

      - name: Deploy to Pi
        uses: appleboy/scp-action@v0.1.4
        with:
          host: raspberrypi.local
          username: pi
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          source: "build/*"
          target: "/home/pi/mon-app/"

      - name: Restart Docker
        uses: appleboy/ssh-action@v0.1.10
        with:
          host: raspberrypi.local
          username: pi
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /home/pi/mon-app
            docker compose down
            docker compose up -d --build
```

---

## 🎯 Exemples Complets par Framework

### Next.js (React SSR)

**Dockerfile** :
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package*.json ./
RUN npm ci --only=production
EXPOSE 3000
CMD ["npm", "start"]
```

---

### Nuxt.js (Vue SSR)

**Dockerfile** :
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
EXPOSE 3000
CMD ["npm", "start"]
```

---

### Django (Python)

**Dockerfile** :
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN python manage.py collectstatic --noinput
EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "myproject.wsgi:application"]
```

---

### Laravel (PHP)

**docker-compose.yml** :
```yaml
version: '3.8'

services:
  laravel:
    image: php:8.2-fpm-alpine
    container_name: laravel-app
    volumes:
      - ./:/var/www/html
    networks:
      - laravel-network

  nginx:
    image: nginx:alpine
    container_name: laravel-nginx
    ports:
      - "8080:80"
    volumes:
      - ./:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    networks:
      - laravel-network

networks:
  laravel-network:
```

---

## 🛠️ Maintenance & Monitoring

### Voir Logs

```bash
# Logs temps réel
docker logs mon-app -f

# Dernières 100 lignes
docker logs mon-app --tail 100

# Depuis 1h
docker logs mon-app --since 1h
```

### Redémarrer

```bash
docker restart mon-app
# ou
docker compose restart
```

### Mise à Jour

```bash
cd ~/mon-app
git pull  # Si code versionné
docker compose down
docker compose up -d --build
```

### Monitoring avec Stack Manager

```bash
# Voir RAM utilisée
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh status
```

---

## ✅ Checklist Déploiement

- [ ] Code prêt (build si nécessaire)
- [ ] Dockerfile créé (si app custom)
- [ ] docker-compose.yml configuré
- [ ] Ports ouverts dans firewall (`sudo ufw allow 8080/tcp`)
- [ ] Variables d'environnement (.env) configurées
- [ ] Base de données créée (si nécessaire)
- [ ] Container démarré (`docker compose up -d`)
- [ ] Test accès (`curl http://localhost:8080`)
- [ ] Logs vérifiés (`docker logs -f`)
- [ ] Backup configuration (`cp docker-compose.yml docker-compose.yml.bak`)

---

## 📚 Documentation Complète

### Par Framework
- [Next.js Docs](https://nextjs.org/docs/deployment)
- [React Docs](https://react.dev/learn/start-a-new-react-project)
- [Vue Docs](https://vuejs.org/guide/quick-start.html)
- [Django Docs](https://docs.djangoproject.com/en/5.0/howto/deployment/)
- [Laravel Docs](https://laravel.com/docs/deployment)

### Docker
- [Docker Compose Docs](https://docs.docker.com/compose/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

### Traefik
- [Traefik Docs](https://doc.traefik.io/traefik/)
- [Phase 2 - Traefik Guide](pi5-traefik-stack/README.md)

---

<p align="center">
  <strong>🌐 Hébergez Votre Site Web sur Raspberry Pi 5 ! 🚀</strong>
</p>

<p align="center">
  <sub>Docker • Traefik • HTTPS • Multiple Sites • 100% Open Source</sub>
</p>
