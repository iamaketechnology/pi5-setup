# Comparaison détaillée des scénarios

Ce document vous aide à choisir le scénario de déploiement de la stack email qui correspond le mieux à vos besoins.

## Tableau comparatif complet

| Critère | Scénario 1 : Client Externe | Scénario 2 : Serveur Complet |
| :--- | :--- | :--- |
| **Complexité** | ⭐ Simple | ⭐⭐⭐ Complexe |
| **Temps d'installation** | 5-10 min | 30-60 min |
| **Niveau requis** | Débutant | Avancé |
| **Domaine nécessaire** | Optionnel (pour HTTPS) | Obligatoire |
| **DNS complexe** | Non (enregistrement A uniquement) | Oui (A, MX, SPF, DKIM, DMARC) |
| **Port 25 ouvert** | Non | Oui (critique) |
| **Emails personnalisés** | Non (@gmail.com) | Oui (@votredomaine.com) |
| **Contrôle des données** | Non (chez Google/Microsoft) | Oui (100% local) |
| **Risque de spam** | Aucun | Moyen-élevé (si mal configuré) |
| **Maintenance** | Faible | Moyenne-élevée |
| **Consommation RAM** | ~500MB | ~1.5-2GB |
| **Coût** | Gratuit | 10-20€/an (nom de domaine) |
| **Backup requis** | Configuration uniquement | Configuration + données mail |
| **Dépendance externe** | Oui (Gmail/Microsoft) | Non (ou relais optionnel) |

## Quand choisir le Scénario 1 ?

✅ Vous voulez juste une interface web pour lire vos emails Gmail/Outlook.
✅ Vous débutez en auto-hébergement.
✅ Vous n'avez pas besoin d'adresses email personnalisées.
✅ Vous ne voulez pas gérer la complexité des DNS.
✅ Vous voulez quelque chose qui "juste marche".

## Quand choisir le Scénario 2 ?

✅ Vous voulez des adresses email avec votre propre nom de domaine (@votredomaine.com).
✅ Vous voulez un contrôle total sur vos données.
✅ Vous êtes à l'aise avec la gestion des DNS et le dépannage.
✅ Vous avez un nom de domaine et pouvez configurer les enregistrements DNS.
✅ Votre fournisseur d'accès à Internet ne bloque pas le port 25 (ou vous êtes prêt à utiliser un relais SMTP).

## Migration du Scénario 1 au Scénario 2

Il est tout à fait possible de commencer avec le Scénario 1 et de migrer plus tard vers le Scénario 2.

1.  Sauvegardez la configuration de votre Roundcube existant.
2.  Déployez le Scénario 2.
3.  Importez les paramètres de Roundcube.
4.  Créez vos utilisateurs dans le nouveau serveur de messagerie.
