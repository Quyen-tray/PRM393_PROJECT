const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..');
const read=p=>fs.readFileSync(p,'utf8').replace(/^\uFEFF/,'');
const base='http://127.0.0.1:8081';
function token(userId){const now=Math.floor(Date.now()/1000),h=Buffer.from(JSON.stringify({alg:'HS256'})).toString('base64url'),p=Buffer.from(JSON.stringify({sub:String(userId),typ:'access',iat:now,exp:now+86400})).toString('base64url');return h+'.'+p+'.'+crypto.createHmac('sha256','it-jwt-secret-'+'a'.repeat(32)).update(h+'.'+p).digest('base64url');}
function context(runArg){
 const config=JSON.parse(read(path.join(root,'.dart_tool/v3-build-env-web.json'))),sessions=JSON.parse(config.ACCEPTANCE_SESSIONS),db=read(path.join(root,'.dart_tool/v3-database.txt')).trim();
 assert.equal(sessions.database,db);assert.match(db,/^HRM_CoffeeShop_V3_Test(?:_\d+)?$/);
 const run=runArg||new Date().toISOString().replace(/\D/g,'').slice(0,14)+'-'+crypto.randomBytes(3).toString('hex');assert.match(run,/^[\da-z-]+$/);
 const dir=path.join(root,'.dart_tool/api-e2e',run);fs.mkdirSync(dir,{recursive:true});
 const statePath=path.join(dir,'private-state.json');const state=fs.existsSync(statePath)?JSON.parse(read(statePath)):{run,db,steps:{},cases:{},actors:{},phases:[]};assert.equal(state.db,db);
 const api=JSON.parse(read(path.join(root,'.dart_tool/openapi-current.json')));
 const ops=[];for(const [p,methods]of Object.entries(api.paths))for(const m of Object.keys(methods))if(['get','post','patch','put','delete'].includes(m))ops.push({key:m.toUpperCase()+' '+p,path:p,method:m.toUpperCase(),schema:methods[m],regex:new RegExp('^'+p.split('/').map(s=>s.startsWith('{')?'[^/]+':s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')).join('/')+'$'),specificity:p.split('/').filter(s=>s&&!s.startsWith('{')).length});ops.sort((a,b)=>b.specificity-a.specificity);
 const ctx={root,base,run,dir,state,ops,bootstrap:{userId:sessions.admin.userId},assert,token};
 ctx.save=()=>fs.writeFileSync(statePath,JSON.stringify(state,null,2));
 ctx.actor=name=>name==='bootstrap'?ctx.bootstrap:state.actors[name];
 ctx.date=(days=0)=>new Date(Date.now()+7*3600000+days*86400000).toISOString().slice(0,10);
 ctx.vn=(date,hour=8,minute=0)=>`${date}T${String(hour).padStart(2,'0')}:${String(minute).padStart(2,'0')}:00+07:00`;
 ctx.fresh=()=>crypto.randomBytes(24).toString('base64url');
 ctx.call=async(label,actorName,method,route,body,options={})=>{
   if(state.steps[label])return state.steps[label].value;
   const url=new URL('/api/v1'+route,base);for(const [k,v]of Object.entries(options.query||{}))if(v!==undefined&&v!==null)url.searchParams.set(k,String(v));
   const op=ops.find(o=>o.method===method&&o.regex.test(url.pathname));assert.ok(op,'Unknown inventory operation: '+method+' '+url.pathname);
   const actor=typeof actorName==='object'?actorName:ctx.actor(actorName);const headers={Accept:'application/json',...options.headers};
   if(options.auth!==false){assert.ok(actor?.userId,'Actor missing: '+actorName);headers.Authorization='Bearer '+(options.accessToken||token(actor.userId));}
   let payload;if(body!==undefined){headers['Content-Type']=options.raw?'image/png':'application/json';payload=options.raw?body:JSON.stringify(body);}
   const started=Date.now();let record={label,operation:op.key,actor:typeof actorName==='string'?actorName:'fixture',expected:options.expected||'2xx',pass:false,checks:[],http:null};
   try{
    const r=await fetch(url,{method,headers,body:payload,signal:AbortSignal.timeout(30000)});record.http=r.status;record.elapsedMs=Date.now()-started;
    let value; if(options.binary){const bytes=Buffer.from(await r.arrayBuffer());value={bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')};}
    else if(options.text){const text=await r.text();value={length:text.length,containsHeader:text.includes('ActionCode')||text.includes('actionCode'),lineCount:text.split('\n').length};}
    else {const envelope=await r.json();record.errorCode=envelope.error?.code||null;fs.writeFileSync(path.join(dir,'last-response.json'),JSON.stringify({label,http:r.status,envelope},null,2));assert.equal(envelope.success,r.status<400,'Envelope success');assert.ok(envelope.timestamp,'Envelope timestamp');value=envelope.data;record.checks.push('JSON envelope');if(r.status>=400)assert.ok(envelope.error?.code,'Error code');}
    const allowed=options.expected===undefined?r.status>=200&&r.status<300:[].concat(options.expected).includes(r.status);
    assert.ok(allowed,label+': HTTP '+r.status+(record.errorCode?' '+record.errorCode:''));
    record.pass=true;record.checks.push('HTTP status');state.steps[label]={value};state.cases[label]=record;ctx.save();process.stdout.write('PASS '+label+' ['+r.status+']\n');return value;
   }catch(e){record.failure=e.message;state.cases[label]=record;ctx.save();throw e;}
 };
 ctx.prove=(label,predicate,message)=>{assert.ok(predicate,message||label);const c=state.cases[label];assert.ok(c,'Missing request evidence '+label);if(!c.checks.includes(message||'read-back assertion'))c.checks.push(message||'read-back assertion');ctx.save();};
 ctx.report=()=>{
   const cases=Object.values(state.cases),operations=ops.map(o=>{const list=cases.filter(c=>c.operation===o.key),positive=list.filter(c=>c.pass&&c.http>=200&&c.http<300),negative=list.filter(c=>c.pass&&c.http>=400);return{operation:o.key,status:positive.length?'positive_verified':negative.length?'negative_only':'not_run',positive:positive.length,negative:negative.length,failed:list.filter(c=>!c.pass).length,cases:list.map(c=>c.label)};}).sort((a,b)=>a.operation.localeCompare(b.operation));
   const result={run,checkedAt:new Date().toISOString(),database:db,transport:'Real TCP HTTP -> Spring Boot -> SQL Server/storage; test JWT actors; no iOS',summary:{total:ops.length,positive:operations.filter(o=>o.positive).length,negativeOnly:operations.filter(o=>!o.positive&&o.negative).length,notRun:operations.filter(o=>o.status==='not_run').length,cases:cases.length,failed:cases.filter(c=>!c.pass).length},operations,cases};
   fs.writeFileSync(path.join(dir,'report.json'),JSON.stringify(result,null,2));fs.writeFileSync(path.join(root,'.dart_tool/api-e2e-latest.json'),JSON.stringify(result,null,2));
   const lines=['# API E2E execution evidence','',`Run: ${run}; database: ${db}; ${result.summary.positive}/${ops.length} operation có nhánh 2xx, ${result.summary.negativeOnly} chỉ có nhánh lỗi hợp lệ, ${result.summary.notRun} chưa chạy.`, '', 'HTTP thật qua backend và SQL Server/storage. JWT là fixture kiểm thử; không thay thế đăng nhập Google. Không kiểm thử iOS. Báo cáo không ghi token, chữ ký URL, ảnh hoặc PII.','', '| Operation | Trạng thái | 2xx | Lỗi hợp lệ | Case evidence |','|---|---|---|---|---|'];
   for(const o of operations)lines.push(`| \`${o.operation}\` | ${o.status} | ${o.positive} | ${o.negative} | ${o.cases.join(', ')} |`);
   lines.push('','## Case assertions','','| Case | HTTP | Kết quả | Kiểm tra |','|---|---|---|---|');for(const c of cases)lines.push(`| ${c.label} | ${c.http} | ${c.pass?'PASS':'FAIL'} | ${c.checks.join('; ')} |`);
   fs.writeFileSync(path.join(root,'docs/specification/v3.0/API_E2E_EXECUTION.md'),lines.join('\n')+'\n');return result.summary;
 };
 ctx.save();return ctx;
}
module.exports={context};
