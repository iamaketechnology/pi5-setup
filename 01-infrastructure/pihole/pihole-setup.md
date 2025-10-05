# ⚡ Installation Rapide - Pi-hole

> **Installation directe via SSH**

---

## 🚀 Installation en 1 Commande

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/pihole/scripts/01-pihole-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ Pi-hole (bloqueur de publicités DNS)
- ✅ Interface web d'administration

**Durée :** ~5 minutes

---

## ✅ Vérification Installation

### Vérifier le service
```bash
cd ~/stacks/pihole
docker compose ps
# Le service doit être "Up (healthy)"
```

### Accéder à l'interface web
```
http://<IP-DU-PI>:8888/admin
```

**Récupérer votre IP :**
```bash
hostname -I | awk '{print $1}'
```

Le mot de passe est affiché à la fin de l'installation.

---

## ⚙️ Configuration

Pour que Pi-hole fonctionne, vous devez configurer vos appareils pour utiliser l'IP de votre Raspberry Pi comme serveur DNS.

**Option 1 : Configurer le routeur (recommandé)**
- Connectez-vous à l'interface de votre box/routeur.
- Trouvez les paramètres DNS.
- Remplacez le DNS actuel par l'IP de votre Pi.
- Tous les appareils sur votre réseau seront protégés.

**Option 2 : Configurer chaque appareil manuellement**
- Allez dans les paramètres réseau de votre PC/Mac/Smartphone.
- Changez le serveur DNS pour l'IP de votre Pi.

---

## 📚 Documentation Complète

- [Guide Débutant](pihole-guide.md) - Pour comprendre ce qu'est Pi-hole et comment l'utiliser.
- [README.md](README.md) - Vue d'ensemble du stack.
