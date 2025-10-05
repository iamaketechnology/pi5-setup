#!/usr/bin/env node

/**
 * Script de migration des fichiers Storage
 *
 * Usage:
 *   node post-migration-storage.js
 *
 * Ce script migre tous les fichiers depuis Supabase Cloud vers le Pi
 */

const readline = require('readline');
const fs = require('fs').promises;
const path = require('path');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function main() {
  console.log('\n📦 Migration des fichiers Storage\n');
  console.log('═'.repeat(50));
  console.log('\nCe script migre vos fichiers de Supabase Cloud vers le Pi.\n');

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

  for (const bucket of buckets) {
    console.log(`\n📦 Bucket: ${bucket.name}`);
    console.log('─'.repeat(50));

    // Créer bucket sur Pi s'il n'existe pas
    const { error: createError } = await piClient.storage.createBucket(bucket.name, {
      public: bucket.public
    });

    if (createError && !createError.message.includes('already exists')) {
      console.log(`  ⚠️  Erreur création bucket: ${createError.message}`);
      continue;
    }

    // Lister fichiers du bucket
    const { data: files, error: listError } = await cloudClient.storage
      .from(bucket.name)
      .list('', { limit: 1000, sortBy: { column: 'name', order: 'asc' } });

    if (listError) {
      console.log(`  ❌ Erreur liste fichiers: ${listError.message}`);
      continue;
    }

    if (!files || files.length === 0) {
      console.log('  📭 Aucun fichier');
      continue;
    }

    console.log(`  📁 ${files.length} fichiers trouvés\n`);
    totalFiles += files.length;

    for (const file of files) {
      try {
        // Télécharger depuis Cloud
        const { data: fileData, error: downloadError } = await cloudClient.storage
          .from(bucket.name)
          .download(file.name);

        if (downloadError) {
          console.log(`    ❌ ${file.name}: ${downloadError.message}`);
          errorCount++;
          continue;
        }

        // Upload vers Pi
        const { error: uploadError } = await piClient.storage
          .from(bucket.name)
          .upload(file.name, fileData, {
            contentType: file.metadata?.mimetype,
            upsert: true
          });

        if (uploadError) {
          console.log(`    ❌ ${file.name}: ${uploadError.message}`);
          errorCount++;
        } else {
          console.log(`    ✅ ${file.name} (${formatBytes(file.metadata?.size || 0)})`);
          successCount++;
        }

        // Pause pour éviter rate limiting
        await new Promise(resolve => setTimeout(resolve, 200));
      } catch (err) {
        console.log(`    ❌ ${file.name}: ${err.message}`);
        errorCount++;
      }
    }
  }

  console.log('\n═'.repeat(50));
  console.log('\n📊 Résumé migration:');
  console.log(`  ✅ Succès: ${successCount}/${totalFiles}`);
  console.log(`  ❌ Erreurs: ${errorCount}/${totalFiles}`);
  console.log(`  📦 Buckets: ${buckets.length}\n`);

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
  console.error('❌ Erreur:', err);
  rl.close();
  process.exit(1);
});
