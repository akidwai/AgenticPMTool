import { readFileSync } from 'fs';
import { createSupabaseTools } from './supabase_tls.mjs';

const SB_URL = process.env.SUPABASE_URL || 'https://kzyjrooaehubmkrfvpob.supabase.co';
const SB_KEY = process.env.SUPABASE_SERVICE_KEY;

const { fetch: apiFetch } = createSupabaseTools(SB_URL, SB_KEY);

const sql = readFileSync('./migration_compat.sql', 'utf8');
const statements = sql
  .split(';')
  .map((statement) => statement.trim())
  .filter((statement) => statement.length > 0 && !statement.startsWith('--'));

console.log(`Running ${statements.length} SQL statements...`);

let passed = 0;
let failed = 0;

for (const stmt of statements) {
  try {
    const res = await apiFetch(`${SB_URL}/pg/v1/query`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${SB_KEY}`,
        apikey: SB_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query: stmt + ';' }),
    });
    if (res.ok) {
      passed++;
    } else {
      const err = await res.text();
      console.error(`FAIL (${res.status}): ${stmt.slice(0, 60)}...\n  -> ${err.slice(0, 120)}`);
      failed++;
    }
  } catch (error) {
    console.error(`ERROR: ${stmt.slice(0, 60)}...\n  -> ${error.message}`);
    failed++;
  }
}

console.log(`\nDone: ${passed} passed, ${failed} failed`);

