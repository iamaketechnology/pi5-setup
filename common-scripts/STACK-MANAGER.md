# 🎛️ Stack Manager - Gestion Facile des Stacks Docker

> **Gérez tous vos stacks Docker Pi5 depuis une interface simple**

---

## 📋 Vue d'Ensemble

Le **Stack Manager** est un outil qui vous permet de contrôler facilement tous vos stacks Docker installés :
- ✅ Voir l'état de tous les stacks (running/stopped)
- ✅ Démarrer/arrêter des stacks pour gérer la RAM
- ✅ Voir la consommation RAM par stack
- ✅ Activer/désactiver le démarrage automatique au boot
- ✅ Interface interactive (TUI) avec menus

---

## 🚀 Quick Start

### Mode Interactif (Recommandé)

```bash
# Lancer l'interface interactive
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh interactive
```

**Navigation** :
- Flèches haut/bas : Sélectionner stack
- Entrée : Valider
- Tab : Changer de champ
- Esc : Retour/Quitter

### Ligne de Commande

```bash
# Voir l'état de tous les stacks
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh status

# Arrêter un stack pour libérer RAM
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop jellyfin

# Démarrer un stack
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh start jellyfin

# Voir consommation RAM
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh ram
```

---

## 📚 Commandes Disponibles

### `status` - État des Stacks

Affiche l'état complet de tous les stacks installés.

```bash
sudo ./09-stack-manager.sh status
```

**Sortie exemple** :
```
STACK           STATUS       CONTAINERS  RAM (MB)  BOOT
─────           ──────       ──────────  ────────  ────
supabase        ✓ running    8           1200      enabled
traefik         ✓ running    1           100       enabled
homepage        ✓ running    1           80        enabled
monitoring      ✓ running    4           1100      enabled
gitea           ✓ running    2           450       disabled
jellyfin        ○ stopped    0           0         disabled
nextcloud       ○ stopped    0           0         disabled
authelia        ✓ running    2           150       enabled

RAM totale utilisée: 3080 MB
RAM système: 4200 MB / 16000 MB (26% utilisé, 11800 MB disponible)
```

**Légende symboles** :
- `✓ running` : Stack complètement démarré (vert)
- `○ stopped` : Stack arrêté (jaune)
- `◐ partial` : Stack partiellement démarré (jaune)
- `✗ error` : Erreur (rouge)

### `list` - Lister Stacks

Alias de `status`.

```bash
sudo ./09-stack-manager.sh list
```

### `ram` - Consommation RAM

Affiche la consommation RAM par stack, triée par ordre décroissant.

```bash
sudo ./09-stack-manager.sh ram
```

**Sortie exemple** :
```
Consommation RAM par stack:

supabase             1200 MB
monitoring           1100 MB
gitea                 450 MB
authelia              150 MB
traefik               100 MB
homepage               80 MB
```

### `start <stack>` - Démarrer Stack

Démarre un stack arrêté.

```bash
# Démarrer Jellyfin
sudo ./09-stack-manager.sh start jellyfin

# Démarrer Nextcloud
sudo ./09-stack-manager.sh start nextcloud
```

**Effet** :
- Exécute `docker compose up -d` dans le répertoire du stack
- Affiche la nouvelle consommation RAM après démarrage

### `stop <stack>` - Arrêter Stack

Arrête un stack en cours d'exécution.

```bash
# Arrêter Jellyfin pour libérer RAM
sudo ./09-stack-manager.sh stop jellyfin

# Arrêter tous les stacks média
sudo ./09-stack-manager.sh stop jellyfin
sudo ./09-stack-manager.sh stop arr-stack
```

**Effet** :
- Exécute `docker compose down`
- Libère immédiatement la RAM utilisée

### `restart <stack>` - Redémarrer Stack

Redémarre un stack (stop + start).

```bash
# Redémarrer Supabase après changement config
sudo ./09-stack-manager.sh restart supabase
```

### `enable <stack>` - Activer Démarrage Auto

Active le démarrage automatique du stack au boot système (via systemd).

```bash
# Activer démarrage auto Supabase
sudo ./09-stack-manager.sh enable supabase

# Activer tous les stacks essentiels
sudo ./09-stack-manager.sh enable traefik
sudo ./09-stack-manager.sh enable homepage
sudo ./09-stack-manager.sh enable monitoring
```

