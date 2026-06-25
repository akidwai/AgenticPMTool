import { readFileSync, existsSync } from 'fs';
import { dirname, join, resolve } from 'path';
import { Agent } from 'undici';
import { createClient } from '@supabase/supabase-js';
import { fileURLToPath } from 'url';

const MODULE_DIR = dirname(fileURLToPath(import.meta.url));

function stripQuotes(value) {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }
  return value;
}

function loadDotEnv() {
  const envCandidates = [
    resolve(process.cwd(), '.env'),
    join(MODULE_DIR, '.env'),
  ];
  const envPath = envCandidates.find((candidate) => existsSync(candidate));
  if (!envPath) {
    return;
  }

  const raw = readFileSync(envPath, 'utf8');
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }
    const idx = trimmed.indexOf('=');
    if (idx === -1) {
      continue;
    }
    const key = trimmed.slice(0, idx).trim();
    const value = stripQuotes(trimmed.slice(idx + 1).trim());
    if (key && process.env[key] == null) {
      process.env[key] = value;
    }
  }
}

function firstEnv(...names) {
  for (const name of names) {
    const value = process.env[name];
    if (value && value.trim()) {
      return value.trim();
    }
  }
  return '';
}

function loadCustomCa() {
  const rawCaPath = firstEnv('HFH_CA_CERT_PATH', 'NODE_EXTRA_CA_CERTS', 'SSL_CERT_FILE');
  if (!rawCaPath) {
    return { ca: undefined, caPath: '' };
  }
  const caPath = resolve(rawCaPath);
  if (!existsSync(caPath)) {
    throw new Error(`CA certificate file was not found: ${caPath}`);
  }
  return { ca: readFileSync(caPath, 'utf8'), caPath };
}

function isEnabled(value) {
  return /^(1|true|yes)$/i.test(String(value || '').trim());
}

function buildTlsMessage(err, caPath, allowInsecure) {
  const detail = err?.cause?.message || err?.message || String(err);
  const lines = [
    'Unable to connect to API: SSL certificate verification failed.',
    `TLS detail: ${detail}`,
    'If you are behind a proxy or corporate SSL inspection, provide your root CA certificate to Node.',
    'Recommended:',
    '  1. Export the corporate/root CA as a PEM file.',
    '  2. Set HFH_CA_CERT_PATH=path/to/corporate-ca.pem',
    '  3. Re-run the script.',
  ];
  if (caPath) {
    lines.push(`Current CA path: ${caPath}`);
  }
  if (allowInsecure) {
    lines.push('Warning: HFH_ALLOW_INSECURE_SSL is enabled, but the TLS handshake still failed.');
  } else {
    lines.push('Temporary fallback: set HFH_ALLOW_INSECURE_SSL=true only for short-lived local debugging.');
  }
  return lines.join('\n');
}

export function createSupabaseTools(url, key) {
  loadDotEnv();
  const allowInsecure = isEnabled(process.env.HFH_ALLOW_INSECURE_SSL);
  const { ca, caPath } = loadCustomCa();

  // Only use undici dispatcher when a custom CA cert or insecure mode is configured.
  // Otherwise fall back to Node's native fetch so --use-system-ca works transparently.
  const needsCustomDispatcher = ca || allowInsecure;

  let apiFetch;
  if (needsCustomDispatcher) {
    const dispatcher = new Agent({
      connect: {
        ca: ca || undefined,
        rejectUnauthorized: !allowInsecure,
      },
    });
    apiFetch = async function (input, init = {}) {
      try {
        return await fetch(input, { ...init, dispatcher });
      } catch (err) {
        throw new Error(buildTlsMessage(err, caPath, allowInsecure), { cause: err });
      }
    };
  } else {
    apiFetch = async function (input, init = {}) {
      try {
        return await fetch(input, init);
      } catch (err) {
        throw new Error(buildTlsMessage(err, caPath, allowInsecure), { cause: err });
      }
    };
  }

  const client = createClient(url, key, {
    auth: { persistSession: false },
    global: { fetch: apiFetch },
  });

  return { client, fetch: apiFetch };
}

export function describeTlsConfig() {
  loadDotEnv();
  const rawCaPath = firstEnv('HFH_CA_CERT_PATH', 'NODE_EXTRA_CA_CERTS', 'SSL_CERT_FILE');
  const resolvedCaPath = rawCaPath ? resolve(rawCaPath) : '';
  const envCandidates = [
    resolve(process.cwd(), '.env'),
    join(MODULE_DIR, '.env'),
  ];
  return {
    cwd: process.cwd(),
    envFileFound: envCandidates.find((candidate) => existsSync(candidate)) || '',
    caPathConfigured: rawCaPath || '',
    caPathResolved: resolvedCaPath,
    caPathExists: resolvedCaPath ? existsSync(resolvedCaPath) : false,
    allowInsecure: isEnabled(process.env.HFH_ALLOW_INSECURE_SSL),
  };
}
