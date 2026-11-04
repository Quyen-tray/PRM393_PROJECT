const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
function walk(directory){return fs.readdirSync(directory,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(directory,e.name)):[path.join(directory,e.name)]);}
function schemaName(schema){if(!schema)return '—';if(schema.$ref)return schema.$ref.split('/').at(-1);if(schema.type==='array')return 'List<'+schemaName(schema.items)+'>';return schema.type||'—';}
(async()=>{
  const r=await fetch('http://127.0.0.1:8081/v3/api-docs',{signal:AbortSignal.timeout(15000)});
  if(!r.ok)throw new Error('OpenAPI: HTTP '+r.status);
  const api=await r.json();fs.writeFileSync(path.join(root,'.dart_tool/openapi-current.json'),JSON.stringify(api,null,2));
  const javaRoot=path.join(root,'hrm-coffeeshop-backend/src/main/java');
  const controllers=new Map(walk(javaRoot).filter(p=>p.endsWith('Controller.java')).map(p=>{const source=fs.readFileSync(p,'utf8'),name=path.basename(p,'.java');return [name.replace(/([a-z0-9])([A-Z])/g,'$1-$2').toLowerCase(),{name,source,file:path.relative(root,p).replaceAll('\\','/')}];}));
  const rows=[];
  for(const [endpoint,verbs] of Object.entries(api.paths))for(const [verb,op] of Object.entries(verbs)){
    if(!['get','post','put','patch','delete'].includes(verb))continue;
    const controller=controllers.get(op.tags?.[0]);
    let permission='Authenticated; service scope applies',services='—';
    if(controller){
      const source=controller.source,classHeader=source.slice(0,source.indexOf('public class'));
      const classPermission=[...classHeader.matchAll(/@PreAuthorize\("([^"]+)"\)/g)].at(-1)?.[1];
      const method=op.operationId.replace(/_\d+$/,''),signature=new RegExp('public\\s+[^;{]+?\\b'+method+'\\s*\\(').exec(source);
      let methodPermission;
      if(signature){const previous=source.lastIndexOf('}',signature.index);methodPermission=[...source.slice(previous+1,signature.index).matchAll(/@PreAuthorize\("([^"]+)"\)/g)].at(-1)?.[1];}
      permission=methodPermission||classPermission||permission;
      services=[...new Set([...source.matchAll(/private final (\w+Service)\b/g)].map(m=>m[1]))].join(', ')||'—';
    }
    if(endpoint.endsWith('/auth/google')||endpoint.endsWith('/auth/refresh')||endpoint.endsWith('/storage/view'))permission='Public (SecurityConfig); endpoint validation applies';
    const bodyContent=Object.values(op.requestBody?.content||{})[0];
    const response=op.responses?.['200']||op.responses?.['201']||op.responses?.['204'];
    const responseContent=Object.values(response?.content||{})[0];
    rows.push({endpoint,verb:verb.toUpperCase(),controller,permission,services,request:schemaName(bodyContent?.schema),response:schemaName(responseContent?.schema),operation:op.operationId});
  }
  const header=['# API inventory — source đang triển khai','',`Xuất từ OpenAPI của backend local và đối chiếu annotation Controller ngày ${new Date().toISOString().slice(0,10)}. Tổng ${rows.length} operation (bao gồm alias).`,'',
    'Inventory xác nhận mapping/schema và guard ở Controller. Service vẫn kiểm tra ownership, no-self-review, permission bổ sung và trạng thái. Danh sách này không khẳng định từng operation đã được E2E; xem VERIFICATION.md và IMPLEMENTED_FLOW_MATRIX.md.','',
    'Base path `/api/v1`. Bearer JWT cho API riêng tư. `X-Device-Credential` bắt buộc khi check-in/out; `Idempotency-Key` giữ nguyên khi retry cùng thao tác. Upload gửi bytes thô. Không sửa hoặc tự tạo signed URL.','',
    '| Method | Endpoint | Controller | Guard Controller / SecurityConfig | Service | Request schema | Response schema |','|---|---|---|---|---|---|---|'];
  for(const row of rows.sort((a,b)=>a.endpoint.localeCompare(b.endpoint)||a.verb.localeCompare(b.verb))){
    const owner=row.controller?`[${row.controller.name}](../../../${row.controller.file})`:row.operation;
    header.push(`| ${row.verb} | \`${row.endpoint}\` | ${owner} | ${row.permission.replaceAll('|','\\|')} | ${row.services} | ${row.request} | ${row.response} |`);
  }
  fs.writeFileSync(path.join(root,'docs/specification/v3.0/API_INVENTORY_IMPLEMENTED.md'),header.join('\n')+'\n');
  console.log('Exported '+rows.length+' OpenAPI operations with Controller references.');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
