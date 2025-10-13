# Portainer Management Scripts

Scripts for managing Portainer installation and API integration on Raspberry Pi 5.

## Available Scripts

### 1. create-portainer-token.sh

**Purpose**: Generate API access token for Portainer widget integration with Homepage dashboard.

**Usage**:
```bash
# Direct execution from GitHub
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/portainer/scripts/create-portainer-token.sh | sudo bash

# Or local execution
sudo bash create-portainer-token.sh
```

**Features**:
- Interactive prompts for username and password
- Validates Portainer installation and API access
- Generates API token with description "homepage-widget"
- Auto-detects Portainer endpoint ID
- Automatically updates Homepage services.yaml configuration
- Restarts Homepage container to apply changes

**Requirements**:
- Portainer container running
- `jq` installed (script checks and prompts if missing)
- Valid Portainer admin credentials

**Output**:
- API token (displayed and saved to Homepage config)
- Updated Homepage configuration
- Restarted Homepage container

**Example Session**:
```
=========================================
  Générateur de Token API Portainer
=========================================

Vérification des prérequis...
✓ Tous les prérequis sont satisfaits

Entrez vos identifiants Portainer

Username [maketech]: maketech
Password: ********

Authentification...
✓ Authentification réussie

Récupération des informations utilisateur...
✓ User ID: 1

Création du token API...
✓ Token créé avec succès

Mise à jour de la configuration Homepage...
✓ Configuration Homepage mise à jour
✓ Homepage redémarré

=========================================
  ✅ TOKEN API CRÉÉ AVEC SUCCÈS
=========================================

✓ Token API:

  ptr_puurZ9G2LLJQvZmYAtx+kOY41Qo3xmU4hZINV9aitCI=

✓ Utilisez ce token pour:

  • Widget Homepage (automatiquement configuré)
  • API calls directs (Header: X-API-Key)
  • Automation scripts

✓ Configuration Homepage:

  📍 URL: http://192.168.1.74:3001
  🔄 Rechargez la page pour voir le widget Portainer

=========================================
```

---

### 2. reset-portainer-password.sh

**Purpose**: Reset Portainer admin password when you've forgotten it.

**Usage**:
```bash
# Direct execution from GitHub
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/portainer/scripts/reset-portainer-password.sh | sudo bash

# Or local execution
sudo bash reset-portainer-password.sh
```

**Features**:
- Backs up existing password file (with timestamp)
- Stops Portainer container
- Removes admin.password file
- Restarts Portainer container
- Provides next steps instructions

**Requirements**:
- Root/sudo access
- Portainer container installed

**Warning**:
- This will delete your current admin password
- You must create a new password within 5 minutes via the web UI
- All API tokens remain valid after password reset

**Example Session**:
```
=========================================
  Réinitialisation Mot de Passe Portainer
=========================================

Volume Portainer trouvé: /var/lib/docker/volumes/portainer_data/_data

⚠️  Cette opération va:
  1. Arrêter le container Portainer
  2. Supprimer le fichier admin.password
  3. Redémarrer Portainer
  4. Vous devrez créer un nouveau mot de passe via l'UI

Continuer ? (y/N) y

Arrêt du container Portainer...
✓ Container arrêté

Sauvegarde de l'ancien fichier admin.password...
✓ Sauvegarde créée

Suppression du fichier admin.password...
✓ Fichier supprimé

Redémarrage du container Portainer...
✓ Container redémarré

Attente de la disponibilité de Portainer (10 secondes)...

✓ Portainer est en cours d'exécution

=========================================
  ✅ MOT DE PASSE RÉINITIALISÉ AVEC SUCCÈS
=========================================

✓ Prochaines étapes:

1. Accédez à Portainer dans votre navigateur:
   🌐 http://raspberrypi.local:8080
   🌐 http://192.168.1.74:8080

2. Vous verrez la page de création de compte admin

3. Créez un nouveau mot de passe:
   - Username: admin
   - Password: [votre nouveau mot de passe]
   - Confirm: [confirmation]

4. Cliquez sur 'Create user'

⚠️  IMPORTANT: Faites-le dans les 5 minutes suivant ce reset
    sinon Portainer se verrouillera à nouveau

=========================================
```

---

## Troubleshooting

### Error: "Invalid credentials"

**Problem**: Authentication failed when creating token.

