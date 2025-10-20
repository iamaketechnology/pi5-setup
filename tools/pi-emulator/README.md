# 🧪 Pi Emulator - Test Environment

Émulateur Raspberry Pi 5 pour tester l'admin panel et les scripts de déploiement dans un environnement isolé.

---

## 📋 Comparaison Plateformes

| Critère | PC Linux | Mac (Docker Desktop) |
|---------|----------|----------------------|
| **Performance** | ✅ Excellent (natif) | ⚠️ Moyen (VM overhead) |
| **Docker-in-Docker** | ✅ Fonctionne | ⚠️ Limité |
| **Isolation réseau** | ✅ Bridge natif | ⚠️ Complexe |
| **Tests production-like** | ✅ Recommandé | ⚠️ Basique seulement |

**Recommandation : PC Linux** pour tests complets.

---

## 🚀 Quick Start

### 🔑 Pré-requis: Configurer SSH Mac → Linux (si distance)

Si tu veux lancer l'émulateur **à distance depuis ton Mac** vers ton Linux Mint :

```bash
cd tools/pi-emulator
bash scripts/00-setup-ssh-access.sh
```

**Guide complet** : [SSH-SETUP.md](SSH-SETUP.md)

### Linux (Local)

```bash
cd tools/pi-emulator
bash scripts/01-pi-emulator-deploy-linux.sh
```

### Linux (Depuis Mac via SSH)

```bash
cd tools/pi-emulator

# Option 1: Via alias
ssh linux-mint 'bash -s' < scripts/01-pi-emulator-deploy-linux.sh

# Option 2: Via IP
ssh user@192.168.1.100 'bash -s' < scripts/01-pi-emulator-deploy-linux.sh
```

### macOS (Local - Tests basiques)

```bash
cd tools/pi-emulator
bash scripts/01-pi-emulator-deploy-mac.sh
```

---

## 🧪 Tester SSH

```bash
cd tools/pi-emulator
bash scripts/test-ssh.sh linux-mint  # ou user@ip
```

---

## 🔌 Connexion SSH

### Direct

```bash
ssh pi@localhost -p 2222
# Password: raspberry
```

### Depuis Admin Panel

Éditer `tools/admin-panel/config.js` :

```javascript
module.exports = {
  pis: [
    {
      name: 'Pi Emulator Test',
      hostname: 'localhost',
      port: 2222,
      username: 'pi',
      password: 'raspberry'
      // privateKeyPath: '~/.ssh/id_rsa' (recommandé en prod)
    }
  ]
};
```

**⚠️ SÉCURITÉ** : Fichier `config.js` dans `.gitignore` - Ne jamais commit.

---

## 🛠️ Installation Services de Base

Une fois connecté via SSH :

```bash
# Copier script d'init dans le container
docker cp tools/pi-emulator/scripts/02-pi-init-services.sh pi-emulator-test:/tmp/

# Exécuter dans le container
docker exec -it pi-emulator-test bash
sudo bash /tmp/02-pi-init-services.sh all
```

**Ou depuis l'intérieur** :

```bash
ssh pi@localhost -p 2222
# Télécharger scripts depuis GitHub
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/01-supabase-deploy.sh | sudo bash
```

---

## 📊 Services Disponibles

| Service | Port Host | Port Container | URL |
|---------|-----------|----------------|-----|
| SSH | 2222 | 22 | `ssh pi@localhost -p 2222` |
| HTTP | 8080 | 80 | http://localhost:8080 |
| HTTPS | 8443 | 443 | https://localhost:8443 |
| PostgreSQL | 5432 | 5432 | `localhost:5432` |
| Kong (Supabase) | 8000 | 8000 | http://localhost:8000 |
| Minio (Storage) | 9000 | 9000 | http://localhost:9000 |
| Supabase Studio | 8001 | 8001 | http://localhost:8001 |

---

## 🧪 Tester Admin Panel

### 1. Configurer Admin Panel

```bash
cd tools/admin-panel
cp config.example.js config.js

# Éditer config.js avec credentials localhost:2222
nano config.js
```

### 2. Lancer Admin Panel

```bash
npm install
node server.js
```

### 3. Accéder

http://localhost:4000

---

## 📁 Structure Pi Emulator

```
pi-emulator/
├── compose/
│   └── docker-compose.yml       # Configuration Docker
├── scripts/
│   ├── 01-pi-emulator-deploy-linux.sh   # Déploiement Linux
│   ├── 01-pi-emulator-deploy-mac.sh     # Déploiement macOS
│   └── 02-pi-init-services.sh           # Init services de base
├── config/
│   └── .env.example             # Variables environnement
└── README.md
```

---

## 🔧 Commandes Utiles

### Gestion Container