**Effet** :
- Crée un service systemd `docker-compose-<stack>.service`
- Le stack démarrera automatiquement au prochain reboot

### `disable <stack>` - Désactiver Démarrage Auto

Désactive le démarrage automatique au boot.

```bash
# Désactiver démarrage auto Jellyfin (libère RAM au boot)
sudo ./09-stack-manager.sh disable jellyfin

# Désactiver stacks non-essentiels
sudo ./09-stack-manager.sh disable nextcloud
sudo ./09-stack-manager.sh disable gitea
```

**Effet** :
- Désactive le service systemd
- Le stack ne démarrera plus au boot (vous le démarrerez manuellement quand nécessaire)

### `interactive` - Mode Interactif (TUI)

Lance une interface interactive pour gérer les stacks facilement.

```bash
sudo ./09-stack-manager.sh interactive
```

**Fonctionnalités** :
- Sélection stack avec flèches
- Menu d'actions contextuelles (start/stop/restart/enable/disable)
- Affichage RAM
- Affichage état détaillé
- Interface intuitive (whiptail/dialog)

---

## 💡 Cas d'Usage Réels

### 1. Libérer RAM pour des Tâches Lourdes

**Scénario** : Vous voulez compiler un gros projet, mais vous avez besoin de plus de RAM.

```bash
# Voir consommation actuelle
sudo ./09-stack-manager.sh ram

# Arrêter stacks temporairement inutilisés
sudo ./09-stack-manager.sh stop jellyfin      # Libère ~300 MB
sudo ./09-stack-manager.sh stop arr-stack     # Libère ~500 MB
sudo ./09-stack-manager.sh stop nextcloud     # Libère ~500 MB

# Vérifier RAM disponible
sudo ./09-stack-manager.sh status

# Faire votre travail lourd...

# Redémarrer les stacks ensuite
sudo ./09-stack-manager.sh start jellyfin
sudo ./09-stack-manager.sh start arr-stack
```

**Résultat** : +1.3 GB RAM libérée temporairement !

### 2. Configurer Stacks Essentiels au Boot

**Scénario** : Vous voulez que seuls les stacks essentiels démarrent automatiquement (backend + monitoring), et démarrer les autres manuellement quand nécessaire.

```bash
# Activer stacks essentiels
sudo ./09-stack-manager.sh enable supabase
sudo ./09-stack-manager.sh enable traefik
sudo ./09-stack-manager.sh enable homepage
sudo ./09-stack-manager.sh enable monitoring
sudo ./09-stack-manager.sh enable authelia

# Désactiver stacks optionnels (démarrage manuel)
sudo ./09-stack-manager.sh disable jellyfin
sudo ./09-stack-manager.sh disable arr-stack
sudo ./09-stack-manager.sh disable nextcloud
sudo ./09-stack-manager.sh disable gitea

# Vérifier configuration boot
sudo ./09-stack-manager.sh status
```

**Résultat** :
- **Au boot** : 2.5 GB RAM utilisée (stacks essentiels)
- **Manuellement** : Démarrer Jellyfin quand vous voulez regarder un film
- **Total disponible** : ~13.5 GB RAM au démarrage !

### 3. Journée "Développement" vs "Média"

**Scénario** : Le matin vous développez (besoin Gitea + Supabase), le soir vous regardez des films (besoin Jellyfin).

**Mode "Développement" (Matin)** :
```bash
# Arrêter stacks média
sudo ./09-stack-manager.sh stop jellyfin
sudo ./09-stack-manager.sh stop arr-stack

# Démarrer stacks dev
sudo ./09-stack-manager.sh start gitea
sudo ./09-stack-manager.sh start supabase
```

**Mode "Média" (Soir)** :
```bash
# Arrêter stacks dev
sudo ./09-stack-manager.sh stop gitea

# Démarrer stacks média
sudo ./09-stack-manager.sh start jellyfin
sudo ./09-stack-manager.sh start arr-stack
```

**Résultat** : Optimisation RAM selon vos besoins du moment !

### 4. Mode Interactif pour Gestion Rapide

**Scénario** : Vous voulez une interface simple pour gérer tous les stacks.

```bash
sudo ./09-stack-manager.sh interactive
```

