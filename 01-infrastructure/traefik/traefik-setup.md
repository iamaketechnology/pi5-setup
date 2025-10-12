# 🚀 Installation Traefik

> **Installation automatisée pour 3 scénarios d'accès externe**

---

## 📋 Prérequis

### Système
*   Raspberry Pi 5.
*   Raspberry Pi OS 64-bit.
*   Docker et Docker Compose installés.
*   Une connexion Internet stable.

### Ressources
*   **RAM** : ~100 Mo
*   **Stockage** : ~50 Mo
*   **Ports** : 80 (HTTP) et 443 (HTTPS) doivent être disponibles.

---

## 🚀 Installation

Choisissez l'un des trois scénarios ci-dessous. Chaque scénario a son propre script d'installation.

### Option 1 : DuckDNS (Facile et Gratuit)

Idéal pour les débutants. Vous obtiendrez une URL comme `https://mon-pi.duckdns.org`.

**Prérequis spécifiques :**
*   Un compte DuckDNS ([duckdns.org](https://www.duckdns.org)).
*   Votre token DuckDNS.
*   Les ports 80 et 443 ouverts sur votre box et redirigés vers votre Pi.

**Commande d'installation :**
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash
```

Le script vous demandera votre sous-domaine DuckDNS, votre token et un email.

### Option 2 : Domaine Personnel + Cloudflare (Recommandé pour la Production)

Idéal pour un usage sérieux avec votre propre nom de domaine et des sous-domaines (`app.mondomaine.com`).

**Prérequis spécifiques :**
*   Un nom de domaine personnel.
*   Un compte Cloudflare (gratuit).
*   Un token d'API Cloudflare avec les permissions `Zone:DNS:Edit`.
*   Les ports 80 et 443 ouverts sur votre box.

**Commande d'installation :**
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-cloudflare.sh | sudo bash
```

Le script vous demandera votre nom de domaine, votre token API Cloudflare et un email.

### Option 3 : VPN (Sécurité Maximale)

Idéal si vous ne voulez rien exposer sur Internet et accéder à vos services via un tunnel sécurisé.

**Prérequis spécifiques :**
*   Un service VPN configuré (Tailscale recommandé, ou WireGuard).
*   Aucun port à ouvrir (sauf celui du VPN si vous hébergez WireGuard vous-même).

**Commande d'installation :**
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-vpn.sh | sudo bash
```

Ce script met en place Traefik avec des certificats auto-signés pour un usage local via le VPN.

---

## 📊 Ce Que Fait le Script

Chaque script d'installation automatise les étapes suivantes :

1.  ✅ **Création de la structure** : Crée le dossier `/opt/stacks/traefik`.
2.  ✅ **Génération de la configuration** : Crée les fichiers `traefik.yml`, `docker-compose.yml` et `.env` adaptés au scénario choisi.
3.  ✅ **Génération du mot de passe** : Crée un mot de passe sécurisé pour le dashboard Traefik.
4.  ✅ **Déploiement Docker Compose** : Lance le conteneur Traefik (et DuckDNS pour le scénario 1).
5.  ✅ **Demande de certificat** : Configure Traefik pour obtenir un certificat SSL de Let's Encrypt (scénarios 1 et 2) ou génère un certificat auto-signé (scénario 3).
6.  ✅ **Affichage du résumé** : Affiche l'URL du dashboard et les identifiants.

---

## 🔧 Configuration Post-Installation

### Accès au Dashboard

L'URL pour accéder au tableau de bord de Traefik dépend du scénario choisi :

*   **DuckDNS** : `http://localhost:8081/dashboard/` ⚠️ **Accès local uniquement**
    *   **Depuis le Pi** : Accès direct via localhost
    *   **Depuis un autre ordinateur** : Utilisez un tunnel SSH :
        ```bash
        ssh -L 8081:localhost:8081 pi@<IP_DU_PI>
        ```
        Puis ouvrez `http://localhost:8081/dashboard/` dans votre navigateur
    *   **Pourquoi ?** Traefik v3 dashboard ne supporte pas le path-based routing (`/traefik`). Il nécessite soit un subdomain dédié, soit le mode insecure (localhost uniquement).
    *   **Alternative** : Utilisez Portainer (`http://<IP_DU_PI>:8080`) pour gérer vos containers.

*   **Cloudflare** : `https://traefik.<your-domain>.com`
*   **VPN** : `https://traefik.pi.local` (nécessite une configuration du fichier `hosts`)

### Credentials

⚠️ **DuckDNS** : Pas d'authentification nécessaire (accès localhost). Le port 8081 n'est accessible que depuis le Pi lui-même.

**Cloudflare/VPN** : Le nom d'utilisateur est `admin`. Le mot de passe est généré aléatoirement et affiché à la fin de l'installation. Il est stocké (hashé) dans le fichier `/home/pi/stacks/traefik/.env`.

---

## 🔗 Intégration d'Autres Applications

Pour que Traefik découvre et expose une autre application (par exemple, Supabase), vous devez ajouter des **labels** à son conteneur Docker. C'est la magie de la découverte automatique.

**Exemple : Intégrer Supabase Studio avec le scénario Cloudflare**

Modifiez le fichier `docker-compose.yml` de Supabase et ajoutez ces labels au service `studio` :

```yaml
services:
  studio:
    # ... autres configurations
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.supabase-studio.rule=Host(`studio.votredomaine.com`)"
      - "traefik.http.routers.supabase-studio.entrypoints=websecure"
      - "traefik.http.routers.supabase-studio.tls.certresolver=cloudflare"
      - "traefik.http.services.supabase-studio.loadbalancer.server.port=3000"
```

Redémarrez la stack Supabase (`docker compose up -d`), et Traefik la rendra automatiquement disponible sur `https://studio.votredomaine.com`.

Des scripts sont fournis pour automatiser cette intégration pour les stacks principaux comme Supabase.

---

## ✅ Validation Installation

**Test 1** : Vérifier que le conteneur Traefik est en cours d'exécution.

```bash
docker ps --filter "name=traefik"
```

**Résultat attendu** : Le conteneur `traefik` doit être listé avec le statut `Up`.

**Test 2** : Consulter les logs de Traefik pour vérifier l'obtention du certificat (Scénarios 1 et 2).

```bash
docker logs traefik
```

**Résultat attendu** : Cherchez une ligne comme `"Successfully obtained ACME certificate"` ou `"Obtained certificate for domains"`.

**Test 3** : Accéder au dashboard via votre navigateur. Vous devriez voir l'interface de Traefik après vous être connecté.

---

## 🛠️ Maintenance

Les scripts de maintenance sont situés dans `/opt/stacks/traefik/scripts/maintenance/`.

### Mettre à jour Traefik
```bash
sudo bash /opt/stacks/traefik/scripts/maintenance/traefik-update.sh
```

### Voir les logs
```bash
sudo bash /opt/stacks/traefik/scripts/maintenance/traefik-logs.sh
```

---

## 🐛 Troubleshooting

### Problème 1 : Erreur de certificat (Warning de sécurité)
*   **Symptôme** : Votre navigateur affiche un avertissement de sécurité (`ERR_CERT_AUTHORITY_INVALID`).
*   **Cause (Scénarios 1 & 2)** : Traefik n'a pas pu obtenir de certificat de Let's Encrypt. Vérifiez que vos ports 80/443 sont bien ouverts et que votre configuration DNS est correcte.
*   **Cause (Scénario 3)** : C'est normal. Vous utilisez un certificat auto-signé. Vous devez l'accepter manuellement dans le navigateur ou installer l'autorité de certification racine (CA) sur votre appareil.

### Problème 2 : 404 Not Found
*   **Symptôme** : Traefik répond, mais ne trouve pas votre application.
*   **Solution** : Vérifiez les labels Docker de votre application. La règle (`rule`) du routeur doit correspondre à l'URL que vous utilisez.

### Problème 3 : Le domaine ne résout pas (NXDOMAIN)
*   **Symptôme** : Votre navigateur ne trouve même pas le serveur.
*   **Solution (DuckDNS)** : Assurez-vous que le conteneur `duckdns` est en cours d'exécution et que votre token est correct.
*   **Solution (Cloudflare)** : Vérifiez que vos enregistrements DNS (A et CNAME) sont bien configurés dans le tableau de bord Cloudflare et qu'ils pointent vers votre adresse IP publique.

---

## 🗑️ Désinstallation

Pour supprimer complètement Traefik :

```bash
cd /opt/stacks/traefik
docker-compose down -v
cd /opt/stacks
sudo rm -rf traefik
```

---

## 📊 Consommation Ressources

*   **RAM utilisée** : ~100 Mo
*   **Stockage utilisé** : ~50 Mo
*   **Conteneurs actifs** : 1 (Traefik) ou 2 (Traefik + DuckDNS)

---

## 🔗 Liens Utiles

*   [Guide Débutant](traefik-guide.md)
*   [Comparaison détaillée des scénarios](docs/SCENARIOS-COMPARISON.md)
*   [Documentation Officielle de Traefik](https://doc.traefik.io/traefik/)
