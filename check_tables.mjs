import { createClient } from '@supabase/supabase-js';
const sb = createClient(
  'https://kzyjrooaehubmkrfvpob.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6eWpyb29hZWh1Ym1rcmZ2cG9iIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3OTQ3ODYzNSwiZXhwIjoyMDk1MDU0NjM1fQ.nX7U1ffOr4UbUw2VaZKP_Bh5fsIAXsxdCqGMS5HzhX0',
  { auth: { persistSession: false } }
);
for(const t of ['tasks','members','projects','sprint_config']){
  const {data,error} = await sb.from(t).select('id').limit(1);
  console.log(t+':', error ? 'MISSING — '+error.message : 'OK');
}