**Navigation** :
1. Menu principal : Liste des stacks avec statut
2. Sélectionner un stack → Menu d'actions
3. Choisir action (start/stop/restart/enable/disable)
4. Résultat affiché immédiatement

**Avantage** : Pas besoin de retenir les commandes, tout est dans des menus !

### 5. Monitoring RAM Avant/Après

**Scénario** : Vous voulez voir combien de RAM vous libérez en arrêtant des stacks.

```bash
# Avant
sudo ./09-stack-manager.sh status
# RAM système: 4500 MB / 16000 MB (28% utilisé)

# Arrêter stacks gourmands
sudo ./09-stack-manager.sh stop monitoring  # -1100 MB
sudo ./09-stack-manager.sh stop nextcloud   # -500 MB

# Après
sudo ./09-stack-manager.sh status
# RAM système: 2900 MB / 16000 MB (18% utilisé)
```

**Résultat** : -1600 MB libérés, visible immédiatement !

---

## 🛠️ Configuration Avancée

### Variables d'Environnement

```bash
# Changer le répertoire base des stacks (défaut: /home/pi/stacks)
export STACKS_BASE_DIR=/mnt/external/stacks
sudo ./09-stack-manager.sh status
```

### Dry-Run (Simulation)

Voir ce qui serait fait sans exécuter réellement :

```bash
sudo ./09-stack-manager.sh stop jellyfin --dry-run
# [DRY-RUN] docker compose -f /home/pi/stacks/jellyfin/docker-compose.yml down
```

### Mode Verbeux

Afficher plus de détails :

```bash
sudo ./09-stack-manager.sh start supabase --verbose
```

---

## 🔧 Intégration avec Autres Scripts

### Backup Avant Arrêt

```bash
# Backup puis arrêt
sudo ~/pi5-setup/pi5-supabase-stack/scripts/maintenance/supabase-backup.sh
sudo ./09-stack-manager.sh stop supabase
```

### Healthcheck Après Démarrage

```bash
# Démarrer puis vérifier santé
sudo ./09-stack-manager.sh start monitoring
sleep 10
sudo ~/pi5-setup/pi5-monitoring-stack/scripts/healthcheck.sh
```

### Script Automatisé (Cron)

Créer un script qui arrête les stacks la nuit (économiser énergie) :

```bash
#!/bin/bash
# /usr/local/bin/stack-night-mode.sh

# Arrêter stacks non-essentiels la nuit (23h-7h)
current_hour=$(date +%H)

if [[ ${current_hour} -ge 23 ]] || [[ ${current_hour} -lt 7 ]]; then
  /home/pi/pi5-setup/common-scripts/09-stack-manager.sh stop jellyfin
  /home/pi/pi5-setup/common-scripts/09-stack-manager.sh stop arr-stack
  /home/pi/pi5-setup/common-scripts/09-stack-manager.sh stop gitea
else
  # Redémarrer le matin
  /home/pi/pi5-setup/common-scripts/09-stack-manager.sh start jellyfin
  /home/pi/pi5-setup/common-scripts/09-stack-manager.sh start gitea
fi
```

**Crontab** :
```bash
# Arrêter stacks à 23h
0 23 * * * /usr/local/bin/stack-night-mode.sh

# Redémarrer stacks à 7h
0 7 * * * /usr/local/bin/stack-night-mode.sh
```

---

## 📊 Exemples de Profils d'Utilisation

### Profil "Minimal" (2.5 GB RAM)

**Stacks activés au boot** :
- ✅ Traefik (reverse proxy)
- ✅ Homepage (dashboard)
- ✅ Supabase (backend)
- ✅ Authelia (auth)

**Stacks démarrés manuellement** :
- ⏸️ Monitoring (quand besoin de voir métriques)
- ⏸️ Gitea (quand besoin de dev)
- ⏸️ Jellyfin (quand besoin de regarder films)
- ⏸️ Nextcloud (quand besoin de sync fichiers)

**Configuration** :
```bash
sudo ./09-stack-manager.sh enable traefik
sudo ./09-stack-manager.sh enable homepage
sudo ./09-stack-manager.sh enable supabase
sudo ./09-stack-manager.sh enable authelia
sudo ./09-stack-manager.sh disable monitoring
sudo ./09-stack-manager.sh disable gitea
sudo ./09-stack-manager.sh disable jellyfin
sudo ./09-stack-manager.sh disable nextcloud
```

