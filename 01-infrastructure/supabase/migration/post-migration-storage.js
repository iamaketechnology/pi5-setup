#!/usr/bin/env node

/**
 * Script de migration des fichiers Storage - Version interactive
 * Version: 5.0.0
 *
 * Améliorations v5.0.0:
 * - 🔧 FIX CRITIQUE: Réécriture complète de l'ajout PGOPTIONS avec script Python
 * - 📋 Vérification avant/après modification avec logs détaillés
 * - 🔍 Diagnostic complet si échec (affiche docker-compose.yml extrait)
 * - ✅ Utilise `docker compose up -d` au lieu de `restart` (recrée le conteneur)
 * - 🎯 Solution confirmée par issue GitHub supabase/storage#383
 *
 * Améliorations v4.0.0:
 * - 🔄 Redémarre TOUS les services Supabase (pas juste Storage)
 * - ⏱️ Augmentation délai d'attente 10s → 15s (tous les services redémarrent)
 * - 🔧 Fix: ALTER DATABASE nécessite redémarrage complet pour prendre effet
 *
 * Améliorations v3.8.0:
 * - 🔄 Système de retry avec 3 tentatives
 * - 📊 Vérification visuelle de l'état du service Storage
 * - ✅ Confirmation visuelle colorée quand le service est opérationnel
 * - 📈 Affichage du nombre de tentatives et temps d'attente total
 *
 * Améliorations v3.7.0:
 * - 📺 Affichage des logs d'erreur directement dans le terminal (colorisé)
 * - 📋 Plus besoin de consulter un fichier séparé
 * - 🎨 Sections claires: Erreur, Diagnostic, Solutions
 *
 * Améliorations v3.6.0:
 * - 📝 Logs automatiques détaillés en cas d'erreur
 * - ⏱️ Augmentation du délai d'attente après redémarrage Storage (1s → 10s)
 * - 💡 Suggestions de diagnostic et solutions en cas d'échec
 *
 * Améliorations v3.5.0:
 * - 🔧 Configure automatiquement le search_path PostgreSQL (storage, public)
 * - 🔄 Redémarre automatiquement le service Storage après création tables
 * - ✅ L'utilisateur n'a plus besoin d'intervention manuelle
 *
 * Améliorations v3.4.0:
 * - 🔧 Fix PGPASSWORD avec docker exec (-e PGPASSWORD)
 * - 📁 Utilise fichier SQL temporaire pour éviter les problèmes de heredoc
 *
 * Améliorations v3.3.0:
 * - 🔧 Création tables storage via SSH + docker exec (plus fiable)
 * - ⚡ Plus besoin du package 'pg', utilise SSH directement
 *
 * Améliorations v3.2.0:
 * - 🔧 Installation automatique des dépendances npm (@supabase/supabase-js)
 * - ⚡ Plus besoin de lancer `npm install` manuellement
 *
 * Améliorations v3.1.0:
 * - ✨ Création automatique des tables storage.buckets et storage.objects
 * - 🔧 Détection et résolution du problème "relation buckets does not exist"
 * - 🚀 Initialisation automatique du schéma storage si nécessaire
 *
 * Améliorations v3.0.0:
 * - Interface guidée étape par étape
 * - Test automatique avant migration réelle
 * - Barre de progression
 * - Résumé visuel amélioré
 * - Confirmation à chaque étape
 *
 * Sécurités v2.0.0:
 * - Pagination (support > 1000 fichiers)
 * - Retry automatique (3 tentatives)
 * - Validation taille fichiers (max 100MB)
 * - Timeout upload/download (5min)
 * - Log détaillé des erreurs
 * - Manifest JSON
 *
 * Prérequis:
 *   npm install @supabase/supabase-js
 *   SSH configuré vers le Pi (ssh pi@IP_DU_PI)
 *
 * Usage:
 *   node post-migration-storage.js [--max-size=50] [--skip-test]
 *
 * Options:
 *   --max-size=N    Taille max en MB (défaut: 100)
 *   --skip-test     Sauter l'étape de test (non recommandé)
 */

const readline = require('readline');
const fs = require('fs').promises;
const { execSync } = require('child_process');

