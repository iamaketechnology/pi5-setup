// =============================================================================
// PI5 Control Center - Secrets Manager
// =============================================================================
// Version: 1.0.0
// Description: Unified interface for multiple secret backends
// Supported: macOS Keychain, 1Password, Bitwarden, Vault, pass
// =============================================================================

const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

class SecretsManager {
  constructor(backend = null) {
    // Auto-detect backend or use provided
    this.backend = backend || process.env.SECRETS_BACKEND || 'keychain';
    console.log(`🔐 Secrets Manager initialized (backend: ${this.backend})`);
  }

  // =============================================================================
  // macOS Keychain Backend
  // =============================================================================

  async _keychainGet(account, service) {
    try {
      const { stdout } = await execPromise(
        `security find-generic-password -a "${account}" -s "${service}" -w 2>/dev/null`
      );
      return stdout.trim();
    } catch (error) {
      throw new Error(`Keychain: Secret not found (${service})`);
    }
  }

  async _keychainSet(account, service, password) {
    // Delete existing first (ignore errors)
    await execPromise(
      `security delete-generic-password -a "${account}" -s "${service}" 2>/dev/null || true`
    );

    // Add new
    await execPromise(
      `security add-generic-password -a "${account}" -s "${service}" -w "${password}" -T ""`
    );
  }

  async _keychainDelete(account, service) {
    await execPromise(
      `security delete-generic-password -a "${account}" -s "${service}"`
    );
  }

  // =============================================================================
  // 1Password Backend
  // =============================================================================

  async _opGet(itemName, field = 'password') {
    try {
      const { stdout } = await execPromise(
        `op item get "${itemName}" --fields ${field} 2>/dev/null`
      );
      return stdout.trim();
    } catch (error) {
      throw new Error(`1Password: Secret not found (${itemName})`);
    }
  }

  async _opSet(itemName, data) {
    // Create item (simplified - adjust for your needs)
    const json = JSON.stringify({
      title: itemName,
      category: 'login',
      fields: Object.entries(data).map(([k, v]) => ({
        id: k,
        type: 'concealed',
        value: v
      }))
    });

    await execPromise(`op item create '${json}'`);
  }

  // =============================================================================
  // Bitwarden Backend
  // =============================================================================

  async _bwGet(itemName, field = 'password') {
    const session = process.env.BW_SESSION;
    if (!session) {
      throw new Error('Bitwarden: BW_SESSION not set. Run: export BW_SESSION=$(bw unlock --raw)');
    }

    try {
      const { stdout } = await execPromise(
        `bw get ${field} "${itemName}" --session ${session} 2>/dev/null`
      );
      return stdout.trim();
    } catch (error) {
      throw new Error(`Bitwarden: Secret not found (${itemName})`);
    }
  }

  // =============================================================================
  // HashiCorp Vault Backend
  // =============================================================================

  async _vaultGet(path, field = null) {
    const addr = process.env.VAULT_ADDR || 'http://127.0.0.1:8200';
    const token = process.env.VAULT_TOKEN;

    if (!token) {
      throw new Error('Vault: VAULT_TOKEN not set');
    }

    try {
      const cmd = field
        ? `vault kv get -field=${field} secret/${path}`
        : `vault kv get -format=json secret/${path}`;

      const { stdout } = await execPromise(cmd, {
        env: { ...process.env, VAULT_ADDR: addr, VAULT_TOKEN: token }
      });

      if (field) {
        return stdout.trim();
      } else {
        const json = JSON.parse(stdout);
        return json.data.data;
      }
    } catch (error) {
      throw new Error(`Vault: Secret not found (${path})`);
    }
  }

  // =============================================================================
  // pass (Unix password store) Backend
  // =============================================================================

  async _passGet(path) {
    try {
      const { stdout } = await execPromise(`pass show ${path} 2>/dev/null`);
      return stdout.trim();
    } catch (error) {
      throw new Error(`pass: Secret not found (${path})`);
    }
  }

