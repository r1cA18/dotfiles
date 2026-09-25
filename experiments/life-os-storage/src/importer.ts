import { readFileSync, lstatSync } from 'node:fs';
import { join, posix, extname } from 'node:path';
import { Store, hash, idFor, type Kind } from './store';

export function category(path:string):Kind {
  const parts=path.toLowerCase().split('/'),root=parts[0];
  if(root==='10_daily')return 'document';
  if(['20_knowledge','knowledge'].includes(root))return 'knowledge';
  if(['30_projects','projects','31_areas','areas'].includes(root))return 'document';
  if(['11_tasks','tasks'].includes(root) || (root==='olympus'&&parts[1]==='tasks'))return 'task';
  if(['40_ai','observations'].includes(root))return 'observation';
  if(['threads','sessions'].includes(root))return 'session';
  if(['reviews'].includes(root))return 'review';
  if(['21_resources','91_attachments','attachments'].includes(root))return 'resource';
  return 'document';
}
export function parseMarkdown(raw:string) {
  let body=raw,meta:any={},warning='';
  const m=/^\uFEFF?---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/.exec(raw);
  if(m) {
    try {
      const value=Bun.YAML.parse(m[1]);
      if(value&&typeof value==='object'&&!Array.isArray(value))meta=value;
      else warning='frontmatter-not-object';
      body=raw.slice(m[0].length);
    } catch {warning='frontmatter-parse-failed';}
  }
  return {body,meta,warning};
}
export function extractTimes(raw:string) {
  const lines=raw.split('\n'),result:{body:string;start:number;end:number;legacyId?:string}[]=[];
  let inTimes=false,fence=false,start=-1,buffer:string[]=[];
  const flush=(end:number)=>{if(start>=0&&buffer.join('\n').trim())result.push({body:buffer.join('\n').trim(),start:start+1,end});start=-1;buffer=[];};
  for(let i=0;i<lines.length;i++) {
    const line=lines[i];
    if(/^\s*(```|~~~)/.test(line)){fence=!fence;if(start>=0)buffer.push(line);continue;}
    if(fence){if(start>=0)buffer.push(line);continue;}
    if(/^##\s+Times\s*$/i.test(line)){flush(i);inTimes=true;continue;}
    if(/^#{1,2}\s/.test(line)){flush(i);inTimes=false;}
    if(inTimes && /^-\s+\d{1,2}:\d{2}\b/.test(line)){flush(i);start=i;buffer=[line.replace(/^-\s+/,'')];}
    else if(start>=0)buffer.push(line);
  }
  flush(lines.length);
  return result;
}
function dayFor(path:string,meta:any) {
  const value=/\b\d{4}-\d{2}-\d{2}\b/.exec(posix.basename(path))?.[0] ?? (typeof meta.date==='string'?meta.date:null);
  if(!value||!/^\d{4}-\d{2}-\d{2}$/.test(value))return null;
  const date=new Date(value);return !isNaN(date.valueOf())&&date.toISOString().slice(0,10)===value?value:null;
}

export function importSnapshot(store:Store, backupRoot:string) {
  const manifest=JSON.parse(readFileSync(join(backupRoot,'manifest.json'),'utf8'));
  if(manifest.format!==1||manifest.verified!==true)throw new Error('Verified backup required');
  const sourceRoot=join(backupRoot,'vault');
  const report={imported:0,excluded:0,symlinks:0,warnings:0,times:0};
  const log=store.db.query('INSERT OR REPLACE INTO import_inventory VALUES(?,?,?,?)');
  for(const [path,entry] of Object.entries(manifest.entries) as [string,any][]) {
    if(entry.type==='directory')continue;
    if(path.startsWith('/')||path.split('/').some(p=>p==='..'))throw new Error('Unsafe manifest path');
    if(entry.type==='symlink'){log.run(path,'excluded','symlink-not-followed',null);report.symlinks++;continue;}
    if(path.split('/').some(p=>p.startsWith('.'))||['AGENTS.md','CLAUDE.md'].includes(posix.basename(path))) {
      log.run(path,'excluded','runtime-or-agent-config',null);report.excluded++;continue;
    }
    const full=join(sourceRoot,path);
    if(!lstatSync(full).isFile())throw new Error('Backup entry type changed');
    const bytes=readFileSync(full);
    if(hash(bytes)!==entry.sha256)throw new Error('Backup file checksum mismatch');
    const markdown=extname(path).toLowerCase()==='.md';
    const parsed=markdown?parseMarkdown(bytes.toString('utf8')):{body:'',meta:{},warning:''};
    const kind=markdown?category(path):'resource';
    const id=idFor('vault-record',path), title=String(parsed.meta.title??posix.basename(path,extname(path)));
    const occurred_on=dayFor(path,parsed.meta);
    store.db.transaction(()=>{
      const source=store.source('vault',path,markdown?'markdown':'attachment',bytes,{path,original_metadata:parsed.meta});
      store.record({id,kind,title,body:parsed.body,occurred_on,metadata:{path,legacy:parsed.meta,archived:path.startsWith('12_Archive/'),parse_warning:parsed.warning}},source.versionId);
      const parts=path.split('/');
      if(parts.length>2&&['30_Projects','31_Areas','projects','areas'].includes(parts[0])) {
        const groupKind=['30_Projects','projects'].includes(parts[0])?'project':'area';
        const groupPath=parts.slice(0,2).join('/'),groupId=idFor('vault-entity',groupPath);
        store.record({id:groupId,kind:groupKind,title:parts[1],body:'',metadata:{directory:groupPath,inferred_from_directory:true}},source.versionId,'directory-membership');
        store.db.query('INSERT OR IGNORE INTO memberships VALUES(?,?)').run(id,groupId);
      }
      if(kind==='task')store.db.query('INSERT OR IGNORE INTO tasks VALUES(?,?,?)').run(id,'candidate','none');
      if(markdown&&path.startsWith('10_Daily/')) {
        for(const part of extractTimes(bytes.toString('utf8'))) {
          const tid=idFor('vault-times',path,String(part.start));
          store.record({id:tid,kind:'times',title:part.body.split('\n')[0].slice(0,100),body:part.body,occurred_on,
            metadata:{path,segmentation:'legacy-daily-lines-v1'}},source.versionId,`lines:${part.start}-${part.end}`);
          report.times++;
        }
      }
      if(markdown&&path.startsWith('times/'))parsed.warning ||= 'times-directive-preserved-needs-parser';
      log.run(path,parsed.warning?'imported-warning':'imported',parsed.warning||'mapped',source.sourceId);
    })();
    report.imported++;if(parsed.warning)report.warnings++;
  }
  resolveLinks(store);
  return report;
}

export function resolveLinks(store:Store) {
  const rows=store.db.query('SELECT id,body,metadata FROM records').all() as any[];
  const names=new Map<string,Set<string>>();
  const add=(name:string,id:string)=>{const key=name.normalize('NFC');if(!names.has(key))names.set(key,new Set());names.get(key)!.add(id);};
  for(const row of rows) {
    const m=JSON.parse(row.metadata);if(!m.path||m.segmentation)continue;
    add(m.path,row.id);add(m.path.replace(/\.md$/i,''),row.id);add(posix.basename(m.path),row.id);add(posix.basename(m.path,'.md'),row.id);
    const aliases=m.legacy?.aliases;for(const a of Array.isArray(aliases)?aliases:[])if(typeof a==='string')add(a,row.id);
  }
  store.db.transaction(()=>{
    store.db.exec('DELETE FROM links');
    for(const row of rows) {
      const path=JSON.parse(row.metadata).path??'';
      const targets=new Set([...row.body.matchAll(/\[\[([^\]\n]+)\]\]/g)].map(m=>m[1].split('|')[0]));
      for(const m of row.body.matchAll(/\]\(([^\s)]+)(?:\s+"[^"\n]*")?\)/g))targets.add(m[1]);
      for(const raw of targets) {
        if(/^[a-z][a-z0-9+.-]*:/i.test(raw)) {store.db.query('INSERT OR IGNORE INTO links VALUES(?,?,?,?)').run(row.id,raw,null,'external');continue;}
        let target=raw.split('#')[0];try{target=decodeURIComponent(target);}catch{}
        if(!target)target=path;
        const relative=posix.normalize(posix.join(posix.dirname(path),target));
        const candidates=names.get(relative.normalize('NFC'))??names.get(target.normalize('NFC'));
        const status=!candidates?.size?'missing':candidates.size===1?'resolved':'ambiguous';
        store.db.query('INSERT OR IGNORE INTO links VALUES(?,?,?,?)').run(row.id,raw,status==='resolved'?[...candidates!][0]:null,status);
      }
    }
  })();
}
