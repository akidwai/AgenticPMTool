import { createSupabaseTools, describeTlsConfig } from './supabase_tls.mjs';

const tls = describeTlsConfig();
console.log('TLS config:', JSON.stringify(tls));

const { client: sb } = createSupabaseTools(
  'https://kzyjrooaehubmkrfvpob.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6eWpyb29hZWh1Ym1rcmZ2cG9iIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTQ3ODYzNSwiZXhwIjoyMDk1MDU0NjM1fQ.nX7U1ffOr4UbUw2VaZKP_Bh5fsIAXsxdCqGMS5HzhX0'
);

for (const table of ['tasks', 'members', 'projects', 'sprint_config']) {
  try {
    const { error } = await sb.from(table).select('id').limit(1);
    console.log(table + ':', error ? 'MISSING - ' + error.message : 'OK');
  } catch (error) {
    console.error(table + ':\n' + error.message);
    process.exitCode = 1;
    break;
  }
}
