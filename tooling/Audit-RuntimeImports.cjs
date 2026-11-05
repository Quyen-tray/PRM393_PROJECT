const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),seen=new Set();
function visit(file){file=path.resolve(file);if(seen.has(file)||!fs.existsSync(file))return;seen.add(file);const source=fs.readFileSync(file,'utf8');for(const match of source.matchAll(/(?:import|export)\s+['"]([^'"]+)['"]/g)){const name=match[1];if(name.startsWith('package:hrm_coffee_shop_flutter/'))visit(path.join(root,'lib',name.split('/').slice(1).join('/')));else if(!name.includes(':'))visit(path.resolve(path.dirname(file),name));}}
visit(path.join(root,'lib/main.dart'));
const files=[...seen].map(p=>path.relative(root,p).replaceAll('\\','/')).sort();
const demoReferences=files.filter(p=>/DemoData|data\/mock\//.test(fs.readFileSync(path.join(root,p),'utf8')));
const result={entry:'lib/main.dart',reachableFiles:files.length,files,demoReferences};
fs.mkdirSync(path.join(root,'.dart_tool'),{recursive:true});fs.writeFileSync(path.join(root,'.dart_tool/runtime-import-audit.json'),JSON.stringify(result,null,2));
console.log(files.length+' reachable Dart files; '+demoReferences.length+' production DemoData references.');
if(demoReferences.length)process.exitCode=1;