### Profil "Complet" (4.5 GB RAM)

**Stacks activés au boot** :
- ✅ Tous les stacks (monitoring inclus)

**Configuration** :
```bash
sudo ./09-stack-manager.sh enable supabase
sudo ./09-stack-manager.sh enable traefik
sudo ./09-stack-manager.sh enable homepage
sudo ./09-stack-manager.sh enable monitoring
sudo ./09-stack-manager.sh enable gitea
sudo ./09-stack-manager.sh enable jellyfin
sudo ./09-stack-manager.sh enable authelia
```

### Profil "Media Server" (3 GB RAM)

**Stacks activés au boot** :
- ✅ Traefik
- ✅ Homepage
- ✅ Jellyfin
- ✅ arr-stack (Radarr, Sonarr, Prowlarr)
- ✅ Authelia

**Stacks désactivés** :
- ⏸️ Supabase (développement pas nécessaire)
- ⏸️ Gitea (développement pas nécessaire)
- ⏸️ Monitoring (optionnel)
- ⏸️ Nextcloud (utilise autre solution cloud)

**Configuration** :
```bash
sudo ./09-stack-manager.sh enable traefik
sudo ./09-stack-manager.sh enable homepage
sudo ./09-stack-manager.sh enable jellyfin
sudo ./09-stack-manager.sh enable arr-stack
sudo ./09-stack-manager.sh enable authelia
sudo ./09-stack-manager.sh disable supabase
sudo ./09-stack-manager.sh disable gitea
sudo ./09-stack-manager.sh disable monitoring
sudo ./09-stack-manager.sh disable nextcloud
```

---

## 🆘 Troubleshooting

### Erreur: "Stack non trouvé"

**Problème** :
```
Stack 'jellyfin' non trouvé (/home/pi/stacks/jellyfin)
```

**Solutions** :
1. Vérifier que le stack est bien installé :
   ```bash
   ls -la /home/pi/stacks/
   ```

2. Vérifier le nom exact du stack :
   ```bash
   sudo ./09-stack-manager.sh list
   ```

3. Si le stack est ailleurs, spécifier le chemin :
   ```bash
   export STACKS_BASE_DIR=/autre/chemin
   sudo ./09-stack-manager.sh status
   ```

### RAM affichée à 0 pour un stack running

**Problème** : Le stack est `running` mais RAM affiche `0 MB`.

**Cause** : Les conteneurs viennent de démarrer (pas encore de stats Docker).

**Solution** : Attendre 5-10 secondes et relancer :
```bash
sleep 10
sudo ./09-stack-manager.sh ram
```

### Service systemd ne démarre pas au boot

**Problème** : Stack configuré avec `enable` mais ne démarre pas au reboot.

**Solutions** :
1. Vérifier le service systemd :
   ```bash
   systemctl status docker-compose-supabase.service
   ```

2. Voir les logs :
   ```bash
   journalctl -u docker-compose-supabase.service -n 50
   ```

3. Vérifier que Docker démarre avant :
   ```bash
   systemctl is-enabled docker.service
   ```

4. Tester manuellement le service :
   ```bash
   systemctl start docker-compose-supabase.service
   ```

### Mode interactif ne fonctionne pas

**Problème** : `whiptail` ou `dialog` non installé.

**Solution** :
```bash
sudo apt-get update
sudo apt-get install -y whiptail
```

### Stack reste en état "partial"

**Problème** : Certains conteneurs running, d'autres stopped.

**Solutions** :
1. Voir quels conteneurs sont en erreur :
   ```bash
   cd /home/pi/stacks/supabase
   docker compose ps
   ```

2. Voir les logs du conteneur en erreur :
   ```bash
   docker compose logs -f <service-en-erreur>
   ```

3. Redémarrer le stack complet :
   ```bash
   sudo ./09-stack-manager.sh restart supabase
   ```

---

## 📚 Référence Complète

### Stacks Détectés Automatiquement