**Solutions**:
1. Verify username (default is `maketech`, not `admin` if you changed it)
2. Check password is correct
3. Try resetting password with `reset-portainer-password.sh`

### Error: "jq not installed"

**Problem**: Missing `jq` dependency.

**Solution**:
```bash
sudo apt-get update
sudo apt-get install -y jq
```

### Error: "Container Portainer non trouvé"

**Problem**: Portainer not installed or not running.

**Solution**:
```bash
# Check if Portainer is running
docker ps | grep portainer

# Start Portainer if stopped
docker start portainer

# Install Portainer if missing
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/portainer/scripts/01-portainer-deploy.sh | sudo bash
```

### Error: "API Portainer non accessible"

**Problem**: Portainer API not responding.

**Solutions**:
1. Check Portainer is running: `docker ps | grep portainer`
2. Check Portainer logs: `docker logs portainer --tail 50`
3. Restart Portainer: `docker restart portainer`
4. Wait 10 seconds and try again

### Homepage Widget Shows "401 Unauthorized"

**Problem**: Invalid or missing API token.

**Solution**:
1. Run `create-portainer-token.sh` again
2. Verify token is in `/home/pi/stacks/homepage/config/services.yaml`
3. Check token format: `key: ptr_...` (should start with `ptr_`)

### Homepage Widget Shows "404 Not Found"

**Problem**: Wrong Portainer endpoint ID.

**Solution**:
The `create-portainer-token.sh` script auto-detects the correct endpoint ID. If you manually edited the config, verify:

```bash
# Get correct endpoint ID
curl -s http://localhost:8080/api/endpoints \
  -H 'X-API-Key: YOUR_TOKEN' | jq -r '.[0].Id'

# Update Homepage config
nano /home/pi/stacks/homepage/config/services.yaml

# Find Portainer widget and update:
widget:
  type: portainer
  url: http://192.168.1.74:8080
  env: 3  # Use the ID from above
  key: ptr_...
```

Then restart Homepage:
```bash
docker restart homepage
```

---

## API Token Management

### View All Tokens

```bash
# Authenticate first
JWT=$(curl -s -X POST http://localhost:8080/api/auth \
  -H "Content-Type: application/json" \
  -d '{"Username":"maketech","Password":"your_password"}' | jq -r .jwt)

# List tokens
curl -s http://localhost:8080/api/users/1/tokens \
  -H "Authorization: Bearer $JWT" | jq
```

### Revoke a Token

```bash
# Get token ID
TOKEN_ID=1

# Revoke it
curl -s -X DELETE http://localhost:8080/api/users/1/tokens/$TOKEN_ID \
  -H "Authorization: Bearer $JWT"
```

### Test Token

```bash
# Test token validity
curl -s http://localhost:8080/api/endpoints \
  -H 'X-API-Key: ptr_YOUR_TOKEN_HERE' | jq
```

---

## Integration with Homepage

After running `create-portainer-token.sh`, your Homepage configuration will look like this:

**File**: `/home/pi/stacks/homepage/config/services.yaml`

```yaml
- Infrastructure:
    - Portainer:
        href: http://192.168.1.74:8080
        description: Docker management interface
        icon: portainer
        widget:
          type: portainer
          url: http://192.168.1.74:8080
          env: 3  # Auto-detected endpoint ID
          key: ptr_puurZ9G2LLJQvZmYAtx+kOY41Qo3xmU4hZINV9aitCI=
```

The widget will display:
- Total containers
- Running containers
- Stopped containers
- Healthy containers

---

## Security Notes

1. **API Tokens**: Treat as passwords, never commit to git
2. **Token Scope**: Tokens inherit user permissions
3. **Token Rotation**: Regenerate tokens periodically
4. **Localhost Only**: Portainer API only accessible on localhost:8080 (not exposed through Traefik)
5. **HTTPS**: If exposing Portainer through Traefik, always use HTTPS

---

## Related Documentation

- [Homepage GUIDE-DEBUTANT.md](../../homepage/GUIDE-DEBUTANT.md) - Homepage dashboard guide
- [Portainer GUIDE-DEBUTANT.md](../GUIDE-DEBUTANT.md) - Portainer setup guide
- [Portainer Official API Docs](https://docs.portainer.io/api/docs) - Full API reference

---

**Version**: 1.0.0
**Last Updated**: 2025-10-13
**Maintainer**: [@iamaketechnology](https://github.com/iamaketechnology)
