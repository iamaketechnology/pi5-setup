# 🎓 Guide Débutant - Cloud Personnel sur Pi5

> **Hébergez votre propre Google Drive/Dropbox à la maison - Expliqué simplement**

---

## 🌟 C'est Quoi un Cloud Personnel ?

### Analogie Simple

Un cloud personnel, c'est comme avoir votre propre Dropbox/Google Drive,
mais au lieu que vos fichiers soient sur les serveurs de Google (aux USA),
ils sont chez vous, sur votre Raspberry Pi.

**Imaginez :**
```
❌ Google Drive = Coffre-fort à la banque
   → Pas chez vous
   → La banque peut regarder dedans
   → Vous payez un loyer mensuel

✅ Cloud Pi5 = Coffre-fort chez vous
   → Chez vous, dans votre salon
   → Vous avez les clés
   → Vous seul y accédez
   → Gratuit une fois acheté
```

---

## 📦 FileBrowser vs Nextcloud : C'est Quoi la Différence ?

### FileBrowser (Léger et Simple)

```
FileBrowser = Clé USB partagée sur Internet

C'est simple :
✅ Vous mettez des fichiers dans un dossier
✅ Vous y accédez depuis le web (téléphone, PC, partout)
✅ C'est léger, rapide, sans fioritures
✅ 50 MB de RAM seulement

Comme une clé USB, mais accessible depuis Internet (de manière sécurisée)
```

**Parfait pour :**
- Partager des fichiers avec la famille
- Uploader/télécharger depuis le web
- Gérer des fichiers simplement
- Utilisateurs avec peu de RAM (4GB Pi5)

### Nextcloud (Complet et Puissant)

```
Nextcloud = Google Workspace complet chez vous

C'est puissant :
✅ Stockage fichiers (comme Google Drive)
✅ Calendrier synchronisé (comme Google Calendar)
✅ Contacts synchronisés (comme Google Contacts)
✅ Édition documents en ligne (comme Google Docs)
✅ Apps mobiles natives (comme Dropbox/iCloud)
✅ Sync automatique sur tous vos appareils

C'est comme avoir TOUT Google Workspace, mais 100% privé chez vous
```

**Parfait pour :**
- Remplacer Google Drive/Calendar/Contacts
- Synchronisation automatique multi-appareils
- Éditer documents en ligne (Word, Excel)
- Backup automatique photos téléphone
- Collaboration (partage avec famille/équipe)

---

## 🔧 Comment Ça Marche ? (Expliqué Simplement)

### Schéma Général

```
Vos Appareils                  Internet               Votre Pi5 (chez vous)
─────────────────             ──────────             ────────────────────

📱 Téléphone  ──┐                                    ┌──> 📦 FileBrowser
                 │                                    │    (Fichiers)
💻 PC         ──┼──> HTTPS (crypté) ──> Traefik ────┤
                 │                                    │
🖥️ Laptop      ──┘                                    └──> ☁️ Nextcloud
                                                           (Suite complète)

Traefik = Portier sécurisé qui dirige le trafic
HTTPS = Tunnel chiffré (personne ne peut lire vos fichiers en transit)
```

### Explications par Étapes

**Étape 1 : Vous uploadez un fichier**
```
Vous (téléphone)
  → Fichier chiffré HTTPS
    → Traefik (vérifie HTTPS + certificat)
      → FileBrowser/Nextcloud
        → Sauvegarde sur disque Pi5
```

**Étape 2 : Vous téléchargez un fichier**
```
Vous (PC)
  → Demande fichier HTTPS
    → Traefik
      → FileBrowser/Nextcloud lit le disque
        → Envoie fichier chiffré
          → Vous
```

**C'est comme :** Envoyer une lettre recommandée (HTTPS) à votre maison (Pi5), où un majordome (Traefik) vérifie l'identité et range/sort vos affaires (FileBrowser/Nextcloud)

---

## 🤔 Quel Stack Choisir ? (Aide à la Décision)

