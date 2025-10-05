# 📚 Guide Débutant - Pi-hole

> **Pour qui ?** Toute personne voulant bloquer les publicités sur son réseau.
> **Durée de lecture** : 10 minutes
> **Niveau** : Débutant

---

## 🤔 C'est quoi Pi-hole ?

### En une phrase
**Pi-hole = Un videur pour votre connexion internet qui bloque les publicités avant qu'elles n'arrivent sur vos appareils.**

### Analogie simple
Imaginez que votre connexion internet est une autoroute. Les publicités sont des voitures indésirables qui essaient de se faufiler dans le trafic pour arriver jusqu'à chez vous (votre téléphone, votre ordinateur, votre TV).

Pi-hole est un **péage intelligent** que vous installez à l'entrée de votre réseau. Quand une voiture "publicité" se présente, Pi-hole lui refuse l'accès. Les voitures légitimes (le contenu que vous voulez voir) passent sans problème.

**Résultat** : Moins de pubs, une navigation plus rapide et plus sécurisée.

---

## 🎯 À quoi ça sert concrètement ?

- **Bloquer les publicités PARTOUT** : Sur votre PC, Mac, smartphone, tablette, et même votre Smart TV.
- **Bloquer les trackers** : Empêche les entreprises de vous pister sur internet.
- **Améliorer la vitesse de navigation** : Moins de contenu à charger = pages plus rapides.
- **Protéger contre les sites malveillants** : Bloque l'accès aux domaines connus pour distribuer des malwares.

### Exemples concrets

- **YouTube sur la TV** : Fini les coupures pub au milieu de vos vidéos.
- **Sites d'actualités** : Lisez les articles sans être envahi de bannières publicitaires.
- **Jeux mobiles** : Réduit les pubs qui apparaissent entre les niveaux.
- **Protection familiale** : Bloque l'accès à des contenus inappropriés (listes de blocage personnalisables).

---

## 🚀 Comment l'utiliser ? (Pas à pas)

### Étape 1 : Installer Pi-hole

C'est déjà fait avec la commande d'installation !

### Étape 2 : Trouver l'IP de votre Pi

```bash
hostname -I | awk '{print $1}'
```
→ Notez cette adresse IP (ex: `192.168.1.100`)

### Étape 3 : Configurer votre réseau

C'est l'étape la plus importante. Vous devez dire à vos appareils d'utiliser Pi-hole comme "annuaire" (serveur DNS).

**Option A : Configurer votre routeur (recommandé)**

1.  **Connectez-vous à l'interface de votre box internet** (Freebox, Livebox, etc.).
2.  **Trouvez les paramètres DNS** (souvent dans "Réseau", "LAN" ou "DHCP").
3.  **Entrez l'adresse IP de votre Pi** comme **unique** serveur DNS.
4.  **Sauvegardez et redémarrez votre box**.

✅ **Avantage** : Tous les appareils qui se connectent à votre WiFi sont automatiquement protégés, sans aucune configuration sur chaque appareil.

**Option B : Configurer un appareil spécifique**

Si vous ne voulez protéger qu'un seul appareil (par exemple, votre ordinateur) :

-   **Sur Windows** : Paramètres > Réseau et Internet > Modifier les options de l'adaptateur > Clic droit sur votre connexion > Propriétés > Protocole Internet version 4 (TCP/IPv4) > Propriétés > Utiliser l'adresse de serveur DNS suivante.
-   **Sur macOS** : Préférences Système > Réseau > Avancé... > DNS > Cliquer sur '+' pour ajouter l'IP du Pi.
-   **Sur Android/iOS** : Paramètres WiFi > Votre réseau > Configurer le DNS > Manuel.

### Étape 4 : Vérifier que ça fonctionne

1.  **Accédez à l'interface de Pi-hole** :
    `http://<IP-DU-PI>:8888/admin`

2.  **Connectez-vous** (le mot de passe a été donné à la fin de l'installation).

3.  **Naviguez sur internet** sur un appareil protégé. Vous devriez voir les chiffres sur le dashboard de Pi-hole augmenter ("Total Queries", "Queries Blocked").

4.  Visitez un site connu pour avoir beaucoup de publicités (ex: `speedtest.net`). La page devrait être beaucoup plus propre.

---

## 🔧 Commandes Utiles

### Changer le mot de passe admin
```bash
docker exec -it pihole pihole -a -p
```

### Mettre à jour les listes de blocage
```bash
docker exec -it pihole pihole -g
```

### Voir les logs en direct
```bash
docker logs -f pihole
```

---

## 🆘 Problèmes Courants

### "Un site ne fonctionne plus correctement"

**Cause** : Pi-hole bloque peut-être un domaine légitime dont le site a besoin.

**Solution** : Mettre le domaine en liste blanche.
1.  Dans l'interface Pi-hole, allez dans "Query Log".
2.  Trouvez la ligne correspondant au domaine bloqué (en rouge).
3.  Cliquez sur le bouton "Whitelist".
4.  Le site devrait fonctionner après quelques secondes.

### "Je vois toujours des pubs sur YouTube/Facebook"

**Cause** : Certaines plateformes (comme YouTube) servent les publicités depuis les mêmes domaines que le contenu. Pi-hole ne peut pas les différencier sans risquer de bloquer la vidéo elle-même.

**Solution** : Pour YouTube, la meilleure solution reste un bloqueur de pub dans le navigateur (ex: uBlock Origin) ou des applications alternatives (ex: NewPipe sur Android).

### "L'interface web ne s'affiche pas"

**Vérifications** :
1.  Le service Pi-hole est bien démarré ?
    ```bash
    cd ~/stacks/pihole && docker compose ps
    ```
2.  Le port 8888 est-il correct ?

---

Félicitations ! Vous avez repris le contrôle de votre réseau internet.
