// Read-only screen sweep through the real Flutter app and its real API calls.
// Chrome must run with a separate local acceptance profile and CDP port 9222.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const suites={
  employee:['/','/tasks','/profile','/module/my-schedule','/attendance/check-in','/module/my-attendance','/module/my-devices','/module/my-explanations','/module/my-overtime','/module/my-adjustments','/module/my-checklists','/module/training','/module/my-documents','/module/my-violations','/module/my-rewards','/module/notifications'],
  manager:['/','/tasks','/module/employees','/module/assignments','/module/shifts','/module/attendance','/module/devices','/module/explanations','/module/overtime','/module/adjustments','/module/checklists','/module/checklist-reviews','/module/training-reviews','/module/documents','/module/violations','/module/decisions','/module/payroll','/module/reports-attendance','/module/reports-operations','/module/courses','/profile'],
  admin:['/','/tasks','/module/employees','/module/shifts','/module/adjustments','/module/training-reviews','/module/documents','/module/payroll','/module/accounts','/module/positions','/module/courses','/module/templates','/module/document-types','/module/store-settings','/module/reminder-rules','/module/skills','/module/audit','/module/deliveries','/module/notifications','/profile']
};
(async()=>{
  const pages=await(await fetch('http://127.0.0.1:9222/json/list')).json();
  const page=pages.find(p=>p.type==='page'&&p.url.startsWith('http://127.0.0.1:5000'));
  if(!page)throw new Error('Local acceptance app tab required');
  const ws=new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{ws.onopen=resolve;ws.onerror=reject;});
  let id=0,events=[];const pending=new Map(),requests=new Set();
  ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);if(p)m.error?p.reject(new Error(m.error.message)):p.resolve(m.result);}
    if(m.method==='Network.requestWillBeSent'&&m.params.request.url.startsWith('http://127.0.0.1:8081/api/'))requests.add(m.params.requestId);
    if(m.method==='Network.responseReceived'&&m.params.response.url.startsWith('http://127.0.0.1:8081/api/'))events.push({path:new URL(m.params.response.url).pathname,status:m.params.response.status});
    if(['Network.loadingFinished','Network.loadingFailed'].includes(m.method))requests.delete(m.params.requestId);
  };
  const send=(method,params={})=>new Promise((resolve,reject)=>{const key=++id;pending.set(key,{resolve,reject});ws.send(JSON.stringify({id:key,method,params}));});
  const evaluate=async expression=>(await send('Runtime.evaluate',{expression,returnByValue:true,userGesture:true})).result.value;
  async function settled(){await delay(900);for(let i=0;requests.size&&i<20;i++)await delay(200);await delay(200);}
  const checks=[];
  async function check(actor,route,denied=false){events=[];await evaluate('location.hash='+JSON.stringify(route));await settled();const text=await evaluate("Array.from(document.querySelectorAll('flt-semantics')).map(e=>(e.getAttribute('aria-label')||'')+' '+(e.innerText||'')).join('\\n')");const forbidden=text.includes('403 · Không đủ quyền');const errorVisible=/Chưa thể hoàn tất|Không tìm thấy trang|Không thể kết nối máy chủ|Dữ liệu không còn tồn tại/.test(text);const bad=events.filter(e=>e.status>=400);const pass=denied?forbidden:!forbidden&&!errorVisible&&!bad.length;const result={actor,route,expectedDenied:denied,pass,errorVisible,forbidden,http:[...events]};checks.push(result);console.log((pass?'PASS ':'FAIL ')+actor+' '+route+' ('+events.length+' API responses)');}
  try {
    await send('Network.enable');await evaluate("document.querySelector('flt-semantics-placeholder')?.click()");
    for(const actor of ['employee','manager','admin']){
      const index=['employee','manager','admin'].indexOf(actor),width=await evaluate('innerWidth'),x=50+(width-50)/3*(index+.5);
      await send('Input.dispatchMouseEvent',{type:'mousePressed',x,y:22,button:'left',clickCount:1});await send('Input.dispatchMouseEvent',{type:'mouseReleased',x,y:22,button:'left',clickCount:1});await settled();
      for(const route of suites[actor])await check(actor,route);
      if(actor==='employee')await check(actor,'/module/accounts',true);
      if(actor==='manager')await check(actor,'/module/store-settings',true);
    }
    const output={checkedAt:new Date().toISOString(),environment:'Flutter web + actual loopback backend + dedicated SQL Server database',checks};
    fs.writeFileSync(path.join(root,'.dart_tool/live-screen-tour.json'),JSON.stringify(output,null,2));
    console.log(checks.filter(r=>r.pass).length+'/'+checks.length+' screen checks passed.');
    if(checks.some(r=>!r.pass))process.exitCode=1;
  } finally {ws.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
