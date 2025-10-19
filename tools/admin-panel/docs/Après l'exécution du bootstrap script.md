📝 Après l'exécution du bootstrap script, voici les étapes :
Étape 1: Le Pi s'enregistre automatiquement
Quand le script bootstrap s'exécute sur le Pi, il :
Génère un token unique
Récupère son hostname, ip_address, mac_address
POST automatiquement à http://localhost:4000/api/bootstrap/register
Le serveur reçoit ça et crée une entrée DB avec status: 'pending' et tags: ['bootstrap', 'pending-pairing']
Réponse du serveur :
{
  "success": true,
  "message": "Pi registered successfully",
  "token": "abc123xyz789"
}
Le bootstrap script affiche ce token à l'écran pour l'admin.
Étape 2: Le Pi apparaît dans le Control Center
Dans ta UI (Control Center), la liste des Pis se rafraîchit et tu vas voir :
Pi5 [OK] - Default
NewPi [PENDING] - Bootstrap  ← Le Pi fraîchement déployé !
Étape 3: Admin entre le token dans une modal (Ajouter un Pi)
Clique sur "Ajouter un Pi" dans l'UI
Une modal s'ouvre qui demande le token de pairing
Tu colles le token que le bootstrap a affiché
Clique sur "Appairer"
Étape 4: SSH Test & Activation
Le système fait POST /api/pis/pair avec le token :
// [pi-manager.js:295-360]
async function pairPi(token) {
  // 1. Trouve le Pi par token
  const pi = await supabaseClient.getPiByToken(token);
  
  // 2. TEST SSH ← C'EST LA CLÉ
  const ssh = new NodeSSH();
  await ssh.connect({
    id: pi.id,
    host: pi.hostname,        // Ex: "raspberrypi.local"
    username: 'pi',
    privateKey: '~/.ssh/id_rsa'  // Clé SSH du Control Center
  });
  
  // 3. Exécute une commande simple pour tester
  const result = await ssh.execCommand('echo "Connection OK"');
  ssh.dispose();
  
  // 4. Si ça marche → Activé le Pi
  if (result.code === 0) {
    await supabaseClient.updatePi(pi.id, {
      status: 'active',        // pending → active ✅
      token: null              // Token supprimé (one-time use)
    });
  }
}
Ce qui se passe dans le SSH test :
Utilise la clé SSH du Control Center (~/.ssh/id_rsa)
Essaie de se connecter au Pi via mDNS (raspberrypi.local)
Exécute echo "Connection OK"
Si exit code = 0 → Connexion réussie → Pi activé
Étape 5: UI Mise à jour
Après le pairing réussi :
Pi5 [OK] - Default
NewPi [OK]  ← Status changé de [PENDING] à [OK] ✅
Et le Setup Wizard se lance automatiquement pour guider la suite :
✅ Docker installé?
✅ Network configuré?
✅ Security setup?
✅ Traefik actif?
✅ Monitoring en place?
Résumé du flux complet :
Pi: curl -fsSL http://localhost:4000/bootstrap | sudo bash
        ↓
    [Token généré]
    ↓
Pi: POST /api/bootstrap/register
    → status: 'pending' créé en DB
    ↓
Admin: Voit "NewPi [PENDING]" dans Control Center
    ↓
Admin: Clique "Ajouter un Pi" + entre le token
    ↓
Control Center: POST /api/pis/pair {token}
    ↓
    [SSH Test: Se connecte via pi@raspberrypi.local]
    ↓
    Si OK → status 'pending' → 'active'
       Token supprimé
    ↓
Admin: Voit "NewPi [OK]"
    ↓
Setup Wizard lance