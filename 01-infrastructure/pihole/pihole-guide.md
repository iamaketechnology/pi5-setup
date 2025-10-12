# 🎓 Guide Débutant : Pi-hole

> **Pour qui ?** : Toute personne souhaitant une expérience Internet plus propre, plus rapide et plus sûre pour tout son foyer.

---

## 📖 C'est Quoi Pi-hole ?

### Analogie Simple

Imaginez qu'Internet est une immense bibliothèque. Pour trouver un livre (un site web), vous utilisez un **annuaire (le DNS)** qui vous dit à quelle étagère (adresse IP) il se trouve.

Par défaut, cet annuaire est fourni par votre fournisseur d'accès à Internet, et il vous envoie vers tous les livres, y compris les **prospectus publicitaires** que personne ne veut lire.

**Pi-hole est votre propre annuaire personnel et intelligent.**

Quand votre ordinateur demande "Où se trouve `publicite-enervante.com` ?", Pi-hole consulte sa liste noire et répond : "Nulle part. Ce livre n'existe pas." La publicité n'est donc jamais chargée. Quand vous demandez `google.com`, Pi-hole vous donne la bonne adresse et le site s'affiche normalement.

En bref, Pi-hole est un **filtre DNS** qui bloque les publicités et les traqueurs pour **tous les appareils** de votre réseau domestique, au niveau de la source.

### En Termes Techniques

Pi-hole agit comme un serveur DNS pour votre réseau local. Lorsqu'un appareil fait une requête DNS pour résoudre un nom de domaine, la requête est envoyée à Pi-hole. Pi-hole compare le domaine demandé à une liste de domaines connus pour servir des publicités ou des contenus malveillants (les "blocklists"). Si le domaine est sur la liste, Pi-hole bloque la requête. Sinon, il la transmet à un vrai serveur DNS en amont (comme Google ou Cloudflare) et renvoie la réponse à l'appareil.

---

## 🎯 Cas d'Usage Concrets

### Scénario 1 : Une navigation web sans bannières
*   **Contexte** : Vous lisez un article sur un site d'actualités, mais la page est couverte de bannières publicitaires clignotantes et de vidéos en lecture automatique.
*   **Solution** : Avec Pi-hole, ces éléments ne sont tout simplement pas chargés. La page est plus propre, plus lisible et se charge plus rapidement.

### Scénario 2 : Moins de pubs dans les applications mobiles
*   **Contexte** : Vos enfants jouent à des jeux gratuits sur une tablette, mais sont constamment interrompus par des publicités vidéo.
*   **Solution** : Pi-hole bloque un grand nombre de domaines publicitaires utilisés par les applications mobiles, réduisant ainsi la fréquence des interruptions.

### Scénario 3 : Protéger sa vie privée
*   **Contexte** : Des dizaines de traqueurs invisibles suivent votre activité sur presque tous les sites que vous visitez pour établir votre profil publicitaire.
*   **Solution** : Pi-hole bloque les domaines de ces traqueurs, rendant beaucoup plus difficile pour les entreprises de suivre vos déplacements en ligne.

---

## 🚀 Premiers Pas

### Installation

Pour installer Pi-hole, suivez le guide d'installation détaillé :

➡️ **[Consulter le Guide d'Installation de Pi-hole](pihole-setup.md)**

### Configuration du Routeur (Étape la plus importante)

Une fois Pi-hole installé, vous devez dire à vos appareils de l'utiliser. La meilleure façon de le faire est de configurer votre routeur (votre box Internet).

1.  Trouvez l'adresse IP de votre Raspberry Pi (ex: `192.168.1.100`).
2.  Connectez-vous à l'interface d'administration de votre routeur.
3.  Trouvez les paramètres du serveur **DHCP** ou **DNS**.
4.  Dans le champ "Serveur DNS primaire" ou "DNS 1", entrez l'adresse IP de votre Pi.
5.  Sauvegardez et redémarrez votre routeur.

Maintenant, chaque appareil qui se connecte à votre Wi-Fi utilisera automatiquement Pi-hole comme filtre.

### Le Tableau de Bord

Accédez à l'interface web de Pi-hole à l'adresse `http://<IP_DU_PI>/admin` (remplacez `<IP_DU_PI>` par l'adresse IP de votre Pi). Vous y verrez des statistiques en temps réel sur les requêtes bloquées.

---

##  whitelist vs. blocklist

*   **Blocklists (Listes de blocage)** : Ce sont des listes de domaines malveillants ou publicitaires maintenues par la communauté. Pi-hole en utilise plusieurs par défaut. Vous pouvez en ajouter d'autres pour un blocage encore plus agressif.
*   **Whitelist (Liste blanche)** : Si Pi-hole bloque un site légitime dont vous avez besoin, vous pouvez l'ajouter à la whitelist pour l'autoriser.

**Comment whitelister un domaine ?**

1.  Dans le dashboard Pi-hole, allez dans `Query Log`.
2.  Trouvez la requête qui a été bloquée (en rouge).
3.  Cliquez sur le bouton vert `Whitelist` à côté.

---

## 🐛 Dépannage Débutants

### Problème 1 : Un site ou une application ne fonctionne plus
*   **Symptôme** : La page d'un site est cassée, ou une application refuse de se charger.
*   **Cause** : Pi-hole bloque un domaine nécessaire au fonctionnement du service.
*   **Solution** : Utilisez l'outil `Query Log` pour voir quelles requêtes ont été récemment bloquées. Identifiez le domaine légitime et ajoutez-le à la whitelist.

### Problème 2 : Je vois toujours des publicités sur YouTube
*   **Symptôme** : Les publicités vidéo avant ou pendant les vidéos YouTube s'affichent toujours.
*   **Cause** : YouTube sert ses publicités depuis les mêmes domaines que ses vidéos. Bloquer l'un bloquerait l'autre.
*   **Solution** : Pi-hole est inefficace contre ce type de publicité. La meilleure solution reste d'utiliser un bloqueur de publicités au niveau du navigateur, comme `uBlock Origin`.

---

## 📚 Ressources d'Apprentissage

*   [Documentation Officielle de Pi-hole](https://docs.pi-hole.net/)
*   [Le subreddit Pi-hole](https://www.reddit.com/r/pihole/) : Une communauté très active pour le support et les astuces.
*   [Listes de blocage recommandées](https://firebog.net/) : Des listes de qualité pour améliorer l'efficacité de votre Pi-hole.
