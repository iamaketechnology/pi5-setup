#!/usr/bin/env node

/**
 * Script de migration des fichiers Storage - Version sécurisée
 * Version: 2.0.0
 *
 * Améliorations de sécurité:
 * - Pagination (support > 1000 fichiers)
 * - Retry automatique (3 tentatives)
 * - Validation taille fichiers (max 100MB)
 * - Timeout upload/download (5min)
 * - Log détaillé des erreurs
 * - Mode dry-run
 * - Résumé avec manifest JSON
 *
 * Usage:
 *   node post-migration-storage.js [--dry-run] [--max-size=50]
 *
 * Options:
 *   --dry-run       Teste sans uploader sur le Pi
 *   --max-size=N    Taille max en MB (défaut: 100)
 */

const readline = require('readline');
const fs = require('fs').promises;
const path = require('path');

const DRY_RUN = process.argv.includes('--dry-run');
const MAX_SIZE_MB = parseInt(process.argv.find(arg => arg.startsWith('--max-size='))?.split('=')[1] || '100');
const MAX_SIZE_BYTES = MAX_SIZE_MB * 1024 * 1024;
const RETRY_COUNT = 3;
const TIMEOUT_MS = 5 * 60 * 1000; // 5 minutes
const PAGINATION_LIMIT = 100;

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
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
      const delay = Math.pow(2, i) * 1000; // 1s, 2s, 4s
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

