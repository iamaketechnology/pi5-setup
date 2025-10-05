# 🎓 Guide Débutant - Serveur Média sur Pi5

> **Créez votre Netflix personnel - Expliqué simplement**

---

## Table des Matières
1. [C'est Quoi un Serveur Média ?](#1-cest-quoi-un-serveur-média-)
2. [Jellyfin vs *arr Stack : Différence](#2-jellyfin-vs-arr-stack--cest-quoi-la-différence-)
3. [Comment Ça Marche ?](#3-comment-ça-marche--expliqué-simplement)
4. [GPU Transcoding : C'est Quoi ?](#4-gpu-transcoding--cest-quoi--expliqué-sans-jargon)
5. [Cas d'Usage Réels](#5-cas-dusage-réels-débutants)
6. [Installation : Qu'est-ce Qui Se Passe ?](#6-installation--quest-ce-qui-se-passe-)
7. [Configuration Première Fois](#7-configuration-première-fois-pas-à-pas)
8. [Utilisation Quotidienne](#8-utilisation-quotidienne)
9. [Troubleshooting Débutant](#9-troubleshooting-débutant)
10. [Récapitulatif Final](#10-récapitulatif-final)

---

## 1. C'est Quoi un Serveur Média ?

### Serveur média = Netflix/Spotify chez vous

**Imaginez** :
```
❌ Netflix = Location films (9.99€/mois, catalogue limité)
✅ Jellyfin Pi5 = Votre vidéothèque personnelle (0€, illimitée)
```

C'est comme avoir une vidéothèque + lecteur DVD intelligent qui :
- 📚 Organise vos films automatiquement
- 🖼️ Affiche jolies affiches + résumés
- 🔖 Se souvient où vous en étiez
- 📱 Fonctionne sur TV, téléphone, tablette

### Pourquoi faire ça ?

| Avant (DVD/Fichiers) | Après (Serveur Média) |
|----------------------|------------------------|
| 📀 Chercher DVD dans placard | 🎬 Cliquer sur affiche |
| 📁 Fichiers "film1.mkv" sans info | 🖼️ Affiches + résumés + notes |
| 💾 Fichier sur PC, pas sur téléphone | 📱 Regarder partout (TV, mobile) |
| ❓ "C'était à quelle minute déjà ?" | 🔖 Reprend automatiquement |

---

## 2. Jellyfin vs *arr Stack : C'est Quoi la Différence ?

### Jellyfin (Lecteur)

```
Jellyfin = Le lecteur Blu-ray de votre salon
```

**C'est pour REGARDER** :
- 🎬 Films, séries, musique, photos
- 🖼️ Interface comme Netflix (jolies affiches)
- 📱 Apps sur TV, téléphone, tablette
- 🔖 Reprendre là où vous étiez

**Comme Netflix, mais** :
- ✅ Vos fichiers (pas location)
- ✅ 0€/mois
- ✅ Pas de limite
- ✅ Hors ligne (voyage, avion)

### *arr Stack (Gestion Automatique)

```
*arr = Robot bibliothécaire qui organise pour vous
```

**3 robots** :
- 🔍 **Prowlarr** = Chercheur (trouve où télécharger)
- 🎬 **Radarr** = Spécialiste films
- 📺 **Sonarr** = Spécialiste séries TV

**Ils font** :
- 🔎 Chercher films/séries
- ⬇️ Télécharger automatiquement
- ✏️ Renommer proprement (`Breaking.Bad.S01E01.mkv`)
- 📁 Organiser dans dossiers
- 🔔 Dire à Jellyfin "nouveau contenu !"

### Analogie Complète

```
Vous voulez regarder "Inception"

SANS *arr Stack (manuel) :
1. Chercher "Inception torrent" sur Google (10 min)
2. Télécharger (attendre)
3. Renommer fichier (Inception.2010.1080p.mkv)
4. Créer dossier /media/movies/Inception (2010)/
5. Déplacer fichier
6. Jellyfin scan
7. Regarder (enfin !)

AVEC *arr Stack (automatique) :
1. Radarr → Add Movie → "Inception" → Add
2. Regarder (tout le reste est automatique !)
```

---

## 3. Comment Ça Marche ? (Expliqué Simplement)

### Schéma Complet

```
Vous                    Pi5                     Internet
────                    ───                     ────────

📱 App Jellyfin    ──> 🎬 Jellyfin Server
(iOS/Android)           (Lit vidéos)
                              ↓
                        📁 /media/movies/
                        📁 /media/tv/
                              ↑
                        🎯 Radarr/Sonarr
                        (Télécharge + Organise)
                              ↑
                        🔍 Prowlarr  ──────>  🌐 Indexers
                        (Cherche)              (Sites torrents)
```

### Workflow Expliqué

#### Étape 1 : Vous voulez regarder "Inception"
```
Vous n'avez PAS le film encore
```

#### Étape 2 : Radarr cherche le film
```
Radarr → Prowlarr → "Cherche Inception 2010 en 1080p"
Prowlarr demande aux indexers (YTS, 1337x, etc.)
Résultat : "Trouvé ! Inception.2010.1080p.BluRay.mkv"
```

#### Étape 3 : Téléchargement automatique
```
Radarr → Client torrent (qBittorrent)
Download dans /downloads/movies/
```

#### Étape 4 : Radarr organise
```
Téléchargement terminé
Radarr renomme + déplace :

/downloads/movies/Inception.2010.1080p.BluRay.mkv
  ↓
/media/movies/Inception (2010)/Inception (2010) - 1080p.mkv
```

#### Étape 5 : Jellyfin trouve le film
```
Jellyfin scan /media/movies/
Trouve "Inception (2010)"
Télécharge affiche + résumé (TMDb)
Film apparaît dans votre bibliothèque
```

#### Étape 6 : Vous regardez !
```
Ouvrir app Jellyfin
→ Films
→ Inception (avec belle affiche)
→ Play
```

### Analogie Complète

```
C'est comme si vous disiez à votre bibliothécaire :
"Je veux ce livre"

→ Il va à la librairie (Internet)
→ Achète le livre (télécharge)
→ Range dans bonne étagère (organise)
→ Vous dit "C'est prêt !"
→ Vous lisez

Sauf que le bibliothécaire = Robot qui travaille 24/7 gratuit !
```

---

## 4. GPU Transcoding : C'est Quoi ? (Expliqué Sans Jargon)

### Le Problème

```
Vous avez un film 4K (très gros fichier, 50 Go)
Votre téléphone ne peut lire que 1080p
Votre connexion WiFi est lente
```

**Sans transcoding** : ❌ Impossible à regarder (trop gros, saccades)
**Avec transcoding** : ✅ Jellyfin convertit en direct 4K → 1080p

### Solution : Transcoding

```
Jellyfin convertit en direct :
4K (50 Go) → 1080p (5 Go) pendant que vous regardez

Comme un traducteur simultané qui traduit film japonais en français
pendant que vous le regardez (sans attendre sous-titres)
```

### GPU vs CPU

#### CPU (Processeur normal)
```
CPU = Ouvrier polyvalent (fait tout, mais rien de spécial)

Pour transcoding vidéo :
❌ Lent (peut prendre 2x temps réel)
❌ Consomme beaucoup d'énergie
❌ Pi5 chauffe (60-70°C)
❌ 1 seul film à la fois maximum
```

#### GPU (Puce graphique VideoCore VII)
```
GPU = Ouvrier SPÉCIALISÉ vidéo (fait QUE ça, mais TRÈS bien)

Pour transcoding vidéo :
✅ TRÈS rapide (5-10x plus rapide que CPU)
✅ Économise énergie (50% moins)
✅ Pi5 reste froid (40-50°C)
✅ 2-3 films en même temps
```

### Pi5 VideoCore VII (GPU Intégré)

```
VideoCore VII = Puce spéciale vidéo dans Raspberry Pi 5

Peut convertir en direct :
✅ 4K → 1080p (2-3 films en même temps)
✅ 1080p → 720p (plusieurs films)
✅ H.264, H.265/HEVC (formats modernes)

Comme avoir mini-carte graphique de PC gaming, mais pour vidéo
```

### Exemple Concret

```
Famille regarde films en même temps :

Papa (TV salon) : Film 4K → 1080p (TV vieille)
Maman (iPad) : Série 1080p → 720p (WiFi lent)
Enfant (téléphone) : Dessin animé 1080p → 480p (petit écran)

SANS GPU : ❌ Impossible (Pi5 plante)
AVEC GPU : ✅ Tout marche, Pi5 à 50°C seulement
```

---

## 5. Cas d'Usage Réels (Débutants)

### Scénario 1 : Famille (Collection DVD)

#### Situation
Vous avez 50 DVD qui prennent la poussière dans placard

#### Solution

**Étape 1 : Ripper DVD → Fichiers**
```
Logiciel : MakeMKV (gratuit pendant beta)
1. Insérer DVD dans lecteur PC
2. MakeMKV → Rip
3. Résultat : Film.mkv (5-8 Go)
4. Répéter pour 50 DVD
```

**Étape 2 : Copier sur Pi5**
```
Copier les 50 fichiers .mkv dans :
/home/pi/media/movies/

Exemple :
/home/pi/media/movies/Inception (2010).mkv
/home/pi/media/movies/Interstellar (2014).mkv
...
```

**Étape 3 : Jellyfin scan**
```
Jellyfin → Dashboard → Scan Library
→ 50 films apparaissent avec belles affiches
```

**Étape 4 : Regarder**
```
TV salon (app Jellyfin Android TV)
→ Films → Inception → Play
```

#### Avantages
- ✅ Plus besoin chercher DVD dans placard
- ✅ Voir affiches, résumés, notes IMDb
- ✅ Reprendre où vous étiez
- ✅ Sous-titres si besoin (télécharger .srt)
- ✅ DVD restent intacts (backup)

---

### Scénario 2 : Série TV (Suivre Breaking Bad)

#### Situation
Vous voulez regarder Breaking Bad (5 saisons, 62 épisodes)

#### Avec Sonarr (Automatique)

**Étape 1 : Ajouter série**
```
Sonarr → Series → Add New Series
1. Chercher : "Breaking Bad"
2. Résultats : Breaking Bad (2008) - 5 saisons
3. Monitor : All Episodes
4. Search now : Yes
5. Add Series
```

**Étape 2 : Sonarr travaille (vous faites RIEN)**
```
Sonarr cherche TOUS les épisodes (62)
→ Télécharge automatiquement (peut prendre 1-2 jours selon connexion)
→ Organise :
  /media/tv/Breaking Bad/Season 01/Breaking.Bad.S01E01.mkv
  /media/tv/Breaking Bad/Season 01/Breaking.Bad.S01E02.mkv
  ...
  /media/tv/Breaking Bad/Season 05/Breaking.Bad.S05E16.mkv
```

**Étape 3 : Jellyfin trouve série**
```
Jellyfin scan /media/tv/
→ Breaking Bad apparaît (5 saisons, 62 épisodes)
→ Affiches + résumés chaque épisode
```

**Étape 4 : Regarder**
```
Jellyfin → Series → Breaking Bad
→ Season 1 → Episode 1 → Play
→ Jellyfin se souvient : "S01E02 prochain"
```

#### Utilisation Après (Nouveaux Épisodes)

```
Nouveau épisode sort (ex: saison 6 annoncée)

Sonarr détecte automatiquement
→ Télécharge dès sortie
→ Vous recevez notification (si configuré)
→ Épisode dans Jellyfin le lendemain matin

Vous faites RIEN ! Robot travaille pour vous.
```

---

### Scénario 3 : Voyage (Hors Ligne)

#### Situation
Voyage en avion (pas de WiFi)

#### Solution

**Avant voyage** (chez vous, WiFi) :
```
1. Ouvrir app Jellyfin mobile (iOS/Android)
2. Films → Inception → ⬇️ Download
3. Films → Interstellar → ⬇️ Download
4. Films téléchargés sur téléphone (stockage local)
```

**Pendant vol** (mode avion) :
```
→ Mode avion activé (pas de réseau)
→ App Jellyfin → Films téléchargés
→ Inception → Play
→ Regarder hors ligne (comme si vous étiez chez vous)
```

#### Comme Netflix, mais

| Netflix | Jellyfin Pi5 |
|---------|--------------|
| ❌ Limite 100 films téléchargés | ✅ Illimité (tant que stockage téléphone) |
| ❌ Films expirent après 30 jours | ✅ Jamais d'expiration |
| ❌ Catalogue limité (pas tous films) | ✅ VOS films (ce que VOUS voulez) |

---

### Scénario 4 : Enfants (Profils Séparés)

#### Situation
Protéger enfants de contenu adulte (films violents, horreur)

#### Solution

**Jellyfin → Utilisateurs** :

**Profil 1 : Papa**
```
Dashboard → Users → Add User : "Papa"
- Libraries : Tous films (Films, Séries TV)
- Parental Control : None
→ Voit TOUT (même films adultes)
```

**Profil 2 : Enfants**
```
Dashboard → Users → Add User : "Enfants"
- Libraries : Films uniquement
- Parental Control : Max Rating = PG (Tous publics)
- Block unrated content : Yes
→ Voient SEULEMENT dessins animés + films famille
```

**Utilisation** :

```
Enfants ouvrent app Jellyfin :
1. Choisir profil "Enfants"
2. Mot de passe (optionnel)
3. Voir SEULEMENT :
   - Toy Story
   - Le Roi Lion
   - Vaiana
   - (PAS de films adultes/violents)

Papa ouvre app :
1. Profil "Papa"
2. Voir TOUT (films famille + adultes)
```

**Comme Netflix Kids Mode**, mais :
- ✅ Plus de contrôle (vous décidez exactement quoi)
- ✅ Pas de "recommandations" bizarres

---

## 6. Installation : Qu'est-ce Qui Se Passe ?

### Jellyfin (Simple - 10 minutes)

#### Ce que fait le script

```
1️⃣ Crée dossiers médias
   /home/pi/media/movies/
   /home/pi/media/tv/
   /home/pi/media/music/
   /home/pi/media/photos/

2️⃣ Télécharge Jellyfin (Docker image)
   Image : jellyfin/jellyfin:latest (~500 Mo)

3️⃣ Active GPU Pi5 (VideoCore VII)
   Ajoute utilisateur 'pi' aux groupes :
   - video (accès GPU)
   - render (transcoding GPU)

4️⃣ Configure accès
   - Port : 8096 (http://IP_PI:8096)
   - HTTPS : via Traefik (si installé)

5️⃣ Démarre Jellyfin
   docker compose up -d

6️⃣ Affiche URL d'accès
   http://192.168.1.XXX:8096

⏱️ Durée : ~10 minutes
```

#### Analogie
```
C'est comme installer app Netflix sur votre TV,
mais l'app est sur le Pi (pas dans cloud Netflix)
```

---

### *arr Stack (Moyen - 10 minutes)

#### Ce que fait le script

```
1️⃣ Crée dossier downloads
   /home/pi/downloads/movies/
   /home/pi/downloads/tv/

2️⃣ Télécharge 3 images Docker :
   - Prowlarr (chercheur) ~200 Mo
   - Radarr (films) ~150 Mo
   - Sonarr (séries) ~150 Mo

3️⃣ Configure chemins
   Les 3 services voient :
   - /media/movies/ (partage avec Jellyfin)
   - /media/tv/
   - /downloads/

4️⃣ Démarre les 3 services
   docker compose up -d

5️⃣ Affiche 3 URLs
   - Prowlarr : http://IP_PI:9696
   - Radarr : http://IP_PI:7878
   - Sonarr : http://IP_PI:8989

⏱️ Durée : ~10 minutes
```

#### Analogie
```
C'est comme embaucher 3 robots bibliothécaires qui travaillent 24/7
Vous leur donnez ordres via leur "bureau" (URLs)
```

---

## 7. Configuration Première Fois (Pas à Pas)

### Jellyfin (5 étapes)

#### Étape 1 : Ouvrir Jellyfin
```
http://IP_PI:8096
(ou https://jellyfin.votredomaine.com si Traefik)

Exemple : http://192.168.1.50:8096
```

#### Étape 2 : Créer compte admin
```
Écran "Welcome to Jellyfin"

- Username : admin (ou votre nom)
- Password : Choisir mot de passe fort
- Confirm Password : Répéter

Next
```

#### Étape 3 : Ajouter bibliothèque Films
```
Dashboard → Libraries → Add Library

- Content type : Movies
- Display name : Films
- Folders : Click "+" → /media/movies
- Preferred language : French
- Country : France

Next → Next → Finish
```

#### Étape 4 : Ajouter bibliothèque Séries
```
Add Library

- Content type : Shows
- Display name : Séries TV
- Folders : /media/tv
- Language : French

Finish
```

#### Étape 5 : Copier des films

**Option A : Via réseau (Windows)** :
```
1. Ouvrir Explorateur Windows
2. Barre adresse : \\IP_PI\media\movies
3. Copier fichiers .mkv/.mp4
4. Attendre copie terminée
```

**Option B : Via SSH** :
```bash
scp Film.mkv pi@IP_PI:/home/pi/media/movies/
```

**Jellyfin scan** :
```
Dashboard → Libraries → Films → Scan Library
→ Films apparaissent avec affiches !
```

---

### *arr Stack (Configuration Prowlarr → Radarr/Sonarr)

#### Étape 1 : Prowlarr (Indexers)

**Ouvrir Prowlarr** :
```
http://IP_PI:9696
```

**Ajouter indexers** :
```
Settings → Indexers → Add Indexer

Indexer 1 : YTS
- Name : YTS
- URL : (auto-rempli)
- Categories : Movies
- Test → Save

Indexer 2 : 1337x
- Name : 1337x
- Categories : Movies, TV
- Test → Save

Indexer 3 : The Pirate Bay (backup)
- Test → Save
```

**Résultat** :
```
3 indexers actifs (pastilles vertes)
```

---

#### Étape 2 : Radarr (Films)

**Ouvrir Radarr** :
```
http://IP_PI:7878
```

**Configurer dossier films** :
```
Settings → Media Management → Root Folders

Add Root Folder :
- Path : /movies
  (C'est /media/movies dans le conteneur Docker)

Save
```

**Copier API Key** :
```
Settings → General → Security

API Key : 1234567890abcdef... (copier ce texte)
```

---

#### Étape 3 : Sonarr (Séries)

**Ouvrir Sonarr** :
```
http://IP_PI:8989
```

**Configurer dossier séries** :
```
Settings → Media Management → Root Folders

Add Root Folder :
- Path : /tv

Save
```

**Copier API Key** :
```
Settings → General → Security

API Key : abcdef1234567890... (copier)
```

---

#### Étape 4 : Connecter Prowlarr aux apps

**Prowlarr → Apps** :
```
Settings → Apps → Add Application

Application 1 : Radarr
- Name : Radarr
- Sync Level : Full Sync
- Prowlarr Server : http://radarr:7878
- Radarr Server : http://radarr:7878
- API Key : [coller API Key Radarr étape 2]
- Test → Save

Application 2 : Sonarr
- Name : Sonarr
- Sync Level : Full Sync
- Prowlarr Server : http://sonarr:8989
- API Key : [coller API Key Sonarr étape 3]
- Test → Save
```

---

#### Étape 5 : Sync

```
Prowlarr → Settings → Apps → Sync

→ Les indexers (YTS, 1337x, TPB) sont ajoutés automatiquement
  à Radarr et Sonarr

Vérifier :
- Radarr → Settings → Indexers (doit afficher 3 indexers)
- Sonarr → Settings → Indexers (doit afficher 3 indexers)
```

**C'est fait !** Les 3 services parlent ensemble maintenant.

---

## 8. Utilisation Quotidienne

### Ajouter un Film (Radarr)

```
Radarr → Movies → Add New Movie

1. Barre de recherche : "Inception"

2. Résultats :
   Inception (2010) - Christopher Nolan
   ⭐ 8.8/10 - Sci-Fi, Action

3. Cliquer sur le film

4. Options :
   - Monitor : Yes (surveiller téléchargement)
   - Quality Profile : HD-1080p
   - Root Folder : /movies
   - Search on add : Yes (chercher immédiatement)

5. Add Movie

→ Radarr cherche automatiquement sur indexers
→ Télécharge meilleure version (1080p BluRay)
→ Déplace vers /media/movies/Inception (2010)/
→ Jellyfin le trouve dans 1-2 minutes
```

**Suivi** :
```
Radarr → Activity → Queue
→ Voir progression téléchargement
→ "Inception (2010) - 45% - 2.3 GB / 5.1 GB"
```

---

### Ajouter une Série (Sonarr)

```
Sonarr → Series → Add New Series

1. Chercher : "Breaking Bad"

2. Résultats :
   Breaking Bad (2008)
   ⭐ 9.5/10 - 5 Seasons, 62 Episodes

3. Options :
   - Monitor : All Episodes (tous épisodes)
   - Season Folder : Yes (dossier par saison)
   - Quality : HD-1080p
   - Search on add : Yes

4. Add Series

→ Sonarr cherche TOUS les épisodes (62)
→ Télécharge séquentiellement
→ Organise : /media/tv/Breaking Bad/Season 01/Breaking.Bad.S01E01.mkv
→ Jellyfin affiche série complète (au fur et à mesure)
```

**Suivi nouveaux épisodes** :
```
Sonarr surveille automatiquement les nouvelles saisons

Si saison 6 annoncée :
→ Sonarr détecte
→ Télécharge nouveaux épisodes dès sortie
→ Vous recevez notification (optionnel)
```

---

### Regarder (Jellyfin)

#### Sur TV (Android TV, Fire TV, Roku)

```
1. TV → App Store
2. Chercher "Jellyfin"
3. Installer (gratuit)
4. Ouvrir app

5. Add Server :
   - Server : http://192.168.1.50:8096
     (ou https://jellyfin.votredomaine.com)

6. Login :
   - Username : admin
   - Password : votre mot de passe

7. Films → Inception → Play
```

---

#### Sur Téléphone (iOS/Android)

```
1. App Store / Play Store
2. Chercher "Jellyfin"
3. Installer (gratuit)

4. Ouvrir app

5. Connect to Server :
   - Server Address : https://jellyfin.votredomaine.com

6. Login

7. Regarder :
   - Films → Inception → Play
   - Download (pour hors ligne)
```

---

#### Sur PC (Navigateur)

```
1. Navigateur (Chrome, Firefox, Safari)
2. http://IP_PI:8096
3. Login
4. Films → Play

Ou :
1. Télécharger Jellyfin Media Player (app desktop)
2. Meilleure qualité (support GPU PC)
```

---

## 9. Troubleshooting Débutant

### Problème 1 : "Jellyfin ne trouve pas mes films"

#### Causes possibles

**Cause 1 : Mauvais dossier**
```
❌ Fichiers dans : /home/pi/media/
✅ Fichiers dans : /home/pi/media/movies/

Jellyfin cherche dans /media/movies/, pas /media/
```

**Cause 2 : Mauvais nom fichier**
```
❌ Mauvais : film1.mkv, movie.avi, test.mp4
✅ Bon : Inception (2010).mkv, Interstellar (2014).mkv

Jellyfin a besoin du TITRE + ANNÉE pour identifier
```

**Cause 3 : Pas de scan**
```
Jellyfin ne détecte PAS automatiquement nouveaux films

Solution :
Dashboard → Libraries → Films → Scan Library

Ou activer scan auto :
Dashboard → Scheduled Tasks → Scan Media Library
→ Every 12 hours
```

#### Solution pas à pas

```bash
# Vérifier fichiers existent
ls /home/pi/media/movies/
# Doit afficher : Inception (2010).mkv, etc.

# Vérifier permissions
ls -la /home/pi/media/movies/
# pi doit être propriétaire (pi:pi)

# Forcer scan
Jellyfin → Dashboard → Scan Library
```

---

### Problème 2 : "GPU transcoding ne marche pas"

#### Vérifier GPU existe

```bash
ls /dev/dri/
# Doit afficher : renderD128

# Si vide, GPU pas détecté (problème hardware)
```

#### Vérifier utilisateur dans bon groupe

```bash
groups pi
# Doit contenir : pi video render

# Si "video" ou "render" manquant :
sudo usermod -aG video,render pi

# Redémarrer session
sudo reboot
```

#### Vérifier Jellyfin utilise GPU

```
Jellyfin → Dashboard → Playback → Transcoding

Hardware acceleration : Video Acceleration API (VAAPI)
VA-API Device : /dev/dri/renderD128

Enable hardware encoding : Yes

Save
```

#### Tester

```
1. Regarder film 4K sur téléphone (force transcoding)
2. Dashboard → Activity → Now Playing
3. Vérifier : "(hw)" dans info transcoding

Exemple : "Transcoding (hw): 4K → 1080p"
```

---

### Problème 3 : "Radarr ne télécharge rien"

#### Checklist

**1. Indexers configurés ?**
```
Prowlarr → Indexers

Au moins 1 indexer actif (pastille verte)
Si rouge : Test failed → Vérifier connexion Internet
```

**2. Prowlarr connecté à Radarr ?**
```
Prowlarr → Settings → Apps

Radarr doit être présent (pastille verte)
Si rouge : Vérifier API Key correct
```

**3. Client torrent configuré ?**
```
Radarr → Settings → Download Clients

Ajouter qBittorrent / Transmission :
- Host : localhost (ou IP Pi)
- Port : 8080 (qBittorrent) ou 9091 (Transmission)
- Username/Password : (si configuré)

Test → Save
```

**4. Recherche manuelle**
```
Radarr → Movies → Inception

Manual Search → Voir résultats ?

Si résultats vides :
→ Problème indexers (aucun résultat trouvé)
→ Vérifier Prowlarr → Indexers (au moins 1 actif)

Si résultats présents mais pas téléchargement :
→ Problème download client
→ Vérifier Radarr → Settings → Download Clients
```

---

### Problème 4 : "Jellyfin accessible localement, pas depuis Internet"

#### Vérifier Traefik

```bash
# Traefik est installé ?
docker ps | grep traefik

# Si vide, installer Traefik :
cd /home/pi/stacks/traefik
docker compose up -d
```

#### Vérifier DNS

```
Votre domaine (ex: jellyfin.example.com)
doit pointer vers IP publique de votre box Internet

1. Trouver IP publique :
   https://whatismyip.com
   Exemple : 90.123.45.67

2. Configurer DNS :
   jellyfin.example.com → A record → 90.123.45.67

3. Attendre propagation DNS (5-30 minutes)
```

#### Vérifier port forwarding (box Internet)

```
Box Internet doit rediriger ports 80 et 443 vers Pi

Exemple (interface box) :
- Port externe : 80 → IP Pi (192.168.1.50) : 80
- Port externe : 443 → IP Pi : 443
```

#### Tester

```
Depuis téléphone (4G, pas WiFi) :
https://jellyfin.example.com

Si ça marche : ✅ Tout bon
Si timeout : ❌ Port forwarding ou DNS
```

---

### Problème 5 : "Film téléchargé mais pas dans Jellyfin"

#### Vérifier Radarr a déplacé fichier

```
Radarr → Movies → Inception

Status : Downloaded ✅

Path : /movies/Inception (2010)/Inception (2010) - 1080p.mkv
```

#### Vérifier fichier existe côté Pi

```bash
ls /home/pi/media/movies/Inception\ \(2010\)/
# Doit afficher : Inception (2010) - 1080p.mkv
```

#### Scanner Jellyfin

```
Jellyfin → Dashboard → Libraries → Films → Scan Library

Ou :
Dashboard → Scheduled Tasks → Scan Media Library → Run Now
```

#### Vérifier logs Jellyfin

```bash
# Logs Jellyfin
docker logs jellyfin

# Chercher erreurs :
# "Error scanning /media/movies/..."
```

---

## 10. Récapitulatif Final

### Ce que vous avez appris

| Sujet | Compris | Testé |
|-------|---------|-------|
| C'est quoi serveur média | ✅ | ✅ |
| Différence Jellyfin vs *arr | ✅ | ✅ |
| Comment ça marche (workflow complet) | ✅ | ✅ |
| GPU transcoding expliqué | ✅ | ✅ |
| Configuration première fois | ✅ | ✅ |
| Ajouter films/séries | ✅ | ✅ |
| Regarder sur TV/téléphone | ✅ | ✅ |
| Résoudre problèmes courants | ✅ | ✅ |

### Vous pouvez maintenant

- 🎬 **Regarder films comme sur Netflix**
  - Interface moderne (affiches, résumés)
  - Reprendre où vous étiez
  - Apps natives (TV, téléphone)

- 📺 **Suivre séries automatiquement**
  - Ajouter série → Tout téléchargé automatiquement
  - Nouveaux épisodes détectés et téléchargés
  - Organisation parfaite (saisons, épisodes)

- 📱 **Apps mobiles**
  - iOS, Android
  - Android TV, Fire TV, Roku
  - Hors ligne (téléchargement)

- 🎮 **GPU Pi5 pour transcoding**
  - 2-3 films en même temps
  - Économie énergie
  - Qualité adaptée automatiquement

- 🤖 **Automatisation complète**
  - Prowlarr trouve
  - Radarr/Sonarr télécharge
  - Jellyfin affiche
  - Vous regardez !

### Prochaines étapes (optionnel)

#### Niveau 2 : Améliorer

- 📖 **Sous-titres automatiques** (Bazarr)
- 🎵 **Musique** (Lidarr + Jellyfin Music)
- 📚 **Livres audio** (Readarr + Audiobookshelf)
- 🔔 **Notifications** (Gotify, Telegram)

#### Niveau 3 : Avancé

- 🌐 **Accès distant sécurisé** (Tailscale VPN)
- 📊 **Monitoring** (Grafana + Prometheus)
- 💾 **Backup automatique** (Duplicati)
- 🎨 **Personnalisation** (thèmes Jellyfin)

---

## Ressources Utiles

### Documentation Officielle

- **Jellyfin** : https://jellyfin.org/docs/
- **Radarr** : https://wiki.servarr.com/radarr
- **Sonarr** : https://wiki.servarr.com/sonarr
- **Prowlarr** : https://wiki.servarr.com/prowlarr

### Communautés Francophones

- **Reddit** : r/jellyfin, r/radarr, r/sonarr
- **Discord** : Jellyfin FR, Servarr FR
- **Forums** : https://forum.jellyfin.org/

### Tutoriels Vidéo (YouTube)

Chercher : "Jellyfin Raspberry Pi 5 setup"

---

<p align="center">
  <strong>🎓 Félicitations ! Vous avez votre Netflix Personnel 🎓</strong>
</p>

<p align="center">
  <sub>Simple • Automatisé • Apps Natives • 100% Gratuit • 0€/mois</sub>
</p>

---

**Note** : Ce guide est pour débutants. Pour configurations avancées, consultez documentation officielle de chaque service.

**Avertissement Légal** : Assurez-vous de respecter les lois sur le droit d'auteur de votre pays. Ce guide est à but éducatif uniquement. Utilisez uniquement pour contenu que vous possédez légalement (DVD rippés, contenu libre de droits, etc.).