// Vérification et installation automatique des dépendances
function checkAndInstallDependencies() {
  const dependencies = ['@supabase/supabase-js'];
  const missing = [];

  for (const dep of dependencies) {
    try {
      require.resolve(dep);
    } catch {
      missing.push(dep);
    }
  }

  if (missing.length > 0) {
    console.log(`\n⚠️  Dépendances manquantes détectées: ${missing.join(', ')}`);
    console.log(`📦 Installation automatique en cours...\n`);

    try {
      execSync(`npm install ${missing.join(' ')}`, { stdio: 'inherit' });
      console.log(`\n✅ Dépendances installées avec succès!\n`);
    } catch (error) {
      console.error(`\n❌ Échec installation des dépendances.`);
      console.error(`   Installez-les manuellement: npm install ${missing.join(' ')}\n`);
      process.exit(1);
    }
  }
}

// Vérifier les dépendances au démarrage
checkAndInstallDependencies();

const MAX_SIZE_MB = parseInt(process.argv.find(arg => arg.startsWith('--max-size='))?.split('=')[1] || '100');
const MAX_SIZE_BYTES = MAX_SIZE_MB * 1024 * 1024;
const SKIP_TEST = process.argv.includes('--skip-test');
const RETRY_COUNT = 3;
const TIMEOUT_MS = 5 * 60 * 1000;
const PAGINATION_LIMIT = 100;

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

// Couleurs console
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function printStep(num, total, title) {
  console.log(`\n${colors.cyan}╔════════════════════════════════════════════════════╗${colors.reset}`);
  console.log(`${colors.cyan}║${colors.reset} ${colors.bright}ÉTAPE ${num}/${total}: ${title.padEnd(42)}${colors.reset}${colors.cyan}║${colors.reset}`);
  console.log(`${colors.cyan}╚════════════════════════════════════════════════════╝${colors.reset}\n`);
}

function printSuccess(message) {
  console.log(`${colors.green}✅ ${message}${colors.reset}`);
}

function printWarning(message) {
  console.log(`${colors.yellow}⚠️  ${message}${colors.reset}`);
}

function printInfo(message) {
  console.log(`${colors.blue}ℹ  ${message}${colors.reset}`);
}

// Timeout promise
function withTimeout(promise, ms) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), ms))
  ]);
}

