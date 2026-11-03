#!/usr/bin/env node
// Small App Store Connect client. Credentials stay in the local environment/config.
import fs from 'node:fs';
import os from 'node:os';
import crypto from 'node:crypto';
import path from 'node:path';

const env = { ...process.env };
const config = env.ASC_ENV_FILE || path.join(os.homedir(), '.html-arcade/asc.env');
if (fs.existsSync(config)) {
  for (const raw of fs.readFileSync(config, 'utf8').split('\n')) {
    const line = raw.trim().replace(/^export\s+/, '');
    if (!line || line.startsWith('#')) continue;
    const i = line.indexOf('=');
    if (i > 0) env[line.slice(0, i)] = line.slice(i + 1).replace(/^(['"])(.*)\1$/, '$2');
  }
}
for (const field of ['ASC_KEY_ID', 'ASC_ISSUER_ID', 'ASC_KEY_PATH']) {
  if (!env[field]) throw new Error(`Missing ${field}. Set ASC_ENV_FILE or the ASC_* environment variables.`);
}
const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const payload = encode({ alg: 'ES256', kid: env.ASC_KEY_ID, typ: 'JWT' }) + '.' +
  encode({ iss: env.ASC_ISSUER_ID, iat: now - 10, exp: now + 900, aud: 'appstoreconnect-v1' });
const key = fs.readFileSync(env.ASC_KEY_PATH.replace(/^~/, os.homedir()));
const token = payload + '.' + crypto.sign('sha256', Buffer.from(payload), { key, dsaEncoding: 'ieee-p1363' }).toString('base64url');
const [method = 'GET', endpoint = '/v1/apps', jsonFile] = process.argv.slice(2);
if (!/^\/v[12]\//.test(endpoint)) throw new Error('Use a versioned Apple API endpoint.');
const response = await fetch('https://api.appstoreconnect.apple.com' + endpoint, {
  method,
  headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
  body: jsonFile ? fs.readFileSync(jsonFile) : undefined,
  signal: AbortSignal.timeout(45000),
});
const result = await response.text();
if (!response.ok) { console.error(response.status, result); process.exitCode = 1; }
else console.log(result || '{}');
