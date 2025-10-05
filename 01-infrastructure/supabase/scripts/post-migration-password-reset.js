#!/usr/bin/env node

/**
 * Script de réinitialisation des mots de passe après migration
 *
 * Usage:
 *   node post-migration-password-reset.js
 *
 * Ce script envoie un email de réinitialisation à tous les utilisateurs
 * après une migration Supabase Cloud → Pi
 */

const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function main() {
  console.log('\n🔐 Réinitialisation des mots de passe utilisateurs\n');
  console.log('═'.repeat(50));
  console.log('\nCe script envoie un email de reset à tous vos utilisateurs.');
  console.log('Prérequis : Avoir configuré SMTP dans Supabase\n');

  // Configuration Supabase Pi
  const supabaseUrl = await question('URL Supabase Pi (ex: http://192.168.1.74:8000): ');
  const serviceRoleKey = await question('Service Role Key Pi (voir ~/stacks/supabase/.env): ');

  // Import dynamique de Supabase
  const { createClient } = await import('@supabase/supabase-js');

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });

  console.log('\n📋 Récupération de la liste des utilisateurs...\n');

  // Récupérer tous les users
  const { data: users, error } = await supabase.auth.admin.listUsers();

  if (error) {
    console.error('❌ Erreur:', error.message);
    process.exit(1);
  }

  if (!users || users.users.length === 0) {
    console.log('⚠️  Aucun utilisateur trouvé.');
    process.exit(0);
  }

  console.log(`✅ ${users.users.length} utilisateurs trouvés\n`);

  // Afficher la liste
  console.log('Liste des utilisateurs:');
  users.users.forEach((user, i) => {
    console.log(`  ${i + 1}. ${user.email} (créé: ${new Date(user.created_at).toLocaleDateString()})`);
  });

  console.log('\n═'.repeat(50));
  const confirm = await question('\nEnvoyer un email de reset à TOUS ces utilisateurs ? (y/n): ');

  if (confirm.toLowerCase() !== 'y') {
    console.log('\n❌ Opération annulée');
    process.exit(0);
  }

  console.log('\n📧 Envoi des emails de réinitialisation...\n');

  let successCount = 0;
  let errorCount = 0;

  for (const user of users.users) {
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(user.email, {
        redirectTo: `${supabaseUrl}/auth/v1/verify`
      });

      if (error) {
        console.log(`❌ ${user.email}: ${error.message}`);
        errorCount++;
      } else {
        console.log(`✅ ${user.email}: Email envoyé`);
        successCount++;
      }

      // Pause pour éviter rate limiting
      await new Promise(resolve => setTimeout(resolve, 500));
    } catch (err) {
      console.log(`❌ ${user.email}: ${err.message}`);
      errorCount++;
    }
  }

  console.log('\n═'.repeat(50));
  console.log('\n📊 Résumé:');
  console.log(`  ✅ Succès: ${successCount}`);
  console.log(`  ❌ Erreurs: ${errorCount}`);
  console.log(`  📧 Total: ${users.users.length}\n`);

  if (errorCount > 0) {
    console.log('⚠️  Vérifiez la configuration SMTP dans ~/stacks/supabase/.env:');
    console.log('  - SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS');
    console.log('  - SMTP_ADMIN_EMAIL (adresse expéditeur)\n');
  }

  rl.close();
}

main().catch(err => {
  console.error('❌ Erreur:', err);
  rl.close();
  process.exit(1);
});