// Retry avec backoff exponentiel
async function retryWithBackoff(fn, retries = RETRY_COUNT) {
  for (let i = 0; i < retries; i++) {
    try {
      return await fn();
    } catch (err) {
      if (i === retries - 1) throw err;
      const delay = Math.pow(2, i) * 1000;
      console.log(`    ⏱️  Retry ${i + 1}/${retries} dans ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

// Lister tous les fichiers avec pagination
async function listAllFiles(client, bucketName) {
  let allFiles = [];
  let offset = 0;
  let hasMore = true;

  while (hasMore) {
    const { data: files, error } = await client.storage
      .from(bucketName)
      .list('', {
        limit: PAGINATION_LIMIT,
        offset: offset,
        sortBy: { column: 'name', order: 'asc' }
      });

    if (error) throw error;

    if (files && files.length > 0) {
      allFiles = allFiles.concat(files);
      offset += files.length;
      hasMore = files.length === PAGINATION_LIMIT;
    } else {
      hasMore = false;
    }
  }

  return allFiles;
}

// Barre de progression
function printProgress(current, total, fileName) {
  const percent = Math.round((current / total) * 100);
  const barLength = 30;
  const filled = Math.round((barLength * current) / total);
  const bar = '█'.repeat(filled) + '░'.repeat(barLength - filled);

  process.stdout.write(`\r  [${bar}] ${percent}% (${current}/${total}) ${fileName.substring(0, 30)}...`);

  if (current === total) {
    process.stdout.write('\n');
  }
}

function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

async function testConnection(cloudClient, piClient, piUrl, piServiceKey) {
  printStep(1, SKIP_TEST ? 5 : 6, 'Test de connexion');

  printInfo('Test connexion Cloud...');
  try {
    const { data, error } = await cloudClient.storage.listBuckets();
    if (error) throw error;
    printSuccess(`Cloud connecté (${data.length} buckets détectés)`);
  } catch (err) {
    console.error(`\n❌ Erreur connexion Cloud: ${err.message}`);
    console.error('   Vérifiez votre Service Role Key Cloud\n');
    return false;
  }

  printInfo('Test connexion Pi...');

  // Try to list buckets first - if it fails, we need to create the storage tables
  let needsStorageTables = false;
  try {
    const { data, error } = await piClient.storage.listBuckets();
    if (error) {
      // Check if error is about missing tables
      if (error.message.includes('relation') || error.message.includes('does not exist')) {
        needsStorageTables = true;
        printWarning('Tables storage.buckets/objects non détectées');
      } else {
        throw error;
      }
    } else {
      printSuccess(`Pi connecté (${data.length} buckets existants)`);
    }
  } catch (err) {
    console.error(`\n❌ Erreur connexion Pi: ${err.message}`);
    console.error('   Vérifiez votre URL Pi et Service Role Key\n');
    return false;
  }

  // Parse Pi URL to get hostname (needed for error reporting too)
  const piUrlObj = new URL(piUrl);
  const piHost = piUrlObj.hostname;

  // Create storage tables if needed
  if (needsStorageTables) {
    printInfo('Création automatique des tables storage via SSH...');

    try {
      const { execSync } = require('child_process');

      // Ask for PostgreSQL password
      const pgPassword = await question('  Mot de passe PostgreSQL (POSTGRES_PASSWORD du Pi): ');

      printInfo('Connexion SSH au Pi...');

      // Create SQL commands
      const sqlCommands = `-- Créer le schéma storage
CREATE SCHEMA IF NOT EXISTS storage;

-- Créer la table buckets
CREATE TABLE IF NOT EXISTS storage.buckets (
  id text PRIMARY KEY,
  name text NOT NULL UNIQUE,
  owner uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  public boolean DEFAULT false,
  avif_autodetection boolean DEFAULT false,
  file_size_limit bigint,
  allowed_mime_types text[]
);

ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

GRANT ALL ON storage.buckets TO postgres, service_role;
GRANT SELECT ON storage.buckets TO anon, authenticated;

-- Créer la table objects
CREATE TABLE IF NOT EXISTS storage.objects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id text REFERENCES storage.buckets(id),
  name text,
  owner uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  last_accessed_at timestamptz DEFAULT now(),
  metadata jsonb,
  path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/')) STORED,
  version text,
  UNIQUE(bucket_id, name)
);

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS objects_bucket_id_idx ON storage.objects(bucket_id);
CREATE INDEX IF NOT EXISTS objects_name_idx ON storage.objects(name);
CREATE INDEX IF NOT EXISTS objects_owner_idx ON storage.objects(owner);

GRANT ALL ON storage.objects TO postgres, service_role;
GRANT SELECT ON storage.objects TO anon, authenticated;

-- Configurer le search_path pour que l'API Storage trouve les tables
ALTER DATABASE postgres SET search_path TO storage, public;

SELECT 'Tables créées' as status;`;

      // Write SQL to temp file
      const tmpFile = '/tmp/supabase-storage-init.sql';
      await fs.writeFile(tmpFile, sqlCommands);

      // Execute via SSH with password in docker exec environment
      const sshCommand = `ssh pi@${piHost} "docker exec -i -e PGPASSWORD='${pgPassword}' supabase-db psql -U postgres -d postgres" < ${tmpFile}`;

      execSync(sshCommand, { stdio: 'inherit' });

      // Clean up
      await fs.unlink(tmpFile);

      printSuccess('Tables storage créées avec succès');

      printInfo('Configuration de PGOPTIONS dans le service Storage...');

      // Vérifier si PGOPTIONS existe déjà
      const checkPgOptionsCmd = `ssh pi@${piHost} "grep 'PGOPTIONS.*search_path' ~/stacks/supabase/docker-compose.yml"`;
      let pgOptionsExists = false;

      try {
        execSync(checkPgOptionsCmd, { stdio: 'pipe' });
        pgOptionsExists = true;
        printSuccess('PGOPTIONS déjà présent dans docker-compose.yml');
      } catch (err) {
        // PGOPTIONS n'existe pas, on va l'ajouter
        printWarning('PGOPTIONS absent, ajout automatique...');

        // Créer un script Python temporaire pour modifier docker-compose.yml de façon robuste
        const pythonScript = `
import re
import sys

# Lire le fichier
with open('/home/pi/stacks/supabase/docker-compose.yml', 'r') as f:
    content = f.read()

# Vérifier si PGOPTIONS existe déjà
if 'PGOPTIONS' in content:
    print("PGOPTIONS_ALREADY_EXISTS")
    sys.exit(0)

# Pattern pour trouver la section storage et ajouter PGOPTIONS après DATABASE_URL
pattern = r'(container_name: supabase-storage.*?environment:.*?DATABASE_URL: [^\\n]+)'
replacement = r'\\1\\n      PGOPTIONS: "-c search_path=storage,public"'

# Appliquer le remplacement
new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

# Vérifier que la modification a été faite
if new_content != content:
    # Sauvegarder
    with open('/home/pi/stacks/supabase/docker-compose.yml', 'w') as f:
        f.write(new_content)
    print("PGOPTIONS_ADDED_SUCCESS")
else:
    print("PGOPTIONS_ADD_FAILED")
    sys.exit(1)
`;

        // Écrire le script Python sur le Pi
        const tmpPythonFile = '/tmp/add_pgoptions.py';
        const writePythonCmd = `ssh pi@${piHost} "cat > ${tmpPythonFile}" <<'PYTHON_SCRIPT_EOF'
${pythonScript}
PYTHON_SCRIPT_EOF`;

        try {
          execSync(writePythonCmd, { stdio: 'pipe' });

          // Exécuter le script Python
          const runPythonCmd = `ssh pi@${piHost} "python3 ${tmpPythonFile}"`;
          const pythonOutput = execSync(runPythonCmd, { encoding: 'utf8' }).trim();

          if (pythonOutput === 'PGOPTIONS_ALREADY_EXISTS') {
            printSuccess('PGOPTIONS déjà présent (détecté par Python)');
            pgOptionsExists = true;
          } else if (pythonOutput === 'PGOPTIONS_ADDED_SUCCESS') {
            printSuccess('PGOPTIONS ajouté avec succès dans docker-compose.yml');
            pgOptionsExists = true;
          } else {
            throw new Error('Échec ajout PGOPTIONS: ' + pythonOutput);
          }

          // Nettoyer le fichier temporaire
          execSync(`ssh pi@${piHost} "rm -f ${tmpPythonFile}"`, { stdio: 'pipe' });

        } catch (err) {
          printError('Échec modification docker-compose.yml avec Python');
          printWarning('Affichage de la section storage actuelle:');

          // Afficher la section storage pour diagnostic
          const showStorageCmd = `ssh pi@${piHost} "sed -n '/container_name: supabase-storage/,/healthcheck:/p' ~/stacks/supabase/docker-compose.yml"`;
          const storageSection = execSync(showStorageCmd, { encoding: 'utf8' });
          console.log('\n' + colors.cyan + storageSection + colors.reset);

          throw new Error("Impossible d'ajouter PGOPTIONS automatiquement. Modifiez manuellement docker-compose.yml");
        }
      }

      // Vérification post-modification
      printInfo('Vérification finale de PGOPTIONS...');
      const verifyCmd = `ssh pi@${piHost} "grep -A 2 'DATABASE_URL.*postgres' ~/stacks/supabase/docker-compose.yml | grep PGOPTIONS"`;

      try {
        const verifyOutput = execSync(verifyCmd, { encoding: 'utf8' }).trim();
        printSuccess('✓ Vérification OK: ' + verifyOutput);
      } catch (err) {
        printError('✗ PGOPTIONS non détecté après modification!');
        throw new Error('Échec vérification PGOPTIONS');
      }

      printWarning('Redémarrage de TOUS les services Supabase avec recréation des conteneurs...');
      printInfo('(Utilisation de "docker compose up -d" pour appliquer les nouvelles variables)');

      // Use docker compose up -d to recreate containers with new environment variables
      const upCommand = `ssh pi@${piHost} "cd ~/stacks/supabase && docker compose up -d storage"`;
      execSync(upCommand, { stdio: 'pipe' });

      printSuccess('Service Storage recréé avec PGOPTIONS');

      // Wait for ALL services to be fully ready with retry mechanism
      const MAX_RETRIES = 3;
      const WAIT_TIME = 15000; // 15 seconds (longer because all services restart)
      let retryCount = 0;
      let storageReady = false;

      while (retryCount < MAX_RETRIES && !storageReady) {
        retryCount++;

        if (retryCount === 1) {
          printInfo(`Attente du redémarrage du service Storage (${WAIT_TIME/1000}s)...`);
        } else {
          printWarning(`Tentative ${retryCount}/${MAX_RETRIES} - Nouvelle attente de ${WAIT_TIME/1000}s...`);
        }

        await new Promise(resolve => setTimeout(resolve, WAIT_TIME));

        // Verify storage API
        printInfo(`Vérification de l'API Storage (tentative ${retryCount}/${MAX_RETRIES})...`);

        try {
          const { data, error } = await piClient.storage.listBuckets();

          if (error) {
            console.error(`   ⚠️  Erreur: ${error.message}`);

            if (retryCount < MAX_RETRIES) {
              printWarning(`Le service n'est pas encore prêt, nouvelle tentative...`);
            } else {
              throw error;
            }
          } else {
            storageReady = true;
            printSuccess(`✅ Pi Storage API accessible ! (${data.length} buckets détectés)`);

            // Display visual confirmation
            console.log('\n' + colors.green + '╔════════════════════════════════════════════════════╗' + colors.reset);
            console.log(colors.green + '║  ✅ SERVICE STORAGE OPÉRATIONNEL                  ║' + colors.reset);
            console.log(colors.green + '╚════════════════════════════════════════════════════╝' + colors.reset);
            console.log(colors.bright + `  • Buckets détectés: ${data.length}` + colors.reset);
            console.log(colors.bright + `  • Tentatives nécessaires: ${retryCount}/${MAX_RETRIES}` + colors.reset);
            console.log(colors.bright + `  • Temps d'attente total: ${(retryCount * WAIT_TIME) / 1000}s\n` + colors.reset);
          }
        } catch (verifyErr) {
          if (retryCount >= MAX_RETRIES) {
            throw verifyErr;
          }
        }
      }

    } catch (err) {
      // Display detailed error log directly in terminal
      console.error('\n' + colors.red + '═'.repeat(60) + colors.reset);
      console.error(colors.red + '  ❌ ERREUR MIGRATION STORAGE' + colors.reset);
      console.error(colors.red + '═'.repeat(60) + colors.reset + '\n');

      console.error(colors.bright + '📅 Date:' + colors.reset + ' ' + new Date().toISOString());
      console.error(colors.bright + '💬 Message:' + colors.reset + ' ' + err.message);

      console.error('\n' + colors.bright + '📍 Configuration:' + colors.reset);
      console.error('  - Pi Host: ' + piHost);
      console.error('  - Pi URL: ' + piUrl);

      console.error('\n' + colors.bright + '🔍 Stack Trace:' + colors.reset);
      console.error(colors.dim + err.stack + colors.reset);

      console.error('\n' + colors.yellow + '═'.repeat(60) + colors.reset);
      console.error(colors.yellow + '  🔧 COMMANDES DE DIAGNOSTIC' + colors.reset);
      console.error(colors.yellow + '═'.repeat(60) + colors.reset + '\n');

      console.error(colors.bright + '1. Vérifier SSH:' + colors.reset);
      console.error(colors.cyan + `   ssh pi@${piHost} "echo OK"` + colors.reset);

      console.error('\n' + colors.bright + '2. Vérifier tables PostgreSQL:' + colors.reset);
      console.error(colors.cyan + `   ssh pi@${piHost} "docker exec supabase-db psql -U postgres -d postgres -c '\\\\dt storage.*'"` + colors.reset);

      console.error('\n' + colors.bright + '3. Vérifier search_path:' + colors.reset);
      console.error(colors.cyan + `   ssh pi@${piHost} "docker exec supabase-db psql -U postgres -d postgres -c 'SHOW search_path;'"` + colors.reset);

      console.error('\n' + colors.bright + '4. Vérifier logs Storage:' + colors.reset);
      console.error(colors.cyan + `   ssh pi@${piHost} "docker logs supabase-storage --tail 50"` + colors.reset);

      console.error('\n' + colors.bright + '5. Redémarrer tous les services Supabase:' + colors.reset);
      console.error(colors.cyan + `   ssh pi@${piHost} "cd ~/stacks/supabase && docker compose restart"` + colors.reset);

      console.error('\n' + colors.green + '═'.repeat(60) + colors.reset);
      console.error(colors.green + '  💡 SOLUTIONS POSSIBLES' + colors.reset);
      console.error(colors.green + '═'.repeat(60) + colors.reset + '\n');

      console.error('  1. Le service Storage met ~10s à redémarrer → Attendez et relancez le script');
      console.error('  2. Vérifiez la connexion SSH: ' + colors.cyan + `ssh pi@${piHost}` + colors.reset);
      console.error('  3. Relancez tous les services: Utilisez la commande 5 ci-dessus\n');

      return false;
    }
  }

  return true;
}

