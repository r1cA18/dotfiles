import { readFileSync } from 'node:fs';
import { Store, idFor } from './store';
import { importSnapshot } from './importer';
import { exportStore, restoreStore } from './portable';

const [command,root,...args]=process.argv.slice(2);
const help=`Usage: bun src/cli.ts <command> <data-directory> [arguments]
  import <data-directory> <verified-backup-directory>
  stats <data-directory>
  search <data-directory> <query> [kind] [YYYY-MM-DD]
  get <data-directory> <record-id>
  intake <data-directory> <input.json>
  propose <data-directory> <proposal.json>
  correct <data-directory> <correction.json>
  export <data-directory> <new-export-directory>
  restore <new-data-directory> <export-directory>
  serve <data-directory> [port]
All data stays local. Intake and proposals never execute tasks.`;
if(!root||command==='--help'){console.log(help);process.exit(root?0:1);}
let store:Store|undefined;
try {
  if(command==='restore'){store=restoreStore(args[0],root);console.log(JSON.stringify(store.stats(),null,2));}
  else {
    store=new Store(root);let result:unknown;
    const json=()=>JSON.parse(readFileSync(args[0],'utf8'));
    switch(command){
      case 'import':result=importSnapshot(store,args[0]);break;
      case 'stats':result=store.stats();break;
      case 'search':result=store.search(args[0]??'',args[1]??'',args[2]??'');break;
      case 'get':result=store.get(args[0]);break;
      case 'intake':{const p=json();result={id:store.intake(p.channel,p.source_key,p.text,p.occurred_on,p.metadata)};break;}
      case 'propose':{const p=json();result={id:store.propose({...p.record,id:p.record.id??idFor('proposal',crypto.randomUUID())},p.parents,p.condition)};break;}
      case 'correct':{const p=json();result={revision:store.correct(p.id,p.expected_revision,p.body,p.reason)};break;}
      case 'export':result=exportStore(store,args[0]);break;
      case 'serve':{
        const {serve}=await import('./server');const server=serve(store,Number(args[0]??4317));
        console.log(`Life OS Lab: http://127.0.0.1:${server.port}`);
        process.on('SIGINT',()=>{server.stop();store?.close();process.exit(0);});store=undefined;break;
      }
      default:throw new Error(help);
    }
    if(result!==undefined)console.log(JSON.stringify(result,null,2));
  }
}catch(error){console.error(error instanceof Error?error.message:String(error));process.exitCode=1;}
finally{store?.close();}
