# 🚀 Quick Start - Pi Emulator

Guide ultra-simple pour configurer SSH Mac → Linux et lancer l'émulateur.

---

## 🎯 Workflow Complet (2 étapes)

### Étape 1️⃣ : Sur ton PC Linux Mint

**Option A - Via clé USB/partage** (recommandé)

Copie le fichier depuis ton Mac vers une clé USB :
```bash
# Sur ton Mac
cp tools/pi-emulator/scripts/linux-setup-ssh.sh /Volumes/USB/
```

Sur ton Linux :
```bash
# Brancher clé USB, puis
sudo bash /media/ton-user/USB/linux-setup-ssh.sh
```

**Option B - Copier-coller manuel**

Sur ton Linux, crée un fichier :
```bash
nano setup-ssh.sh
```

Copie tout le contenu de `linux-setup-ssh.sh`, colle-le, puis :
```bash
sudo bash setup-ssh.sh
```

**Option C - Si Git déjà cloné sur Linux**

```bash
cd /path/to/pi5-setup/tools/pi-emulator
sudo bash scripts/linux-setup-ssh.sh
```

**✅ Le script va :**
- ✅ Installer SSH server
- ✅ Configurer SSH de manière sécurisée
- ✅ Démarrer le service
- ✅ Configurer le firewall
- ✅ T'afficher l'IP et le username

**Note l'IP affichée !** (ex: 192.168.1.100)

---

### Étape 2️⃣ : Sur ton Mac

```bash
cd "/Volumes/WDNVME500/GITHUB CODEX/pi5-setup/tools/pi-emulator"
bash scripts/00-setup-ssh-access.sh
```

**Le script va :**
1. Te demander de scanner le réseau (choix 1) ou entrer l'IP (choix 2)
2. Créer une clé SSH sur ton Mac
3. Te donner des commandes à copier-coller **sur le Linux**
4. Tester la connexion

**Suis les instructions à l'écran !**

---

## 🎉 Une fois SSH configuré

### Lancer l'émulateur Pi sur Linux (depuis ton Mac)

```bash
cd "/Volumes/WDNVME500/GITHUB CODEX/pi5-setup/tools/pi-emulator"

# Via alias (si configuré)
ssh linux-mint 'bash -s' < scripts/01-pi-emulator-deploy-linux.sh

# OU via IP
ssh user@192.168.1.100 'bash -s' < scripts/01-pi-emulator-deploy-linux.sh
```

### Tester la connexion à l'émulateur

```bash
# Depuis ton Mac
ssh pi@localhost -p 2222
# Password: raspberry
```

---

## 📊 Résumé Visual

```
┌─────────────┐                    ┌──────────────┐
│   Mac       │                    │  Linux Mint  │
│             │                    │              │
│  1️⃣ Copie    │ ─── USB/Git ────→  │  2️⃣ Lance     │
│  script     │                    │  setup-ssh   │
│             │                    │              │
│  3️⃣ Lance    │ ←── SSH ready ───  │              │
│  00-setup   │                    │              │
│             │                    │              │
│  4️⃣ Clé SSH  │ ─── commandes ──→  │  5️⃣ Copie     │
│  créée      │                    │  clé Mac     │
│             │                    │              │
│  6️⃣ Déploie  │ ═══ SSH OK ═════→  │  7️⃣ Lance     │
│  émulateur  │                    │  Docker Pi   │
└─────────────┘                    └──────────────┘

                8️⃣ Connecte à émulateur
┌─────────────┐                    ┌──────────────┐
│   Mac       │ ═══════════════→   │  Émulateur   │
│             │  ssh pi@localhost  │  (port 2222) │
└─────────────┘       :2222        └──────────────┘
```

---

## 🔥 Ultra Quick (si SSH déjà installé sur Linux)

```bash
# Sur Mac
cd "/Volumes/WDNVME500/GITHUB CODEX/pi5-setup/tools/pi-emulator"
bash scripts/00-setup-ssh-access.sh

# Puis déployer émulateur
ssh linux-mint 'bash -s' < scripts/01-pi-emulator-deploy-linux.sh

# Tester
ssh pi@localhost -p 2222
```

---

## 🐛 Problèmes Courants

### "Connection refused" sur Linux

```bash
# Sur Linux
sudo systemctl status ssh
sudo systemctl start ssh
```

### Script Mac ne trouve pas le Linux

```bash
# Sur Linux, vérifier IP
ip addr show | grep "inet " | grep -v 127.0.0.1

# Sur Mac, scanner manuellement
nmap -p 22 --open 192.168.1.0/24
```

### Permission denied

```bash
# Sur Linux
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

---

## 📁 Fichiers Nécessaires

| Fichier | Où | Usage |
|---------|-----|-------|
| `linux-setup-ssh.sh` | Linux | Installer SSH server |
| `00-setup-ssh-access.sh` | Mac | Configurer connexion SSH |
| `01-pi-emulator-deploy-linux.sh` | Linux (via Mac SSH) | Lancer émulateur |

---

## 💡 Astuces

### Copier script sur Linux sans clé USB

**Via serveur web temporaire sur Mac** :
```bash
# Sur Mac
cd tools/pi-emulator/scripts
python3 -m http.server 8000

# Sur Linux (remplacer IP_MAC)
curl -O http://IP_MAC:8000/linux-setup-ssh.sh
sudo bash linux-setup-ssh.sh
```

### Alias SSH pratique

Une fois configuré, ajoute dans `~/.ssh/config` sur Mac :
```
Host linux-mint
    HostName 192.168.1.100
    User ton-user
```

Puis simplement :
```bash
ssh linux-mint
```

---

**Version** : 1.0.0
**Last Updated** : 2025-01-20
