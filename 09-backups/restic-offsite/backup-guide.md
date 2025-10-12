# 🎓 Guide Débutant : Sauvegardes Offsite

> **Pour qui ?** : Toute personne qui auto-héberge des données et qui ne veut jamais rien perdre.

---

## 📖 C'est Quoi une Sauvegarde Offsite ?

### Analogie Simple : La Règle 3-2-1

Imaginez que vos données les plus précieuses sont dans un coffre-fort chez vous. C'est bien, mais que se passe-t-il si votre maison brûle ?

La stratégie de sauvegarde 3-2-1 est la norme d'or pour la protection des données :

*   **TROIS copies** de vos données.
*   Sur **DEUX supports différents** (ex: le disque de votre Pi et un disque dur externe).
*   Dont **UNE copie hors-site** (offsite).

Cette stack s'occupe de la partie la plus importante : la **copie hors-site**. C'est comme faire une photocopie de vos documents les plus importants et la déposer dans un coffre-fort à la banque, dans une autre ville. En cas de problème majeur chez vous (incendie, inondation, vol), cette copie externe est votre assurance vie numérique.

### En Termes Techniques

Une sauvegarde offsite consiste à répliquer vos sauvegardes locales vers un emplacement de stockage distant et géographiquement séparé, généralement un service de stockage cloud. Cette stack utilise **rclone**, un outil en ligne de commande puissant, pour synchroniser vos sauvegardes locales (créées par les scripts de maintenance) vers un fournisseur de stockage objet comme Cloudflare R2 ou Backblaze B2.

---

## 🎯 Pourquoi est-ce CRUCIAL ?

*   **Protection contre les sinistres** : Incendie, inondation, surtension... Si votre matériel est détruit, vos données survivent.
*   **Protection contre le vol** : Si on vous vole votre Raspberry Pi, le voleur n'aura pas vos sauvegardes.
*   **Protection contre les erreurs humaines** : Vous supprimez accidentellement un fichier important ? Vous pouvez le restaurer depuis la sauvegarde de la veille.
*   **Tranquillité d'esprit** : Dormez sur vos deux oreilles, en sachant que même dans le pire des scénarios, vos données sont en sécurité.

---

## ☁️ rclone avec Cloudflare R2 vs. Backblaze B2

| Critère | 🟠 Cloudflare R2 (Recommandé) | 🔵 Backblaze B2 |
| :--- | :--- | :--- |
| **Coût de stockage** | $0.015 / Go / mois | **$0.005 / Go / mois** (moins cher) |
| **Coût de téléchargement** | **Gratuit !** | $0.01 / Go |
| **Tier gratuit** | 10 Go / mois | 10 Go / mois |
| **Facilité** | Très simple | Très simple |

**Conclusion :**

*   **Cloudflare R2** est idéal si vous prévoyez de devoir restaurer vos données de temps en temps, car les téléchargements sont gratuits.
*   **Backblaze B2** est légèrement moins cher pour le stockage pur, mais peut coûter plus cher si vous devez télécharger vos sauvegardes.

Pour la plupart des utilisateurs, les 10 Go gratuits de l'un ou l'autre suffiront amplement pour commencer.

---

## 🔄 La Stratégie de Rotation GFS

Cette stack ne se contente pas de copier le dernier backup. Elle utilise une stratégie de rotation intelligente appelée **Grandfather-Father-Son (GFS)** pour optimiser l'espace de stockage et vous donner plusieurs points de restauration dans le temps.

*   **Son (Fils)** : 7 sauvegardes quotidiennes (la semaine passée).
*   **Father (Père)** : 4 sauvegardes hebdomadaires (le mois passé).
*   **Grandfather (Grand-père)** : 6+ sauvegardes mensuelles (l'année passée).

Cela signifie que vous pouvez restaurer la version de vos données d'hier, de la semaine dernière, ou d'il y a six mois.

---

## 🚀 Premiers Pas

### Installation

Pour configurer les sauvegardes offsite, suivez le guide d'installation détaillé :

➡️ **[Consulter le Guide d'Installation des Sauvegardes Offsite](backup-setup.md)**

### Tester la Restauration

Une sauvegarde n'est utile que si vous êtes sûr de pouvoir la restaurer. Le guide d'installation vous montrera comment effectuer un test de restauration en toute sécurité pour vérifier que tout fonctionne comme prévu.

---

## 🐛 Dépannage Débutants

### Problème 1 : L'upload vers le cloud échoue
*   **Symptôme** : Le script de sauvegarde local fonctionne, mais les fichiers n'apparaissent pas dans votre espace de stockage cloud.
*   **Cause** : Les clés d'API de votre fournisseur cloud sont probablement incorrectes ou ont expiré.
*   **Solution** : Relancez le script d'installation de rclone (`01-rclone-setup.sh`) pour reconfigurer votre "remote" avec de nouvelles clés d'API.

### Problème 2 : Mon espace de stockage cloud est plein
*   **Symptôme** : Vous recevez une notification de votre fournisseur cloud indiquant que vous avez dépassé votre quota.
*   **Solution** : Vérifiez la taille de vos sauvegardes. Si elles sont trop volumineuses, vous pouvez soit passer à un plan payant (souvent très abordable), soit réduire la politique de rétention (par exemple, ne garder que 3 mois de sauvegardes mensuelles au lieu de 6).

---

## 📚 Ressources d'Apprentissage

*   [Documentation Officielle de rclone](https://rclone.org/)
*   [La stratégie de sauvegarde 3-2-1 expliquée par Backblaze](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/)