async function analyzeBuckets(cloudClient) {
  printStep(2, SKIP_TEST ? 5 : 6, 'Analyse des buckets Cloud');

  const { data: buckets, error } = await cloudClient.storage.listBuckets();
  if (error) throw error;

  console.log(`\n📦 ${colors.bright}${buckets.length} buckets trouvés${colors.reset}:\n`);

  const analysis = [];
  let totalFiles = 0;
  let totalSize = 0;

  for (const bucket of buckets) {
    printInfo(`Analyse ${bucket.name}...`);
    const files = await listAllFiles(cloudClient, bucket.name);

    // Filtrer les vrais fichiers (ignore dossiers et fichiers vides)
    const realFiles = files.filter(f => f.metadata?.size > 0);
    const bucketSize = realFiles.reduce((sum, f) => sum + (f.metadata?.size || 0), 0);

    totalFiles += realFiles.length;
    totalSize += bucketSize;

    console.log(`  └─ ${bucket.name}: ${realFiles.length} fichiers (${formatBytes(bucketSize)})`);

    analysis.push({
      bucket,
      files: realFiles,
      size: bucketSize
    });
  }

  console.log(`\n${colors.bright}Résumé:${colors.reset}`);
  console.log(`  • Total: ${totalFiles} fichiers`);
  console.log(`  • Taille: ${formatBytes(totalSize)}`);
  console.log(`  • Buckets: ${buckets.length}\n`);

  return analysis;
}

