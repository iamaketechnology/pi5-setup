// =============================================================================
// SQL Source Manager - Local or GitHub
// =============================================================================
// Manages SQL script sources for database installation
// Supports local files (dev) and GitHub raw URLs (production)
// =============================================================================

const fs = require('fs');
const path = require('path');
const https = require('https');

class SqlSourceManager {
  constructor() {
    this.source = process.env.SQL_SOURCE || 'local';
    this.githubRepo = process.env.GITHUB_SQL_REPO || 'https://github.com/iamaketechnology/pi5-setup';
    this.githubBranch = process.env.GITHUB_SQL_BRANCH || 'main';
    this.githubPath = process.env.GITHUB_SQL_PATH || 'tools/admin-panel/supabase';
    this.localPath = path.join(__dirname, '..', 'supabase');
  }

  /**
   * Get SQL content from configured source
   * @param {string} filename - SQL filename (e.g., 'schema.sql')
   * @returns {Promise<string>} SQL content
   */
  async getSqlContent(filename) {
    if (this.source === 'github') {
      return this.fetchFromGitHub(filename);
    } else {
      return this.readFromLocal(filename);
    }
  }

  /**
   * Read SQL from local file system
   * @param {string} filename
   * @returns {string} SQL content
   */
  readFromLocal(filename) {
    const filePath = path.join(this.localPath, filename);

    if (!fs.existsSync(filePath)) {
      throw new Error(`SQL file not found: ${filePath}`);
    }

    return fs.readFileSync(filePath, 'utf8');
  }

  /**
   * Fetch SQL from GitHub raw URL
   * @param {string} filename
   * @returns {Promise<string>} SQL content
   */
  async fetchFromGitHub(filename) {
    // Convert GitHub URL to raw.githubusercontent.com format
    const repoMatch = this.githubRepo.match(/github\.com\/([^\/]+)\/([^\/]+)/);

    if (!repoMatch) {
      throw new Error(`Invalid GitHub repo URL: ${this.githubRepo}`);
    }

    const [, owner, repo] = repoMatch;
    const rawUrl = `https://raw.githubusercontent.com/${owner}/${repo}/${this.githubBranch}/${this.githubPath}/${filename}`;

    return new Promise((resolve, reject) => {
      https.get(rawUrl, (res) => {
        if (res.statusCode !== 200) {
          reject(new Error(`Failed to fetch ${filename} from GitHub: HTTP ${res.statusCode}`));
          return;
        }

        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
        });

        res.on('end', () => {
          resolve(data);
        });
      }).on('error', (error) => {
        reject(new Error(`Network error fetching ${filename}: ${error.message}`));
      });
    });
  }

  /**
   * Get current source configuration
   * @returns {object} Current config
   */
  getConfig() {
    return {
      source: this.source,
      githubRepo: this.githubRepo,
      githubBranch: this.githubBranch,
      githubPath: this.githubPath,
      localPath: this.localPath
    };
  }

  /**
   * List available SQL files
   * @returns {Promise<string[]>} List of SQL filenames
   */
  async listFiles() {
    if (this.source === 'github') {
      // Return known files for GitHub (can't list directory via raw URLs)
      return ['schema.sql', 'policies.sql', 'seed.sql', 'expose-schema.sql'];
    } else {
      // List local directory
      const files = fs.readdirSync(this.localPath);
      return files.filter(f => f.endsWith('.sql'));
    }
  }
}

module.exports = new SqlSourceManager();
