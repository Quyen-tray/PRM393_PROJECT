const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const target = process.argv[2] || 'android';
if (!['android', 'web'].includes(target)) throw new Error('Target must be android or web');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8').replace(/^\uFEFF/, '');
if (process.argv.includes('--production')) {
  const existing = fs.existsSync(path.join(root, 'env.json')) ? JSON.parse(read('env.json')) : {};
  const values = {API_BASE_URL: target === 'android' ? 'http://127.0.0.1:8081' : 'http://127.0.0.1:8081'};
  const googleClientId = existing.GOOGLE_SERVER_CLIENT_ID?.trim() || existing.GOOGLE_CLIENT_ID?.trim();
  if (googleClientId) values.GOOGLE_SERVER_CLIENT_ID = googleClientId;
  fs.mkdirSync(path.join(root,'.dart_tool'), {recursive:true});
  fs.writeFileSync(path.join(root, `.dart_tool/v3-build-env-${target}.json`), JSON.stringify(values));
  console.log(`Prepared local ${target} application configuration.`);
  process.exit(0);
}
const sessions = JSON.parse(read('.dart_tool/v3-acceptance.json'));
const database = read('.dart_tool/v3-database.txt').trim();
if (sessions.database !== database || !/^HRM_CoffeeShop_V3_Test(?:_\d+)?$/.test(database)) throw new Error('Test sessions/database mismatch');
// Test-only signer matches the isolated, loopback backend configuration.
// Business authorization still reloads actual roles/permissions/employee ownership from SQL Server.
for (const actor of ['employee','manager','admin']) {
  const now = Math.floor(Date.now()/1000);
  const header = Buffer.from(JSON.stringify({alg:'HS256'})).toString('base64url');
  const payload = Buffer.from(JSON.stringify({sub:String(sessions[actor].userId),typ:'access',iat:now,exp:now+86400})).toString('base64url');
  const signature = crypto.createHmac('sha256','it-jwt-secret-'+'a'.repeat(32)).update(`${header}.${payload}`).digest('base64url');
  sessions[actor].accessToken = `${header}.${payload}.${signature}`;
}
const values = {API_BASE_URL: target === 'android' ? 'http://127.0.0.1:8081' : 'http://127.0.0.1:8081', ACCEPTANCE_SESSIONS: JSON.stringify(sessions)};
fs.writeFileSync(path.join(root, `.dart_tool/v3-build-env-${target}.json`), JSON.stringify(values));
console.log(`Prepared local ${target} acceptance configuration.`);
