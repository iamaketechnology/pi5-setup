# ⚡ Installation Rapide - Navidrome

> **Installation directe via SSH**

---

## 🚀 Installation en 1 Commande

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/navidrome/scripts/01-navidrome-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ Navidrome (serveur de streaming musical)

**Durée :** ~3 minutes

---

## ✅ Vérification Installation

### Vérifier le service
```bash
cd ~/stacks/navidrome
docker compose ps
# Le service doit être "Up"
```

### Accéder à l'interface web
L'URL dépend de votre configuration Traefik :
- **Avec Traefik (Cloudflare)** : `https://music.VOTRE-DOMAINE.com`
- **Avec Traefik (DuckDNS)** : `https://VOTRE-SOUS-DOMAINE.duckdns.org/music`
- **Sans Traefik** : `http://<IP-DU-PI>:4533`

L'URL exacte est affichée à la fin du script d'installation.

---

## ⚙️ Configuration Initiale

1.  **Préparez votre musique** : Navidrome a besoin d'un dossier contenant vos fichiers musicaux (MP3, FLAC, etc.). Placez votre musique sur votre Pi, par exemple dans `/home/pi/data/music`.

2.  **Ouvrez l'interface web** de Navidrome pour la première fois.

3.  Il vous sera demandé de **créer un utilisateur administrateur**. Choisissez un nom d'utilisateur et un mot de passe solide.

4.  Une fois connecté, Navidrome commencera automatiquement à scanner le dossier de musique que le script d'installation a configuré (`/home/pi/data/music`).

5.  **Soyez patient !** Le premier scan peut prendre beaucoup de temps si votre bibliothèque est volumineuse. Vous pouvez voir la progression dans le menu **"Activity"**.

---

## 📱 Utiliser les applications mobiles

Navidrome est compatible avec l'API **Subsonic**, ce qui signifie que vous pouvez utiliser de nombreuses applications mobiles pour écouter votre musique.

Quelques applications populaires :
- **iOS** : `substreamer`, `play:Sub`
- **Android** : `DSub`, `Subsonic Music Streamer`, `Ultrasonic`

**Configuration d'un client Subsonic :**
1.  Téléchargez une application compatible.
2.  Dans les paramètres du serveur, entrez :
    -   **Adresse du serveur** : L'URL de votre Navidrome (ex: `https://music.votre-domaine.com`).
    -   **Nom d'utilisateur** : Votre nom d'utilisateur Navidrome.
    -   **Mot de passe** : Votre mot de passe Navidrome.
3.  L'application se synchronisera avec votre serveur, et vous aurez accès à toute votre musique sur votre téléphone, avec la possibilité de la télécharger pour une écoute hors ligne.

---

## 📚 Documentation Complète

- [Guide Débutant](navidrome-guide.md) - Pour découvrir comment profiter au mieux de votre serveur musical personnel.
- [README.md](README.md) - Vue d'ensemble du stack.
