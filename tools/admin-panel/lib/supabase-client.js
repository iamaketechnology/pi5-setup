// =============================================================================
// Supabase Client - Wrapper for @supabase/supabase-js
// =============================================================================
// Version: 1.0.0
// Description: Centralized Supabase client with helper methods
// =============================================================================

require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

// =============================================================================
// Configuration
// =============================================================================

const SUPABASE_URL = process.env.SUPABASE_URL || 'http://localhost:8001';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!SUPABASE_SERVICE_KEY) {
  console.warn('⚠️ SUPABASE_SERVICE_KEY not set in .env');
  console.warn('   Supabase features will be unavailable');
}

// =============================================================================
// Client Initialization
// =============================================================================

let supabase = null;

if (SUPABASE_SERVICE_KEY) {
  supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });

  console.log('✅ Supabase client initialized');
  console.log(`   URL: ${SUPABASE_URL}`);
} else {
  console.log('⏭️ Supabase client not initialized (no SERVICE_KEY)');
}

// =============================================================================
// Helper Methods
// =============================================================================

class SupabaseClient {
  constructor() {
    this.client = supabase;
    this.enabled = !!supabase;
  }

  /**
   * Check if Supabase is configured and available
   */
  isEnabled() {
    return this.enabled;
  }

  /**
   * Get all Pis from control_center.pis
   */
  async getPis() {
    if (!this.enabled) {
      throw new Error('Supabase not configured');
    }

    const { data, error } = await this.client
      .schema('control_center')
      .from('pis')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching Pis:', error);
      throw error;
    }

    return data;
  }

  /**
   * Get a single Pi by ID
   */
  async getPi(piId) {
    if (!this.enabled) {
      throw new Error('Supabase not configured');
    }

    const { data, error } = await this.client
      .schema('control_center')
      .from('pis')
      .select('*')
      .eq('id', piId)
      .single();

    if (error) {
      console.error('Error fetching Pi:', error);
      throw error;
    }

    return data;
  }

  /**
   * Get Pi by hostname
   */
  async getPiByHostname(hostname) {
    if (!this.enabled) {
      throw new Error('Supabase not configured');
    }

    const { data, error } = await this.client
      .schema('control_center')
      .from('pis')
      .select('*')
      .eq('hostname', hostname)
      .single();

    if (error && error.code !== 'PGRST116') { // PGRST116 = no rows
      console.error('Error fetching Pi by hostname:', error);
      throw error;
    }

    return data;
  }

  /**
   * Get Pi by token (for pairing)
   */
  async getPiByToken(token) {
    if (!this.enabled) {
      throw new Error('Supabase not configured');
    }

    const { data, error } = await this.client
      .schema('control_center')
      .from('pis')
      .select('*')
      .eq('token', token)
      .single();

    if (error && error.code !== 'PGRST116') {
      console.error('Error fetching Pi by token:', error);
      throw error;
    }

    return data;
  }

  /**
   * Create new Pi (bootstrap registration)
   */
  async createPi(piData) {
    if (!this.enabled) {
      throw new Error('Supabase not configured');
    }

    const { data, error } = await this.client
      .schema('control_center')
      .from('pis')
      .insert([piData])
      .select()
      .single();

    if (error) {
      console.error('Error creating Pi:', error);
      throw error;
    }

    return data;
  }

  /**
   * Update Pi
   */
  async updatePi(piId, updates) {
    if (!this.enabled) {
      throw new Error('Supabase not configured');
    }

    const { data, error } = await this.client
      .schema('control_center')
      .from('pis')
      .update(updates)
      .eq('id', piId)
      .select()
      .single();

    if (error) {
      console.error('Error updating Pi:', error);
      throw error;
    }

    return data;
  }

  /**
   * Update Pi last_seen timestamp
   */
  async updatePiLastSeen(piId) {
    if (!this.enabled) return null;

    return this.updatePi(piId, { last_seen: new Date().toISOString() });
  }

  /**
   * Delete Pi
   */
  async deletePi(piId) {
    if (!this.enabled) {
      throw new Error('Supabase not configured');
    }

    const { error } = await this.client
      .schema('control_center')
      .from('pis')
      .delete()
      .eq('id', piId);

    if (error) {
      console.error('Error deleting Pi:', error);
      throw error;
    }

    return true;
  }

  /**
   * Add installation record
   */
  async addInstallation(installData) {
    if (!this.enabled) {
      throw new Error('Supabase not configured');
    }

    const { data, error } = await this.client
      .schema('control_center')
      .from('installations')
      .insert([installData])
      .select()
      .single();

    if (error) {
      console.error('Error adding installation:', error);
      throw error;
    }

    return data;
  }

  /**
   * Update installation status
   */
  async updateInstallation(installationId, updates) {
    if (!this.enabled) {
      throw new Error('Supabase not configured');
    }

    const { data, error } = await this.client
      .schema('control_center')
      .from('installations')
      .update(updates)
      .eq('id', installationId)
      .select()
      .single();

    if (error) {
      console.error('Error updating installation:', error);
      throw error;
    }

    return data;
  }

  /**
   * Get installation history for a Pi
   */
  async getInstallations(piId, limit = 50) {
    if (!this.enabled) {
      throw new Error('Supabase not configured');
    }

    const { data, error} = await this.client
      .schema('control_center')
      .from('installations')
      .select('*')
      .eq('pi_id', piId)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) {
      console.error('Error fetching installations:', error);
      throw error;
    }

    return data;
  }

  /**
   * Add system stats
   */
  async addSystemStats(statsData) {
    if (!this.enabled) return null;

    const { data, error } = await this.client
      .schema('control_center')
      .from('system_stats')
      .insert([statsData])
      .select()
      .single();

    if (error) {
      console.error('Error adding system stats:', error);
      // Don't throw, just log (stats are non-critical)
      return null;
    }

    return data;
  }

  /**
   * Get recent system stats for a Pi
   */
  async getSystemStats(piId, minutes = 60) {
    if (!this.enabled) {
      throw new Error('Supabase not configured');
    }

    const cutoff = new Date(Date.now() - minutes * 60 * 1000).toISOString();

    const { data, error } = await this.client
      .schema('control_center')
      .from('system_stats')
      .select('*')
      .eq('pi_id', piId)
      .gte('collected_at', cutoff)
      .order('collected_at', { ascending: true });

    if (error) {
      console.error('Error fetching system stats:', error);
      throw error;
    }

    return data;
  }

  /**
   * Check if schema exists
   */
  async checkSchema() {
    if (!this.enabled) return false;

    try {
      // Try to select from pis table
      const { error } = await this.client
        .schema('control_center')
        .from('pis')
        .select('count', { count: 'exact', head: true });

      return !error;
    } catch (error) {
      return false;
    }
  }
}

// Export singleton instance
const supabaseClient = new SupabaseClient();
module.exports = supabaseClient;
