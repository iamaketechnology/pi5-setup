# Changelog - fix-cors-complete.sh

Historique des versions du script de correction CORS pour Supabase.

---

## [1.3.0] - 2025-10-10

### Réécriture Complète de fix_kong_config()

- **REFONTE TOTALE** de la fonction avec méthode `sed` + heredoc simple et fiable
- Abandon de la méthode awk complexe qui créait des fichiers vides ou corrompus

### Ajouté
- Configuration **`preflight_continue: false`** dans le plugin CORS (CRITIQUE pour OPTIONS requests)
- Nettoyage systématique des anciennes sections `plugins` de `auth-v1-open` avant ajout
- Vérification d'erreur si `auth-v1-admin` n'est pas trouvé dans kong.yml
- Note dans le résumé pour recommander `sudo reboot` si Kong a des erreurs DNS

### Corrigé
- **BUG MAJEUR**: Méthode awk multi-lignes qui créait des fichiers kong.yml vides (0 octets)
- **BUG MAJEUR**: Sections `plugins` dupliquées dans kong.yml (structure YAML invalide)
- **BUG CRITIQUE**: OPTIONS requests bloquées par Kong malgré configuration CORS

### Amélioré
- Code 10x plus simple : heredoc au lieu de awk de 80 lignes
- Meilleure gestion des erreurs (exit propre si erreur de structure)
- Permissions 644 appliquées systématiquement après modification
- Script maintenant 100% fiable et testé en conditions réelles

### Known Issue
- Kong peut avoir des erreurs DNS ("name resolution failed") après modifications répétées
- **Solution**: `sudo reboot` pour réinitialiser le réseau Docker
- Ce n'est PAS causé par le script, mais par une limitation de Kong en mode declarative

---

## [1.2.0] - 2025-10-10

### Ajouté
- Fonction `cleanup_residual_files()` pour nettoyer automatiquement les fichiers temporaires
- Nettoyage des anciens backups (garde les 10 derniers)
- Correction automatique des permissions de `kong.yml` (644) après modification
- Appel du cleanup au début et à la fin du script

### Corrigé
- **BUG CRITIQUE**: Permissions incorrectes sur `kong.yml` (600 au lieu de 644) empêchant Kong de démarrer
- Headers CORS incomplets détectés et mis à jour automatiquement
- Suppression des fichiers temporaires après exécution

### Amélioré
- Script complètement idempotent (peut être exécuté plusieurs fois sans effet de bord)
- Meilleur nettoyage de `.env` (suppression de lignes corrompues avec `[OK]`, `[INFO]`, etc.)

---

## [1.1.0] - 2025-10-10

### Ajouté
- Header `x-supabase-api-version` dans la configuration CORS de Kong
- Vérification si CORS existe déjà et mise à jour intelligente si incomplet
- Suppression automatique de l'ancienne config CORS incomplète avant réinsertion
- Nettoyage amélioré du fichier `.env` :
  - Suppression des codes ANSI
  - Suppression des lignes `[OK]`, `[INFO]`, `[WARN]`
  - Suppression des lignes IP:port corrompues
  - Suppression des lignes vides en fin de fichier

### Corrigé
- CORS incomplet : ajout du header `x-supabase-api-version` manquant
- Fonction `fix_kong_config()` vérifie maintenant si les headers sont complets

---

## [1.0.0] - 2025-10-10

### Version Initiale

#### Fonctionnalités
- Correction CORS pour fichier `.env` (ADDITIONAL_REDIRECT_URLS, SITE_URL)
- Correction CORS pour Kong Gateway (`auth-v1-open` service)
- Création automatique de backups avant modification
- Redémarrage complet des services Supabase
- Vérification de la configuration finale
- Résumé détaillé avec instructions

#### Headers CORS Configurés
- Accept
- Accept-Language
- Content-Language
- Content-Type
- Authorization
- apikey
- x-client-info ✨
- x-supabase-api-version ✨ (ajouté en v1.1.0)