### Test Simple : Répondez aux Questions

**Question 1** : Vous voulez juste partager des fichiers simplement ?
- ✅ **OUI** → **FileBrowser** (parfait pour vous !)
- ❌ NON → Question 2

**Question 2** : Vous voulez remplacer Google Drive + Calendar + Contacts ?
- ✅ **OUI** → **Nextcloud** (c'est pour vous !)
- ❌ NON → Question 3

**Question 3** : Vous avez besoin d'éditer documents en ligne (Word, Excel) ?
- ✅ **OUI** → **Nextcloud** (avec Collabora/OnlyOffice)
- ❌ NON → Question 4

**Question 4** : Apps mobiles natives sont importantes ?
- ✅ **OUI** → **Nextcloud** (apps iOS/Android natives)
- ❌ NON → **FileBrowser** (web suffit)

**Question 5** : Vous avez <8GB RAM sur votre Pi ?
- ✅ **OUI** → **FileBrowser** (ultra-léger, 50 MB)
- ❌ NON → Les deux options sont possibles

### Tableau Comparatif Rapide

| Fonctionnalité | FileBrowser | Nextcloud |
|----------------|-------------|-----------|
| Upload/Download fichiers | ✅ | ✅ |
| Interface web | ✅ | ✅ |
| Apps mobiles natives | ❌ | ✅ |
| Sync automatique | ❌ | ✅ |
| Calendrier | ❌ | ✅ |
| Contacts | ❌ | ✅ |
| Édition documents | ❌ | ✅ |
| RAM requise | 50 MB | 512 MB |
| Complexité | Simple | Avancé |

---

## 🎬 Scénarios d'Utilisation Concrets

### Scénario 1 : Famille (Partage Photos Vacances)

**Besoin** : Partager photos vacances avec famille (sans Facebook/Google)

**Solution FileBrowser** :
```
1. Upload photos dans /storage/vacances-2025
2. Créer lien de partage avec expiration (7 jours)
3. Envoyer lien à famille par WhatsApp/Email
4. Famille télécharge photos (sans compte requis si lien public)
```

**Solution Nextcloud** :
```
1. Créer dossier "Vacances 2025"
2. Upload photos depuis app mobile (auto-upload possible)
3. Partager dossier avec famille (ils créent compte Nextcloud)
4. Famille voit photos dans leur app Nextcloud mobile
5. Bonus : Créer album partagé avec geolocalisation
```

### Scénario 2 : Télétravail (Sync Documents)

**Besoin** : Accéder documents de travail depuis PC/Laptop/Mobile

**Solution FileBrowser** :
```
❌ Pas idéal : Pas de sync automatique
✅ Possible : Upload/download manuel via web
```

**Solution Nextcloud** :
```
✅ Parfait :
1. Installer client Nextcloud sur PC/Laptop
2. Sélectionner dossier "Documents" à synchroniser
3. Modifications automatiquement sync sur tous appareils
4. Travailler offline → sync automatique au retour Internet
5. Bonus : Éditer documents dans navigateur (Collabora)
```

### Scénario 3 : Backup Personnel

**Besoin** : Sauvegarder photos/vidéos téléphone automatiquement

**Solution FileBrowser** :
```
❌ Pas idéal : Pas d'app mobile, upload manuel via web
```

**Solution Nextcloud** :
```
✅ Parfait :
1. Installer app Nextcloud mobile
2. Activer "Auto Upload" photos
3. Chaque nouvelle photo → Upload automatique vers Pi5
4. Bonus : Reconnaissance faciale, tri par date/lieu
```

---

## 🚀 Installation : Qu'est-ce Qui Se Passe ?

### FileBrowser (Simple)

**Ce que fait le script** :
```
1️⃣ Crée dossier /home/pi/storage (votre espace fichiers)
2️⃣ Télécharge image Docker FileBrowser
3️⃣ Configure FileBrowser (langue FR, permissions)
4️⃣ Crée utilisateur admin avec mot de passe sécurisé
5️⃣ Connecte à Traefik (HTTPS automatique)
6️⃣ Ajoute widget au Dashboard Homepage
7️⃣ Affiche URL d'accès + credentials

⏱️ Durée : ~10 minutes
💾 Espace disque : ~100 MB
🧠 RAM : 50 MB
```

**Analogie** : C'est comme installer une app sur votre téléphone, mais sur le Pi5

### Nextcloud (Complet)

**Ce que fait le script** :
```
1️⃣ Crée dossier /home/pi/nextcloud-data (vos données)
2️⃣ Télécharge 3 images Docker :
   - Nextcloud (l'application)
   - PostgreSQL (base de données)
   - Redis (cache pour performances)
3️⃣ Configure Nextcloud + BDD + Cache
4️⃣ Crée utilisateur admin
5️⃣ Installe apps recommandées (calendar, contacts, etc.)
6️⃣ Optimise pour Raspberry Pi 5 (cache Redis, opcache)
7️⃣ Connecte à Traefik (HTTPS)
8️⃣ Ajoute widget Homepage
9️⃣ Affiche URL + credentials

⏱️ Durée : ~20 minutes
💾 Espace disque : ~1.5 GB
🧠 RAM : 512 MB
```

**Analogie** : C'est comme installer Google Workspace, mais sur votre Pi5

---

## 🔒 Sécurité Expliquée (Sans Jargon)

### HTTPS / TLS (Chiffrement)

**C'est quoi ?**
```
HTTPS = Tunnel sécurisé entre vous et votre Pi5

Analogie :
❌ HTTP (sans S) = Envoyer carte postale
   → Tout le monde peut lire pendant le transport

✅ HTTPS (avec S) = Envoyer lettre cachetée
   → Seul destinataire peut ouvrir

Votre FAI (Orange, Free, SFR) voit :
❌ HTTP : "Il télécharge photo-vacances.jpg de son Pi5"
✅ HTTPS : "Il envoie des données chiffrées quelque part"
           (impossible de savoir quoi)
```

**Comment c'est activé ?**
```
Traefik + Let's Encrypt génèrent automatiquement certificat HTTPS
Vous n'avez RIEN à faire → C'est automatique ✅

Let's Encrypt = Autorité qui dit "Oui, ce site est bien sécurisé"
Comme un tampon officiel sur une lettre
```

### Authentification (User/Password)

**FileBrowser** :
```
Simple : Nom d'utilisateur + Mot de passe

Comme un cadenas classique (1 clé)
└─> Username : admin
└─> Password : votre_mot_de_passe_sécurisé
```

**Nextcloud** :
```
Avancé : Nom d'utilisateur + Mot de passe + 2FA (optionnel)

2FA = Double authentification
Comme un cadenas classique + alarme
└─> Password : votre_mot_de_passe
└─> Code 6 chiffres sur téléphone (Google Authenticator)

Même si quelqu'un vole votre password,
il ne peut pas se connecter sans votre téléphone ✅
```

**Activer 2FA (Nextcloud)** :
```
1. Installer app "Two-Factor TOTP Provider"
2. Paramètres → Sécurité → Two-Factor Authentication
3. Scanner QR code avec Google Authenticator
4. Entrer code 6 chiffres pour valider
5. Sauvegarder codes de secours (au cas où vous perdez téléphone)
```

### Où Sont Stockés Vos Fichiers ?

```
FileBrowser :
📁 /home/pi/storage/
   ├── uploads/
   ├── documents/
   ├── media/
   └── archives/

Nextcloud :
📁 /home/pi/nextcloud-data/
   ├── alice/files/
   ├── bob/files/
   └── admin/files/

Ces dossiers = Disque dur de votre Pi5
100% chez vous, pas sur Internet
Personne ne peut y accéder sans vos credentials
```

---

## 🌐 Accès depuis l'Extérieur (3 Méthodes)

### Méthode 1 : DuckDNS (Gratuit, Path-based)

**C'est quoi ?**
```
DuckDNS = Adresse web gratuite qui pointe vers votre maison

Exemple : moncloud.duckdns.org

Analogie :
Votre maison a une adresse IP qui change souvent (IP dynamique)
→ Orange/Free change votre IP régulièrement

DuckDNS = Facteur qui connaît toujours votre nouvelle adresse
→ Même si IP change, DuckDNS suit automatiquement
```

**URLs** :
```
FileBrowser : https://moncloud.duckdns.org/files
Nextcloud   : https://moncloud.duckdns.org/cloud
Dashboard   : https://moncloud.duckdns.org
```

**Avantages** :
- ✅ Gratuit
- ✅ Facile à configurer
- ✅ Auto-update IP

**Inconvénients** :
- ❌ Nom de domaine moins "pro" (duckdns.org)
- ❌ Accès par chemins (/files, /cloud)

### Méthode 2 : Cloudflare (Subdomain)

**C'est quoi ?**
```
Cloudflare = Votre domaine personnalisé (mondomaine.com)

Vous achetez un domaine (10€/an chez Namecheap, OVH, etc.)
Cloudflare gère DNS gratuitement
```

**URLs** :
```
FileBrowser : https://files.mondomaine.com
Nextcloud   : https://cloud.mondomaine.com
Dashboard   : https://home.mondomaine.com
```

**Avantages** :
- ✅ Domaine personnalisé (plus professionnel)
- ✅ Sous-domaines propres (files.mondomaine.com)
- ✅ Protection DDoS Cloudflare (gratuit)

**Inconvénients** :
- ❌ Payant (domaine ~10€/an)
- ❌ Configuration DNS un peu plus complexe

**Comment faire ?**
```
1. Acheter domaine sur Namecheap/OVH/Gandi
2. Créer compte Cloudflare (gratuit)
3. Ajouter domaine à Cloudflare
4. Changer DNS chez registrar → DNS Cloudflare
5. Créer enregistrements DNS :
   - files.mondomaine.com → IP_PUBLIQUE_PI5
   - cloud.mondomaine.com → IP_PUBLIQUE_PI5
6. Traefik génère automatiquement certificats HTTPS
```

### Méthode 3 : VPN/Tailscale (Plus Sécurisé)

**C'est quoi ?**
```
VPN = Réseau privé virtuel (comme si vous étiez chez vous)

Analogie :
Sans VPN : Vous sonnez à la porte (tout le monde voit)
Avec VPN : Vous avez un tunnel secret direct à votre maison

Tailscale = VPN facile sans config réseau complexe
→ Pas de port forwarding
→ Pas de firewall à configurer
→ Connexion peer-to-peer chiffrée
```

**URLs** :
```
FileBrowser : https://files.pi.local (via VPN uniquement)
Nextcloud   : https://cloud.pi.local (via VPN uniquement)
```

**Avantages** :
- ✅ Le plus sécurisé (jamais exposé publiquement)
- ✅ Pas de port forwarding
- ✅ Gratuit (jusqu'à 20 appareils)
- ✅ Chiffrement bout-en-bout

**Inconvénients** :
- ❌ Nécessite app Tailscale sur chaque appareil
- ❌ Impossible de partager avec quelqu'un sans VPN

**Comment faire ?**
```
1. Créer compte Tailscale (gratuit)
2. Installer Tailscale sur Pi5 :
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
3. Installer app Tailscale sur téléphone/PC
4. Se connecter avec même compte
5. Accéder Pi5 via IP Tailscale (100.x.x.x)
```

---

## 🛠️ Maintenance Simple

### Vérifier Que Ça Marche

**FileBrowser** :
```bash
# Voir si conteneur tourne
docker ps | grep filebrowser

# Si vous voyez ligne "filebrowser-app" → ✅ Ça marche
# Si rien → ❌ Problème

# Redémarrer si besoin
cd /home/pi/stacks/filebrowser
docker compose restart
```

**Nextcloud** :
```bash
# Voir si conteneurs tournent
docker ps | grep nextcloud

# Doit afficher 3 lignes :
# - nextcloud-app
# - nextcloud-db
# - nextcloud-redis

# Si moins de 3 lignes → ❌ Problème

# Redémarrer si besoin
cd /home/pi/stacks/nextcloud
docker compose restart
```

### Voir les Logs (Messages de Debug)

**Si quelque chose ne marche pas** :
```bash
# FileBrowser logs
docker logs filebrowser-app --tail 50

# Nextcloud logs
docker logs nextcloud-app --tail 50
docker logs nextcloud-db --tail 50

# Chercher mots-clés : "error", "failed", "permission denied"
```

### Faire un Backup (Sauvegarde)

**Analogie** : Copier vos fichiers sur clé USB, mais automatique

**FileBrowser** :
```bash
# Backup simple (copie tout)
sudo tar czf backup-filebrowser-$(date +%Y%m%d).tar.gz \
  /home/pi/stacks/filebrowser \
  /home/pi/storage

# Fichier créé : backup-filebrowser-20251004.tar.gz
# À copier sur disque externe ou cloud

# Exemple : Copier sur clé USB
sudo cp backup-filebrowser-*.tar.gz /media/usb/backups/
```

**Nextcloud** :
```bash
# 1. Backup Base de Données
docker exec nextcloud-db pg_dump -U nextcloud nextcloud \
  > nextcloud-db-backup-$(date +%Y%m%d).sql

# 2. Backup fichiers utilisateurs
sudo tar czf backup-nextcloud-data-$(date +%Y%m%d).tar.gz \
  /home/pi/nextcloud-data

# 3. Backup configuration
sudo tar czf backup-nextcloud-config-$(date +%Y%m%d).tar.gz \
  /home/pi/stacks/nextcloud

# Copier sur disque externe
sudo cp backup-nextcloud-*.tar.gz /media/usb/backups/
sudo cp nextcloud-db-backup-*.sql /media/usb/backups/
```

**Automatiser les backups** :
```bash
# Créer script backup automatique
sudo nano /home/pi/backup-cloud.sh

# Contenu :
#!/bin/bash
BACKUP_DIR="/media/usb/backups"
DATE=$(date +%Y%m%d)

# Nextcloud
docker exec nextcloud-db pg_dump -U nextcloud nextcloud > \
  $BACKUP_DIR/nextcloud-db-$DATE.sql
tar czf $BACKUP_DIR/nextcloud-data-$DATE.tar.gz /home/pi/nextcloud-data

# Garder seulement 7 derniers jours
find $BACKUP_DIR -name "nextcloud-*" -mtime +7 -delete

# Rendre exécutable
sudo chmod +x /home/pi/backup-cloud.sh

# Ajouter cron (automatique chaque jour à 3h du matin)
crontab -e
# Ajouter ligne :
0 3 * * * /home/pi/backup-cloud.sh
```

### Restaurer un Backup

**Si problème (disque cassé, erreur, etc.)** :

**FileBrowser** :
```bash
# Arrêter service
cd /home/pi/stacks/filebrowser
docker compose down

# Restaurer backup
sudo tar xzf backup-filebrowser-20251004.tar.gz -C /

# Redémarrer
docker compose up -d

# Vérifier
docker ps | grep filebrowser
```

**Nextcloud** :
```bash
# Arrêter service
cd /home/pi/stacks/nextcloud
docker compose down

# Restaurer fichiers
sudo tar xzf backup-nextcloud-data-20251004.tar.gz -C /
sudo tar xzf backup-nextcloud-config-20251004.tar.gz -C /

# Redémarrer conteneurs
docker compose up -d

# Attendre 30 secondes que DB démarre

# Restaurer base de données
cat nextcloud-db-backup-20251004.sql | \
  docker exec -i nextcloud-db psql -U nextcloud nextcloud

# Vérifier
docker ps | grep nextcloud  # Doit afficher 3 lignes
```

---

## 🚨 Problèmes Courants (et Solutions)

### "Je n'arrive pas à me connecter"

**Checklist** :
```
1. Vérifier que conteneur tourne :
   docker ps | grep filebrowser  (ou nextcloud)

2. Vérifier URL correcte :
   - DuckDNS : https://subdomain.duckdns.org/files
   - Cloudflare : https://files.mondomaine.com
   - VPN : https://files.pi.local (VPN actif ?)

3. Vérifier credentials :
   cat /home/pi/stacks/filebrowser/credentials.txt

4. Tester en local d'abord :
   http://IP_PI:8080 (FileBrowser)
   http://IP_PI:8081 (Nextcloud)

   Trouver IP Pi :
   hostname -I
```

**Tester HTTPS** :
```bash
# Depuis un autre PC/téléphone
curl -I https://files.mondomaine.com

# Si erreur SSL :
# → Certificat pas encore généré (attendre 5 min)
# → Cloudflare DNS pas propagé (attendre 24h max)

# Si connexion refusée :
# → Port forwarding pas configuré
# → Firewall bloque
```

### "Upload de fichier échoue"

**Causes possibles** :

**1. Fichier trop gros**
```
FileBrowser : max 50 MB par défaut
Nextcloud : max 512 MB par défaut

Solution FileBrowser :
Éditer /home/pi/stacks/filebrowser/docker-compose.yml
Ajouter : --max-upload-size=1G

Solution Nextcloud :
docker exec -u www-data nextcloud-app php occ config:system:set \
  'max_upload' --value='2G'
```

**2. Espace disque plein**
```bash
# Vérifier espace disque
df -h /home/pi

# Si >90% utilisé → Nettoyer fichiers inutiles
du -sh /home/pi/nextcloud-data/*  # Voir qui prend de la place

# Supprimer vieux fichiers
docker system prune -a  # Nettoyer images Docker inutilisées
```

**3. Permissions**
```bash
# FileBrowser
sudo chown -R pi:pi /home/pi/storage

# Nextcloud
sudo chown -R 33:33 /home/pi/nextcloud-data
```

### "Nextcloud affiche 'Trusted Domain Error'"

**Cause** : Nextcloud n'accepte que certaines URLs (sécurité)

**Solution** :
```bash
# Ajouter votre domaine
docker exec -u www-data nextcloud-app php occ config:system:set \
  trusted_domains 1 --value=cloud.mondomaine.com

# Vérifier
docker exec -u www-data nextcloud-app php occ config:system:get trusted_domains

# Doit afficher :
# 0 => localhost
# 1 => cloud.mondomaine.com
```

### "Nextcloud lent / ne répond pas"

**Causes** :

**1. Cache pas activé**
```bash
# Vérifier Redis actif
docker ps | grep redis

# Activer cache (si pas fait)
docker exec -u www-data nextcloud-app php occ config:system:set \
  'memcache.local' --value='\OC\Memcache\Redis'
```

**2. Trop de fichiers dans un dossier**
```bash
# Scanner fichiers (optimise base de données)
docker exec -u www-data nextcloud-app php occ files:scan --all
```

**3. RAM insuffisante**
```bash
# Vérifier RAM libre
free -h

# Si <500 MB disponible sur Pi 8GB → Redémarrer
sudo reboot
```

### "FileBrowser : 404 Not Found"

**Cause** : Traefik routing mal configuré

**Solution** :
```bash
# Vérifier labels Docker
docker inspect filebrowser-app | grep traefik

# Doit avoir :
# - traefik.http.routers.filebrowser.rule
# - traefik.http.services.filebrowser.loadbalancer.server.port

# Redémarrer Traefik
docker restart traefik

# Tester accès direct (sans Traefik)
curl http://localhost:8080
# Si ça marche → Problème Traefik
```

---

## 📱 Pour Aller Plus Loin

### Apps Mobiles Nextcloud

**iOS** :
```
1. App Store → Rechercher "Nextcloud"
2. Installer (gratuit)
3. Ouvrir → Server address : https://cloud.mondomaine.com
4. Login : admin / votre_mot_de_passe
5. Activer auto-upload photos :
   - Settings → Auto Upload
   - Sélectionner dossier "Photos"
   - Activer "Upload only on WiFi" (économiser data mobile)
```

**Android** :
```
1. Play Store → "Nextcloud"
2. Installer (gratuit)
3. Même config que iOS
4. Auto-upload :
   - Menu → Settings → Auto Upload
   - Enable auto upload
   - Source folder : Camera
   - Destination : /Photos
```

**Astuce** : Désactiver auto-upload Google Photos pour économiser stockage cloud payant

### Client Desktop Nextcloud (Sync Auto)

**Windows/macOS/Linux** :
```
1. Télécharger : https://nextcloud.com/install/#install-clients
2. Installer (double-clic, Next Next Finish)
3. Configurer :
   - URL : https://cloud.mondomaine.com
   - Login : admin / password
4. Choisir dossiers à synchroniser :
   - Documents → Sync bidirectionnel (modifications sync)
   - Photos → Upload seulement (backup one-way)
   - Téléchargements → Ignorer (pas besoin)
5. Modifications automatiquement sync ✅
```

**Exemple d'usage** :
```
1. Modifier document sur PC portable
   → Client Nextcloud détecte changement
   → Upload vers Pi5 automatiquement

2. Ouvrir même document sur PC bureau
   → Client télécharge dernière version automatiquement
   → Toujours à jour ✅

C'est comme Dropbox, mais gratuit et privé !
```

### Éditer Documents en Ligne (Nextcloud Only)

**Installer Collabora** (Office en ligne) :
```bash
# Méthode 1 : Via interface web
1. Nextcloud → Apps → Office & text
2. Chercher "Collabora Online"
3. Cliquer "Enable"

# Méthode 2 : Via CLI
docker exec -u www-data nextcloud-app php occ app:install richdocuments

# Ou OnlyOffice (alternative)
docker exec -u www-data nextcloud-app php occ app:install onlyoffice
```

**Utiliser** :
```
1. Aller dans Nextcloud web
2. Créer nouveau fichier → Document
3. Éditeur Word-like s'ouvre dans navigateur
4. Éditer, sauvegarder, partager
5. Collaborer à plusieurs en temps réel ✅

Types de documents :
- Documents texte (.docx) → Comme Word
- Tableurs (.xlsx) → Comme Excel
- Présentations (.pptx) → Comme PowerPoint
```

**Collaborer** :
```
1. Partager document avec utilisateur (bouton Share)
2. Autoriser édition (Edit permission)
3. Les deux peuvent éditer en même temps
4. Curseurs colorés montrent qui édite quoi
5. Modifications visibles en temps réel

Comme Google Docs, mais privé !
```

### Calendrier et Contacts (Nextcloud Only)

**Activer** :
```bash
# Installer apps
docker exec -u www-data nextcloud-app php occ app:install calendar
docker exec -u www-data nextcloud-app php occ app:install contacts
```

**Utiliser** :
```
1. Nextcloud web → Icône calendrier (haut droite)
2. Créer événements, inviter participants
3. Synchroniser avec téléphone :
   - iOS : Réglages → Comptes → Ajouter compte → CalDAV/CardDAV
   - Android : App DAVx5 (gratuit Play Store)
4. Calendrier Pi5 sync avec calendrier natif téléphone

Plus besoin de Google Calendar !
```

### Partage Public (Lien de Téléchargement)

**FileBrowser** :
```
1. Sélectionner fichier/dossier
2. Bouton "Share" → Créer lien
3. Options :
   - Expiration : 7 jours (auto-suppression)
   - Mot de passe : optionnel (sécurité++)
4. Copier lien, envoyer par email/WhatsApp
5. Destinataire clique → Télécharge (sans compte)
```

**Nextcloud** :
```
1. Clic droit fichier/dossier → Share
2. Share link → Create public link
3. Options :
   - Set expiration date : 7 jours
   - Password protect : optionnel
   - Allow upload : Si vous voulez que d'autres uploadent
4. Copy link, partager

Bonus : Voir statistiques (combien de téléchargements)
```

---

## 🎓 Récapitulatif Final

### Ce que vous avez appris

| Sujet | ✅ |
|-------|-----|
| C'est quoi un cloud personnel | ✅ |
| Différence FileBrowser vs Nextcloud | ✅ |
| Comment ça marche (schéma) | ✅ |
| Quel stack choisir | ✅ |
| Sécurité (HTTPS, 2FA) | ✅ |
| 3 méthodes d'accès (DuckDNS, Cloudflare, VPN) | ✅ |
| Faire backup/restauration | ✅ |
| Résoudre problèmes courants | ✅ |
| Apps mobiles + client desktop | ✅ |
| Édition documents en ligne | ✅ |
| Calendrier/Contacts sync | ✅ |
| Partage public sécurisé | ✅ |

### Votre Cloud Personnel en Résumé

```
┌──────────────────────────────────────────────────────────┐
│  🏠 CLOUD PERSONNEL PI5                                  │
│                                                           │
│  ✅ Vos fichiers 100% chez vous                          │
│  ✅ Privacy totale (pas de Google/Dropbox)               │
│  ✅ HTTPS chiffré automatique                            │
│  ✅ Accessible partout (web + apps mobiles)              │
│  ✅ Sync automatique multi-appareils                     │
│  ✅ Gratuit (pas d'abonnement mensuel)                   │
│  ✅ Vous contrôlez tout                                  │
│                                                           │
│  💡 Simple • Sécurisé • Privacy-first                    │
└──────────────────────────────────────────────────────────┘
```

### Prochaines Étapes

**Débutant** :
1. ✅ Installer FileBrowser (simple)
2. ✅ Configurer DuckDNS (gratuit)
3. ✅ Uploader premiers fichiers
4. ✅ Partager lien avec famille
5. ✅ Faire premier backup manuel

**Intermédiaire** :
1. ✅ Migrer vers Nextcloud (plus de fonctionnalités)
2. ✅ Acheter domaine personnalisé (Cloudflare)
3. ✅ Installer apps mobiles (auto-upload photos)
4. ✅ Sync calendrier/contacts
5. ✅ Automatiser backups (cron)

**Avancé** :
1. ✅ Configurer Tailscale VPN (sécurité maximale)
2. ✅ Installer Collabora (édition documents)
3. ✅ Multi-utilisateurs (famille/équipe)
4. ✅ Reconnaissance faciale photos (Nextcloud)
5. ✅ Monitoring (Prometheus/Grafana)

---

## 📚 Ressources Utiles

### Documentation Officielle

- **FileBrowser** : https://filebrowser.org/
- **Nextcloud** : https://docs.nextcloud.com/
- **Traefik** : https://doc.traefik.io/traefik/
- **Docker** : https://docs.docker.com/

### Communautés Françaises

- **Forum Nextcloud FR** : https://help.nextcloud.com/c/francais/
- **Reddit /r/selfhosted** : https://reddit.com/r/selfhosted
- **Discord Homelab FR** : Chercher "Homelab France" sur Discord

### Tutoriels Vidéo

- **YouTube** : Chercher "Nextcloud Raspberry Pi 5 tuto FR"
- **Vidéos recommandées** :
  - "Installer Nextcloud sur Raspberry Pi" (Le Professeur d'Informatique)
  - "Self-hosted cloud complet" (Cocadmin)

---

<p align="center">
  <strong>🎓 Félicitations ! Vous maîtrisez votre Cloud Personnel 🎓</strong>
</p>

<p align="center">
  <sub>Simple • Sécurisé • 100% chez vous • Privacy-first</sub>
</p>

<p align="center">
  <sub>📝 Créé pour le projet PI5-SETUP - 2025</sub>
</p>
