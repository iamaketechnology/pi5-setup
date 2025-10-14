# 🔒 Security - Scripts de Sécurisation

Scripts de correction et migration pour renforcer la sécurité des services.

---

## 📜 Scripts

### `fix-portainer-localhost.sh`

Reconfigure Portainer existant pour bind localhost only (127.0.0.1) au lieu de 0.0.0.0.

**Problème** :
Par défaut, Portainer expose le port 9000 sur 0.0.0.0 (toutes interfaces réseau), ce qui le rend accessible depuis Internet si UFW est mal configuré.

**Solution** :
Ce script migre Portainer vers 127.0.0.1:8080, accessible uniquement :
- Localement (depuis le Pi)
- Via SSH tunnel (depuis Mac/PC)

**Variables** :
```bash
PORTAINER_CONTAINER=portainer          # Nom du container
PORTAINER_PORT=8080                    # Port localhost (défaut: 8080)
PORTAINER_IMAGE=portainer/portainer-ce:latest
```

**Usage** :

```bash
# Migration standard
sudo bash fix-portainer-localhost.sh

# Port custom
PORTAINER_PORT=9001 sudo bash fix-portainer-localhost.sh

# Container custom
PORTAINER_CONTAINER=my-portainer sudo bash fix-portainer-localhost.sh
```

**Process** :
1. Vérifie si Portainer existe
2. Affiche configuration actuelle (0.0.0.0:9000 → RISQUE)
3. Demande confirmation
4. Arrête le container
5. Supprime le container (données préservées dans volume)
6. Recrée avec `-p 127.0.0.1:8080:9000`
7. Vérifie nouvelle config (127.0.0.1:8080 → ✅)

**Données préservées** :
- Volume `portainer_data` conservé
- Utilisateurs, configuration, connexions Docker inchangées

**Accès après migration** :

```bash
# LOCAL (depuis le Pi)
http://localhost:8080

# DISTANT (depuis Mac/PC)
ssh -L 8080:localhost:8080 pi@192.168.1.74
# Puis ouvrir : http://localhost:8080

# TUNNEL PERMANENT (background)
ssh -f -N -L 8080:localhost:8080 pi@192.168.1.74
```

**Vérification** :

```bash
# Vérifier bind
docker port portainer
# Output attendu : 9000/tcp -> 127.0.0.1:8080

# Vérifier netstat
sudo netstat -tlnp | grep :8080
# Output attendu : tcp 0 0 127.0.0.1:8080 0.0.0.0:* LISTEN

# Test accès local
curl http://localhost:8080
# ✅ OK

# Test accès public (doit échouer)
curl http://192.168.1.74:8080 --max-time 3
# ❌ Connection refused (normal)
```

---

## 🔐 Bonnes Pratiques

### Portainer

1. **Toujours localhost** : Jamais exposer Portainer sur 0.0.0.0
2. **Mot de passe fort** : 16+ caractères, alphanumérique + symboles
3. **SSH tunnel** : Utiliser `-L` pour accès distant sécurisé
4. **HTTPS** : Si exposition nécessaire, toujours via Traefik + Let's Encrypt
5. **RBAC** : Activer rôles utilisateurs (Business Edition)

### Services sensibles

**Jamais exposer publiquement** :
- Portainer (gestion Docker)
- Grafana (monitoring)
- Prometheus (métriques)
- PostgreSQL (base de données)
- Redis (cache)

**Toujours via Traefik** :
- Applications web (Supabase, Nextcloud, etc.)
- APIs publiques
- Sites statiques

**SSH Tunneling** :
```bash
# Portainer
ssh -L 8080:localhost:8080 pi@pi5.local

# Grafana
ssh -L 3000:localhost:3000 pi@pi5.local

# Multiple ports
ssh -L 8080:localhost:8080 -L 3000:localhost:3000 pi@pi5.local

# Permanent (background)
ssh -f -N -L 8080:localhost:8080 pi@pi5.local

# Tuer tunnel background
pkill -f "ssh.*-L 8080"
```

---

## 🛡️ Audit Sécurité

### Vérifier exposition ports

```bash
# Voir tous les ports ouverts
sudo netstat -tlnp

# Filtrer Docker
sudo netstat -tlnp | grep docker-proxy

# Vérifier bindings dangereux (0.0.0.0)
sudo netstat -tlnp | grep "0.0.0.0:" | grep -v ":80\|:443"
```

**Ports attendus** :
```
127.0.0.1:8080    # Portainer (OK)
0.0.0.0:80        # Traefik HTTP (OK)
0.0.0.0:443       # Traefik HTTPS (OK)
127.0.0.1:*       # Tous autres services (OK)
```

**Ports DANGEREUX** :
```
0.0.0.0:9000      # Portainer public (❌ RISQUE)
0.0.0.0:5432      # PostgreSQL public (❌ CRITIQUE)
0.0.0.0:6379      # Redis public (❌ CRITIQUE)
0.0.0.0:3000      # Grafana public (❌ RISQUE)
```

### Audit complet

```bash
# 1. Script audit réseau
sudo bash /home/pi/pi5-setup/common-scripts/security-audit-complete.sh

# 2. Vérifier UFW
sudo ufw status verbose

# 3. Docker networks
docker network ls
docker network inspect bridge | grep -A 5 "Containers"

# 4. Containers exposition
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

---

## 🆘 Urgence - Correction Rapide

### Portainer exposé publiquement

```bash
# Fix immédiat
sudo bash maintenance/security/fix-portainer-localhost.sh

# Ou manuellement
docker stop portainer
docker rm portainer
docker run -d \
  --name portainer \
  --restart=always \
  -p 127.0.0.1:8080:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

### PostgreSQL exposé publiquement

```bash
# Vérifier
docker ps | grep postgres
docker port supabase-db

# Fix : Reconfigurer docker-compose.yml
# AVANT:
#   ports:
#     - "5432:5432"
#
# APRÈS:
#   ports:
#     - "127.0.0.1:54322:5432"

cd /home/pi/stacks/supabase
docker compose down
docker compose up -d
```

### Bloquer port avec UFW

```bash
# Si service ne peut pas être reconfiguré
sudo ufw deny 9000/tcp comment "Block Portainer"
sudo ufw deny 5432/tcp comment "Block PostgreSQL"
sudo ufw reload
```

---

## 📚 Références

- [SSH Tunneling Guide](../../docs/SSH-TUNNELING-GUIDE.md)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Portainer Security](https://docs.portainer.io/advanced/security)
- [UFW Guide](../../docs/UFW-FIREWALL-GUIDE.md)

---

**Version** : 1.0.0
