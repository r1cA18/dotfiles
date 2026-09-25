import { test, expect, afterEach } from 'bun:test';
import { mkdtempSync, rmSync, mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Store, idFor, hash, tables } from '../src/store';
import { extractTimes, importSnapshot } from '../src/importer';
import { exportStore, restoreStore } from '../src/portable';
import { serve } from '../src/server';
const roots:string[]=[],stores:Store[]=[];
const temp=()=>{const p=mkdtempSync(join(tmpdir(),'life-os-test-'));roots.push(p);return p;};
const fresh=()=>{const s=new Store(join(temp(),'data'));stores.push(s);return s;};
afterEach(()=>{for(const s of stores.splice(0))s.close();for(const r of roots.splice(0))rmSync(r,{recursive:true,force:true});});
function base(s:Store,text='机を来月直したい。今日は作業しない。'){return s.intake('voice','capture-1',text,'2026-09-14');}

test('same event retries once; same text in a different event stays separate',()=>{
 const s=fresh(),id=base(s);expect(base(s)).toBe(id);
 const other=s.intake('voice','capture-2','机を来月直したい。今日は作業しない。','2026-09-14');
 expect(other).not.toBe(id);expect(s.search('', 'times')).toHaveLength(2);
 expect(s.db.query('SELECT count(*) AS n FROM jobs').get()).toEqual({n:2});
 expect(()=>s.intake('voice','capture-1','違う発言','2026-09-14')).toThrow('Idempotency conflict');
 expect(s.get(id)!.record.body).toContain('今日は作業しない');
});
test('job insertion failure rolls back receipt and Times',()=>{
 const s=fresh();s.db.exec("CREATE TRIGGER fail_job BEFORE INSERT ON jobs BEGIN SELECT RAISE(ABORT,'test crash'); END;");
 expect(()=>base(s)).toThrow('test crash');expect(s.search('')).toHaveLength(0);
 expect(s.db.query('SELECT count(*) AS n FROM sources').get()).toEqual({n:0});
 s.db.exec('DROP TRIGGER fail_job');base(s);expect(s.search('')).toHaveLength(1);
});
test('Japanese one and two character searches and literal punctuation work',()=>{
 const s=fresh();base(s);s.intake('discord','one','C++ と 100%_ の比較','2026-09-13');
 expect(s.search('机')).toHaveLength(1);expect(s.search('来月')).toHaveLength(1);
 expect(s.search('今日は')).toHaveLength(1);expect(s.search('C++')).toHaveLength(1);
 expect(s.search('100%_')).toHaveLength(1);expect(s.search('机','knowledge')).toHaveLength(0);
 expect(s.search('机','times','2026-09-13')).toHaveLength(0);
 expect(()=>s.search('','','',10000)).toThrow();
});
test('revision conflicts do not overwrite data; correction invalidates transitive knowledge',()=>{
 const s=fresh(),id=base(s);
 s.propose({id:'k1',kind:'knowledge',title:'計画',body:'机を来月直す'},[{id,revision:1}]);
 s.propose({id:'k2',kind:'knowledge',title:'予定一覧',body:'机の計画'},[{id:'k1',revision:1}]);
 expect(s.correct(id,1,'机の修理は取り消し','本人による訂正')).toBe(2);
 expect(()=>s.correct(id,1,'古い更新','競合')).toThrow('Revision conflict');
 expect(s.search('','knowledge')).toHaveLength(0);
 expect(s.get('k1')!.record.stale).toBe(1);expect(s.get('k2')!.record.stale).toBe(1);
 expect(s.db.query('SELECT body FROM record_revisions WHERE record_id=? AND revision=1').get(id)).toEqual({body:'机を来月直したい。今日は作業しない。'});
 expect(()=>s.propose({id:'k3',kind:'knowledge',title:'古い推論',body:'bad'},[{id:'k1',revision:1}])).toThrow('Stale');
});
test('agent proposals cannot turn a remembered wish into an executable task',()=>{
 const s=fresh(),id=base(s);
 s.propose({id:'task',kind:'task',title:'修理',body:'来月'},[{id,revision:1}]);
 expect(s.db.query('SELECT state,authorization FROM tasks').get()).toEqual({state:'candidate',authorization:'none'});
 expect(()=>s.db.query("UPDATE tasks SET state='running' WHERE record_id='task'").run()).toThrow();
 expect(()=>s.propose({id:'bad',kind:'intent',title:'不明',body:'x'},[{id:'missing',revision:1}])).toThrow();
 expect(s.get('bad')).toBeNull();
});
test('export and restore preserve all canonical tables, revisions and evidence',()=>{
 const s=fresh(),id=base(s);s.correct(id,1,'後で検討する','訂正');
 s.propose({id:'intent',kind:'intent',title:'保留',body:'修理'},[{id,revision:2}],'来月');
 const path=join(temp(),'export');exportStore(s,path);
 const restored=restoreStore(path,join(temp(),'restore'));stores.push(restored);
 for(const table of tables)expect(restored.db.query(`SELECT * FROM ${table} ORDER BY rowid`).all()).toEqual(s.db.query(`SELECT * FROM ${table} ORDER BY rowid`).all());
 expect(restored.search('検討')).toHaveLength(1);
 expect(restored.stats().foreignKeys).toEqual([]);
 expect(()=>restoreStore(path,restored.root)).toThrow('must be new');
});
test('tampered export is rejected before database import',()=>{
 const s=fresh();base(s);const path=join(temp(),'export');exportStore(s,path);
 writeFileSync(join(path,'records.jsonl'),'tampered');
 expect(()=>restoreStore(path,join(temp(),'restore'))).toThrow('checksum');
});
test('missing and modified binary attachments fail restore',()=>{
 const s=fresh();base(s);const path=join(temp(),'export');exportStore(s,path);
 const blob=(s.db.query('SELECT hash FROM blobs').get() as any).hash;
 writeFileSync(join(path,'blobs',blob),'bad');
 expect(()=>restoreStore(path,join(temp(),'restore'))).toThrow('Blob checksum');
});
test('legacy Times extraction retains multiline text and ignores other sections and fenced examples',()=>{
 const raw='# day\n## Times\n- 09:00 @self: やりたい\n\t来月でいい\n- 10:00 @self: 取り消し\n## Other\n- 11:00 not a post\n```\n## Times\n- 12:00 sample\n```\n';
 const posts=extractTimes(raw);expect(posts).toHaveLength(2);expect(posts[0].body).toContain('来月でいい');expect(posts[0].start).toBe(3);
});
test('snapshot importer is lossless, idempotent and exposes ambiguous links',()=>{
 const root=temp(),files:Record<string,string>={
  '10_Daily/2026-09-14.md':'## Times\n- 09:00 @self: 机を直す。[[note]]\n\t来月でいい\n',
  '20_Knowledge/a/note.md':'---\ntitle: note\n---\n内容',
  '20_Knowledge/b/note.md':'内容2',
  '20_Knowledge/ref.md':'[[note]] [[missing]] [[a/note]]',
  '.env':'SECRET=not-indexed',
  '91_attachments/test.bin':'\u0000binary\u0001',
 };
 const entries:any={};for(const [path,body] of Object.entries(files)){
  const full=join(root,'vault',path);mkdirSync(join(full,'..'),{recursive:true});writeFileSync(full,body);
  entries[path]={type:'file',sha256:hash(body),size:Buffer.byteLength(body)};
 }
 writeFileSync(join(root,'manifest.json'),JSON.stringify({format:1,verified:true,entries}));
 const s=fresh();expect(importSnapshot(s,root).times).toBe(1);
 const count=s.db.query('SELECT count(*) AS n FROM records').get();importSnapshot(s,root);
 expect(s.db.query('SELECT count(*) AS n FROM records').get()).toEqual(count);
 expect(s.search('SECRET')).toHaveLength(0);
 const links=s.db.query('SELECT status FROM links WHERE from_id=? ORDER BY target').all(idFor('vault-record','20_Knowledge/ref.md'));
 expect(links).toEqual([{status:'resolved'},{status:'missing'},{status:'ambiguous'}]);
 expect(s.stats().foreignKeys).toEqual([]);
 const data=s.get(idFor('vault-record','91_attachments/test.bin'))!;
 expect(readFileSync(s.blobPath((data.evidence[0] as any).blob_hash)).toString()).toBe(files['91_attachments/test.bin']);
});
