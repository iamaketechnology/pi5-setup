# 🚀 Installation Pi-hole

> **Installation automatisée du bloqueur de publicités pour l'ensemble de votre réseau.**

---

## 📋 Prérequis

### Système
*   Raspberry Pi 5.
*   Docker et Docker Compose installés.

### Ressources
*   **RAM** : ~50 Mo
*   **Stockage** : ~100 Mo
*   **Ports** : 53 (DNS), 8088 (HTTP - si non utilisé).

---

## 🚀 Installation

### Installation Rapide (Recommandé)

Une seule commande pour déployer Pi-hole via Docker :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/pihole/scripts/01-pihole-deploy.sh | sudo bash
```

**Durée** : ~2-3 minutes

---

## 📊 Ce Que Fait le Script

1.  ✅ **Création de la structure** : Crée le dossier `/opt/stacks/pihole`.
2.  ✅ **Génération du Docker Compose** : Crée un fichier `docker-compose.yml` pour lancer Pi-hole.
3.  ✅ **Configuration de l'environnement** : Définit un mot de passe administrateur sécurisé et le stocke dans un fichier `.env`.
4.  ✅ **Déploiement** : Lance le conteneur Pi-hole.
5.  ✅ **Affichage du résumé** : Affiche l'adresse IP du Pi et le mot de passe administrateur pour que vous puissiez vous connecter.

---

## 🔧 Configuration Post-Installation

L'étape la plus importante est de configurer vos appareils pour qu'ils utilisent Pi-hole comme serveur DNS.

### Accès à l'Interface Web

*   **URL** : `http://<IP_DU_PI>/admin` (remplacez `<IP_DU_PI>` par l'adresse IP de votre Pi).
*   **Mot de passe** : Il est affiché à la fin de l'installation et stocké dans `/opt/stacks/pihole/.env`.

### Configuration du Réseau

La méthode recommandée est de configurer votre **routeur** (box Internet) pour qu'il distribue l'adresse IP de votre Pi comme unique serveur DNS à tous les appareils de votre réseau. Cela protège automatiquement tout appareil qui se connecte à votre Wi-Fi.

1.  Connectez-vous à l'interface de votre routeur.
2.  Trouvez les paramètres DNS (souvent dans la section DHCP ou LAN).
3.  Entrez l'adresse IP de votre Pi comme serveur DNS primaire.
4.  Sauvegardez et redémarrez votre routeur.

---

## ✅ Validation Installation

**Test 1** : Vérifier que le conteneur Pi-hole est en cours d'exécution.

```bash
cd /opt/stacks/pihole
docker compose ps
```

**Résultat attendu** : Le conteneur `pihole` doit être `Up (healthy)`.

**Test 2** : Vérifier que le blocage fonctionne.

1.  Connectez-vous au tableau de bord de Pi-hole.
2.  Sur un appareil configuré pour utiliser Pi-hole, visitez un site web connu pour ses publicités (ex: `forbes.com`).
3.  Observez le graphique "Total queries" sur le tableau de bord de Pi-hole. Le nombre de requêtes bloquées devrait augmenter.

---

## 🛠️ Maintenance

### Mettre à jour les listes de blocage

Pi-hole le fait automatiquement une fois par semaine. Pour forcer une mise à jour manuelle :

```bash
docker exec pihole pihole -g
```

### Mettre à jour Pi-hole

```bash
cd /opt/stacks/pihole
docker compose pull
docker compose up -d
```

---

## 🐛 Troubleshooting

### Problème 1 : L'interface web est inaccessible
*   **Symptôme** : La page `http://<IP_DU_PI>/admin` ne se charge pas.
*   **Solution** : Vérifiez que le conteneur Pi-hole est bien démarré avec `docker compose ps`. Si un autre service utilise le port 80 sur votre Pi, le conteneur Pi-hole pourrait ne pas démarrer. Le script d'installation tente d'utiliser un port alternatif comme 8088 dans ce cas.

### Problème 2 : Un site légitime est bloqué
*   **Symptôme** : Vous ne pouvez plus accéder à un site ou une application.
*   **Solution** : Connectez-vous à l'interface de Pi-hole, allez dans `Query Log`, trouvez le domaine qui a été bloqué, et cliquez sur `Whitelist`.

---

## 🗑️ Désinstallation

```bash
cd /opt/stacks/pihole
docker-compose down -v
cd /opt/stacks
sudo rm -rf pihole
```

N'oubliez pas de reconfigurer le DNS de votre routeur pour qu'il n'utilise plus l'adresse IP de votre Pi.

---

## 📊 Consommation Ressources

*   **RAM utilisée** : ~50 Mo. Pi-hole est extrêmement léger.
*   **CPU** : Moins de 1%.

---

## 🔗 Liens Utiles

*   [Guide Débutant](pihole-guide.md)
*   [Documentation Officielle de Pi-hole](https://docs.pi-hole.net/)
