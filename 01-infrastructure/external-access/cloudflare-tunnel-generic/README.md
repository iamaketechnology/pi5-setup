# ☁️ Cloudflare Tunnel - Configuration Générique (Multi-Apps)

> **Installation et gestion d'un tunnel Cloudflare unique pour plusieurs applications**

## 📋 Vue d'ensemble

Ce dossier contient les scripts pour installer et gérer un **tunnel Cloudflare générique** qui peut router plusieurs applications via un seul container Docker.

### Architecture

```
Internet
   ↓
Cloudflare CDN
   ↓
Cloudflare Tunnel (1 container, ~50 MB RAM)
   ├──→ certidoc.votredomaine.com → certidoc-frontend:80
   ├──→ app2.votredomaine.com → autre-app:3000
   ├──→ api.votredomaine.com → supabase-kong:8000
   └──→ studio.votredomaine.com → supabase-studio:3000
```

### Avantages

- ✅ **Un seul container** = économie RAM (50 MB vs 50 MB × N apps)
- ✅ **Gestion centralisée** via base de données JSON
- ✅ **Scripts automatisés** pour ajouter/supprimer/lister apps
- ✅ **Idempotent** : réexécution safe
- ✅ **Évolutif** : ajouter une app en < 1 minute

---

## 🚀 Installation

### Méthode 1 : Via le Wizard (Recommandé)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/external-access/scripts/00-cloudflare-tunnel-wizard.sh | sudo bash
```

Le wizard vous guidera pour choisir entre tunnel générique ou par app.

### Méthode 2 : Installation directe

```bash
# 1. Télécharger le script
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/external-access/cloudflare-tunnel-generic/scripts/01-setup-generic-tunnel.sh -o /tmp/setup-tunnel.sh

# 2. Rendre exécutable
chmod +x /tmp/setup-tunnel.sh

# 3. Lancer l'installation
sudo bash /tmp/setup-tunnel.sh
```

---

## 📱 Gestion des Applications

### Ajouter une application

```bash
sudo bash /path/to/02-add-app-to-tunnel.sh \
  --name certidoc \
  --hostname certidoc.example.com \
  --service certidoc-frontend:80
```

**Options** :
- `--name` : Nom de l'app (identifiant unique)
- `--hostname` : Hostname complet (sous-domaine.domaine.com)
- `--service` : Service Docker (container:port)
- `--no-tls-verify` : Désactiver vérification TLS (optionnel)

**Exemple CertiDoc** :
```bash
sudo bash 02-add-app-to-tunnel.sh \
  --name certidoc \
  --hostname certidoc.votredomaine.com \
  --service certidoc-frontend:80
```

**Exemple Supabase Studio** :
```bash
sudo bash 02-add-app-to-tunnel.sh \
  --name studio \
  --hostname studio.votredomaine.com \
  --service supabase-studio:3000
```

### Lister toutes les applications

```bash
sudo bash 04-list-tunnel-apps.sh
```

**Sortie exemple** :
```
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║     ☁️  Apps Cloudflare Tunnel                          ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

📊 Informations Tunnel :
   • Nom : pi5-generic-tunnel
   • Domaine : example.com
   • Nombre d'apps : 3

📱 Apps configurées :

NOM             HOSTNAME                            SERVICE                        NO_TLS
───────────────  ──────────────────────────────────  ──────────────────────────────  ──────────
certidoc        certidoc.example.com                certidoc-frontend:80            false
studio          studio.example.com                  supabase-studio:3000            false
api             api.example.com                     supabase-kong:8000              false

✅ 3 app(s) active(s)
```

### Supprimer une application

```bash
sudo bash 03-remove-app-from-tunnel.sh --name certidoc
```

---

## 🗂️ Structure des Fichiers

```
cloudflare-tunnel-generic/
├── README.md                          # Ce fichier
├── docker-compose.yml                 # Généré par le script
├── config/
│   ├── apps.json                      # Base de données apps
│   ├── config.yml                     # Config tunnel (auto-générée)
│   ├── credentials.json               # Credentials Cloudflare
│   └── tunnel-token.txt               # Token (si mode manuel)
├── logs/                              # Logs (optionnel)
└── scripts/
    ├── 01-setup-generic-tunnel.sh     # Installation initiale
    ├── 02-add-app-to-tunnel.sh        # Ajouter une app
    ├── 03-remove-app-from-tunnel.sh   # Supprimer une app
    └── 04-list-tunnel-apps.sh         # Lister les apps
