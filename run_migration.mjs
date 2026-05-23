import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

const SB_URL = 'https://kzyjrooaehubmkrfvpob.supabase.co';
const SB_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6eWpyb29hZWh1Ym1rcmZ2cG9iIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTQ3ODYzNSwiZXhwIjoyMDk1MDU0NjM1fQ.nX7U1ffOr4UbUw2VaZKP_Bh5fsIAXsxdCqGMS5HzhX0';

const sb = createClient(SB_URL, SB_KEY, {
  auth: { persistSession: false }
});

// Split SQL into individual statements and run each via rpc
const sql = readFileSync('./migration_compat.sql', 'utf8');

// Use Supabase's pg endpoint via fetch
const statements = sql
  .split(';')
  .map(s => s.trim())
  .filter(s => s.length > 0 && !s.startsWith('--'));

console.log(`Running ${statements.length} SQL statements...`);

let passed = 0, failed = 0;
for (const stmt of statements) {
  try {
    const res = await fetch(`${SB_URL}/pg/v1/query`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SB_KEY}`,
        'apikey': SB_KEY,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query: stmt + ';' }),
    });
    if (res.ok) {
      passed++;
    } else {
      const err = await res.text();
      console.error(`FAIL (${res.status}): ${stmt.slice(0, 60)}...\n  → ${err.slice(0, 120)}`);
      failed++;
    }
  } catch (e) {
    console.error(`ERROR: ${stmt.slice(0, 60)}...\n  → ${e.message}`);
    failed++;
  }
}

console.log(`\nDone: ${passed} passed, ${failed} failed`);
