Parfait 👍 faisons un **README pour la Semaine 1** que tu pourras ajouter à ton dépôt GitHub `pi5-setup`.
Ça servira de **documentation claire + pas-à-pas** pour toi (et tes futurs Pi5).

---

# 📘 `WEEK1.md`

````markdown
# 🟢 Semaine 1 – Configuration de base Raspberry Pi 5

🎯 Objectif : transformer un **Raspberry Pi 5 (16 Go)** en **mini-serveur sécurisé et prêt pour Docker**, avec **Portainer** pour gérer les conteneurs.

---

## ✅ Étape 1 – Préparer la microSD (sur Mac/PC)

1. Installer **Raspberry Pi Imager**.  
2. Choisir :
   - Device → *Raspberry Pi 5*
   - OS → *Raspberry Pi OS Lite (64-bit)*
   - Storage → carte microSD
3. Dans ⚙️ (options avancées) :
   - Hostname : `pi5.local`
   - Enable SSH ✔
   - Username : `pi`
   - Password : mot de passe fort
   - Wi-Fi : SSID + mot de passe (si pas Ethernet)
   - Locale : `Europe/Paris`, clavier `fr`
4. Flash → insérer la carte → démarrer le Pi.

---

## ✅ Étape 2 – Connexion en SSH

Depuis ton Mac/PC :

```bash
ssh pi@pi5.local
````

👉 Si ça échoue, utilise l’IP trouvée sur ta box :

```bash
ssh pi@192.168.X.XX
```

---

## ✅ Étape 3 – Mise à jour de l’OS

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

Reconnecte-toi ensuite :

```bash
ssh pi@pi5.local
```

⚠️ Si Debian demande `initramfs.conf (Y/I/N/O/D/Z)` → choisis **Y** (prendre la version mainteneur).

---

## ✅ Étape 4 – Installer Docker + Portainer + Sécurité

Depuis ton Pi :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week1.sh -o setup-week1.sh \
&& chmod +x setup-week1.sh \
&& sudo MODE=beginner ./setup-week1.sh
```

Le script installe :

* Docker + Compose
* Portainer ([http://PI:9000](http://PI:9000))
* UFW (pare-feu)
* Fail2ban (anti-bruteforce SSH)
* Mises à jour auto

---

## ✅ Étape 5 – Ajouter ton user au groupe Docker

```bash
sudo usermod -aG docker pi
exit
ssh pi@pi5.local
```

Vérifie que Docker fonctionne :

```bash
docker run --rm hello-world
```

---

## ✅ Étape 6 – Configurer Portainer

Si tu vois le message *“New installation timed out”* → redémarre :

```bash
docker restart portainer
```

Puis ouvre dans ton navigateur :

* [http://192.168.X.XX:9000](http://192.168.X.XX:9000)
* ou [https://192.168.X.XX:9443](https://192.168.X.XX:9443)

👉 Crée un compte **admin**, choisis “Local environment”.

---

## ✅ Vérifications finales

```bash
docker run --rm hello-world       # Docker OK
sudo ufw status                   # Pare-feu actif
sudo fail2ban-client status       # Fail2ban actif
```

---

# 📦 Résultat

Ton Pi est maintenant :

* **À jour et sécurisé**
* **Docker installé et fonctionnel**
* **Portainer prêt pour gérer tes conteneurs**

👉 Tu peux passer à la **Semaine 2 : Supabase self-hosted** 🚀

```

---

👉 Veux-tu que je le sauvegarde directement comme fichier `WEEK1.md` prêt à **ajouter dans ton dépôt GitHub** (avec la commande `git add && git commit && git push`), ou que je t’explique comment le créer toi-même avec `nano` ?
```