```

---

## 🔧 Configuration

### Format `apps.json`

```json
{
  "tunnel_name": "pi5-generic-tunnel",
  "domain": "example.com",
  "apps": [
    {
      "name": "certidoc",
      "hostname": "certidoc.example.com",
      "service": "certidoc-frontend:80",
      "no_tls_verify": false,
      "added_at": "2025-01-13T10:30:00Z"
    },
    {
      "name": "studio",
      "hostname": "studio.example.com",
      "service": "supabase-studio:3000",
      "no_tls_verify": false,
      "added_at": "2025-01-13T11:00:00Z"
    }
  ]
}
```

### Format `config.yml` (généré automatiquement)

```yaml
# Cloudflare Tunnel - Configuration Générique

tunnel: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: certidoc.example.com
    service: http://certidoc-frontend:80
    originRequest:
      noTLSVerify: false

  - hostname: studio.example.com
    service: http://supabase-studio:3000
    originRequest:
      noTLSVerify: false

  # Catch-all rule (obligatoire)
  - service: http_status:404
```

---

## 🌐 Configuration DNS

Après avoir ajouté une app, configurez le DNS dans Cloudflare :

1. **Accédez à votre dashboard Cloudflare**
2. **Sélectionnez votre domaine**
3. **Allez dans DNS > Records**
4. **Ajoutez un record A** :

```
Type : A
Name : certidoc  (ou nom de votre app)
Content : VOTRE_IP_PUBLIQUE  (ex: 203.0.113.42)
Proxy : DNS only (gris/nuage désactivé)
TTL : Auto
```

⚠️ **Important** : Utilisez **"DNS only" (gris)** et non "Proxied" (orange) pour que Let's Encrypt puisse valider vos certificats.

---

## 🐳 Gestion du Container

### Démarrer le tunnel

```bash
cd /path/to/cloudflare-tunnel-generic
docker compose up -d
```

### Arrêter le tunnel

```bash
docker compose down
```

### Redémarrer le tunnel

```bash
docker compose restart
```

### Voir les logs

```bash
# Logs en temps réel
docker logs -f cloudflared-tunnel

# Dernières 50 lignes
docker logs cloudflared-tunnel --tail 50
```

### Status du container

```bash
docker ps --filter "name=cloudflared-tunnel"
```

---

## 🐛 Troubleshooting

### Le tunnel ne démarre pas

1. **Vérifier les logs** :
   ```bash
   docker logs cloudflared-tunnel --tail 50
   ```

2. **Vérifier les credentials** :
   ```bash
   ls -l config/credentials.json
   # Doit afficher : -rw------- (permissions 600)
   ```

3. **Tester l'authentification** :
   ```bash
   cloudflared tunnel info pi5-generic-tunnel
   ```

### Erreur 502 Bad Gateway

1. **Vérifier que le service Docker existe et tourne** :
   ```bash
   docker ps | grep certidoc-frontend
   ```

2. **Vérifier la config du service dans apps.json** :
   ```bash
   jq '.apps[] | select(.name == "certidoc")' config/apps.json
   ```

3. **Vérifier les réseaux Docker** :
   ```bash
   docker network ls | grep -E "traefik|supabase"
   ```

4. **Redémarrer le tunnel** :
   ```bash
   docker compose restart
   ```

### DNS ne résout pas

1. **Attendre 5-10 minutes** (propagation DNS)

2. **Vérifier le DNS avec dig** :
   ```bash
   dig certidoc.votredomaine.com
   ```

3. **Vérifier dans Cloudflare Dashboard** → DNS → Records

4. **Ajouter manuellement le record si nécessaire**

### App ne répond pas

1. **Tester en local d'abord** :
   ```bash
   curl -I http://localhost:9000  # Si CertiDoc sur port 9000
   ```

2. **Vérifier que le container est dans le bon réseau** :
   ```bash
   docker inspect certidoc-frontend | grep -A 10 Networks
   ```

3. **Vérifier les logs du tunnel** :
   ```bash
   docker logs cloudflared-tunnel | grep certidoc
   ```

---

## 📊 Consommation Ressources

| Nombre d'apps | RAM Tunnel | RAM Totale | CPU |
|---------------|------------|------------|-----|
| 1 app         | 50 MB      | 50 MB      | <1% |
| 5 apps        | 50 MB      | 50 MB      | 2%  |
| 10 apps       | 50 MB      | 50 MB      | 3%  |

**Conclusion** : La consommation RAM est **fixe** peu importe le nombre d'apps ! 🎉

---

## 📚 Ressources

- **Documentation Cloudflare Tunnel** : https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
- **Dashboard Cloudflare** : https://one.dash.cloudflare.com/
- **GitHub PI5-SETUP** : https://github.com/iamaketechnology/pi5-setup

---

## 🆘 Support

- **Issues GitHub** : https://github.com/iamaketechnology/pi5-setup/issues
- **Email** : iamaketechnology@gmail.com

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-01-13
**Auteur** : PI5-SETUP Project
