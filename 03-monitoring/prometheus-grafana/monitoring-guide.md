# 🎓 Guide Débutant : Monitoring avec Prometheus & Grafana

> **Pour qui ?** : Toute personne qui auto-héberge des services et veut s'assurer que tout fonctionne bien.
> **Durée de lecture** : 15 minutes
> **Niveau** : Débutant

---

## 📖 C'est Quoi le Monitoring ?

### Analogie Simple

Imaginez que votre Raspberry Pi et tous les services que vous y hébergez (Supabase, Traefik, etc.) sont une voiture de course. Vous êtes le pilote. Pour gagner la course (et ne pas finir dans le mur), vous ne pouvez pas vous contenter de regarder la route. Vous avez besoin d'un **tableau de bord**.

*   **Le compteur de vitesse (CPU)** : Vous indique si votre moteur (le processeur) tourne trop vite.
*   **La jauge d'essence (RAM)** : Vous dit s'il vous reste assez de carburant (la mémoire) pour continuer.
*   **La jauge de température (Température CPU)** : Vous alerte si le moteur est en surchauffe.
*   **Le compteur kilométrique (Espace disque)** : Vous montre combien de place il vous reste dans le coffre.

La stack de monitoring, c'est exactement ça : un tableau de bord complet pour votre serveur. Elle collecte des milliers de données chaque seconde et vous les présente sous forme de graphiques et de jauges faciles à comprendre.

*   **Prometheus** : C'est le mécanicien qui installe des capteurs partout dans la voiture et enregistre toutes les données dans un grand carnet.
*   **Grafana** : C'est le designer qui prend le carnet du mécanicien et conçoit un magnifique tableau de bord numérique, clair et lisible, pour que vous, le pilote, puissiez prendre les bonnes décisions.

### En Termes Techniques

*   **Prometheus** est une base de données de séries temporelles (Time-Series Database) et un système d'alerting. Son rôle est de "scraper" (collecter) à intervalles réguliers des métriques exposées par différentes applications (appelées "exporters") et de les stocker de manière optimisée.
*   **Grafana** est une plateforme de visualisation et d'analyse. Elle se connecte à des sources de données comme Prometheus et vous permet de créer des tableaux de bord interactifs en utilisant un langage de requêtes (PromQL pour Prometheus).

---

## 🎯 Cas d'Usage Concrets

### Scénario 1 : Prévenir la surchauffe
*   **Contexte** : Votre Raspberry Pi est dans un petit boîtier et vous lancez une application gourmande. Vous avez peur qu'il ne surchauffe et ne s'endommage.
*   **Solution** : Vous affichez le dashboard "Raspberry Pi 5 - Système" sur un écran. Vous gardez un œil sur la jauge de température. Si elle passe dans le rouge (> 70°C), vous savez qu'il faut soit arrêter l'application, soit améliorer le refroidissement.

### Scénario 2 : Identifier un conteneur qui fuit
*   **Contexte** : Votre serveur devient de plus en plus lent, mais vous ne savez pas pourquoi.
*   **Solution** : Vous ouvrez le dashboard "Docker Containers". Dans le panneau "Top 10 Memory", vous voyez qu'un conteneur que vous avez déployé hier consomme de plus en plus de RAM (une "fuite mémoire"). Vous pouvez alors l'arrêter et investiguer le problème sans que tout votre serveur ne plante.

### Scénario 3 : Anticiper une panne de disque
*   **Contexte** : Vous stockez beaucoup de données (fichiers, backups, etc.) et vous ne voulez pas vous réveiller un matin avec un message "Disque plein".
*   **Solution** : Vous configurez une alerte dans Grafana. Si l'espace disque utilisé dépasse 85%, Grafana vous envoie automatiquement un email ou une notification sur Discord. Vous avez le temps de faire le ménage avant la catastrophe.

---

## 🏗️ Comment Ça Marche ?

### Architecture de la Stack

```mermaid
graph TD
    subgraph "Sources de données"
        A[Node Exporter<br>(Métriques du Pi)]
        B[cAdvisor<br>(Métriques Docker)]
        C[Postgres Exporter<br>(Métriques Supabase)]
    end

    subgraph "Stack de Monitoring"
        D[Prometheus<br>(Collecte et Stockage)]
        E[Grafana<br>(Visualisation)]
    end

    A -- Scrape --> D
    B -- Scrape --> D
    C -- Scrape --> D
    D -- Requêtes PromQL --> E
```

### Composants Principaux

*   **Prometheus** : Le cœur. Il contacte toutes les 15 secondes les "exporters" pour leur demander leurs dernières métriques.
*   **Grafana** : La vitrine. Il demande à Prometheus "Donne-moi l'évolution de la température CPU sur les 6 dernières heures" et l'affiche sous forme de graphique.
*   **Node Exporter** : Un petit programme qui tourne sur le Pi et qui expose des centaines de métriques sur le système lui-même (CPU, RAM, disque, réseau, etc.).
*   **cAdvisor** : Un outil de Google qui se spécialise dans l'exposition des métriques de tous les conteneurs Docker en cours d'exécution.
*   **Postgres Exporter** : Un exporteur spécialisé qui se connecte à la base de données de Supabase pour en extraire des métriques de performance.

---

## 🚀 Premiers Pas

### Installation

Pour installer la stack de monitoring, suivez le guide d'installation détaillé :