| Stack | Répertoire | RAM Typique |
|-------|------------|-------------|
| `supabase` | `/home/pi/stacks/supabase` | ~1200 MB |
| `traefik` | `/home/pi/stacks/traefik` | ~100 MB |
| `homepage` | `/home/pi/stacks/homepage` | ~80 MB |
| `monitoring` | `/home/pi/stacks/monitoring` | ~1100 MB |
| `gitea` | `/home/pi/stacks/gitea` | ~450 MB |
| `storage` | `/home/pi/stacks/storage` | ~50 MB (FileBrowser) |
| `nextcloud` | `/home/pi/stacks/nextcloud` | ~500 MB |
| `jellyfin` | `/home/pi/stacks/jellyfin` | ~300 MB |
| `arr-stack` | `/home/pi/stacks/arr-stack` | ~500 MB |
| `authelia` | `/home/pi/stacks/authelia` | ~150 MB |
| `portainer` | `/home/pi/portainer` | ~100 MB |

### Commandes Résumées

| Commande | Description | Exemple |
|----------|-------------|---------|
| `status` | État de tous les stacks | `./09-stack-manager.sh status` |
| `list` | Alias de `status` | `./09-stack-manager.sh list` |
| `ram` | Consommation RAM triée | `./09-stack-manager.sh ram` |
| `start <stack>` | Démarrer stack | `./09-stack-manager.sh start jellyfin` |
| `stop <stack>` | Arrêter stack | `./09-stack-manager.sh stop jellyfin` |
| `restart <stack>` | Redémarrer stack | `./09-stack-manager.sh restart supabase` |
| `enable <stack>` | Activer boot auto | `./09-stack-manager.sh enable traefik` |
| `disable <stack>` | Désactiver boot auto | `./09-stack-manager.sh disable gitea` |
| `interactive` | Mode TUI interactif | `./09-stack-manager.sh interactive` |

### Options Communes

| Option | Description |
|--------|-------------|
| `--dry-run` | Simulation sans exécution |
| `--verbose, -v` | Mode verbeux |
| `--quiet, -q` | Mode silencieux |
| `--no-color` | Sans couleurs |
| `--help, -h` | Aide |

---

## 🎯 Raccourcis Utiles (Alias)

Ajouter à votre `~/.bashrc` pour accès rapide :

```bash
# Stack Manager shortcuts
alias stacks='sudo /home/pi/pi5-setup/common-scripts/09-stack-manager.sh status'
alias stack='sudo /home/pi/pi5-setup/common-scripts/09-stack-manager.sh'
alias stack-tui='sudo /home/pi/pi5-setup/common-scripts/09-stack-manager.sh interactive'
alias stack-ram='sudo /home/pi/pi5-setup/common-scripts/09-stack-manager.sh ram'

# Quick stack controls
alias start-jellyfin='sudo /home/pi/pi5-setup/common-scripts/09-stack-manager.sh start jellyfin'
alias stop-jellyfin='sudo /home/pi/pi5-setup/common-scripts/09-stack-manager.sh stop jellyfin'
alias start-gitea='sudo /home/pi/pi5-setup/common-scripts/09-stack-manager.sh start gitea'
alias stop-gitea='sudo /home/pi/pi5-setup/common-scripts/09-stack-manager.sh stop gitea'
```

**Après recharger** :
```bash
source ~/.bashrc
```

**Utilisation** :
```bash
stacks                # Voir état de tous les stacks
stack-tui            # Mode interactif
stack-ram            # Voir RAM
start-jellyfin       # Démarrer Jellyfin
stop-jellyfin        # Arrêter Jellyfin
```

---

## 🏆 Résumé

Le **Stack Manager** vous permet de :

✅ **Gérer facilement la RAM** : Arrêter stacks temporairement non utilisés
✅ **Optimiser le boot** : Activer seulement les stacks essentiels
✅ **Interface intuitive** : Mode interactif avec menus (TUI)
✅ **Monitoring RAM** : Voir consommation par stack en temps réel
✅ **Flexibilité** : Adapter configuration selon vos besoins (dev/média/minimal)

**Commande la plus utile** :
```bash
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh interactive
```

---

<p align="center">
  <strong>🎛️ Stack Manager - Contrôlez Votre Pi5 Facilement 🎛️</strong>
</p>

<p align="center">
  <sub>Gestion RAM • Démarrage Auto • Interface Interactive • 100% Open Source</sub>
</p>
