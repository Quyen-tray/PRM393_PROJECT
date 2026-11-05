// Author missing sample questions through the Admin UI, only in the isolated test DB.
// Existing question banks are preserved. This is fixture preparation, not production seeding.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..');
const config=JSON.parse(fs.readFileSync(path.join(root,'.dart_tool/v3-build-env-web.json'),'utf8').replace(/^\uFEFF/,''));
const sessions=JSON.parse(config.ACCEPTANCE_SESSIONS),database=fs.readFileSync(path.join(root,'.dart_tool/v3-database.txt'),'utf8').trim();
if(sessions.database!==database||!/^HRM_CoffeeShop_V3_Test(?:_\d+)?$/.test(database))throw new Error('Dedicated acceptance database required');
const ui=(...args)=>cp.execFileSync(process.execPath,[path.join(__dirname,'browser-ui.cjs'),...args],{encoding:'utf8',windowsHide:true,maxBuffer:1024*1024});
const examples=[
  {id:1,question:'Trước khi tiếp xúc trực tiếp với thực phẩm cần làm gì?',options:['Vệ sinh tay theo quy trình an toàn thực phẩm','Bỏ qua vệ sinh tay','Chỉ lau tay vào tạp dề','Dùng dụng cụ đang bẩn']},
  {id:2,question:'Khi cần sửa giờ công đã ghi nhận, nhân viên cần làm gì?',options:['Gửi yêu cầu điều chỉnh và theo dõi các bước duyệt','Đổi giờ hệ thống để sửa công','Dùng tài khoản của đồng nghiệp','Tự xóa bản ghi chấm công']},
  {id:3,question:'Trước khi sử dụng máy pha đầu ca cần làm gì?',options:['Kiểm tra vệ sinh và tình trạng thiết bị theo checklist','Sử dụng ngay, không kiểm tra','Bỏ qua checklist đầu ca','Để dụng cụ bẩn cho ca sau xử lý']},
  {id:4,question:'Cách nào giúp ghi nhận nhất quán khi so sánh các mẫu cà phê?',options:['Dùng cùng tiêu chí và ghi nhận riêng từng mẫu','Trộn tất cả mẫu rồi ghi một kết quả','Không ghi lại nhận xét','Chỉ đánh giá theo màu của cốc']}
];
async function bank(id){const r=await fetch('http://127.0.0.1:8081/api/v1/admin/training/courses/'+id+'/questions',{headers:{Authorization:'Bearer '+sessions.admin.accessToken},signal:AbortSignal.timeout(12000)});if(!r.ok)throw new Error('Question bank read failed: '+r.status);return(await r.json()).data;}
(async()=>{
  ui('actor','admin');
  for(const sample of examples){
    if((await bank(sample.id)).length){console.log('Preserved existing questions for course '+sample.id);continue;}
    ui('navigate','/record/courses/'+sample.id);ui('enable');ui('scroll','9999');
    ui('activate','Chỉnh sửa câu hỏi');ui('activate','Thêm mục');
    ui('fill','Câu hỏi',sample.question);
    for(let i=0;i<4;i++)ui('fill','Đáp án '+String.fromCharCode(65+i),sample.options[i]);
    ui('tap','Đáp án đúng');ui('click','90','537');
    ui('activate','Lưu và hoàn tất');ui('activate','Lưu và hoàn tất');
    const saved=await bank(sample.id);
    if(saved.length!==1||saved[0].questionText!==sample.question||saved[0].correctOption!=='A')throw new Error('Published question did not match submitted UI data for course '+sample.id);
    console.log('Prepared course '+sample.id+' through Admin UI.');
  }
})().catch(e=>{console.error(e.message);process.exitCode=1;});
