const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..');
const adb='D:\\dev\\Android\\Sdk\\platform-tools\\adb.exe';
const run=(...args)=>cp.execFileSync(adb,['-s','emulator-5554',...args],{encoding:'utf8',windowsHide:true});
const args=process.argv.slice(2),action=args[0]||'dump';
const decode=s=>s.replaceAll('&amp;','&').replaceAll('&quot;','"').replaceAll('&#10;','\n');
function nodes(){run('shell','uiautomator','dump','/sdcard/hrm-ui.xml');const xml=run('exec-out','cat','/sdcard/hrm-ui.xml');fs.writeFileSync(path.join(root,'.dart_tool/android-ui.xml'),xml);return [...xml.matchAll(/<node\b([^>]+)>/g)].map(m=>Object.fromEntries([...m[1].matchAll(/([\w-]+)="([^"]*)"/g)].map(a=>[a[1],decode(a[2])])));}
function tap(x,y){run('shell','input','tap',String(Math.round(x)),String(Math.round(y)));}
if(action==='dump'){console.log(JSON.stringify(nodes().filter(n=>n.text||n['content-desc']).map(n=>({text:n.text,label:n['content-desc'],bounds:n.bounds,clickable:n.clickable})),null,2));}
else if(action==='tap'){const list=nodes();const needle=args[1];const matches=list.filter(n=>(n.text||n['content-desc']||'').includes(needle)&&n.enabled==='true');const target=matches.find(n=>n.clickable==='true')||matches[0];if(!target)throw new Error('UI target not found: '+needle);const [x1,y1,x2,y2]=target.bounds.match(/\d+/g).map(Number);tap((x1+x2)/2,(y1+y2)/2);console.log('Tapped '+needle);}
else if(action==='tap-at'){tap(Number(args[1]),Number(args[2]));}
else if(action==='actor'){const size=run('shell','wm','size').match(/(\d+)x(\d+)/);const width=Number(size[1]);const index=['employee','manager','admin'].indexOf(args[1]);if(index<0)throw new Error('Unknown actor');tap(95+(width-95)/3*(index+.5),120);console.log('Selected acceptance actor '+args[1]);}
else if(action==='scroll'){run('shell','input','swipe','540',args[1]==='up'?'650':'1800','540',args[1]==='up'?'1800':'650','450');}
else if(action==='back'){run('shell','input','keyevent','4');}
else if(action==='gps'){run('emu','geo','fix',args[1]||'105.8342',args[2]||'21.0278');console.log('Emulator GPS updated.');}
else if(action==='screenshot'){const name=args[1]||'android-screen';if(!/^[a-z0-9-]+$/.test(name))throw new Error('Invalid screenshot name');const dir=path.join(root,'.dart_tool/screenshots');fs.mkdirSync(dir,{recursive:true});run('shell','screencap','-p','/sdcard/hrm-screen.png');run('pull','/sdcard/hrm-screen.png',path.join(dir,name+'.png'));console.log('Saved '+name+'.png');}
else throw new Error('Unknown action');
