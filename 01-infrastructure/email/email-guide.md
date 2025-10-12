# 📧 Guide du Débutant pour la Stack Email

Bienvenue dans le guide du débutant pour la stack email sur Raspberry Pi 5. Ce guide est conçu pour vous aider à comprendre et à déployer votre propre solution de messagerie, même si vous n'avez jamais fait cela auparavant.

## Introduction

### C'est quoi, cette stack email ?

Imaginez que vous puissiez avoir votre propre service de messagerie, comme Gmail ou Outlook, mais entièrement sous votre contrôle. C'est exactement ce que cette stack vous permet de faire. Elle vous donne les outils pour soit créer une interface web pour vos emails existants, soit construire votre propre "bureau de poste" personnel.

*   **Roundcube, c'est comme l'interface de Gmail que vous contrôlez.** C'est une application web qui vous permet de lire, écrire et organiser vos emails.
*   **Un serveur mail complet, c'est comme avoir votre propre bureau de poste personnel.** Au lieu que Google ou Microsoft gèrent votre courrier, c'est vous qui le faites, avec vos propres règles et sur votre propre matériel.

## Pourquoi utiliser cette stack ?

Voici quelques cas d'utilisation concrets :

*   **Pour le débutant curieux** : Vous voulez une interface web unique et centralisée pour consulter tous vos comptes emails (Gmail, Outlook, etc.) sans avoir à jongler entre plusieurs onglets. C'est le **Scénario 1**.
*   **Pour le créateur de contenu** : Vous avez un nom de domaine et vous voulez des adresses email professionnelles (par exemple, `contact@mon-super-site.com`). C'est le **Scénario 2**.
*   **Pour le petit entrepreneur** : Vous voulez une solution de communication professionnelle, indépendante des grands fournisseurs, pour gérer les emails de votre entreprise. C'est le **Scénario 2**.
*   **Pour la famille** : Vous voulez créer des adresses email pour toute la famille avec un nom de domaine personnalisé (par exemple, `papa@famille-dupont.com`, `maman@famille-dupont.com`). C'est le **Scénario 2**.
*   **Pour le soucieux de la vie privée** : Vous voulez un contrôle total sur vos données et ne pas dépendre des géants du web pour vos communications par email. C'est le **Scénario 2**.

## Concepts clés expliqués simplement

*   **Webmail** : C'est une interface web (comme Roundcube) pour lire et écrire des emails. C'est une alternative aux clients lourds comme Thunderbird ou Outlook, qui sont des logiciels à installer sur votre ordinateur.
*   **IMAP/SMTP** : Ce sont les protocoles qui permettent de recevoir (IMAP) et d'envoyer (SMTP) des emails. 
    *   **IMAP** est comme votre **boîte aux lettres** : il vous permet de consulter les emails qui sont arrivés sur le serveur.
    *   **SMTP** est comme le **bureau de poste** : c'est lui qui se charge d'envoyer votre courrier à son destinataire.
*   **MX/SPF/DKIM/DMARC** : Ce sont des enregistrements DNS, un peu comme la **carte d'identité de votre serveur mail**. Ils permettent de prouver que votre serveur est bien qui il prétend être et d'éviter que vos emails soient considérés comme du spam.
*   **Postfix** : C'est le **facteur**. Il reçoit le courrier et le distribue aux bonnes boîtes aux lettres.
*   **Dovecot** : C'est le **casier** où sont stockés vos emails. Il les garde en sécurité et vous permet d'y accéder via IMAP.
*   **Rspamd** : C'est le **garde du bureau de poste**. Il filtre les emails entrants et met de côté le spam pour que vous n'ayez pas à le faire.

## Choisir son scénario

| Critère | Scénario 1 (Client Externe) | Scénario 2 (Serveur Complet) |
| :--- | :--- | :--- |
| **Niveau** | ⭐ Débutant | ⭐⭐⭐ Avancé |
| **Coût** | Gratuit | 10-20€/an (nom de domaine) |
| **Domaine requis** | Non | Oui (obligatoire) |
| **DNS complexe** | Non | Oui (MX, SPF, DKIM, DMARC) |
| **Emails custom** | Non (@gmail.com) | Oui (@ton-domaine.com) |
| **Contrôle total** | Non (Google/Microsoft) | Oui (100%) |
| **Maintenance** | Facile | Moyenne |
| **Risque spam** | Aucun | Moyen (configuration requise) |

**Recommandation** :

*   Commencez avec le **Scénario 1** pour vous familiariser avec Roundcube et l'écosystème.
*   Passez au **Scénario 2** lorsque vous vous sentez prêt à gérer votre propre serveur de messagerie et que vous avez besoin d'adresses email personnalisées.

## Tutoriel pas-à-pas : Scénario 1 (Client Externe)

### Étape 1 : Prérequis

Avant de commencer, assurez-vous que Docker et Traefik sont bien installés et fonctionnels.

```bash
# Vérifier Docker
docker --version

# Vérifier Traefik
docker ps | grep traefik
```

### Étape 2 : Déploiement

Copiez et collez la commande suivante dans votre terminal :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-email-stack/scripts/01-roundcube-deploy-external.sh | sudo bash
```

Le script va vous poser quelques questions. Par exemple, si vous utilisez Gmail, il vous demandera de sélectionner "Gmail" dans la liste.

### Étape 3 : Configuration Gmail (si vous utilisez Gmail)

1.  **Activez la validation en deux étapes** sur votre compte Google : [https://myaccount.google.com/security](https://myaccount.google.com/security)
2.  **Créez un mot de passe d'application** : [https://myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords). C'est un mot de passe à 16 caractères que vous utiliserez uniquement pour Roundcube.
3.  Copiez ce mot de passe de 16 caractères.

### Étape 4 : Première connexion

1.  Ouvrez votre navigateur et allez à l'adresse que vous avez configurée (par exemple, `https://mail.votredomaine.com`).
2.  **Username** : votre-email@gmail.com
3.  **Password** : le mot de passe d'application à 16 caractères que vous venez de créer (PAS le mot de passe de votre compte Gmail).

