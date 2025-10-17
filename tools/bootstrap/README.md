# PI5 Bootstrap - Add New Pi to Control Center

Script pour ajouter un nouveau Raspberry Pi au Control Center en une seule commande.

---

## 🚀 Usage Rapide

Sur le **nouveau Pi** (fraîchement flashé) :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/tools/bootstrap/bootstrap-pi.sh | sudo bash -s -- http://IP_CONTROL_CENTER:4000
```

**Remplacez** `IP_CONTROL_CENTER` par l'IP de votre machine qui exécute le Control Center.

---

## 📋 Ce que fait le script

| Étape | Action |
|-------|--------|
| **1. Token** | Génère un token unique (ex: `a3f9-b2c8-4d7e`) |
| **2. Info Pi** | Collecte hostname, IP, MAC, modèle |
| **3. Dépendances** | Installe `avahi-daemon` (mDNS) + `qrencode` |
| **4. SSH** | Configure clé publique Control Center |
| **5. Enregistrement** | Envoie les infos au Control Center |
| **6. Sauvegarde** | Crée `/etc/pi5-control-center.conf` |

---

## 🔑 Résultat

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Pi Bootstrap Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔑 Pairing Token: a3f9-b2c8-4d7e

📱 Next Steps:
   1. Open Control Center: http://192.168.1.100:4000
   2. Go to 'Add Pi' section
   3. Enter token: a3f9-b2c8-4d7e
   4. Start managing this Pi!

📊 Pi Information:
   Hostname: pi5-new
   IP: 192.168.1.119
   mDNS: pi5-new.local
   MAC: dc:a6:32:xx:xx:xx

📱 QR Code (scan with mobile):
[QR CODE ASCII ART]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🔐 Sécurité

### Token
- **Usage unique** : Le token est utilisé pour le pairing initial uniquement
- **Durée** : Valide pendant 24h après génération
- **Stockage** : Sauvegardé dans `/etc/pi5-control-center.conf` (root only)

### SSH
- Le script ajoute la clé publique du Control Center dans `~/.ssh/authorized_keys`
- Aucun mot de passe n'est stocké
- Authentification par clé SSH uniquement

### Réseau
- mDNS (avahi) permet la découverte automatique sur LAN
- Pour VPN : Utiliser l'IP directe au lieu du hostname

---

## 📡 Découverte Automatique

Une fois bootstrapé, le Pi est découvrable via :

### mDNS (LAN)
```bash
# Depuis Control Center (Mac/Linux)
ping pi5-new.local
ssh pi@pi5-new.local
```

### Scan réseau
Le Control Center peut scanner le réseau pour détecter les Pi bootstrapés.

---

## 🛠️ Configuration Manuelle

Si le bootstrap automatique échoue, pairing manuel :

### 1. Sur le Pi

Créer `/etc/pi5-control-center.conf` :
```bash
TOKEN=a3f9-b2c8-4d7e
CONTROL_CENTER_URL=http://192.168.1.100:4000
HOSTNAME=pi5-new
IP=192.168.1.119
MAC=dc:a6:32:xx:xx:xx
```

### 2. Ajouter clé SSH

```bash
# Depuis Control Center
ssh-copy-id -i ~/.ssh/id_rsa.pub pi@192.168.1.119
```

### 3. Dans Control Center

- Aller dans "Add Pi"
- Entrer le token : `a3f9-b2c8-4d7e`
- Cliquer "Pair"

---

## 🧪 Test Local

Pour tester le script localement (sans curl) :

```bash
# Sur le Pi
sudo bash /path/to/bootstrap-pi.sh http://192.168.1.100:4000
```

---

## 🔄 Workflow Complet

```
1. Flash nouveau Pi (Raspberry Pi OS)
   └─> Configurer SSH + user pi

2. Exécuter bootstrap script
   └─> Token généré: a3f9-b2c8-4d7e

3. Ouvrir Control Center web
   └─> Onglet "Add Pi"
   └─> Scan réseau OU entrer token

4. Pairing automatique
   └─> Validation token
   └─> Ajout dans Supabase
   └─> SSH connection établie

5. Installation guidée
   └─> Cocher services (Docker, Supabase, etc.)
   └─> Lancer installation
   └─> Voir logs temps réel

6. Pi opérationnel
   └─> Visible dans liste Pis
   └─> Monitoring actif
   └─> Scripts exécutables
```

---

## 📦 Fichiers Générés

| Fichier | Description |
|---------|-------------|
| `/etc/pi5-control-center.conf` | Config Control Center (root) |
| `~/pi5-bootstrap-token.txt` | Token de pairing (user) |
| `~/.ssh/authorized_keys` | Clé SSH Control Center |

---

## ❓ Troubleshooting

### Erreur : "Control Center unreachable"
```bash
# Vérifier connectivité
ping <IP_CONTROL_CENTER>

# Vérifier firewall
sudo ufw allow 4000/tcp
```

### Erreur : "SSH key not added"
```bash
# Ajouter manuellement
ssh-copy-id -i ~/.ssh/id_rsa.pub pi@<PI_IP>
```

### Token perdu ?
```bash
# Relire le fichier
cat ~/pi5-bootstrap-token.txt
# ou
sudo cat /etc/pi5-control-center.conf
```

---

## 🔗 Liens Utiles

- **Control Center** : http://localhost:4000
- **Documentation** : [../admin-panel/README.md](../admin-panel/README.md)
- **Quick Start** : [../../QUICK-START.md](../../QUICK-START.md)

---

**Version** : 1.0.0
**Auteur** : PI5-SETUP Project
**License** : MIT
