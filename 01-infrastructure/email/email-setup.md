# 📧 Guide d'Installation

Ce guide fournit des instructions détaillées pour installer la stack email sur votre Raspberry Pi 5.

## Installation Scénario 1 (Client Externe)

### Prérequis détaillés

*   Raspberry Pi 5 (2Go de RAM ou plus).
*   Docker 24+.
*   Docker Compose 2.20+.
*   Traefik déployé et fonctionnel.
*   Un compte email existant (Gmail, Outlook, ProtonMail, etc.).

### Installation automatique

La méthode la plus simple est d'utiliser le script d'installation one-liner :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-email-stack/scripts/01-roundcube-deploy-external.sh | sudo bash
```

Ce script vous guidera à travers les étapes de configuration.

### Installation manuelle

Si vous préférez une installation manuelle :

1.  **Clonez le dépôt** :
    ```bash
    git clone https://github.com/iamaketechnology/pi5-setup
    cd pi5-setup/pi5-email-stack
    ```

2.  **Configurez le fichier `.env`** :
    ```bash
    cp .env.example .env
    nano .env
    ```
    Modifiez les variables `MAIL_DOMAIN`, `IMAP_HOST`, `SMTP_HOST`, etc., en fonction de votre fournisseur de messagerie.

3.  **Déployez la stack** :
    ```bash
    docker-compose -f compose/docker-compose-external.yml up -d
    ```

4.  **Vérifiez la santé de la stack** :
    ```bash
    docker ps
    docker logs roundcube
    ```

### Configuration des fournisseurs

**Gmail** :
```env
IMAP_HOST=ssl://imap.gmail.com
IMAP_PORT=993
SMTP_HOST=tls://smtp.gmail.com
SMTP_PORT=587
```
N'oubliez pas de créer un mot de passe d'application.

**Outlook** :
```env
IMAP_HOST=ssl://outlook.office365.com
IMAP_PORT=993
SMTP_HOST=tls://smtp.office365.com
SMTP_PORT=587
```

**ProtonMail** (nécessite Proton Bridge) :
```env
IMAP_HOST=127.0.0.1
IMAP_PORT=1143
SMTP_HOST=127.0.0.1
SMTP_PORT=1025
```

### Vérification post-installation

```bash
# Santé des conteneurs
docker ps --filter "name=roundcube"

# Logs
docker logs roundcube
docker logs roundcube-db

# Test HTTPS (via Traefik)
curl -I https://mail.votredomaine.com
```

## Installation Scénario 2 (Serveur Complet)

### Prérequis détaillés

*   Tous les prérequis du Scénario 1.
*   **Nom de domaine acheté**.
*   **Accès à la configuration DNS** de votre nom de domaine.
*   **Port 25 ouvert** par votre fournisseur d'accès à Internet.
*   **Adresse IP statique** ou un service de DNS dynamique (DynDNS).
*   Minimum 4Go de RAM (8Go recommandés).

### ⚠️ Vérifications critiques AVANT installation

```bash
# 1. Le port 25 est-il ouvert ?
telnet smtp.gmail.com 25
# Si vous voyez "Connected to smtp.gmail.com", c'est bon.
# Si ça mouline dans le vide (timeout), le port est bloqué.

# 2. La propagation DNS est-elle terminée ?
dig mail.votredomaine.com A
# Doit retourner l'adresse IP publique de votre Pi.

dig votredomaine.com MX
# Doit retourner : 10 mail.votredomaine.com
```

### Installation automatique

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-email-stack/scripts/01-roundcube-deploy-full.sh | sudo bash
```

Le script va :
1.  Vérifier les dépendances.
2.  Vous demander votre nom de domaine.
3.  Vérifier les enregistrements DNS A, MX et SPF.
4.  Générer les clés DKIM.
5.  Vous demander si vous voulez utiliser un relais SMTP.
6.  Générer les fichiers de configuration.
7.  Déployer la stack Docker Compose.
8.  Afficher les enregistrements DKIM et DMARC à ajouter à vos DNS.

### Configuration DNS post-installation

Le script affichera des enregistrements DKIM et DMARC. Vous devez les ajouter à la configuration DNS de votre nom de domaine. C'est une étape **critique**.

**Exemple pour Namecheap** :
1.  Allez dans "Advanced DNS".
2.  Cliquez sur "Add New Record" et choisissez "TXT Record".
3.  **Host** : `dkim._domainkey`
4.  **Value** : `v=DKIM1; k=rsa; p=...` (copiez-collez la valeur fournie par le script).
5.  Répétez pour l'enregistrement DMARC.

Attendez 15-30 minutes que les DNS se propagent.

### Gestion des utilisateurs

**Créer un utilisateur (manuellement)** :

```bash
# Se connecter à la base de données
docker exec -it mail-db psql -U mailuser mailserver

# Créer un utilisateur
INSERT INTO virtual_users (domain_id, email, password)
VALUES (
    (SELECT id FROM virtual_domains WHERE name = 'votredomaine.com'),
    'user@votredomaine.com',
    crypt('MotDePasse123', gen_salt('bf'))
);
```

### Tests de délivrabilité

1.  **Test d'envoi** : Connectez-vous à Roundcube et envoyez un email à une adresse Gmail. Vérifiez qu'il arrive bien en boîte de réception.
2.  **Score de spam** : Allez sur [https://www.mail-tester.com](https://www.mail-tester.com), envoyez un email à l'adresse de test fournie, et vérifiez votre score. Visez 8/10 ou plus.

### Utiliser un relais SMTP (recommandé pour les débutants)

Si votre FAI bloque le port 25 ou si vous avez des problèmes de délivrabilité, vous pouvez utiliser un relais SMTP.

1.  Créez un compte chez un fournisseur comme [SendGrid](https://sendgrid.com) (100 emails/jour gratuits).
2.  Créez une clé API pour le relais SMTP.
3.  Modifiez votre fichier `.env` avec les informations de SendGrid :
    ```env
    RELAYHOST=smtp.sendgrid.net:587
    RELAYHOST_USERNAME=apikey
    RELAYHOST_PASSWORD=VOTRE_CLE_API_SENDGRID
    ```
4.  Redémarrez Postfix :
    ```bash
    docker-compose -f compose/docker-compose-full.yml restart postfix
    ```

## Commandes utiles

```bash
# Démarrer la stack
docker-compose -f compose/docker-compose-full.yml start

# Arrêter la stack
docker-compose -f compose/docker-compose-full.yml stop

# Voir les logs
docker-compose -f compose/docker-compose-full.yml logs -f

# Voir la file d'attente de Postfix
docker exec postfix postqueue -p
```
