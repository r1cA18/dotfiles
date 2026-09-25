import { Store } from './store';
import { readFileSync } from 'node:fs';

export function serve(store:Store,port=4317) {
  return Bun.serve({hostname:'127.0.0.1',port,
    fetch(request){
      const url=new URL(request.url);
      const headers={'Cache-Control':'no-store','X-Content-Type-Options':'nosniff',
        'Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self'; frame-ancestors 'none'; base-uri 'none'"};
      if(request.method!=='GET')return new Response('Method not allowed',{status:405,headers});
      if(!['127.0.0.1','localhost'].includes(url.hostname))return new Response('Invalid host',{status:403,headers});
      const json=(value:unknown)=>Response.json(value,{headers});
      try {
        if(url.pathname==='/api/stats')return json(store.stats());
        if(url.pathname==='/api/search')return json(store.search(url.searchParams.get('q')??'',url.searchParams.get('kind')??'',url.searchParams.get('day')??''));
        if(url.pathname.startsWith('/api/records/')){
          const record=store.get(url.pathname.slice('/api/records/'.length));
          return record?json(record):new Response('Not found',{status:404,headers});
        }
        const assets:Record<string,[string,string]>={'/':['index.html','text/html; charset=utf-8'],'/app.js':['app.js','text/javascript; charset=utf-8'],'/style.css':['style.css','text/css; charset=utf-8']};
        const asset=assets[url.pathname];
        if(asset)return new Response(readFileSync(new URL('../web/'+asset[0],import.meta.url)),{headers:{...headers,'Content-Type':asset[1]}});
        return new Response('Not found',{status:404,headers});
      }catch{return json({error:'取得できませんでした。検索条件を確認してください。'});}
    }});
}
