# 🚀 Installation Homepage Stack - Guide Rapide

> **Dashboard central en 5 minutes**

---

## 📋 Prérequis

Avant d'installer Homepage, vous devez avoir :

- [x] **Raspberry Pi 5** avec Pi OS 64-bit
- [x] **Docker + Docker Compose** installés ([Phase 1](../pi5-supabase-stack/))
- [x] **Traefik** installé et fonctionnel ([Phase 2](../pi5-traefik-stack/))
- [x] Un **scénario Traefik** choisi (DuckDNS, Cloudflare, ou VPN)

**Vérifier que Traefik fonctionne** :
```bash
docker ps | grep traefik
```
→ Doit afficher un container `traefik` running ✅

---

## ⚡ Installation Express

### Commande Unique

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homepage-stack/scripts/01-homepage-deploy.sh | sudo bash
```

**Durée** : ~3-5 min

---

## 🎬 Processus d'Installation

### Étape 1 : Lancement du Script

Le script va automatiquement :

1. **Détecter votre scénario Traefik** :
   - Lit `/home/pi/stacks/traefik/.env`
   - Identifie DuckDNS, Cloudflare, ou VPN

2. **Détecter vos services installés** :
   - Supabase (vérifie `/home/pi/stacks/supabase`)
   - Portainer (vérifie container running)
   - Grafana (vérifie `/home/pi/stacks/monitoring`)
   - Autres services Docker

3. **Demander configuration** :
   - **DuckDNS** : Pas de question (utilise automatiquement `/`)
   - **Cloudflare** : "Voulez-vous utiliser le domaine racine ou un sous-domaine ?"
   - **VPN** : "Quel domaine local utiliser ?"

---

### Étape 2 : Questions Interactives

#### Scénario DuckDNS
```
✓ Detected Traefik scenario: DuckDNS (monpi.duckdns.org)
✓ Homepage will be deployed on root path: /
  Access URL will be: https://monpi.duckdns.org
```
→ Aucune question, continue automatiquement ✅

---

#### Scénario Cloudflare
```
✓ Detected Traefik scenario: Cloudflare (monpi.fr)

