const {context}=require('./context.cjs');
const ctx=context(process.argv[2]);
const phases=['foundation','attendance','requests','training-documents','checklists','decisions-payroll','readers-auth','denials'];
(async()=>{console.log('API E2E run '+ctx.run);for(const phase of phases){if(ctx.state.phases.includes(phase))continue;console.log('PHASE '+phase);await require('./'+phase+'.cjs')(ctx);ctx.state.phases.push(phase);ctx.save();}})().catch(e=>{console.error('API E2E stopped: '+e.message);process.exitCode=1;}).finally(()=>{console.log(JSON.stringify(ctx.report()));});