async function main() {
  console.log('\n📦 Migration des fichiers Storage v2.0.0\n');
  console.log('═'.repeat(50));

  if (DRY_RUN) {
    console.log('🧪 MODE DRY-RUN: Aucun fichier ne sera uploadé\n');
  }

  console.log(`⚙️  Configuration:`);
  console.log(`  • Taille max par fichier: ${MAX_SIZE_MB}MB`);
  console.log(`  • Timeout: ${TIMEOUT_MS / 1000}s`);
  console.log(`  • Retry: ${RETRY_COUNT} tentatives\n`);

  // Configuration Cloud
  console.log('📋 Configuration Supabase Cloud (source):\n');
  const cloudUrl = await question('URL Cloud (ex: https://xxxxx.supabase.co): ');
  const cloudServiceKey = await question('Service Role Key Cloud: ');

  // Configuration Pi
  console.log('\n📋 Configuration Supabase Pi (destination):\n');
  const piUrl = await question('URL Pi (ex: http://192.168.1.74:8000): ');
  const piServiceKey = await question('Service Role Key Pi: ');

  // Import dynamique
  const { createClient } = await import('@supabase/supabase-js');

  const cloudClient = createClient(cloudUrl, cloudServiceKey);
  const piClient = createClient(piUrl, piServiceKey);

  console.log('\n📂 Récupération de la liste des buckets...\n');

  // Lister les buckets Cloud
  const { data: buckets, error: bucketsError } = await cloudClient.storage.listBuckets();

  if (bucketsError) {
    console.error('❌ Erreur buckets:', bucketsError.message);
    process.exit(1);
  }

  if (!buckets || buckets.length === 0) {
    console.log('⚠️  Aucun bucket trouvé sur Cloud.');
    process.exit(0);
  }

  console.log(`✅ ${buckets.length} buckets trouvés:\n`);
  buckets.forEach((bucket, i) => {
    console.log(`  ${i + 1}. ${bucket.name} (${bucket.public ? 'public' : 'private'})`);
  });

  console.log('\n═'.repeat(50));
  const confirm = await question('\nMigrer TOUS les fichiers ? (y/n): ');

  if (confirm.toLowerCase() !== 'y') {
    console.log('\n❌ Opération annulée');
    process.exit(0);
  }

  let totalFiles = 0;
  let successCount = 0;
  let errorCount = 0;
  let skippedCount = 0;
  const errorLog = [];
  const manifest = [];

  const startTime = Date.now();

  for (const bucket of buckets) {
    console.log(`\n📦 Bucket: ${bucket.name}`);
    console.log('─'.repeat(50));

    // Créer bucket sur Pi s'il n'existe pas (sauf dry-run)
    if (!DRY_RUN) {
      const { error: createError } = await piClient.storage.createBucket(bucket.name, {
        public: bucket.public
      });

      if (createError && !createError.message.includes('already exists')) {
        console.log(`  ⚠️  Erreur création bucket: ${createError.message}`);
        errorLog.push({ bucket: bucket.name, error: createError.message });
        continue;
      }
    }

    try {
      // Lister TOUS les fichiers avec pagination
      console.log(`  🔍 Récupération fichiers (pagination)...`);
      const files = await listAllFiles(cloudClient, bucket.name);

      if (!files || files.length === 0) {
        console.log('  📭 Aucun fichier');
        continue;
      }

      console.log(`  📁 ${files.length} fichiers trouvés\n`);
      totalFiles += files.length;

      for (const file of files) {
        const fileSize = file.metadata?.size || 0;

        // Vérifier taille
        if (fileSize > MAX_SIZE_BYTES) {
          console.log(`    ⏭️  ${file.name}: Trop gros (${formatBytes(fileSize)} > ${MAX_SIZE_MB}MB)`);
          skippedCount++;
          errorLog.push({
            bucket: bucket.name,
            file: file.name,
            error: `File too large: ${formatBytes(fileSize)}`
          });
          continue;
        }

        try {
          // Download avec retry et timeout
          const fileData = await retryWithBackoff(async () => {
            return await withTimeout(
              cloudClient.storage.from(bucket.name).download(file.name),
              TIMEOUT_MS
            );
          });

          if (fileData.error) {
            console.log(`    ❌ ${file.name}: ${fileData.error.message}`);
            errorCount++;
            errorLog.push({
              bucket: bucket.name,
              file: file.name,
              error: fileData.error.message
            });
            continue;
          }

          // Upload vers Pi (sauf dry-run)
          if (!DRY_RUN) {
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
              console.log(`    ❌ ${file.name}: ${uploadResult.error.message}`);
              errorCount++;
              errorLog.push({
                bucket: bucket.name,
                file: file.name,
                error: uploadResult.error.message
              });
              continue;
            }
          }

          console.log(`    ✅ ${file.name} (${formatBytes(fileSize)})`);
          successCount++;
          manifest.push({
            bucket: bucket.name,
            file: file.name,
            size: fileSize,
            mimetype: file.metadata?.mimetype
          });

          // Pause pour éviter rate limiting
          await new Promise(resolve => setTimeout(resolve, 100));

        } catch (err) {
          console.log(`    ❌ ${file.name}: ${err.message}`);
          errorCount++;
          errorLog.push({
            bucket: bucket.name,
            file: file.name,
            error: err.message
          });
        }
      }
    } catch (err) {
      console.log(`  ❌ Erreur bucket: ${err.message}`);
      errorLog.push({
        bucket: bucket.name,
        error: err.message
      });
    }
  }

  const duration = Math.round((Date.now() - startTime) / 1000);

  console.log('\n═'.repeat(50));
  console.log('\n📊 Résumé migration:');
  console.log(`  ✅ Succès: ${successCount}/${totalFiles}`);
  console.log(`  ❌ Erreurs: ${errorCount}/${totalFiles}`);
  console.log(`  ⏭️  Ignorés (trop gros): ${skippedCount}/${totalFiles}`);
  console.log(`  📦 Buckets: ${buckets.length}`);
  console.log(`  ⏱️  Durée: ${duration}s\n`);

  // Sauvegarder manifest
  const manifestPath = `storage-migration-manifest-${Date.now()}.json`;
  await fs.writeFile(manifestPath, JSON.stringify({
    timestamp: new Date().toISOString(),
    dryRun: DRY_RUN,
    maxSizeMB: MAX_SIZE_MB,
    stats: {
      total: totalFiles,
      success: successCount,
      errors: errorCount,
      skipped: skippedCount,
      duration: duration
    },
    files: manifest,
    errors: errorLog
  }, null, 2));

  console.log(`📄 Manifest sauvegardé : ${manifestPath}\n`);

  if (errorCount > 0) {
    console.log('⚠️  Erreurs détaillées dans le manifest JSON');
  }

  rl.close();
}

function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

main().catch(err => {
  console.error('❌ Erreur fatale:', err);
  rl.close();
  process.exit(1);
});