Choose Homepage URL:
1) Root domain (https://monpi.fr)
2) Subdomain (https://home.monpi.fr)
Choice [1-2]:
```

**Recommandation** :
- **Option 1** si vous n'avez pas encore de site sur le domaine racine
- **Option 2** si vous voulez garder le racine pour autre chose

→ Tapez `1` ou `2` et appuyez sur Entrée

---

#### Scénario VPN
```
✓ Detected Traefik scenario: VPN

Enter local domain for Homepage (default: home.pi.local):
```

**Options** :
- Appuyez sur **Entrée** pour utiliser `home.pi.local`
- Ou tapez votre propre domaine : `dashboard.pi.local`, `pi.local`, etc.

---

### Étape 3 : Installation Automatique

Le script va ensuite :

✅ Créer `/home/pi/stacks/homepage/`
✅ Générer `docker-compose.yml`
✅ Générer configurations YAML personnalisées :
   - `services.yaml` (avec vos services détectés)
   - `widgets.yaml` (stats système)
   - `settings.yaml` (thème dark)
   - `bookmarks.yaml` (liens utiles)
✅ Lancer Homepage dans Docker
✅ Configurer labels Traefik
✅ Vérifier santé du container
✅ Tester connectivité

**Durée** : ~2-3 min (téléchargement image + démarrage)

---

### Étape 4 : Résumé Final

À la fin, vous verrez :

```
═════════════════════════════════════════════════
📋 HOMEPAGE DEPLOYMENT SUMMARY
═════════════════════════════════════════════════

🌐 Access URL:
   Homepage: https://monpi.duckdns.org

📂 Config Directory:
   /home/pi/stacks/homepage/config/

📝 Edit Configuration:
   cd /home/pi/stacks/homepage/config
   nano services.yaml

🔄 Restart Homepage:
   docker restart homepage

📊 Services Detected:
   ✓ Supabase Studio
   ✓ Supabase API
   ✓ Traefik Dashboard
   ✓ Portainer

🎨 Customize:
   Edit config/*.yaml files
   Changes reload automatically (max 30s)

✅ Installation Complete!
```

---

## 🌐 Accéder à Homepage

### Selon Votre Scénario

**Scénario DuckDNS** :
```
https://monpi.duckdns.org
```

**Scénario Cloudflare** (option 1 - root domain) :
```
https://monpi.fr
```

**Scénario Cloudflare** (option 2 - subdomain) :
```
https://home.monpi.fr
```

**Scénario VPN** :
```
https://home.pi.local
```
(ou le domaine que vous avez choisi)

---

## ✅ Vérifier l'Installation

### 1. Container Running

```bash
docker ps | grep homepage
```

**Résultat attendu** :
```
CONTAINER ID   IMAGE                                CREATED          STATUS                    PORTS                    NAMES
abc123def456   ghcr.io/gethomepage/homepage:latest  2 minutes ago    Up 2 minutes (healthy)    0.0.0.0:3000->3000/tcp   homepage
```

✅ `STATUS` doit afficher `Up ... (healthy)`

---

### 2. Logs Sans Erreur

```bash
docker logs homepage --tail 50
```

**Résultat attendu** :
```
Homepage is running on port 3000
Configuration loaded successfully
```

❌ **Si erreur** : Voir [Troubleshooting](#troubleshooting)

---

### 3. Traefik Détecte Homepage

```bash
docker logs traefik | grep homepage
```

**Résultat attendu** :
```
"Creating router homepage@docker"
```

---

### 4. Accès Web Fonctionne

Ouvrir dans navigateur : `https://VOTRE_URL`

**Résultat attendu** :
- Page Homepage s'affiche ✅
- Services détectés affichés ✅
- Widgets système affichés ✅

---

## ⚙️ Personnalisation Post-Installation

### Modifier la Configuration

```bash
cd /home/pi/stacks/homepage/config
nano services.yaml
```

**Ctrl+O** pour sauvegarder, **Ctrl+X** pour quitter

**Changes take effect** : Automatiquement dans 30 secondes (pas besoin redémarrer)

---

### Ajouter un Service Manuellement

**Éditer** `services.yaml` :

```yaml
- Mes Apps:
    - Mon App:
        href: https://monapp.monpi.fr
        description: Description de mon app
        icon: rocket
```

Sauvegarder → Attendre 30s → Rafraîchir page

---

### Changer le Thème

**Éditer** `settings.yaml` :

```yaml
color: slate    # ou: blue, green, red, purple, etc.
theme: dark     # ou: light
```

Sauvegarder → Attendre 30s → Rafraîchir page

---

## 🆘 Troubleshooting

### "Cannot access Homepage"

**Vérifier** :
```bash
# Container running ?
docker ps | grep homepage

# Logs ?
docker logs homepage

# Traefik running ?
docker ps | grep traefik
```

**Si container stopped** :
```bash
cd /home/pi/stacks/homepage
docker compose up -d
```

---

### "Services not showing"

**Cause** : Configuration YAML incorrecte

**Solution** :
```bash
# Valider syntax YAML
sudo apt install yamllint
yamllint /home/pi/stacks/homepage/config/*.yaml
```

**Si erreur YAML** : Corriger le fichier et sauvegarder

---

### "Widgets not updating"

**Cause** : URL ou API key incorrecte dans widget config

**Solution** :
```bash
# Voir logs pour erreurs API
docker logs homepage | grep -i error
```

Corriger URL/API key dans `services.yaml` ou `widgets.yaml`

---

### "503 Service Unavailable"

**Cause** : Homepage pas encore démarré ou unhealthy

**Attendre** 30-60 secondes pour que le container devienne healthy

**Vérifier santé** :
```bash
docker inspect homepage | grep -A 5 Health
```

**Si reste unhealthy** :
```bash
docker restart homepage
```

---

## 🔄 Commandes Utiles

### Redémarrer Homepage
```bash
docker restart homepage
```

### Voir Logs en Direct
```bash
docker logs homepage -f
```

### Arrêter Homepage
```bash
cd /home/pi/stacks/homepage
docker compose down
```

### Démarrer Homepage
```bash
cd /home/pi/stacks/homepage
docker compose up -d
```

### Backup Configuration
```bash
sudo tar -czf homepage-config-backup-$(date +%Y%m%d).tar.gz /home/pi/stacks/homepage/config/
```

### Restaurer Configuration
```bash
sudo tar -xzf homepage-config-backup-YYYYMMDD.tar.gz -C /
docker restart homepage
```

---

## 📚 Ressources

### Documentation
- [Guide Débutant](homepage-guide.md) - Tout savoir sur Homepage
- [README](README.md) - Vue d'ensemble complète
- [Homepage Docs](https://gethomepage.dev/) - Documentation officielle

### Exemples de Configuration
- [Services Examples](https://gethomepage.dev/latest/configs/services/)
- [Widgets Examples](https://gethomepage.dev/latest/widgets/)
- [Themes](https://gethomepage.dev/latest/configs/settings/)

---

## 🎯 Prochaines Étapes

Après avoir installé Homepage :

1. **Personnaliser** :
   - Ajouter vos propres services
   - Changer le thème
   - Configurer widgets avancés

2. **Sécuriser** (optionnel) :
   - Activer Authelia (SSO + 2FA) - Phase 9

3. **Installer Phase 3** (optionnel) :
   - [Monitoring Grafana](../ROADMAP.md#phase-3) - Dashboards avancés

---

**Installation terminée !** Profitez de votre nouveau dashboard ! 🎉

**Besoin d'aide ?** → [GUIDE DÉBUTANT](homepage-guide.md) | [Troubleshooting](README.md#troubleshooting)