```bash
# Voir logs
docker logs pi-emulator-test -f

# Entrer dans le container
docker exec -it pi-emulator-test bash

# Redémarrer
docker restart pi-emulator-test

# Arrêter
cd tools/pi-emulator
docker compose -f compose/docker-compose.yml down

# Supprimer tout (avec volumes)
docker compose -f compose/docker-compose.yml down -v
```

### Depuis l'intérieur du Container

```bash
# Vérifier Docker
docker ps

# Vérifier user
whoami  # Devrait être 'pi'

# Vérifier stacks
ls ~/stacks/

# Voir mémoire/CPU
free -h
df -h
```

---

## 🐛 Troubleshooting

### SSH ne démarre pas

```bash
docker logs pi-emulator-test --tail 50

# Redémarrer SSH dans le container
docker exec pi-emulator-test service ssh restart
```

### Docker-in-Docker ne fonctionne pas (macOS)

⚠️ Limitation connue sur Mac. Utiliser PC Linux pour tests Docker-in-Docker.

### Ports déjà utilisés

```bash
# Vérifier ports occupés
lsof -i :2222
lsof -i :5432

# Modifier ports dans compose/docker-compose.yml
```

### Permissions volumes

```bash
# Fixer permissions dans le container
docker exec pi-emulator-test bash -c "chown -R pi:pi /home/pi/stacks"
```

---

## 🔄 Reset Complet

```bash
# Arrêter et supprimer tout
cd tools/pi-emulator
docker compose -f compose/docker-compose.yml down -v

# Supprimer volumes
docker volume rm pi-emulator-home pi-emulator-docker

# Relancer
bash scripts/01-pi-emulator-deploy-linux.sh  # ou -mac.sh
```

---

## 📚 Cas d'Usage

### 1. Tester Scripts Déploiement

```bash
ssh pi@localhost -p 2222
curl -fsSL https://raw.githubusercontent.com/.../script.sh | sudo bash
```

### 2. Développer Admin Panel

- Connecter admin panel à `localhost:2222`
- Tester fonctionnalités SSH
- Vérifier status services

### 3. Valider Idempotence

```bash
# Lancer script 2x
curl -fsSL https://.../script.sh | sudo bash
curl -fsSL https://.../script.sh | sudo bash  # Devrait skip si déjà installé
```

### 4. Debugger Issues Production

- Reproduire état production
- Tester fixes
- Valider avant déploiement Pi réel

---

## ⚠️ Limitations

### macOS (Docker Desktop)

- Docker-in-Docker instable
- Performance réduite (VM)
- Réseau bridge complexe
- **Recommandé pour tests basiques uniquement**

### Linux (Natif)

- Pas de limitation majeure
- Comportement proche du Pi réel
- **Recommandé pour validation complète**

### Général

- **Pas 100% identique** au Pi réel (architecture peut différer)
- Toujours tester sur Pi réel avant production
- Services ARM64 peuvent avoir différences subtiles

---

## 🎯 Workflow Recommandé

1. **Développer** : Admin panel sur Mac (tests légers)
2. **Valider** : Scripts sur émulateur Linux (tests complets)
3. **Tester** : Sur Pi réel (validation finale)
4. **Déployer** : Production

---

## 📦 Volumes Persistants

| Volume | Contenu | Taille |
|--------|---------|--------|
| `pi-emulator-home` | `/home/pi` (stacks, config) | Dynamique |
| `pi-emulator-docker` | Images/containers Docker | Dynamique |

**Backup** :

```bash
docker run --rm -v pi-emulator-home:/data -v $(pwd):/backup alpine tar czf /backup/pi-home-backup.tar.gz /data
```

**Restore** :

```bash
docker run --rm -v pi-emulator-home:/data -v $(pwd):/backup alpine tar xzf /backup/pi-home-backup.tar.gz -C /
```

---

## 🔐 Sécurité

**⚠️ Émulateur = Environnement de test uniquement**

- Password par défaut (`raspberry`) - **Ne jamais utiliser en prod**
- Pas de firewall
- Accès root facile
- SSH password auth (vs keys)

**Pour production** :
- Utiliser clés SSH
- Désactiver password auth
- Configurer firewall
- Changer user/password par défaut

---

## 📝 Prochaines Étapes

- [ ] Tester admin panel avec émulateur
- [ ] Valider scripts déploiement
- [ ] Ajouter monitoring (Netdata)
- [ ] Ajouter backups automatiques
- [ ] Créer snapshots pour tests rapides

---

## 🤝 Contribution

Pour améliorer l'émulateur :

1. Tester sur ton environnement
2. Remonter bugs/limitations
3. Proposer improvements
4. Documenter cas d'usage

---

**Version** : 1.0.0
**Last Updated** : 2025-01-20
**Mainteneur** : [@iamaketechnology](https://github.com/iamaketechnology)
