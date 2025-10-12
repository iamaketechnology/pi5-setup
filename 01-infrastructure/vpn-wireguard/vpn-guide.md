# 🎓 Guide Débutant : VPN (WireGuard & Tailscale)

> **Pour qui ?** : Toute personne souhaitant accéder à ses services auto-hébergés de manière sécurisée depuis l'extérieur.

---

## 📖 C'est Quoi un VPN ?

### Analogie Simple

Imaginez que votre Raspberry Pi et tous vos services sont votre **maison**. Pour y accéder depuis l'extérieur (un café, votre bureau), vous devez passer par la **rue publique (Internet)**.

*   **Sans VPN**, c'est comme si vous laissiez la porte d'entrée ouverte. N'importe qui peut essayer de regarder à l'intérieur, et c'est risqué.
*   **Avec un VPN**, vous construisez un **tunnel privé et secret** qui part de votre téléphone ou de votre ordinateur portable et qui débouche directement dans le salon de votre maison. Personne de l'extérieur ne peut voir ce tunnel, et tout ce qui y transite est chiffré. Vous êtes en sécurité, comme si vous n'aviez jamais quitté votre domicile.

Un VPN (Virtual Private Network) crée ce tunnel sécurisé par-dessus Internet, vous permettant d'accéder à votre réseau local de n'importe où dans le monde.

### En Termes Techniques

Un VPN établit une connexion chiffrée (un "tunnel") entre votre appareil distant (le client) and votre réseau domestique (le serveur). Tout le trafic passant par ce tunnel est protégé des regards indiscrets. Pour vos applications, c'est comme si votre appareil distant était physiquement connecté à votre réseau local.

---

## ⚖️ Tailscale vs. WireGuard Self-Hosted

Il existe deux approches principales pour mettre en place un VPN sur votre Pi :

1.  **Tailscale (Recommandé pour les débutants)** : Un service qui utilise le protocole WireGuard mais qui s'occupe de toute la configuration complexe pour vous.
2.  **WireGuard Self-Hosted** : Vous installez et configurez manuellement un serveur WireGuard sur votre Pi.

| Critère | ✅ Tailscale | 🛠️ WireGuard Self-Hosted |
| :--- | :--- | :--- |
| **Difficulté** | ⭐ Facile | ⭐⭐⭐⭐ Très Complexe |
| **Temps d'installation** | ~5 minutes | ~1-2 heures |
| **Configuration** | Zéro-config, automatique | Manuelle (clés, pairs, IP) |
| **Ouvrir des ports** | Non | Oui (un port UDP) |
| **Compatibilité CGNAT** | Oui, automatique | Non, très difficile |
| **Gestion des appareils**| Interface web simple | Fichiers de configuration manuels |
| **Dépendance externe** | Oui (serveur de coordination) | Non (100% auto-hébergé) |
| **Coût** | Gratuit (jusqu'à 100 appareils) | Gratuit |

**Conclusion :**

*   Choisissez **Tailscale** si vous voulez une solution qui "juste marche", qui est incroyablement simple à installer et à gérer.
*   Choisissez **WireGuard Self-Hosted** si vous êtes un utilisateur avancé, que vous ne voulez aucune dépendance externe et que la configuration manuelle ne vous fait pas peur.

Ce guide se concentrera principalement sur **Tailscale**, la solution recommandée pour 99% des utilisateurs.

---

## 🚀 Premiers Pas avec Tailscale

### Installation

Pour installer Tailscale, suivez le guide d'installation détaillé :

➡️ **[Consulter le Guide d'Installation du VPN](vpn-setup.md)**

### Configuration des Clients (Android, iOS, Desktop)

Une fois Tailscale installé sur votre Pi, vous devez installer le client Tailscale sur tous les appareils que vous souhaitez connecter à votre réseau privé (votre ordinateur portable, votre téléphone, etc.).

1.  **Téléchargez l'application** depuis le site de Tailscale ou les magasins d'applications.
2.  **Connectez-vous** avec le **même compte** que celui utilisé pour votre Raspberry Pi.
3.  C'est tout ! Votre appareil fait maintenant partie de votre réseau privé.

### Tests de Connexion

Une fois le client installé et activé sur votre ordinateur ou votre téléphone :

1.  **Test de Ping** : Ouvrez un terminal et tapez `ping raspberrypi`. Vous devriez voir une réponse de l'adresse IP Tailscale de votre Pi (ex: `100.x.x.x`).
2.  **Test d'accès à un service** : Ouvrez votre navigateur et allez sur `http://raspberrypi:3002` (pour Grafana, si installé). Le service devrait s'afficher comme si vous étiez chez vous.

---

## 🐛 Dépannage Débutants

### Problème 1 : `ping raspberrypi` ne fonctionne pas
*   **Symptôme** : Le nom `raspberrypi` n'est pas trouvé, mais `ping 100.x.x.x` (l'IP Tailscale du Pi) fonctionne.
*   **Cause** : MagicDNS n'est pas activé ou mal configuré.
*   **Solution** : 
    1.  Allez sur votre [console d'administration Tailscale](https://login.tailscale.com/admin/dns).
    2.  Assurez-vous que "MagicDNS" est bien activé.
    3.  Redémarrez le client Tailscale sur votre appareil.

### Problème 2 : La connexion est lente
*   **Symptôme** : L'accès à vos services est lent, les vidéos saccadent.
*   **Cause** : Votre connexion passe probablement par un "relay" DERP de Tailscale au lieu d'être directe.
*   **Solution** : C'est souvent inévitable (surtout derrière un CGNAT), mais la performance reste généralement bonne. Vous pouvez vérifier le type de connexion en tapant `tailscale status` sur votre Pi. Si vous voyez "relay", c'est la cause. Il n'y a pas de solution simple, mais c'est le compromis pour ne pas avoir à ouvrir de ports.

### Problème 3 : Un service est inaccessible même avec le VPN
*   **Symptôme** : Vous pouvez pinger le Pi, mais `http://raspberrypi:3002` ne fonctionne pas.
*   **Cause** : Le service lui-même n'est pas démarré sur le Pi, ou un pare-feu sur le Pi bloque la connexion.
*   **Solution** : Connectez-vous en SSH à votre Pi (`ssh pi@raspberrypi`) et vérifiez que le conteneur Docker du service est bien en cours d'exécution (`docker ps`).

---

## 📚 Ressources d'Apprentissage

*   [Documentation Officielle de Tailscale](https://tailscale.com/kb/)
*   [How Tailscale Works](https://tailscale.com/blog/how-tailscale-works/) : Une explication détaillée de la magie derrière Tailscale.
*   [Communauté Tailscale sur Reddit](https://www.reddit.com/r/Tailscale/)
