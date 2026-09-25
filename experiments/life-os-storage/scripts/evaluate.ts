import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Store, tables, hash } from '../src/store';
import { importSnapshot } from '../src/importer';
import { exportStore, restoreStore } from '../src/portable';

const [backup, root] = process.argv.slice(2);
if (!backup || !root) throw new Error('Usage: bun scripts/evaluate.ts <verified-backup> <evaluation-root>');
mkdirSync(root, { recursive: true, mode: 0o700 });
const store = new Store(join(root, 'data'));
const started = performance.now();
const imported = importSnapshot(store, backup);
const firstMs = performance.now() - started;
const before = Object.fromEntries(tables.map((table) => [table, store.db.query(`SELECT count(*) AS n FROM ${table}`).get()]));
const retryStarted = performance.now();
const retry = importSnapshot(store, backup);
const retryMs = performance.now() - retryStarted;
for (const table of tables) {
  const after = store.db.query(`SELECT count(*) AS n FROM ${table}`).get();
  if (JSON.stringify(after) !== JSON.stringify(before[table])) throw new Error(`Idempotency failed: ${table}`);
}
const checked = store.db.query('SELECT hash,size FROM blobs').all() as {hash:string;size:number}[];
for (const blob of checked) {
  const bytes = readFileSync(store.blobPath(blob.hash));
  if (hash(bytes) !== blob.hash || bytes.byteLength !== blob.size) throw new Error(`Blob verification failed: ${blob.hash}`);
}
const exportPath = join(root, 'export');
const exported = exportStore(store, exportPath);
const restored = restoreStore(exportPath, join(root, 'restored'));
for (const table of tables) {
  const a = store.db.query(`SELECT * FROM ${table} ORDER BY rowid`).all();
  const b = restored.db.query(`SELECT * FROM ${table} ORDER BY rowid`).all();
  if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`Roundtrip failed: ${table}`);
}
const report = {imported, first_ms:firstMs, retry, retry_ms:retryMs, stats:store.stats(), blobs_verified:checked.length, export:exported, roundtrip:true};
writeFileSync(join(root, 'evaluation.json'), JSON.stringify(report, null, 2), { mode: 0o600 });
restored.close(); store.close();
console.log(JSON.stringify(report, null, 2));
