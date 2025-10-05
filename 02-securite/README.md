# 🔐 Sécurité & Authentification

> **Catégorie** : Solutions de sécurité et authentification centralisée

---

## 📦 Stacks Inclus

### 1. [Authelia](authelia/)
**SSO (Single Sign-On) + Authentification 2FA**

- 🔐 **SSO** : Un seul login pour toutes vos apps
- 📱 **2FA/MFA** : TOTP (Google Authenticator, Authy)
- 🛡️ **Protection** : Intégration Traefik pour protéger n'importe quelle app
- 📧 **Notifications** : Alertes connexion par email
- 🌐 **LDAP/AD** : Support Active Directory (optionnel)

**RAM** : ~150 MB
**Ports** : 9091 (interface)

**Utilisation** :
- Protège Grafana, FileBrowser, Jellyfin, etc.
- Login unique pour toutes les applications
- 2FA obligatoire configurable

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/authelia/scripts/01-authelia-deploy.sh | sudo bash
```

**Configuration** :
```bash
# Créer utilisateur
sudo ~/pi5-setup/02-securite/authelia/scripts/add-user.sh

# Ajouter protection à une app via Traefik
labels:
  - "traefik.http.routers.mon-app.middlewares=authelia@file"
```

---

## 🔒 Sécurité Complémentaire

Le projet pi5-setup intègre **d'autres mesures de sécurité automatiques** :

### UFW (Firewall)
✅ Auto-configuré dans [Phase 1 - Prerequisites](../01-infrastructure/supabase/scripts/01-prerequisites-setup.sh)

**Ports ouverts par défaut** :
- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)
- 8080 (Portainer - optionnel)

**Vérifier** :
```bash
sudo ufw status verbose
```

**Voir détails** : [FIREWALL-FAQ.md](../FIREWALL-FAQ.md)

---

### Fail2ban
✅ Auto-configuré dans [Phase 1 - Prerequisites](../01-infrastructure/supabase/scripts/01-prerequisites-setup.sh)

**Protection** :
- SSH (3 tentatives ratées → ban 10 min)
- Logs automatiques

**Vérifier** :
```bash
sudo fail2ban-client status sshd
```

---

## 📊 Statistiques Catégorie

| Métrique | Valeur |
|----------|--------|
| **Nombre de stacks** | 1 (+ UFW + Fail2ban automatiques) |
| **RAM totale** | ~150 MB (Authelia uniquement) |
| **Complexité** | ⭐⭐⭐ (Avancée) |
| **Priorité** | 🟡 **RECOMMANDÉ** (optionnel mais fortement conseillé) |
| **Ordre installation** | Phase 9 (après infrastructure + applications à protéger) |

---

## 🎯 Cas d'Usage

### Scénario 1 : Protection Applications Sensibles
**Exemple** : Protéger Grafana et Portainer avec 2FA

```yaml
# Dans votre docker-compose.yml
services:
  grafana:
    labels:
      - "traefik.http.routers.grafana.middlewares=authelia@file"
```

✅ Résultat : Login Authelia avant accès Grafana

---

### Scénario 2 : SSO Multi-Applications
**Exemple** : Un seul login pour Jellyfin, FileBrowser, Gitea

- Première connexion : Email + Password + 2FA code
- Connexions suivantes : Session valide 7 jours
- Déconnexion globale possible

---

### Scénario 3 : Règles d'Accès Avancées
**Exemple** : Accès admin uniquement depuis IP locale

```yaml
# config/configuration.yml
access_control:
  rules:
    - domain: "admin.mondomaine.fr"
      policy: two_factor
      networks:
        - 192.168.1.0/24  # Réseau local uniquement
```

---

## 🔗 Liens Utiles

- [Authelia README](authelia/README.md) - Documentation complète
- [ROADMAP Phase 9](../ROADMAP.md#phase-9-auth) - Détails Phase 9
- [Traefik Integration](../01-infrastructure/traefik/README.md) - Intégration Traefik

---

## 💡 Notes

- **Authelia** est optionnel mais **fortement recommandé** pour production
- **UFW + Fail2ban** sont activés automatiquement dès la Phase 1
- **2FA** protège efficacement contre le vol de mot de passe
- Compatible avec tous les navigateurs et apps mobiles (via TOTP standard)
- Ne pas confondre avec **Supabase Auth** (authentication pour vos apps) vs **Authelia** (protection accès aux services)