Vous devriez maintenant voir l'interface de Roundcube avec tous vos emails Gmail.

## Tutoriel pas-à-pas : Scénario 2 (Serveur Complet)

### Étape 0 : Prérequis critiques

*   Vous devez posséder un nom de domaine.
*   Vous devez avoir accès à la configuration DNS de votre nom de domaine.
*   Le port 25 doit être ouvert par votre fournisseur d'accès à Internet. Vous pouvez le tester avec la commande `telnet smtp.gmail.com 25`.

### Étape 1 : Préparer les DNS (AVANT le déploiement)

Ajoutez les enregistrements suivants dans la configuration DNS de votre nom de domaine :

```
# Enregistrement A (obligatoire)
mail.votredomaine.com  A  VOTRE_IP_PUBLIQUE

# Enregistrement MX (obligatoire)
votredomaine.com  MX  10  mail.votredomaine.com

# Enregistrement SPF (obligatoire)
votredomaine.com  TXT  "v=spf1 mx ~all"
```

### Étape 2 : Déploiement

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-email-stack/scripts/01-roundcube-deploy-full.sh | sudo bash
```

Le script vous demandera votre nom de domaine et vérifiera automatiquement la configuration DNS.

### Étape 3 : Ajouter DKIM et DMARC

À la fin de l'installation, le script affichera des enregistrements DKIM et DMARC que vous devrez ajouter à votre configuration DNS. C'est une étape CRUCIALE pour que vos emails ne soient pas considérés comme du spam.

Copiez-collez exactement les valeurs fournies par le script.

### Étape 4 : Créer votre premier utilisateur

```bash
# Se connecter à la base de données
docker exec -it mail-db psql -U mailuser mailserver

# Créer un utilisateur
INSERT INTO virtual_users (domain_id, email, password)
VALUES (
    (SELECT id FROM virtual_domains WHERE name = 'votredomaine.com'),
    'admin@votredomaine.com',
    crypt('MonMotDePasse123', gen_salt('bf'))
);
```

### Étape 5 : Tester

1.  Connectez-vous à Roundcube à l'adresse `https://mail.votredomaine.com` avec l'email et le mot de passe que vous venez de créer.
2.  Envoyez un email de test à une adresse Gmail.
3.  Vérifiez votre score de spam sur [https://www.mail-tester.com](https://www.mail-tester.com). L'objectif est d'avoir un score de 8/10 ou plus.

## Troubleshooting pour les débutants

### Scénario 1

| Erreur | Cause | Solution |
| :--- | :--- | :--- |
| "Authentication failed" | Mot de passe incorrect | Utilisez le mot de passe d'application, pas votre mot de passe normal. |
| "Cannot connect to IMAP" | IMAP désactivé sur Gmail | Activez IMAP dans les paramètres de Gmail. |
| "502 Bad Gateway" | Traefik n'est pas démarré | Vérifiez que Traefik est bien en cours d'exécution. |

### Scénario 2

| Erreur | Cause | Solution |
| :--- | :--- | :--- |
| "Relay access denied" | Enregistrement MX manquant | Vérifiez que votre enregistrement MX est correctement configuré. |
| Emails en spam | SPF/DKIM/DMARC manquants | Vérifiez que vous avez bien ajouté les enregistrements TXT. |
| "Connection refused port 25" | Votre FAI bloque le port 25 | Utilisez un relais SMTP (voir le guide d'installation). |

## Checklist de progression

**Niveau Débutant** ✅
- [ ] Déployer le Scénario 1 avec Gmail
- [ ] Se connecter à Roundcube
- [ ] Envoyer/recevoir des emails via Gmail
- [ ] Comprendre la différence entre IMAP/SMTP

**Niveau Intermédiaire** 🔄
- [ ] Acheter un nom de domaine
- [ ] Configurer les DNS (A, MX, SPF)
- [ ] Déployer le Scénario 2
- [ ] Ajouter DKIM/DMARC
- [ ] Créer des utilisateurs manuellement

**Niveau Avancé** 🚀
- [ ] Configurer un relais SMTP (SendGrid)
- [ ] Obtenir un score de 8/10 ou plus sur mail-tester.com
- [ ] Automatiser la création d'utilisateurs
- [ ] Intégrer le monitoring avec Grafana
- [ ] Mettre en place des backups automatiques

## Ressources d'apprentissage

*   **Vidéos** :
    *   "How email works" - Hussein Nasser (YouTube)
    *   "Self-hosting email server 2024" - Techno Tim
*   **Documentation** :
    *   [Roundcube](https://roundcube.net/)
    *   [Postfix](http://www.postfix.org/documentation.html)
    *   [DKIM/SPF/DMARC](https://www.cloudflare.com/learning/dns/dns-records/)
*   **Communautés** :
    *   [r/selfhosted](https://www.reddit.com/r/selfhosted/) (Reddit)
    *   Forum Yunohost (français)
*   **Outils de test** :
    *   [https://www.mail-tester.com](https://www.mail-tester.com) (score de spam)
    *   [https://mxtoolbox.com](https://mxtoolbox.com) (vérification DNS/MX)
    *   [https://dkimvalidator.com](https://dkimvalidator.com) (validation DKIM)
