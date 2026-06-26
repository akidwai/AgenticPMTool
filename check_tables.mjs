import { createSupabaseTools, describeTlsConfig } from './supabase_tls.mjs';

const tls = describeTlsConfig();
console.log('TLS config:', JSON.stringify(tls));

const { client: sb } = createSupabaseTools(
  process.env.SUPABASE_URL || 'https://kzyjrooaehubmkrfvpob.supabase.co',
  process.env.SUPABASE_SERVICE_KEY
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