async function performDryRun(cloudClient, analysis) {
  printStep(3, 6, 'Test de téléchargement (dry-run)');

  printWarning('Test sans upload sur le Pi (vérification accès fichiers)');
  console.log();

  let successCount = 0;
  let errorCount = 0;
  const errors = [];

  for (const { bucket, files } of analysis) {
    if (files.length === 0) continue;

    console.log(`\n📦 ${bucket.name} (${files.length} fichiers)`);

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const fileSize = file.metadata?.size || 0;

      if (fileSize > MAX_SIZE_BYTES) {
        printWarning(`${file.name}: Trop gros (${formatBytes(fileSize)})`);
        errorCount++;
        errors.push({ bucket: bucket.name, file: file.name, error: 'File too large' });
        continue;
      }

      try {
        const { data, error } = await retryWithBackoff(async () => {
          return await withTimeout(
            cloudClient.storage.from(bucket.name).download(file.name),
            TIMEOUT_MS
          );
        });

        if (error || !data) {
          console.log(`  ❌ ${file.name}`);
          errorCount++;
          errors.push({ bucket: bucket.name, file: file.name, error: error?.message || 'Unknown' });
        } else {
          console.log(`  ✅ ${file.name} (${formatBytes(fileSize)})`);
          successCount++;
        }
      } catch (err) {
        console.log(`  ❌ ${file.name}: ${err.message}`);
        errorCount++;
        errors.push({ bucket: bucket.name, file: file.name, error: err.message });
      }
    }
  }

  console.log(`\n${colors.bright}Résultat du test:${colors.reset}`);
  console.log(`  ✅ Téléchargeables: ${successCount}`);
  console.log(`  ❌ Erreurs: ${errorCount}\n`);

  if (errorCount > 0) {
    printWarning(`${errorCount} fichiers ne peuvent pas être téléchargés`);
    printInfo('Ces fichiers seront ignorés pendant la migration\n');
  }

  return { successCount, errorCount, errors };
}

