import { Database } from 'bun:sqlite';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync, existsSync, renameSync } from 'node:fs';
import { join, resolve } from 'node:path';

export const hash = (data: string | Uint8Array) => createHash('sha256').update(data).digest('hex');
export const idFor = (...parts: string[]) => hash(JSON.stringify(parts));
export const kinds = ['document','times','knowledge','project','area','intent','task','session','review','resource','observation'] as const;
export type Kind = typeof kinds[number];
export type RecordInput = { id: string; kind: Kind; title: string; body: string; occurred_on?: string | null; origin?: 'import'|'owner'|'agent'; metadata?: object };
export const tables = ['blobs','sources','source_versions','records','record_revisions','evidence','dependencies','memberships','intents','tasks','links','jobs','import_inventory'] as const;

export class Store {
  db: Database;
  root: string;
  constructor(root: string) {
    this.root = resolve(root);
    mkdirSync(join(this.root,'blobs'), {recursive:true, mode:0o700});
    this.db = new Database(join(this.root,'life.sqlite'), {create:true, strict:true});
    this.db.exec(readFileSync(new URL('./schema.sql',import.meta.url),'utf8'));
  }
  close() { this.db.close(); }
  blobPath(h: string) {
    if (!/^[a-f0-9]{64}$/.test(h)) throw new Error('Invalid blob hash');
    return join(this.root,'blobs',h);
  }
  putBlob(data: Uint8Array) {
    const h = hash(data), path = this.blobPath(h);
    if (!existsSync(path)) {
      const temp = path + '.' + crypto.randomUUID() + '.tmp';
      writeFileSync(temp,data,{mode:0o600,flag:'wx'});
      renameSync(temp,path);
    } else if (hash(readFileSync(path)) !== h) throw new Error('Existing blob corrupted');
    this.db.query('INSERT OR IGNORE INTO blobs VALUES(?,?)').run(h,data.byteLength);
    return h;
  }
  source(namespace: string, key: string, kind: string, data: Uint8Array, metadata: object = {}) {
    const blob = this.putBlob(data), id = idFor(namespace,key);
    return this.db.transaction(() => {
      this.db.query('INSERT OR IGNORE INTO sources VALUES(?,?,?,?)').run(id,namespace,key,kind);
      const prior = this.db.query('SELECT * FROM source_versions WHERE source_id=? AND blob_hash=?').get(id,blob) as any;
      if (prior) return {sourceId:id,versionId:prior.id,blob,newVersion:false};
      const max = this.db.query('SELECT coalesce(max(revision),0) AS n FROM source_versions WHERE source_id=?').get(id) as any;
      const versionId=idFor(id,blob);
      this.db.query('INSERT INTO source_versions VALUES(?,?,?,?,?,?)').run(versionId,id,max.n+1,blob,new Date().toISOString(),JSON.stringify(metadata));
      return {sourceId:id,versionId,blob,newVersion:true};
    })();
  }
  record(input: RecordInput, versionId?: string, locator='whole') {
    return this.db.transaction(() => {
      const old=this.db.query('SELECT * FROM records WHERE id=?').get(input.id) as any;
      if (old && (old.body !== input.body || old.title !== input.title)) throw new Error('Existing record differs; use correction');
      if (!old) {
        this.db.query('INSERT INTO records(id,kind,title,body,occurred_on,origin,metadata) VALUES(?,?,?,?,?,?,?)')
          .run(input.id,input.kind,input.title,input.body,input.occurred_on??null,input.origin??'import',JSON.stringify(input.metadata??{}));
        this.db.query('INSERT INTO record_revisions VALUES(?,?,?,?,?,?)').run(input.id,1,input.body,input.title,'create',new Date().toISOString());
      }
      if (versionId) this.db.query('INSERT OR IGNORE INTO evidence VALUES(?,?,?)').run(input.id,versionId,locator);
      return input.id;
    })();
  }
  correct(id: string, expectedRevision: number, body: string, reason: string) {
    if (!reason.trim()) throw new Error('Correction reason required');
    return this.db.transaction(() => {
      const old=this.db.query('SELECT * FROM records WHERE id=?').get(id) as any;
      if (!old || old.revision!==expectedRevision) throw new Error('Revision conflict');
      this.db.query('UPDATE records SET body=?,revision=revision+1 WHERE id=?').run(body,id);
      this.db.query('INSERT INTO record_revisions VALUES(?,?,?,?,?,?)').run(id,old.revision+1,body,old.title,reason,new Date().toISOString());
      this.db.query(`WITH RECURSIVE affected(id) AS (
        SELECT derived_id FROM dependencies WHERE parent_id=? UNION
        SELECT d.derived_id FROM dependencies d JOIN affected a ON d.parent_id=a.id)
        UPDATE records SET stale=1 WHERE id IN (SELECT id FROM affected)`).run(id);
      return old.revision+1;
    })();
  }
  propose(input: RecordInput, parents: {id:string;revision:number}[], condition='') {
    if (!parents.length || !['knowledge','intent','task'].includes(input.kind)) throw new Error('Proposal requires evidence and supported kind');
    return this.db.transaction(() => {
      for (const p of parents) {
        const row=this.db.query('SELECT revision,stale FROM records WHERE id=?').get(p.id) as any;
        if (!row || row.revision!==p.revision || row.stale) throw new Error('Stale or missing evidence');
      }
      this.record({...input,origin:'agent'});
      for (const p of parents) this.db.query('INSERT INTO dependencies VALUES(?,?,?)').run(input.id,p.id,p.revision);
      if(input.kind==='intent') this.db.query('INSERT INTO intents VALUES(?,?,?)').run(input.id,'candidate',condition);
      if(input.kind==='task') this.db.query('INSERT INTO tasks VALUES(?,?,?)').run(input.id,'candidate','none');
      return input.id;
    })();
  }
  intake(channel:string,key:string,text:string, occurredOn:string, metadata:object={}) {
    if (!channel || !key || !text.trim() || !/^\d{4}-\d{2}-\d{2}$/.test(occurredOn) || new Date(occurredOn).toISOString().slice(0,10)!==occurredOn) throw new Error('Invalid intake');
    const id=idFor('intake',channel,key), bytes=new TextEncoder().encode(text);
    const blob=this.putBlob(bytes);
    return this.db.transaction(()=>{
      const existing=this.db.query('SELECT r.id,v.blob_hash FROM records r JOIN evidence e ON e.record_id=r.id JOIN source_versions v ON v.id=e.source_version_id WHERE r.id=?').get(id) as any;
      if(existing) {if(existing.blob_hash!==blob)throw new Error('Idempotency conflict'); return id;}
      const source=this.source('intake:'+channel,key,channel,bytes,metadata);
      this.record({id,kind:'times',title:text.slice(0,80),body:text,occurred_on:occurredOn,origin:'owner'},source.versionId);
      this.db.query('INSERT INTO jobs VALUES(?,?,?,?)').run(idFor('job',id),id,'memory-review','pending');
      return id;
    })();
  }
  get(id:string) {
    const record=this.db.query('SELECT * FROM records WHERE id=?').get(id);
    if(!record)return null;
    return {record,evidence:this.db.query(`SELECT e.*,s.source_key,s.kind,v.blob_hash FROM evidence e
      JOIN source_versions v ON v.id=e.source_version_id JOIN sources s ON s.id=v.source_id WHERE e.record_id=?`).all(id),
      parents:this.db.query('SELECT * FROM dependencies WHERE derived_id=?').all(id),
      links:this.db.query('SELECT * FROM links WHERE from_id=?').all(id),
      memberships:this.db.query('SELECT m.entity_id,r.title FROM memberships m JOIN records r ON r.id=m.entity_id WHERE m.record_id=?').all(id),
      members:this.db.query('SELECT r.id,r.kind,r.title FROM memberships m JOIN records r ON r.id=m.record_id WHERE m.entity_id=? ORDER BY r.title LIMIT 100').all(id)};
  }
  search(query='',kind='',day='',limit=30,includeStale=false) {
    if(!Number.isInteger(limit)||limit<1||limit>100)throw new Error('Limit must be 1..100');
    if(kind&&!kinds.includes(kind as Kind))throw new Error('Invalid kind');
    const terms=query.trim().split(/\s+/u).filter(Boolean);
    const where=['(? = 1 OR r.stale=0)'],args:any[]=[includeStale?1:0];
    if(kind){where.push('r.kind=?');args.push(kind);}
    if(day){where.push('r.occurred_on=?');args.push(day);}
    const long=terms.filter(t=>[...t].length>=3),short=terms.filter(t=>[...t].length<3);
    if(long.length){where.push('r.id IN (SELECT id FROM record_fts WHERE record_fts MATCH ?)');args.push(long.map(t=>'"'+t.replaceAll('"','""')+'"').join(' AND '));}
    for(const t of short){where.push("instr(lower(r.title || char(10) || r.body), lower(?))>0");args.push(t);}
    args.push(limit);
    return this.db.query(`SELECT r.id,r.kind,r.title,r.occurred_on,r.revision,r.stale,substr(r.body,1,240) AS excerpt
      FROM records r WHERE ${where.join(' AND ')} ORDER BY r.occurred_on DESC,r.id LIMIT ?`).all(...args);
  }
  stats(){return {records:this.db.query('SELECT kind,count(*) AS count FROM records GROUP BY kind ORDER BY kind').all(),
    inventory:this.db.query('SELECT disposition,count(*) AS count FROM import_inventory GROUP BY disposition').all(),
    links:this.db.query('SELECT status,count(*) AS count FROM links GROUP BY status').all(),
    blobs:this.db.query('SELECT count(*) AS count,sum(size) AS bytes FROM blobs').get(),
    integrity:this.db.query('PRAGMA integrity_check').get(),foreignKeys:this.db.query('PRAGMA foreign_key_check').all()};}
}
