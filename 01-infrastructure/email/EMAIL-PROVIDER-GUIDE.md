# 📧 Guide Email Provider Setup - Configuration Email Transactionnel

> **Guide complet pour configurer un fournisseur d'email (Resend, SendGrid ou Mailgun) avec Supabase**

---

## 📋 Vue d'Ensemble

Ce guide vous explique comment configurer un service d'email transactionnel pour envoyer des emails depuis vos applications Supabase déployées sur Raspberry Pi 5.

### Pourquoi un fournisseur d'email externe ?

- ✅ **Délivrabilité maximale** : Vos emails arrivent dans la boîte de réception (pas en spam)
- ✅ **Pas de configuration serveur** : Pas de Postfix/Dovecot à gérer
- ✅ **Analytics intégrées** : Suivi des opens, clics, bounces
- ✅ **API modernes** : Intégration simple via REST
- ✅ **Gratuit** : 100 emails/jour sur tous les providers

---

## 🎯 Choix du Fournisseur

### Comparaison des 3 providers

| Critère | Resend | SendGrid | Mailgun |
|---------|--------|----------|---------|
| **Gratuit** | 100 emails/jour | 100 emails/jour | 100 emails/jour (1er mois) |
| **Facilité** | ⭐⭐⭐⭐⭐ Très simple | ⭐⭐⭐⭐ Simple | ⭐⭐⭐ Moyen |
| **API** | Moderne, épurée | Complète, robuste | Puissante, flexible |
| **Analytics** | Basiques | Avancées | Détaillées |
| **Templates** | React Email | Oui | Oui |
| **Datacenters** | US | Global | US + EU |
| **Recommandé pour** | Startups, devs | Entreprises | Apps européennes |

### Notre recommandation

🏆 **Resend** - Pour débuter et la plupart des cas d'usage
- API la plus simple
- Parfait pour React/Next.js
- Support React Email templates
- Documentation excellente

---

## 🚀 Installation Rapide

### Prérequis

- ✅ Raspberry Pi 5 avec Supabase installé
- ✅ Stack Supabase opérationnel (`docker ps` montre supabase-*)
- ✅ Accès root (`sudo`)

### Installation en une commande

**Deux modes disponibles** :

#### Mode 1 : Interactif (menu de choix)
Le script affiche un menu pour choisir entre Resend, SendGrid ou Mailgun :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/01-email-provider-setup.sh | sudo bash
```

#### Mode 2 : Automatique (provider pré-sélectionné)
Tu choisis directement le provider en ligne de commande (utile pour scripts, CI/CD, ou installation rapide) :
```bash
# Resend
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/01-email-provider-setup.sh | sudo bash -s -- --provider resend

# SendGrid
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/01-email-provider-setup.sh | sudo bash -s -- --provider sendgrid

