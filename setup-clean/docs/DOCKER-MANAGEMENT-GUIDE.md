# 🐳 Guide de gestion Docker pour Raspberry Pi 5

## 📋 Commandes Docker essentielles

### 🔍 Inspection et monitoring

```bash
# État de tous les conteneurs
docker ps -a

# Utilisation des ressources en temps réel
docker stats

# Informations détaillées d'un conteneur
docker inspect [CONTAINER_NAME]

# Logs d'un conteneur
docker logs [CONTAINER_NAME] --tail=50 --follow

# Espace disque utilisé par Docker
docker system df
```

### 🔄 Gestion des conteneurs

```bash
# Démarrer un conteneur
docker start [CONTAINER_NAME]

# Arrêter un conteneur
docker stop [CONTAINER_NAME]

# Redémarrer un conteneur
docker restart [CONTAINER_NAME]

# Supprimer un conteneur (après l'avoir arrêté)
docker rm [CONTAINER_NAME]

# Exécuter une commande dans un conteneur actif
docker exec -it [CONTAINER_NAME] [COMMAND]
```

### 🖼️ Gestion des images

```bash
# Lister toutes les images
docker images

# Télécharger une image
docker pull [IMAGE_NAME:TAG]

# Supprimer une image
docker rmi [IMAGE_ID]

# Construire une image depuis un Dockerfile
docker build -t [IMAGE_NAME] .
```

## 🎛️ Docker Compose pour Supabase

### 📁 Structure des fichiers

```
/home/pi/stacks/supabase/
├── docker-compose.yml     # Configuration des services
├── .env                   # Variables d'environnement
├── volumes/              # Données persistantes
│   ├── db/              # Base de données PostgreSQL
│   ├── storage/         # Fichiers Storage
│   └── kong/            # Configuration Kong
└── config/              # Configurations
    └── kong.yml         # Config Kong Gateway
```

### 🚀 Commandes Docker Compose

```bash
# Aller dans le répertoire Supabase
cd /home/pi/stacks/supabase

# Démarrer tous les services
docker compose up -d

# Arrêter tous les services
docker compose down

# Redémarrer tous les services
docker compose restart

# Voir l'état des services
docker compose ps

# Logs de tous les services
docker compose logs --tail=20

# Logs d'un service spécifique
docker compose logs [SERVICE_NAME] --tail=50 --follow

# Mettre à jour les images
docker compose pull
docker compose up -d

# Reconstruire et redémarrer
docker compose up -d --build

# Arrêter et supprimer tout (ATTENTION: supprime les données)
docker compose down -v
```

### 🔧 Services Supabase individuels

```bash
# Redémarrer un service spécifique
docker compose restart db
docker compose restart auth
docker compose restart realtime
docker compose restart storage
docker compose restart kong
docker compose restart studio

# Voir les logs d'un service
docker compose logs db --tail=100
docker compose logs auth --follow
docker compose logs realtime --tail=50

# Arrêter/démarrer un service
docker compose stop auth
docker compose start auth
```

## 📊 Monitoring et performance

### 🔍 Surveillance des ressources

```bash
# Utilisation CPU/RAM de chaque conteneur
docker stats --no-stream

# Utilisation continue (actualisée)
docker stats

# Informations détaillées sur un conteneur
docker inspect supabase-db | grep -A 10 "State"

# Processus actifs dans un conteneur
docker top supabase-db
```

### 💾 Gestion de l'espace disque

```bash
# Espace utilisé par Docker
docker system df

# Détail par type
docker system df -v

# Nettoyer les éléments non utilisés
docker system prune -f

# Nettoyer tout (images, conteneurs, réseaux)
docker system prune -a -f

# Nettoyer uniquement les images
docker image prune -a -f

# Nettoyer les volumes (ATTENTION: supprime les données)
docker volume prune -f
```

### 📈 Optimisation Pi 5

```bash
# Vérifier les limites système pour Docker
ulimit -n
cat /proc/sys/fs/file-max

# Statistiques mémoire
free -h
cat /proc/meminfo | grep Available

# Utilisation disque
df -h
du -sh /var/lib/docker
```

## 🗄️ Gestion des données et volumes

### 💾 Volumes Docker

```bash
# Lister tous les volumes
docker volume ls

# Informations sur un volume
docker volume inspect [VOLUME_NAME]

# Créer un volume
docker volume create [VOLUME_NAME]

# Supprimer un volume (ATTENTION: perte de données)
docker volume rm [VOLUME_NAME]
```

### 🔄 Sauvegardes

```bash
# Sauvegarde de la base de données PostgreSQL
docker exec supabase-db pg_dump -U postgres -d postgres > backup_$(date +%Y%m%d_%H%M).sql

# Sauvegarde des volumes Docker
sudo tar -czf supabase_backup_$(date +%Y%m%d).tar.gz /home/pi/stacks/supabase/volumes/

# Restauration de la base de données
docker exec -i supabase-db psql -U postgres -d postgres < backup_20250915_1430.sql
```

### 📁 Accès aux fichiers des conteneurs

