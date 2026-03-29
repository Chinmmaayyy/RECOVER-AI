const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

// Try all AWS regions
const REGIONS = [
  'ap-south-1', 'us-east-1', 'us-west-1', 'us-west-2',
  'eu-west-1', 'eu-west-2', 'eu-central-1',
  'ap-southeast-1', 'ap-northeast-1', 'ap-southeast-2',
];
const CONFIGS = REGIONS.map(region => ({
  name: `Pooler (${region})`,
  host: `aws-0-${region}.pooler.supabase.com`,
  port: 6543,
  database: 'postgres',
  user: 'postgres.fqjriojizqnevfojirss',
  password: 'Chinmay10@10',
  ssl: { rejectUnauthorized: false },
}));

const migrations = [
  '001_initial_schema.sql',
  '002_seed_demo_data.sql',
  '003_streak_function.sql',
];

async function tryConnect() {
  for (const config of CONFIGS) {
    const { name, ...pgConfig } = config;
    const c = new Client(pgConfig);
    try {
      console.log(`Trying ${name} (${pgConfig.host}:${pgConfig.port})...`);
      await Promise.race([
        c.connect(),
        new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), 8000)),
      ]);
      console.log(`Connected via ${name}!`);
      return c;
    } catch (err) {
      console.log(`  ${name} failed: ${err.message}`);
      try { await c.end(); } catch {}
    }
  }
  return null;
}

async function run() {
  const client = await tryConnect();
  if (!client) {
    console.error('\nAll connection methods failed.');
    process.exit(1);
  }

  for (const file of migrations) {
    const filePath = path.join(__dirname, 'supabase', 'migrations', file);
    const sql = fs.readFileSync(filePath, 'utf8');
    console.log(`\nRunning ${file}...`);
    try {
      await client.query(sql);
      console.log(`  ${file} — SUCCESS`);
    } catch (err) {
      console.error(`  ${file} — ERROR: ${err.message}`);
    }
  }

  await client.end();
  console.log('\nDone. All migrations executed.');
}

run();