➡️ **[Consulter le Guide d'Installation du Monitoring](monitoring-setup.md)**

### Visite Guidée de Grafana

Une fois l'installation terminée, connectez-vous à Grafana.

**Étape 1** : Accéder à Grafana
L'URL dépend de votre configuration Traefik (ex: `http://<IP_DU_PI>:3002` ou `https://grafana.mondomaine.com`). Les identifiants par défaut sont `admin` / `admin` (il vous sera demandé de changer le mot de passe).

**Étape 2** : Explorer les Dashboards
Dans le menu de gauche, allez dans "Dashboards". Vous y trouverez les 3 dashboards pré-configurés :

1.  **Raspberry Pi 5 - Système** : Votre vue d'ensemble matérielle.
2.  **Docker Containers** : La santé de toutes vos applications.
3.  **Supabase PostgreSQL** : Le cœur de votre backend (si Supabase est installé).

**Étape 3** : Interagir avec un panneau
Cliquez sur le titre d'un panneau (ex: "CPU Usage") et cliquez sur "Explore". Vous êtes maintenant dans l'interface "Explore" de Grafana. Vous pouvez y voir la requête PromQL qui génère le graphique et expérimenter avec d'autres requêtes.

---

## 📈 Les Dashboards Disponibles

### Raspberry Pi 5 - Système
Ce dashboard est votre vue d'ensemble. Il vous permet de répondre rapidement à la question : "Est-ce que mon serveur va bien ?". Les indicateurs clés sont la **température CPU** et l'**utilisation de la RAM**.

### Docker Containers
C'est ici que vous passez le plus de temps pour analyser les performances de vos applications. Les panneaux "Top 10" sont parfaits pour identifier rapidement les conteneurs les plus gourmands.

### Supabase PostgreSQL
Ce dashboard est plus avancé. Il est crucial si vous utilisez Supabase en production. La métrique la plus importante ici est le **"Cache Hit Ratio"**. Un ratio élevé (> 95%) signifie que votre base de données est performante et n'a pas besoin de lire constamment sur le disque. Si ce ratio baisse, c'est peut-être un signe qu'il faut allouer plus de RAM à PostgreSQL.

---

## 🔔 Alertes

Grafana dispose d'un système d'alertes puissant. Vous pouvez définir des règles sur n'importe quel panneau.

**Exemple : Créer une alerte de température**

1.  Allez sur le dashboard "Raspberry Pi 5 - Système".
2.  Cliquez sur le titre du panneau "CPU Temperature" > "Edit".
3.  Allez dans l'onglet "Alert".
4.  Créez une règle : `WHEN last() OF query(A, 5m, now) IS ABOVE 75`.
5.  Configurez un "Notification channel" (par exemple, un webhook Discord ou un email) pour être prévenu.

---

## 🐛 Dépannage Débutants

### Problème 1 : Les dashboards sont vides ("No Data")
*   **Symptôme** : Tous les panneaux affichent "No Data".
*   **Cause** : Grafana n'arrive pas à se connecter à Prometheus, ou Prometheus n'arrive pas à collecter les données.
*   **Solution** : 
    1.  Vérifiez que tous les conteneurs de la stack sont bien en cours d'exécution (`docker compose ps`).
    2.  Allez sur l'interface de Prometheus (`http://<IP_DU_PI>:9090`) > Status > Targets. Tous les "targets" doivent être à l'état `UP`.
    3.  Si un target est `DOWN`, redémarrez le conteneur correspondant (ex: `docker compose restart node-exporter`).

### Problème 2 : Le dashboard Supabase est vide
*   **Symptôme** : Seul le dashboard Supabase est vide, les autres fonctionnent.
*   **Cause** : Le `postgres-exporter` n'arrive pas à se connecter à la base de données de Supabase.
*   **Solution** : Vérifiez les logs du conteneur `postgres-exporter` (`docker compose logs postgres-exporter`). L'erreur la plus courante est un mot de passe incorrect. Le script d'installation est censé le détecter automatiquement, mais si vous avez changé le mot de passe de Supabase manuellement, vous devrez le mettre à jour dans le fichier `.env` de la stack de monitoring.

---

## ✅ Checklist Progression

### Niveau Débutant
- [ ] Installation réussie de la stack.
- [ ] Connexion à Grafana et changement du mot de passe par défaut.
- [ ] Compréhension des 3 dashboards principaux.
- [ ] Identification de la température CPU et de l'utilisation RAM.

### Niveau Intermédiaire
- [ ] Création d'une alerte simple (ex: température CPU).
- [ ] Importation d'un dashboard depuis la communauté Grafana.
- [ ] Utilisation de l'interface "Explore" pour écrire une requête PromQL simple.

### Niveau Avancé
- [ ] Création de votre propre dashboard personnalisé.
- [ ] Configuration d'un nouveau "scrape target" dans Prometheus pour monitorer une application non standard.
- [ ] Mise en place de l'alerting vers plusieurs canaux (Email, Discord, Telegram).

---

## 📚 Ressources d'Apprentissage

*   [Introduction to PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/) : Apprenez les bases du langage de requêtes de Prometheus.
*   [Grafana Fundamentals](https://grafana.com/tutorials/grafana-fundamentals/) : Un tutoriel officiel de Grafana.
*   [Awesome Prometheus](https://github.com/roaldnefs/awesome-prometheus) : Une liste de ressources sur Prometheus.
*   [Grafana Dashboards](https://grafana.com/grafana/dashboards/) : Des milliers de dashboards partagés par la communauté.