```bash
# Copier un fichier du conteneur vers l'hôte
docker cp supabase-db:/var/lib/postgresql/data/postgresql.conf ./

# Copier un fichier de l'hôte vers le conteneur
docker cp ./config.conf supabase-db:/tmp/

# Explorer le système de fichiers d'un conteneur
docker exec -it supabase-db ls -la /
docker exec -it supabase-db find / -name "*.conf" 2>/dev/null
```

## 🌐 Gestion des réseaux

### 🔗 Réseaux Docker

```bash
# Lister les réseaux
docker network ls

# Informations sur un réseau
docker network inspect [NETWORK_NAME]

# Créer un réseau
docker network create [NETWORK_NAME]

# Connecter un conteneur à un réseau
docker network connect [NETWORK_NAME] [CONTAINER_NAME]
```

### 🔍 Diagnostic réseau

```bash
# Tester la connectivité entre conteneurs
docker exec supabase-studio ping supabase-db
docker exec supabase-auth wget -qO- http://supabase-db:5432

# Vérifier les ports ouverts
docker exec supabase-db netstat -tuln
docker port supabase-kong
```

## ⚙️ Configuration et variables d'environnement

### 📝 Fichier .env

```bash
# Éditer les variables d'environnement
cd /home/pi/stacks/supabase
nano .env

# Voir les variables actuelles
cat .env | grep -v "^#" | sort

# Variables importantes à surveiller
grep -E "PASSWORD|SECRET|KEY" .env
```

### 🔄 Rechargement de configuration

```bash
# Après modification du .env ou docker-compose.yml
docker compose down
docker compose up -d

# Vérifier que les variables sont bien prises en compte
docker exec supabase-auth env | grep JWT_SECRET
```

## 🐛 Dépannage Docker

### ❌ Problèmes courants

#### Conteneur qui ne démarre pas
```bash
# Voir les logs d'erreur
docker compose logs [SERVICE] --tail=100

# Vérifier la configuration
docker compose config

# Tenter un redémarrage forcé
docker compose stop [SERVICE]
docker compose start [SERVICE]
```

#### Problème de permissions
```bash
# Corriger les permissions des volumes
sudo chown -R pi:pi /home/pi/stacks/supabase/volumes/

# Vérifier les permissions Docker
sudo usermod -aG docker pi
# Puis redémarrer la session
```

#### Manque d'espace disque
```bash
# Nettoyer Docker
docker system prune -a -f

# Supprimer les logs volumineux
sudo journalctl --vacuum-time=7d

# Vérifier l'espace libre
df -h
```

#### Problèmes de réseau
```bash
# Redémarrer le daemon Docker
sudo systemctl restart docker

# Recréer les réseaux
docker compose down
docker network prune -f
docker compose up -d
```

### 🔧 Commandes de diagnostic

```bash
# État du daemon Docker
sudo systemctl status docker

# Version Docker
docker version
docker compose version

# Informations système Docker
docker info

# Événements Docker en temps réel
docker events

# Vérifier les process Docker
ps aux | grep docker
```

## 🔄 Mise à jour et maintenance

### 📦 Mise à jour des images

```bash
# Mettre à jour toutes les images Supabase
cd /home/pi/stacks/supabase
docker compose pull

# Redémarrer avec les nouvelles images
docker compose down
docker compose up -d

# Nettoyer les anciennes images
docker image prune -a -f
```

### 🧹 Maintenance régulière

```bash
# Script de maintenance hebdomadaire
#!/bin/bash
cd /home/pi/stacks/supabase

# Sauvegarder la base de données
docker exec supabase-db pg_dump -U postgres -d postgres > backup_$(date +%Y%m%d).sql

# Nettoyer Docker
docker system prune -f

# Vérifier l'état des services
docker compose ps

# Redémarrer si nécessaire
docker compose restart
```

### 📊 Logs et rotation

```bash
# Configurer la rotation des logs Docker
sudo nano /etc/docker/daemon.json
```

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

```bash
# Redémarrer Docker pour appliquer
sudo systemctl restart docker
```

## 🚀 Optimisations Pi 5

### ⚡ Configuration optimale

```bash
# Vérifier la configuration Docker optimisée pour Pi 5
cat /etc/docker/daemon.json
```

```json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

### 🔧 Réglages système

```bash
# Vérifier les paramètres kernel optimisés
sysctl vm.swappiness
sysctl vm.max_map_count

# Ajuster si nécessaire
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
```

## 📚 Ressources utiles

### 📖 Documentation

- [Docker Official Docs](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Best Practices](https://docs.docker.com/develop/best-practices/)

### 🛠️ Outils de monitoring

```bash
# Installation d'outils supplémentaires
sudo apt install htop iotop ncdu

# Monitoring des conteneurs
htop
iotop -ao
ncdu /var/lib/docker
```

---

**🎯 Ce guide vous permet de maîtriser complètement Docker sur votre Raspberry Pi 5 !**

Pour toute question spécifique, référez-vous aux logs avec `docker compose logs [service]` et à la documentation officielle Docker.