# Mailgun
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/01-email-provider-setup.sh | sudo bash -s -- --provider mailgun
```

**Durée** : 2-3 minutes (inclut redémarrage du stack Supabase)

---

## 📖 Guide Détaillé par Provider

### 1️⃣ Resend

#### Étape 1 : Créer un compte

1. Allez sur https://resend.com/signup
2. Créez un compte gratuit (email + mot de passe)
3. Vérifiez votre email

#### Étape 2 : Obtenir l'API Key

1. Dashboard → **API Keys**
2. Cliquez sur **Create API Key**
3. Nom : `Supabase-Pi5`
4. Permissions : **Full Access** (ou **Sending Access** uniquement)
5. **Copiez la clé** (commence par `re_`)

⚠️ **Important** : La clé n'est affichée qu'une seule fois !

#### Étape 3 : Lancer le script

```bash
sudo bash /path/to/01-email-provider-setup.sh
```

Le script vous demandera :
- **Provider** : Choisir `1` pour Resend
- **API Key** : Coller votre clé `re_xxxxx`
- **Domaine** : ENTER pour skip (optionnel)
- **From Email** : Votre email (ex: `noreply@votredomaine.com`)

#### Étape 4 (Optionnel) : Vérifier un domaine

Pour envoyer depuis votre propre domaine (ex: `contact@votredomaine.com`) :

1. Dashboard Resend → **Domains**
2. **Add Domain**
3. Entrez votre domaine : `votredomaine.com`
4. Ajoutez les **3 DNS records** chez votre registrar :
   - SPF (TXT)
   - DKIM (TXT)
   - DMARC (TXT)
5. Attendez validation (quelques minutes à 24h)

**Sans domaine vérifié** : Vous pouvez quand même envoyer, mais depuis `onboarding@resend.dev`

---

### 2️⃣ SendGrid

#### Étape 1 : Créer un compte

1. Allez sur https://sendgrid.com/signup
2. Créez un compte gratuit
3. Vérifiez votre email
4. Complétez le questionnaire (Single Sender, 100 emails/jour)

#### Étape 2 : Obtenir l'API Key

1. **Settings** → **API Keys**
2. **Create API Key**
3. Nom : `Supabase-Pi5`
4. Permissions : **Full Access** (ou **Mail Send** uniquement)
5. **Copiez la clé** (commence par `SG.`)

#### Étape 3 : Vérifier un expéditeur

⚠️ **SendGrid requiert une vérification** avant d'envoyer :

**Option A : Single Sender** (rapide, pour débuter)
1. **Settings** → **Sender Authentication** → **Single Sender Verification**
2. Entrez votre email
3. Vérifiez via le lien reçu par email

**Option B : Domain Authentication** (recommandé pour production)
1. **Settings** → **Sender Authentication** → **Domain Authentication**
2. Ajoutez vos DNS records
3. Attendez validation

#### Étape 4 : Lancer le script

```bash
sudo bash /path/to/01-email-provider-setup.sh
```

Le script vous demandera :
- **Provider** : Choisir `2` pour SendGrid
- **API Key** : Coller votre clé `SG.xxxxx`
- **From Email** : Votre email vérifié

---

### 3️⃣ Mailgun

#### Étape 1 : Créer un compte

1. Allez sur https://mailgun.com/signup
2. Créez un compte (carte bancaire requise, mais pas de charge pour <100 emails/jour)
3. Vérifiez votre email

#### Étape 2 : Obtenir l'API Key

1. **Sending** → **Domain Settings** → **API Keys**
2. Copiez votre **Private API Key**

#### Étape 3 : Configurer un domaine

⚠️ **Mailgun requiert un domaine** :

1. **Sending** → **Domains** → **Add New Domain**
2. Entrez un sous-domaine : `mg.votredomaine.com`
3. Région : **US** ou **EU** (choisir EU si RGPD)
4. Ajoutez les **DNS records** :
   - 2 TXT (SPF + DKIM)
   - 1 CNAME (tracking)
5. Attendez validation (~10 minutes)

#### Étape 4 : Lancer le script

```bash
sudo bash /path/to/01-email-provider-setup.sh
```

Le script vous demandera :
- **Provider** : Choisir `3` pour Mailgun
- **API Key** : Coller votre clé
- **Domaine** : `mg.votredomaine.com`
- **Région** : `1` pour US, `2` pour EU
- **From Email** : `noreply@mg.votredomaine.com`

---

## 🔧 Ce que fait le script

### 1. Validation des prérequis
- Vérif ie que Supabase est installé
- Vérifie que Docker fonctionne
- Vérifie qu'Edge Functions est démarré

### 2. Configuration des fichiers
Crée/met à jour :
- `/home/pi/stacks/supabase/.env` (variables Docker Compose)
- `/home/pi/stacks/supabase/functions/.env` (variables Edge Functions)
- `/home/pi/stacks/supabase/docker-compose.yml` (injection variables)

Variables créées :
```bash
EMAIL_PROVIDER=resend|sendgrid|mailgun
EMAIL_API_KEY=votre_clé_api
EMAIL_FROM=noreply@votredomaine.com
EMAIL_DOMAIN=votredomaine.com  # optionnel
MAILGUN_REGION=us|eu           # si Mailgun
```

### 3. Redémarrage du stack

⚠️ **Important** : Le script fait un **redémarrage complet** du stack Supabase :

```bash
docker compose down
docker compose up -d
```

**Pourquoi ?** Les variables d'environnement ne sont chargées qu'au démarrage des containers. Un simple `restart` ne suffit pas.

**Durée** : 30-60 secondes

### 4. Vérification

Le script vérifie que :
- ✅ Tous les services Supabase sont démarrés (db, auth, rest, storage, edge-functions, kong, etc.)
- ✅ Les variables `EMAIL_*` sont accessibles dans le container Edge Functions

---

## 💻 Utilisation dans votre Code

### Dans vos Edge Functions Supabase

Une fois configuré, **toutes vos Edge Functions** ont accès aux variables email :

```typescript
// supabase/functions/send-invite/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const EMAIL_API_KEY = Deno.env.get("EMAIL_API_KEY")!;
const EMAIL_FROM = Deno.env.get("EMAIL_FROM")!;
const EMAIL_PROVIDER = Deno.env.get("EMAIL_PROVIDER")!;

