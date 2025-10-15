# 🚀 PI5-SETUP Bootstrap - Installation One-Liner

## Installation rapide (Recommandé)

Sur votre Raspberry Pi fraîchement installé, exécutez :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/bootstrap.sh | sudo bash
```

C'est tout ! Le script va :
- ✅ Installer Docker si nécessaire
- ✅ Cloner le repository pi5-setup
- ✅ Configurer le PI5 Control Center
- ✅ Créer un service systemd
- ✅ Démarrer l'interface web

## Après l'installation

### 1. Accéder au Control Center

Le script affichera l'URL d'accès. Généralement :

```
http://192.168.1.XXX:4000
http://raspberry-pi.local:4000
```

### 2. Suivre le Setup Wizard

Au premier accès, vous verrez la **Configuration Initiale** dans le dashboard avec 5 étapes :

#### ✅ Étape 1 : Docker (déjà fait)
Docker est installé automatiquement par le bootstrap.

#### ⏸️ Étape 2 : Configuration réseau
Cliquez sur **Configurer** pour :
- Définir une IP statique
- Configurer le hostname
- Paramétrer le DNS

**Script utilisé** : `common-scripts/set-static-ip.sh`

#### ⏸️ Étape 3 : Sécurité de base
Cliquez sur **Configurer** pour :
- Installer et configurer UFW (firewall)
- Installer Fail2ban
- Durcir la configuration SSH

**Script utilisé** : `common-scripts/setup-ufw-firewall.sh`

#### ⏸️ Étape 4 : Reverse Proxy (Traefik)
Cliquez sur **Installer** pour :
- Déployer Traefik
- Configurer les certificats SSL automatiques
- Router les sous-domaines

**Script utilisé** : `01-infrastructure/traefik/scripts/01-traefik-deploy.sh`

#### ⏸️ Étape 5 : Monitoring
Cliquez sur **Installer** pour :
- Déployer Prometheus
- Déployer Grafana
- Configurer les exporteurs (Node, cAdvisor, Postgres)

**Script utilisé** : `03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh`

### 3. Explorer les autres onglets

Une fois la configuration initiale terminée, explorez :

- **🚀 Déploiement** : Installer Supabase, n8n, Ollama, etc.
- **🔧 Maintenance** : Backup, mises à jour, nettoyage
- **🧪 Tests** : Diagnostics et tests de santé
- **🐳 Docker** : Gérer les conteneurs
- **📜 Historique** : Voir toutes les exécutions passées
- **📅 Scheduler** : Planifier des tâches automatiques

## Gestion du service

### Voir le statut
```bash
sudo systemctl status pi5-control-center
```

### Redémarrer
```bash
sudo systemctl restart pi5-control-center
```

### Voir les logs
```bash
sudo journalctl -u pi5-control-center -f
```

### Arrêter
```bash
sudo systemctl stop pi5-control-center
```

## Mise à jour

Pour mettre à jour le Control Center :

```bash
cd ~/pi5-control-center
git pull
cd tools/admin-panel
npm install
sudo systemctl restart pi5-control-center
```

## Architecture

```
~/pi5-control-center/           # Repository cloné
├── bootstrap.sh                # Script d'installation
├── tools/admin-panel/          # Control Center
│   ├── server.js              # Serveur Express
│   ├── config.js              # Configuration SSH
│   ├── data/                  # Base SQLite
│   └── public/                # Interface web
├── 01-infrastructure/         # Scripts infrastructure
├── 02-securite/              # Scripts sécurité
├── 03-monitoring/            # Scripts monitoring
└── common-scripts/           # Scripts utilitaires
```

## Prérequis

- Raspberry Pi OS (Bookworm 64-bit recommandé)
- SSH activé
- Connexion internet
- Au moins 4GB de RAM (8GB recommandé pour Raspberry Pi 5)

## Dépannage

### Le Control Center ne démarre pas

```bash
# Vérifier les logs
sudo journalctl -u pi5-control-center -n 50

# Vérifier Node.js
node --version  # Doit être >= 18

# Réinstaller les dépendances
cd ~/pi5-control-center/tools/admin-panel
npm install
sudo systemctl restart pi5-control-center
```

### Impossible d'accéder à l'interface

```bash
# Vérifier le port
sudo lsof -i :4000

# Vérifier le firewall (si UFW activé)
sudo ufw allow 4000/tcp
```

### Erreur SSH dans le Control Center

Le Control Center se connecte à `localhost` (le Pi lui-même). Vérifiez que SSH écoute sur localhost :

```bash
sudo systemctl status ssh
```

## Support

- 📚 Documentation : [README principal](README.md)
- 🐛 Issues : [GitHub Issues](https://github.com/iamaketechnology/pi5-setup/issues)
- 💬 Discussions : [GitHub Discussions](https://github.com/iamaketechnology/pi5-setup/discussions)

## Sécurité

⚠️ **Important** : Par défaut, le Control Center n'a pas d'authentification. Il est accessible sur le réseau local uniquement.

Pour sécuriser l'accès :
1. Activer l'authentification dans `config.js`
2. Utiliser un tunnel Cloudflare pour l'accès distant
3. Configurer UFW pour restreindre l'accès

---

**Version Bootstrap** : 1.0.0
**Dernière mise à jour** : 2025-01-14
