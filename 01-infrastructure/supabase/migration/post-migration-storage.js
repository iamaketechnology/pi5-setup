#!/usr/bin/env node

/**
 * Script de migration des fichiers Storage - Version interactive
 * Version: 3.0.0
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
 * Usage:
 *   node post-migration-storage.js [--max-size=50] [--skip-test]
 *
 * Options:
 *   --max-size=N    Taille max en MB (défaut: 100)
 *   --skip-test     Sauter l'étape de test (non recommandé)
 */

const readline = require('readline');
const fs = require('fs').promises;

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

async function testConnection(cloudClient, piClient) {
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
  try {
    const { data, error } = await piClient.storage.listBuckets();
    if (error) throw error;
    printSuccess(`Pi connecté (${data.length} buckets existants)`);
  } catch (err) {
    console.error(`\n❌ Erreur connexion Pi: ${err.message}`);
    console.error('   Vérifiez votre URL Pi et Service Role Key\n');
    return false;
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
  console.log(`${colors.bright}  📦 Migration Storage Supabase Cloud → Pi (v3.0.0)${colors.reset}`);
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
  const connected = await testConnection(cloudClient, piClient);
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
