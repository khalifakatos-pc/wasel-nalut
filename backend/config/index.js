const path = require('path');
const fs = require('fs');
const { Pool } = require('pg');

// Load environment variables from .env if present
const envPath = path.join(__dirname, '../.env');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf-8');
  envContent.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const [key, ...vals] = trimmed.split('=');
      if (key && vals.length > 0) {
        process.env[key.trim()] = vals.join('=').trim();
      }
    }
  });
}

const config = {
  PORT: process.env.PORT || 3000,
  JWT_SECRET: process.env.JWT_SECRET || 'wasel-nalut-secure-jwt-key-2026-prod',
  SEED_DATA_PATH: path.join(__dirname, '../seed_data.json'),
  PROXIMITY_THRESHOLD_METERS: 200,
  SYSTEM_WALLETS: {
    ESCROW: '00000000-0000-0000-0000-000000000001',
    REVENUE: '00000000-0000-0000-0000-000000000002',
  },
};

let pgPool = null;
const DATABASE_URL = process.env.DATABASE_URL;
if (DATABASE_URL) {
  try {
    pgPool = new Pool({
      connectionString: DATABASE_URL,
      ssl: DATABASE_URL.includes('localhost') ? false : { rejectUnauthorized: false },
      max: 20,
      connectionTimeoutMillis: 5000,
      idleTimeoutMillis: 30000
    });
    console.log('[PostgreSQL] Initialized pg pool with cloud database');
  } catch (err) {
    console.error('[PostgreSQL] Pool initialization error:', err.message);
  }
}

module.exports = {
  config,
  pgPool
};