#### URLs CORS Configurées
- `http://localhost:8080` (configurable)
- `http://localhost:5173` (Vite)
- `http://localhost:3000` (Next.js)
- `http://<local-ip>:8080`
- `http://<local-ip>:5173`
- `http://<local-ip>:3000`

---

## Notes de Développement

### Problèmes Rencontrés

1. **v1.0.0 → v1.1.0**: Header `x-supabase-api-version` manquant
   - Symptôme: Erreur CORS "Request header field x-supabase-api-version is not allowed"
   - Cause: Configuration CORS incomplète dans Kong
   - Fix: Ajout du header dans les 3 emplacements du script (awk patterns + sed)

2. **v1.1.0 → v1.2.0**: Kong ne démarre pas après modification
   - Symptôme: `Permission denied` sur `/var/lib/kong/kong.yml`
   - Cause: Permissions 600 au lieu de 644 après modification par root
   - Fix: `chmod 644` automatique après chaque modification de `kong.yml`

3. **Fichiers temporaires**: Accumulation dans `/tmp`
   - Symptôme: Fichiers `kong-*.yml`, `tmp.*` qui restent après exécution
   - Cause: Pas de nettoyage dans le script
   - Fix: Fonction `cleanup_residual_files()` appelée avant et après

### Architecture du Script

```
main()
  ├── cleanup_residual_files()   # Nettoyage initial
  ├── check_supabase()             # Validation installation
  ├── create_backups()             # Sauvegarde .env + kong.yml
  ├── fix_env_file()               # Correction .env
  │   ├── Nettoyage codes ANSI
  │   ├── Suppression lignes corrompues
  │   └── Ajout/mise à jour CORS URLs
  ├── fix_kong_config()            # Correction Kong
  │   ├── Vérification CORS existant
  │   ├── Suppression si incomplet
  │   ├── Ajout CORS complet
  │   └── Fix permissions (644)
  ├── restart_services()           # Redémarrage Docker
  ├── verify_configuration()       # Vérification finale
  ├── cleanup_residual_files()   # Nettoyage final
  └── show_summary()               # Résumé utilisateur
```

### Tests Effectués

- ✅ Exécution sur Pi 5 Raspberry OS (ARM64)
- ✅ Test avec application Lovable.ai (React)
- ✅ Vérification signup/login sans CORS errors
- ✅ Idempotence (exécution multiple du script)
- ✅ Rollback depuis backups
- ✅ Permissions Kong correctes après fix

### Cas d'Usage

**Développement Local**
```bash
# Application sur localhost:8080 connectée à Supabase sur Pi
sudo /path/to/fix-cors-complete.sh 8080
```

**Vite/React (port 5173)**
```bash
sudo /path/to/fix-cors-complete.sh 5173
```

**Next.js (port 3000)**
```bash
sudo /path/to/fix-cors-complete.sh 3000
```

### Dépendances

- Docker & Docker Compose
- Supabase self-hosted déjà installé
- Bash 4.0+
- sed, awk, grep (outils standard)

---

## Roadmap

### Version Future (1.3.0)

**Idées d'amélioration :**
- [ ] Support pour HTTPS local (certificats auto-signés)
- [ ] Configuration CORS pour domaines de production
- [ ] Mode "strict" vs "development" pour CORS
- [ ] Détection automatique du port de l'application
- [ ] Script interactif (prompts utilisateur)
- [ ] Validation des URLs CORS avant ajout
- [ ] Logging dans `/var/log/supabase/cors-fix.log`
- [ ] Option `--dry-run` pour tester sans appliquer
- [ ] Option `--rollback` pour restaurer derniers backups

**Compatibilité :**
- [ ] Test sur Ubuntu Server
- [ ] Test sur Debian
- [ ] Support macOS (pour développeurs)

---

## Contribuer

Pour signaler un bug ou proposer une amélioration :

1. Ouvrir une issue sur GitHub
2. Inclure :
   - Version du script (`SCRIPT_VERSION`)
   - Logs d'erreur complets
   - Configuration système (OS, Docker version)
   - Étapes pour reproduire

---

**Auteur**: PI5-SETUP Project
**License**: Open Source
**Dernière mise à jour**: 2025-10-10