serve(async (req) => {
  const { email, inviteLink } = await req.json();

  // Envoyer email via Resend
  if (EMAIL_PROVIDER === "resend") {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${EMAIL_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: EMAIL_FROM,
        to: email,
        subject: "Invitation to join",
        html: `<h1>You're invited!</h1><p>Click here: ${inviteLink}</p>`,
      }),
    });

    if (!response.ok) {
      throw new Error(`Email failed: ${await response.text()}`);
    }

    const data = await response.json();
    return new Response(JSON.stringify({ success: true, id: data.id }));
  }

  // Ou via SendGrid
  if (EMAIL_PROVIDER === "sendgrid") {
    const response = await fetch("https://api.sendgrid.com/v3/mail/send", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${EMAIL_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        personalizations: [{ to: [{ email }] }],
        from: { email: EMAIL_FROM },
        subject: "Invitation to join",
        content: [{
          type: "text/html",
          value: `<h1>You're invited!</h1><p>Click here: ${inviteLink}</p>`
        }],
      }),
    });

    if (!response.ok) {
      throw new Error(`Email failed: ${await response.text()}`);
    }

    return new Response(JSON.stringify({ success: true }));
  }

  // Ou via Mailgun
  if (EMAIL_PROVIDER === "mailgun") {
    const DOMAIN = Deno.env.get("EMAIL_DOMAIN")!;
    const REGION = Deno.env.get("MAILGUN_REGION") || "us";
    const API_BASE = REGION === "eu"
      ? "https://api.eu.mailgun.net/v3"
      : "https://api.mailgun.net/v3";

    const formData = new FormData();
    formData.append("from", EMAIL_FROM);
    formData.append("to", email);
    formData.append("subject", "Invitation to join");
    formData.append("html", `<h1>You're invited!</h1><p>Click here: ${inviteLink}</p>`);

    const response = await fetch(`${API_BASE}/${DOMAIN}/messages`, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${btoa(`api:${EMAIL_API_KEY}`)}`,
      },
      body: formData,
    });

    if (!response.ok) {
      throw new Error(`Email failed: ${await response.text()}`);
    }

    const data = await response.json();
    return new Response(JSON.stringify({ success: true, id: data.id }));
  }
});
```

### Helper function réutilisable

Créez un helper pour simplifier :

```typescript
// supabase/functions/_shared/email.ts
const EMAIL_API_KEY = Deno.env.get("EMAIL_API_KEY")!;
const EMAIL_FROM = Deno.env.get("EMAIL_FROM")!;
const EMAIL_PROVIDER = Deno.env.get("EMAIL_PROVIDER")!;

export async function sendEmail(
  to: string,
  subject: string,
  html: string
): Promise<{ success: boolean; id?: string; error?: string }> {
  try {
    if (EMAIL_PROVIDER === "resend") {
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${EMAIL_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ from: EMAIL_FROM, to, subject, html }),
      });

      if (!response.ok) {
        const error = await response.text();
        return { success: false, error };
      }

      const data = await response.json();
      return { success: true, id: data.id };
    }

    // Ajouter SendGrid et Mailgun ici...

    return { success: false, error: "Provider not configured" };
  } catch (error) {
    return { success: false, error: error.message };
  }
}
```

Puis dans vos fonctions :

```typescript
import { sendEmail } from "../_shared/email.ts";

const result = await sendEmail(
  "user@example.com",
  "Welcome!",
  "<h1>Welcome to our platform</h1>"
);

if (!result.success) {
  throw new Error(`Email failed: ${result.error}`);
}
```

---

## 🧪 Tests et Vérifications

### Vérifier les variables dans le container

```bash
# SSH dans le Pi
ssh pi@192.168.1.74

# Vérifier les variables EMAIL dans Edge Functions
docker exec supabase-edge-functions env | grep EMAIL

# Devrait afficher :
# EMAIL_PROVIDER=resend
# EMAIL_API_KEY=re_xxxxx
# EMAIL_FROM=noreply@votredomaine.com
```

### Tester l'envoi d'email

```bash
# Récupérer l'ANON_KEY
cd /home/pi/stacks/supabase
ANON_KEY=$(grep "^ANON_KEY=" .env | cut -d= -f2 | tr -d '"')

# Tester l'envoi (si vous avez une fonction send-email)
curl -X POST "http://localhost:54321/send-email" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "votre@email.com",
    "subject": "Test depuis Pi5",
    "html": "<h1>Test réussi!</h1>"
  }'
```

### Consulter les analytics

- **Resend** : https://resend.com/emails
- **SendGrid** : https://app.sendgrid.com/statistics
- **Mailgun** : https://app.mailgun.com/app/logs

---

## 🔄 Changer de Provider

Pour passer d'un provider à un autre :

```bash
# Relancer le script avec --force
sudo bash /path/to/01-email-provider-setup.sh --force

# Ou supprimer les variables et relancer
sudo sed -i '/^EMAIL_/d' /home/pi/stacks/supabase/.env
sudo bash /path/to/01-email-provider-setup.sh
```

Le script :
1. Détectera la config existante
2. Proposera de reconfigurer
3. Sauvegardera l'ancienne config dans `/home/pi/backups/supabase/`

---

## 🐛 Troubleshooting

### Problème : Variables non détectées dans le container

**Symptôme** :
```bash
docker exec supabase-edge-functions env | grep EMAIL
# Aucun résultat
```

**Solution** :
```bash
# Redémarrage complet du stack
cd /home/pi/stacks/supabase
sudo docker compose down
sudo docker compose up -d

# Attendre 30 secondes
sleep 30

# Re-vérifier
docker exec supabase-edge-functions env | grep EMAIL
```

### Problème : Stack ne redémarre pas

**Symptôme** : Services n'apparaissent pas dans `docker ps`

**Solution** :
```bash
# Vérifier les logs
cd /home/pi/stacks/supabase
docker compose logs

# Regarder un service spécifique
docker compose logs edge-functions

# Forcer recreate
docker compose up -d --force-recreate
```

### Problème : Email non reçu

**1. Vérifier les logs du provider**
- Resend : https://resend.com/emails
- SendGrid : Email Activity
- Mailgun : Logs

**2. Vérifier l'API Key**
```bash
# Tester l'API Key directement
curl https://api.resend.com/emails \
  -H "Authorization: Bearer re_votre_cle" \
  -H "Content-Type: application/json" \
  -d '{"from":"onboarding@resend.dev","to":"test@example.com","subject":"Test","html":"<p>Test</p>"}'
```

**3. Vérifier le domaine**
- Le domaine est-il vérifié ?
- Les DNS records sont-ils bien configurés ?

**4. Vérifier les quotas**
- Resend gratuit : 100 emails/jour
- SendGrid gratuit : 100 emails/jour
- Mailgun gratuit : 100 emails/jour (1er mois)

### Problème : Erreur 401 Unauthorized

**Cause** : API Key invalide ou expirée

**Solution** :
1. Regénérer une API Key sur le dashboard du provider
2. Relancer le script avec `--force`
3. Entrer la nouvelle clé

---

## 📊 Limites et Quotas

### Plan Gratuit

| Provider | Emails/jour | Emails/mois | Expire ? |
|----------|-------------|-------------|----------|
| Resend | 100 | 3000 | ❌ Non |
| SendGrid | 100 | 3000 | ❌ Non |
| Mailgun | 100 | 3000 | ⚠️ Après 1 mois, passer à payant ou sandbox |

### Passer au payant

**Resend Pro** : $20/mois pour 50k emails
**SendGrid Essentials** : $19.95/mois pour 50k emails
**Mailgun Foundation** : $35/mois pour 50k emails

---

## 🔐 Sécurité

### Bonnes pratiques

✅ **Ne committez JAMAIS les API Keys** dans Git
✅ **Utilisez des clés séparées** par environnement (dev/prod)
✅ **Rotez les clés** régulièrement (tous les 3-6 mois)
✅ **Limitez les permissions** (Sending Access uniquement si possible)
✅ **Surveillez les quotas** pour détecter les abus
✅ **Activez les webhooks** pour tracking avancé

### Webhooks (optionnel)

Les 3 providers supportent les webhooks pour être notifié des événements :
- Email delivered
- Email bounced
- Email opened
- Link clicked
- Spam complaint

Configuration : Dashboard du provider → Webhooks → Ajouter URL de callback

---

## 📚 Ressources

### Documentation officielle
- **Resend** : https://resend.com/docs
- **SendGrid** : https://docs.sendgrid.com
- **Mailgun** : https://documentation.mailgun.com

### Tutoriels
- [Resend avec Next.js](https://resend.com/docs/send-with-nextjs)
- [SendGrid avec Node.js](https://docs.sendgrid.com/for-developers/sending-email/quickstart-nodejs)
- [Mailgun Getting Started](https://documentation.mailgun.com/en/latest/quickstart-sending.html)

### Support
- **Resend** : support@resend.com (rapide, ~1h)
- **SendGrid** : Chat + tickets (24-48h)
- **Mailgun** : Tickets (48h)

---

## ✅ Checklist Post-Installation

Après avoir lancé le script, vérifiez :

- [ ] Le script s'est terminé sans erreur
- [ ] Les variables `EMAIL_*` sont présentes dans le container (`docker exec supabase-edge-functions env | grep EMAIL`)
- [ ] Tous les services Supabase sont démarrés (`docker ps | grep supabase`)
- [ ] Vous pouvez accéder au dashboard provider (Resend/SendGrid/Mailgun)
- [ ] Le domaine est vérifié (si applicable)
- [ ] Un email de test a été envoyé et reçu
- [ ] Les analytics montrent l'email envoyé

---

## 🎯 Prochaines Étapes

1. **Modifier vos Edge Functions** pour utiliser les variables `EMAIL_*`
2. **Redéployer vos fonctions** sur le Pi
3. **Tester** l'envoi d'email depuis votre application
4. **Consulter les analytics** pour vérifier la délivrabilité
5. **Configurer les webhooks** (optionnel)

---

**Version du script** : 1.1.0
**Dernière mise à jour** : 2025-10-13
**Auteur** : PI5-SETUP Project

---

**Besoin d'aide ?** Consultez :
- [README Email Stack](README.md)
- [Guide Débutant Email](GUIDE-DEBUTANT.md)
- [Troubleshooting Supabase](../supabase/docs/troubleshooting/)