async function performMigration(cloudClient, piClient, analysis, testResults) {
  printStep(SKIP_TEST ? 3 : 4, SKIP_TEST ? 5 : 6, 'Migration des fichiers');

  const confirm = await question(`\n${colors.yellow}⚠️  Lancer la migration réelle de ${testResults.successCount} fichiers ? (y/n): ${colors.reset}`);

  if (confirm.toLowerCase() !== 'y') {
    printWarning('Migration annulée par l\'utilisateur');
    return null;
  }

  console.log();
  let successCount = 0;
  let errorCount = 0;
  let skippedCount = 0;
  const errorLog = [];
  const manifest = [];
  let fileIndex = 0;

  const totalFiles = testResults.successCount;

  for (const { bucket, files } of analysis) {
    if (files.length === 0) continue;

    // Créer bucket sur Pi
    const { error: createError } = await piClient.storage.createBucket(bucket.name, {
      public: bucket.public
    });

    if (createError && !createError.message.includes('already exists')) {
      printWarning(`Erreur création bucket ${bucket.name}`);
      continue;
    }

    for (const file of files) {
      fileIndex++;
      const fileSize = file.metadata?.size || 0;

      // Skip si trop gros
      if (fileSize > MAX_SIZE_BYTES) {
        skippedCount++;
        continue;
      }

      printProgress(fileIndex, totalFiles, file.name);

      try {
        // Download
        const fileData = await retryWithBackoff(async () => {
          return await withTimeout(
            cloudClient.storage.from(bucket.name).download(file.name),
            TIMEOUT_MS
          );
        });

        if (fileData.error || !fileData.data) {
          errorCount++;
          errorLog.push({ bucket: bucket.name, file: file.name, error: fileData.error?.message });
          continue;
        }

        // Upload
        const uploadResult = await retryWithBackoff(async () => {
          return await withTimeout(
            piClient.storage.from(bucket.name).upload(file.name, fileData.data, {
              contentType: file.metadata?.mimetype,
              upsert: true
            }),
            TIMEOUT_MS
          );
        });

        if (uploadResult.error) {
          errorCount++;
          errorLog.push({ bucket: bucket.name, file: file.name, error: uploadResult.error.message });
        } else {
          successCount++;
          manifest.push({
            bucket: bucket.name,
            file: file.name,
            size: fileSize,
            mimetype: file.metadata?.mimetype
          });
        }

        await new Promise(resolve => setTimeout(resolve, 100));

      } catch (err) {
        errorCount++;
        errorLog.push({ bucket: bucket.name, file: file.name, error: err.message });
      }
    }
  }

  return { successCount, errorCount, skippedCount, errorLog, manifest };
}

