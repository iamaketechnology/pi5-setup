# 📚 Guide Débutant - Uptime Kuma

> **Pour qui ?** Tous ceux qui auto-hébergent des services et qui veulent dormir sur leurs deux oreilles.
> **Durée de lecture** : 10 minutes
> **Niveau** : Débutant

---

## 🤔 C'est quoi Uptime Kuma ?

### En une phrase
**Uptime Kuma = Un gardien qui surveille vos sites web et services 24h/24 et qui vous crie dessus dès que quelque chose tombe en panne.**

### Analogie simple
Imaginez que vous avez plusieurs boutiques en ligne. Vous ne pouvez pas rester éveillé toute la nuit pour vérifier si elles sont toujours accessibles par vos clients.

Uptime Kuma est un **agent de sécurité** que vous engagez. Toutes les minutes, il va visiter chacune de vos boutiques. Si une boutique ne répond pas, il vous appelle immédiatement (ou vous envoie un message sur Discord, Telegram, etc.) pour vous dire "Attention, la boutique XYZ est fermée !".

---

## 🎯 Pourquoi utiliser Uptime Kuma ?

Quand on auto-héberge des services (comme Supabase, Gitea, ou même un simple blog), il peut arriver qu'ils plantent pour diverses raisons (bug, manque de RAM, problème réseau...).

-   ✅ **Être le premier informé** : Soyez au courant d'une panne avant vos utilisateurs.
-   ✅ **Réagir rapidement** : Une notification instantanée vous permet de corriger le problème au plus vite.
-   ✅ **Historique des pannes** : Visualisez la fiabilité de vos services dans le temps avec des graphiques clairs.
-   ✅ **Communication transparente** : Créez une "page de statut" publique pour informer vos utilisateurs de l'état de vos services (comme le fait Google ou Microsoft).
-   ✅ **Super simple** : Contrairement à des outils de monitoring complexes comme Prometheus, Uptime Kuma est extrêmement simple à configurer et à utiliser.

---

## ✨ Fonctionnalités Clés

-   **Multiples types de moniteurs** : Surveillez bien plus que des sites web.
    -   **HTTP(s)** : Pour les sites et API web.
    -   **Ping** : Pour vérifier si un serveur est joignable sur le réseau.
    -   **Port TCP** : Pour s'assurer qu'un service spécifique est à l'écoute (ex: une base de données).
    -   **Docker** : Pour surveiller si un conteneur Docker est en cours d'exécution.
    -   Et bien d'autres...
-   **Notifications** : Plus de 90 types de notifications supportées (Discord, Telegram, Slack, Email, SMS, etc.).
-   **Pages de Statut** : Créez de belles pages de statut personnalisables pour afficher l'état de vos services.
-   **Certificat SSL** : Vous alerte automatiquement quand un certificat SSL est sur le point d'expirer.

---

## 🚀 Comment l'utiliser ? (Pas à pas)

### Étape 1 : Ajouter un moniteur

C'est la base. Un "moniteur" est une tâche de surveillance pour un service.

1.  Cliquez sur **"+ Ajouter un nouveau moniteur"**.
2.  **Choisissez le type**. Pour commencer, "HTTP(s)" est le plus courant.
3.  **Remplissez les informations** :
    -   `Nom Convivial` : Un nom clair, ex: "Supabase API".
    -   `URL` : L'adresse à vérifier, ex: `https://supabase.votre-domaine.com`.
4.  Laissez les autres options par défaut pour le moment et **enregistrez**.

Votre premier moniteur est actif ! Uptime Kuma va maintenant vérifier cette URL toutes les 60 secondes.

### Étape 2 : Configurer les notifications

Être alerté, c'est tout l'intérêt d'Uptime Kuma.

1.  Dans la barre de menu en haut, cliquez sur votre photo de profil > **Paramètres**.
2.  Allez dans l'onglet **Notifications**.
3.  Cliquez sur **"Configurer une notification"**.
4.  **Choisissez le type de notification**. Prenons Discord comme exemple.
    -   `Nom Convivial` : "Alertes Discord".
    -   `Webhook URL` : Allez dans votre serveur Discord > Paramètres du serveur > Intégrations > Webhooks > Nouveau Webhook. Copiez l'URL du webhook et collez-la ici.
5.  **Testez** la notification pour vous assurer que ça fonctionne, puis **enregistrez**.

Maintenant, à chaque fois qu'un moniteur tombera en panne, vous recevrez une alerte sur Discord.

### Étape 3 : Créer une page de statut (optionnel)

C'est utile si vous hébergez des services pour d'autres personnes (amis, famille, clients).

1.  En haut, cliquez sur **"Pages de Statut"**.
2.  Cliquez sur **"Nouvelle Page de Statut"**.
3.  Donnez-lui un nom (ex: "Statut des Services de Mon Pi").
4.  Personnalisez le chemin (ex: `status`).
5.  **Ajoutez les moniteurs** que vous souhaitez afficher publiquement.
6.  **Enregistrez**.

Vous avez maintenant une page comme `https://uptime.votre-domaine.com/status` que vous pouvez partager.

---

## 💡 Astuces

-   **Monitorez vos services internes** : Uptime Kuma peut aussi surveiller des services qui ne sont pas exposés sur internet. Utilisez le type de moniteur "Ping" ou "Port TCP" avec l'adresse IP locale de vos services (ex: `192.168.1.100`).
-   **Heartbeat** : Pour les scripts de sauvegarde (backups). Votre script envoie un "ping" à Uptime Kuma à la fin de son exécution. Si Uptime Kuma ne reçoit pas de ping après un certain temps, il vous alerte. Cela permet de savoir si vos sauvegardes ont échoué !
-   **Groupes de moniteurs** : Organisez vos moniteurs en groupes (ex: "Infrastructure", "Média", "Productivité") pour un tableau de bord plus clair.

---

## 🆘 Problèmes Courants

### "Mon moniteur est en panne alors que le site fonctionne"

-   **Vérifiez l'URL** : Une faute de frappe est vite arrivée.
-   **Problème de DNS** : Si vous monitorez une URL locale, assurez-vous que le conteneur Uptime Kuma peut la résoudre. Essayez d'utiliser l'adresse IP à la place du nom de domaine.
-   **Timeout trop court** : Si le service est lent à répondre, Uptime Kuma peut le considérer comme en panne. Augmentez la valeur de "Timeout" dans les paramètres avancés du moniteur.

### "Je ne reçois pas de notifications"

-   Utilisez le bouton **"Tester"** lors de la configuration de la notification pour vous assurer que la configuration est correcte.
-   Vérifiez que vous avez bien associé la notification à vos moniteurs (vous pouvez le faire pour chaque moniteur individuellement ou la définir par défaut).

---

Avec Uptime Kuma, vous avez maintenant une visibilité complète sur la santé de votre homelab. Plus de mauvaises surprises !
