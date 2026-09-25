import { mkdirSync, writeFileSync, readFileSync, copyFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { Store, hash, tables } from './store';

export function exportStore(store:Store,dest:string) {
  if(existsSync(dest))throw new Error('Export destination must be new');
  mkdirSync(join(dest,'blobs'),{recursive:true,mode:0o700});
  const records:string[]=[];const snapshot:Record<string,any[]>={};
  store.db.transaction(()=>{
    for(const table of tables){snapshot[table]=store.db.query(`SELECT * FROM ${table} ORDER BY rowid`).all();for(const row of snapshot[table])records.push(JSON.stringify({table,row}));}
  })();
  const text=records.join('\n')+'\n';
  writeFileSync(join(dest,'records.jsonl'),text,{mode:0o600});
  const blobs=snapshot.blobs;
  for(const b of blobs){const bytes=readFileSync(store.blobPath(b.hash));if(hash(bytes)!==b.hash)throw new Error('Corrupted blob');copyFileSync(store.blobPath(b.hash),join(dest,'blobs',b.hash));}
  mkdirSync(join(dest,'markdown'),{recursive:true});
  const documents=snapshot.records;
  for(const r of documents){
    const dir=join(dest,'markdown',r.kind);mkdirSync(dir,{recursive:true});
    const evidence=snapshot.evidence.filter(e=>e.record_id===r.id);
    writeFileSync(join(dir,r.id+'.md'),`---\n${Bun.YAML.stringify({id:r.id,title:r.title,kind:r.kind,revision:r.revision,occurred_on:r.occurred_on,stale:!!r.stale,evidence})}---\n\n${r.body}\n`,{mode:0o600});
  }
  const manifest={format:1,schema:1,records_hash:hash(text),rows:records.length,blobs:blobs.length,created_at:new Date().toISOString()};
  writeFileSync(join(dest,'manifest.json'),JSON.stringify(manifest,null,2));
  return manifest;
}
export function restoreStore(bundle:string,dest:string) {
  if(existsSync(dest))throw new Error('Restore destination must be new');
  const manifest=JSON.parse(readFileSync(join(bundle,'manifest.json'),'utf8'));
  const text=readFileSync(join(bundle,'records.jsonl'),'utf8');
  if(manifest.format!==1||manifest.schema!==1||hash(text)!==manifest.records_hash)throw new Error('Invalid export manifest/checksum');
  const entries=text.trim().split('\n').map(line=>JSON.parse(line));
  if(entries.length!==manifest.rows)throw new Error('Row count mismatch');
  for(const e of entries)if(!tables.includes(e.table))throw new Error('Unknown export table');
  const store=new Store(dest);
  try {
    for(const {row:b} of entries.filter(e=>e.table==='blobs')){
      if(!/^[a-f0-9]{64}$/.test(b.hash))throw new Error('Invalid blob identifier');
      const data=readFileSync(join(bundle,'blobs',b.hash));
      if(hash(data)!==b.hash||data.byteLength!==b.size)throw new Error('Blob checksum mismatch');
      copyFileSync(join(bundle,'blobs',b.hash),store.blobPath(b.hash));
    }
    store.db.transaction(()=>{
      for(const {table,row} of entries){
        const allowed=new Set((store.db.query(`PRAGMA table_info(${table})`).all() as any[]).map(c=>c.name));
        const keys=Object.keys(row);if(keys.length!==allowed.size||keys.some(k=>!allowed.has(k)))throw new Error('Unknown export columns');
        store.db.query(`INSERT INTO ${table}(${keys.map(k=>'"'+k+'"').join(',')}) VALUES(${keys.map(()=>'?').join(',')})`).run(...keys.map(k=>row[k]));
      }
      if(store.db.query('PRAGMA foreign_key_check').all().length)throw new Error('Foreign key mismatch');
    })();
    return store;
  }catch(error){store.close();throw error;}
}