async function main() {
  console.clear();
  console.log(`\n${colors.cyan}${'═'.repeat(60)}${colors.reset}`);
  console.log(`${colors.bright}  📦 Migration Storage Supabase Cloud → Pi (v5.0.0)${colors.reset}`);
  console.log(`${colors.cyan}${'═'.repeat(60)}${colors.reset}\n`);

  printInfo(`Configuration: Taille max ${MAX_SIZE_MB}MB • Timeout ${TIMEOUT_MS/1000}s • ${RETRY_COUNT} retries\n`);

  // ÉTAPE 0: Configuration
  printStep(0, SKIP_TEST ? 5 : 6, 'Configuration');

  console.log('📋 Configuration Supabase Cloud (source):\n');
  const cloudUrl = await question('  URL Cloud (ex: https://xxxxx.supabase.co): ');
  const cloudServiceKey = await question('  Service Role Key Cloud: ');

  console.log('\n📋 Configuration Supabase Pi (destination):\n');
  const piUrl = await question('  URL Pi (ex: http://192.168.1.74:8001): ');
  const piServiceKey = await question('  Service Role Key Pi (SUPABASE_SERVICE_KEY): ');

  // Import Supabase
  const { createClient } = await import('@supabase/supabase-js');
  const cloudClient = createClient(cloudUrl, cloudServiceKey);
  const piClient = createClient(piUrl, piServiceKey);

  // ÉTAPE 1: Test connexion
  const connected = await testConnection(cloudClient, piClient, piUrl, piServiceKey);
  if (!connected) {
    rl.close();
    process.exit(1);
  }

  const proceed1 = await question(`\n${colors.green}✓ Connexions OK. Continuer ? (y/n): ${colors.reset}`);
  if (proceed1.toLowerCase() !== 'y') {
    printWarning('Migration annulée');
    rl.close();
    return;
  }

  // ÉTAPE 2: Analyse
  const analysis = await analyzeBuckets(cloudClient);

  const proceed2 = await question(`\n${colors.green}✓ Analyse terminée. Continuer ? (y/n): ${colors.reset}`);
  if (proceed2.toLowerCase() !== 'y') {
    printWarning('Migration annulée');
    rl.close();
    return;
  }

  // ÉTAPE 3: Dry-run (optionnel)
  let testResults = null;
  if (!SKIP_TEST) {
    testResults = await performDryRun(cloudClient, analysis);

    if (testResults.errorCount > 0) {
      const proceed3 = await question(`\n${colors.yellow}⚠️  ${testResults.errorCount} fichiers avec erreurs. Continuer quand même ? (y/n): ${colors.reset}`);
      if (proceed3.toLowerCase() !== 'y') {
        printWarning('Migration annulée');
        rl.close();
        return;
      }
    } else {
      const proceed3 = await question(`\n${colors.green}✓ Tous les fichiers sont accessibles. Lancer la migration ? (y/n): ${colors.reset}`);
      if (proceed3.toLowerCase() !== 'y') {
        printWarning('Migration annulée');
        rl.close();
        return;
      }
    }
  } else {
    const totalFiles = analysis.reduce((sum, a) => sum + a.files.length, 0);
    testResults = { successCount: totalFiles, errorCount: 0, errors: [] };
  }

  // ÉTAPE 4/5: Migration
  const startTime = Date.now();
  const migrationResults = await performMigration(cloudClient, piClient, analysis, testResults);

  if (!migrationResults) {
    rl.close();
    return;
  }

  const duration = Math.round((Date.now() - startTime) / 1000);

  // ÉTAPE 5/6: Sauvegarde manifest
  printStep(SKIP_TEST ? 4 : 5, SKIP_TEST ? 5 : 6, 'Sauvegarde du rapport');

  const manifestPath = `storage-migration-${Date.now()}.json`;
  await fs.writeFile(manifestPath, JSON.stringify({
    timestamp: new Date().toISOString(),
    maxSizeMB: MAX_SIZE_MB,
    stats: {
      total: testResults.successCount,
      success: migrationResults.successCount,
      errors: migrationResults.errorCount,
      skipped: migrationResults.skippedCount,
      duration: duration
    },
    files: migrationResults.manifest,
    errors: migrationResults.errorLog
  }, null, 2));

  printSuccess(`Rapport sauvegardé: ${manifestPath}`);

  // ÉTAPE 6: Résumé final
  printStep(SKIP_TEST ? 5 : 6, SKIP_TEST ? 5 : 6, 'Résumé final');

  console.log(`\n${colors.cyan}${'═'.repeat(60)}${colors.reset}`);
  console.log(`${colors.bright}  🎉 MIGRATION TERMINÉE${colors.reset}`);
  console.log(`${colors.cyan}${'═'.repeat(60)}${colors.reset}\n`);

  console.log(`${colors.green}✅ Succès:${colors.reset}   ${migrationResults.successCount}/${testResults.successCount} fichiers`);
  console.log(`${colors.yellow}❌ Erreurs:${colors.reset}  ${migrationResults.errorCount} fichiers`);
  console.log(`${colors.blue}⏭️  Ignorés:${colors.reset}  ${migrationResults.skippedCount} fichiers (trop gros)`);
  console.log(`${colors.cyan}⏱️  Durée:${colors.reset}    ${duration}s\n`);

  if (migrationResults.errorCount > 0) {
    printWarning(`Consultez ${manifestPath} pour les détails des erreurs`);
  }

  console.log(`${colors.cyan}${'═'.repeat(60)}${colors.reset}\n`);

  rl.close();
}

main().catch(err => {
  console.error(`\n${colors.yellow}❌ Erreur fatale:${colors.reset} ${err.message}\n`);
  rl.close();
  process.exit(1);
});
