# 🚀 Installation VPN (Tailscale)

> **Installation automatisée de Tailscale pour un accès VPN zéro-config.**

---

## 📋 Prérequis

### Système
*   Raspberry Pi 5 avec Raspberry Pi OS 64-bit.
*   Connexion Internet active.

### Dépendances
*   Un compte Tailscale (gratuit), qui peut être créé pendant l'installation avec un compte Google, GitHub, ou Microsoft.

---

## 🚀 Installation

### Installation Rapide (Recommandé)

Une seule commande pour installer et configurer Tailscale sur votre Raspberry Pi :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vpn-wireguard/scripts/01-tailscale-setup.sh | sudo bash
```

**Durée** : ~2-3 minutes

Le script vous guidera pour vous connecter à votre compte Tailscale et authentifier le Pi.

---

## 📊 Ce Que Fait le Script

1.  ✅ **Installation de Tailscale** : Télécharge et installe la dernière version de Tailscale.
2.  ✅ **Démarrage du service** : Lance le service Tailscale et le configure pour démarrer automatiquement avec le système.
3.  ✅ **Authentification** : Génère une URL unique pour connecter votre Pi à votre compte Tailscale.
4.  ✅ **Activation de MagicDNS** : S'assure que vous pourrez accéder à votre Pi avec un nom simple (`raspberrypi`) au lieu de son adresse IP.
5.  ✅ **Options avancées (optionnel)** : Le script peut également configurer le Pi comme "Subnet Router" ou "Exit Node".

---

## 🔧 Configuration Post-Installation

### Authentifier le Pi

Après avoir lancé le script, une URL sera affichée dans le terminal. Copiez cette URL et ouvrez-la dans un navigateur sur n'importe quel appareil pour autoriser le Pi à rejoindre votre réseau.

### Installer les clients

Pour que le VPN soit utile, vous devez installer l'application Tailscale sur vos autres appareils (ordinateur, téléphone). Téléchargez-la depuis le [site officiel de Tailscale](https://tailscale.com/download) et connectez-vous avec le même compte.

---

## ✅ Validation Installation

### Tests Manuels

**Test 1** : Vérifier le statut de Tailscale sur le Pi.

```bash
tailscale status
```

**Résultat attendu** : Vous devriez voir votre Pi listé avec son adresse IP Tailscale (commençant par `100.x.x.x`) et son statut `online`.

**Test 2** : Pinger le Pi depuis un autre appareil.

Sur votre ordinateur où Tailscale est installé et activé, ouvrez un terminal et tapez :

```bash
ping raspberrypi
```

**Résultat attendu** : Vous devriez recevoir une réponse du Pi, confirmant que la connexion VPN et MagicDNS fonctionnent.

---

## 🛠️ Maintenance

### Mettre à jour Tailscale

Tailscale se met généralement à jour automatiquement. Pour forcer une mise à jour :

```bash
# Le script d'installation peut être relancé pour mettre à jour
curl -fsSL https://tailscale.com/install.sh | sh
```

### Voir les logs

Pour diagnostiquer des problèmes, vous pouvez consulter les logs du service Tailscale :

```bash
journalctl -u tailscaled -f
```

---

## 🐛 Troubleshooting

### Problème 1 : L'URL d'authentification a expiré
*   **Symptôme** : Le lien affiché par le script ne fonctionne plus.
*   **Solution** : Relancez la commande d'authentification sur le Pi pour générer une nouvelle URL :
    ```bash
    sudo tailscale up
    ```

### Problème 2 : Impossible de se connecter aux services via le nom `raspberrypi`
*   **Symptôme** : `ping raspberrypi` échoue.
*   **Solution** : Assurez-vous que MagicDNS est activé dans votre [console d'administration Tailscale](https://login.tailscale.com/admin/dns) et redémarrez le client Tailscale sur votre appareil.

---

## 🗑️ Désinstallation

Pour déconnecter le Pi de votre réseau et désinstaller Tailscale :

```bash
sudo tailscale down
sudo apt remove tailscale
```

---

## 📊 Consommation Ressources

*   **RAM utilisée** : ~10-20 Mo. Tailscale est extrêmement léger.
*   **CPU** : Moins de 1% en veille.
*   **Stockage utilisé** : Moins de 50 Mo.

---

## 🔗 Liens Utiles

*   [Guide Débutant](vpn-guide.md)
*   [Documentation Officielle de Tailscale](https://tailscale.com/kb/)