  async _passSet(path, password) {
    await execPromise(`echo "${password}" | pass insert -e ${path}`);
  }

  // =============================================================================
  // Unified Interface
  // =============================================================================

  /**
   * Get SSH password for a Pi
   * @param {string} hostname - Pi hostname (e.g., 'pi5.local')
   * @param {string} username - SSH username (default: 'pi')
   * @returns {Promise<string>} SSH password
   */
  async getSSHPassword(hostname, username = 'pi') {
    switch (this.backend) {
      case 'keychain':
        return this._keychainGet(username, hostname);

      case '1password':
      case 'op':
        return this._opGet(`Pi ${hostname}`, 'password');

      case 'bitwarden':
      case 'bw':
        return this._bwGet(`Pi ${hostname}`, 'password');

      case 'vault':
        return this._vaultGet(`pi/${hostname}`, 'password');

      case 'pass':
        return this._passGet(`${hostname}/ssh`);

      default:
        throw new Error(`Unknown secrets backend: ${this.backend}`);
    }
  }

  /**
   * Store SSH password for a Pi
   * @param {string} hostname - Pi hostname
   * @param {string} password - SSH password
   * @param {string} username - SSH username (default: 'pi')
   */
  async setSSHPassword(hostname, password, username = 'pi') {
    switch (this.backend) {
      case 'keychain':
        return this._keychainSet(username, hostname, password);

      case 'pass':
        return this._passSet(`${hostname}/ssh`, password);

      default:
        throw new Error(`setSSHPassword not implemented for backend: ${this.backend}`);
    }
  }

  /**
   * Get API key for a service
   * @param {string} service - Service name (e.g., 'supabase')
   * @param {string} keyName - Key name (e.g., 'service_role_key')
   * @returns {Promise<string>} API key
   */
  async getAPIKey(service, keyName = 'api_key') {
    switch (this.backend) {
      case 'keychain':
        return this._keychainGet(service, keyName);

      case '1password':
      case 'op':
        return this._opGet(`${service} API Key`, 'credential');

      case 'bitwarden':
      case 'bw':
        return this._bwGet(`${service} API Key`, 'password');

      case 'vault':
        return this._vaultGet(service, keyName);

      case 'pass':
        return this._passGet(`${service}/${keyName}`);

      default:
        throw new Error(`Unknown secrets backend: ${this.backend}`);
    }
  }

  /**
   * Get multiple secrets from a service
   * @param {string} service - Service name
   * @returns {Promise<Object>} All secrets for service
   */
  async getServiceSecrets(service) {
    switch (this.backend) {
      case 'vault':
        return this._vaultGet(service);

      default:
        throw new Error(`getServiceSecrets only supported for Vault backend`);
    }
  }

  /**
   * Check if secret exists
   * @param {string} key - Secret key
   * @returns {Promise<boolean>}
   */
  async exists(key) {
    try {
      await this.getSSHPassword(key);
      return true;
    } catch {
      return false;
    }
  }
}

// =============================================================================
// Usage Examples
// =============================================================================

/*

// Example 1: Using with Pi Manager
const secretsManager = new SecretsManager('keychain');

const password = await secretsManager.getSSHPassword('pi5.local', 'pi');
await ssh.connect({
  host: 'pi5.local',
  username: 'pi',
  password: password
});

// Example 2: Get Supabase keys
const serviceRoleKey = await secretsManager.getAPIKey('supabase', 'service_role_key');

// Example 3: Store new password
await secretsManager.setSSHPassword('pi-new.local', 'strong_password');

// Example 4: Use environment variable to select backend
// export SECRETS_BACKEND=vault
const secrets = new SecretsManager(); // Auto-detects from env

// Example 5: Vault with multiple secrets
const supabaseSecrets = await secretsManager.getServiceSecrets('supabase');
console.log(supabaseSecrets);
// { service_role_key: '...', anon_key: '...', url: '...' }

*/

// =============================================================================
// Export
// =============================================================================

module.exports = SecretsManager;
