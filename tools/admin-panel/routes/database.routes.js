const fs = require('fs');
const os = require('os');
const path = require('path');

function registerDatabaseRoutes({ app, piManager, sqlSource, middlewares }) {
  const { authOnly, adminOnly } = middlewares;

  app.post('/api/database/security-audit', ...authOnly, async (req, res) => {
    try {
      const { piId } = req.query;

      const scriptPath = path.join(__dirname, '../../../common-scripts/security/audit-all-databases.sh');

      if (!fs.existsSync(scriptPath)) {
        throw new Error('Security audit script not found');
      }

      await piManager.uploadFile(scriptPath, '/tmp/audit-all-databases.sh', piId);

      const commands = [
        'chmod +x /tmp/audit-all-databases.sh',
        'sudo bash /tmp/audit-all-databases.sh 2>&1'
      ];

      const result = await piManager.executeCommand(commands.join(' && '), piId);

      const output = result.stdout || result.stderr || '';
      const cleanOutput = output.replace(/\x1b\[[0-9;]*m/g, '');

      const totalMatch = cleanOutput.match(/Total databases audited:\s*(\d+)/);
      const secureMatch = cleanOutput.match(/Secure databases:\s*(\d+)/);
      const vulnerableMatch = cleanOutput.match(/Vulnerable databases:\s*(\d+)/);

      const totalDatabases = totalMatch ? parseInt(totalMatch[1]) : 0;
      const secureDatabases = secureMatch ? parseInt(secureMatch[1]) : 0;
      const vulnerableDatabases = vulnerableMatch ? parseInt(vulnerableMatch[1]) : 0;

      const databaseDetails = [];
      const dbRegex = /📊 Database: (\w+)\s*\(Container: ([\w-]+)\)[\s\S]*?(🎉 DATABASE FULLY SECURE|❌ \d+ CRITICAL ISSUE|⚠️.*?warning)/g;
      let match;
      while ((match = dbRegex.exec(cleanOutput)) !== null) {
        databaseDetails.push({
          name: match[1],
          container: match[2],
          status: match[3].includes('SECURE') ? 'secure' : 'vulnerable'
        });
      }

      const allSecure = vulnerableDatabases === 0;

      res.json({
        success: true,
        secure: allSecure,
        totalDatabases,
        secureDatabases,
        vulnerableDatabases,
        databases: databaseDetails,
        fullOutput: output,
        message: allSecure
          ? `🎉 All ${totalDatabases} database(s) are secure!`
          : `⚠️ ${vulnerableDatabases} of ${totalDatabases} database(s) have security issues`
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });

  app.get('/api/database/status', ...authOnly, async (req, res) => {
    try {
      const ssh = await piManager.getSSH();

      if (!ssh) {
        return res.json({
          success: false,
          error: 'No Pi connected',
          schema_exists: false
        });
      }

      const pgPassResult = await ssh.execCommand(
        'docker exec supabase-db env | grep "^POSTGRES_PASSWORD=" | cut -d"=" -f2'
      );
      const pgPassword = pgPassResult.stdout.trim();

      if (!pgPassword) {
        throw new Error('Failed to retrieve Postgres password');
      }

      const checkSchemaCmd = `docker exec -e PGPASSWORD="${pgPassword}" supabase-db psql -U postgres -d postgres -t -c "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'control_center');"`;

      const schemaResult = await ssh.execCommand(checkSchemaCmd);
      const schemaExists = schemaResult.stdout.trim() === 't';

      let tableCount = 0;
      let piCount = 0;
      let piNames = '';

      if (schemaExists) {
        const countTablesCmd = `docker exec -e PGPASSWORD="${pgPassword}" supabase-db psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'control_center';"`;

        const tablesResult = await ssh.execCommand(countTablesCmd);
        tableCount = parseInt(tablesResult.stdout.trim()) || 0;

        const countPisCmd = `docker exec -e PGPASSWORD="${pgPassword}" supabase-db psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM control_center.pis;"`;

        const pisResult = await ssh.execCommand(countPisCmd);
        piCount = parseInt(pisResult.stdout.trim()) || 0;

        const getPiNamesCmd = `docker exec -e PGPASSWORD="${pgPassword}" supabase-db psql -U postgres -d postgres -t -c "SELECT string_agg(name, ', ') FROM control_center.pis;"`;

        const namesResult = await ssh.execCommand(getPiNamesCmd);
        piNames = namesResult.stdout.trim() || 'Aucun';
      }

      res.json({
        success: true,
        schema_exists: schemaExists,
        table_count: tableCount,
        pi_count: piCount,
        pi_names: piNames
      });
    } catch (error) {
      console.error('Error checking database status:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });

  app.post('/api/database/install', ...adminOnly, async (req, res) => {
    try {
      const ssh = await piManager.getSSH();

      if (!ssh) {
        return res.json({
          success: false,
          error: 'No Pi connected'
        });
      }

      const pgPassResult = await ssh.execCommand(
        'docker exec supabase-db env | grep "^POSTGRES_PASSWORD=" | cut -d"=" -f2'
      );
      const pgPassword = pgPassResult.stdout.trim();

      if (!pgPassword) {
        throw new Error('Failed to retrieve Postgres password');
      }

      const executeSqlFile = async (filename, description) => {
        console.log(`Executing ${filename} from ${sqlSource.getConfig().source}...`);

        const sqlContent = await sqlSource.getSqlContent(filename);

        const tmpDir = os.tmpdir();
        const localTmpFile = path.join(tmpDir, `pi5-${filename}`);
        fs.writeFileSync(localTmpFile, sqlContent, 'utf8');

        const remoteTmpFile = `/tmp/${filename}`;
        await ssh.putFile(localTmpFile, remoteTmpFile);

        const command = `cat ${remoteTmpFile} | docker exec -i -e PGPASSWORD="${pgPassword}" supabase-db psql -U postgres -d postgres -f -`;

        const result = await ssh.execCommand(command);

        console.log(`  ${filename} result: code=${result.code}`);
        if (result.stdout) console.log(`  stdout: ${result.stdout.substring(0, 200)}`);
        if (result.stderr) console.log(`  stderr: ${result.stderr.substring(0, 200)}`);

        await ssh.execCommand(`rm -f ${remoteTmpFile}`);
        fs.unlinkSync(localTmpFile);

        if (result.code !== 0) {
          throw new Error(`${description} failed: ${result.stderr}`);
        }

        return result;
      };

      await executeSqlFile('schema.sql', 'Schema installation');
      await executeSqlFile('policies.sql', 'Policies installation');
      await executeSqlFile('seed.sql', 'Seed installation');

      console.log('Exposing control_center schema to PostgREST API...');
      try {
        await executeSqlFile('expose-schema.sql', 'Schema exposure');
      } catch (error) {
        console.warn('Warning: Schema exposure failed:', error.message);
      }

      const countPisCmd = `docker exec -e PGPASSWORD="${pgPassword}" supabase-db psql -U postgres -d postgres -t -c "SELECT COUNT(*) FROM control_center.pis;"`;

      const pisResult = await ssh.execCommand(countPisCmd);
      const piCount = parseInt(pisResult.stdout.trim()) || 0;

      console.log(`✅ Installation completed: ${piCount} Pi(s) migrated to Supabase`);

      res.json({
        success: true,
        message: 'Schema installed successfully',
        pi_count: piCount
      });
    } catch (error) {
      console.error('Error installing database schema:', error);
      res.status(500).json({
        success: false,
        error: error.message
      });
    }
  });
}

module.exports = {
  registerDatabaseRoutes
};
