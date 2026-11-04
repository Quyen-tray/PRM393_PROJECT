// Read-only verification against the isolated SQL Server acceptance backend.
// Prints business states/counts only, never credentials or signed file URLs.
const fs = require('node:fs'), path = require('node:path');
const root = path.resolve(__dirname, '..');
const config = JSON.parse(fs.readFileSync(path.join(root, '.dart_tool/v3-build-env-web.json'), 'utf8').replace(/^\uFEFF/, ''));
const sessions = JSON.parse(config.ACCEPTANCE_SESSIONS);
const database = fs.readFileSync(path.join(root, '.dart_tool/v3-database.txt'), 'utf8').trim();
if (sessions.database !== database || !/^HRM_CoffeeShop_V3_Test(?:_\d+)?$/.test(database)) throw new Error('Dedicated test database required');
async function get(actor, endpoint) {
  const r = await fetch('http://127.0.0.1:8081/api/v1' + endpoint, {headers: {Authorization: 'Bearer ' + sessions[actor].accessToken}, signal: AbortSignal.timeout(12000)});
  const body = await r.json();
  if (!r.ok) throw new Error(endpoint + ': HTTP ' + r.status + ' ' + body.error?.code);
  return body.data;
}
(async () => {
  const history = await get('employee', '/attendance/me');
  console.log('Attendance', JSON.stringify(history.items.map(r => ({id:r.attendanceId,workDate:r.workDate,checkInAt:r.checkInAt,checkOutAt:r.checkOutAt,attendanceStatus:r.attendanceStatus,status:r.status}))));
  for (const attendance of history.items) {
    const verifications = await get('employee', '/attendance/' + attendance.attendanceId + '/verifications');
    console.log('Verifications', attendance.attendanceId, JSON.stringify(verifications.map(r => ({type:r.verificationType,status:r.verificationStatus,distance:r.distanceMeters,hasPhoto:!!r.evidenceViewUrl}))));
  }
  const courses = await get('employee', '/training/courses');
  console.log('Courses', JSON.stringify(courses.map(r=>({id:r.courseId,name:r.courseName,quiz:r.isMandatoryTest}))));
  const mine = await get('employee','/training/me');
  console.log('Enrollments', JSON.stringify(mine.map(r=>({id:r.employeeTrainingId,courseId:r.courseId,status:r.status,score:r.testScore}))));
  for (const row of mine.filter(r=>courses.some(c=>c.courseId===r.courseId&&c.isMandatoryTest))) {
    try {
      const quiz=await get('employee','/training/courses/'+row.courseId+'/quiz');
      console.log('Quiz',row.courseId,'questions',quiz.length);
    } catch(e) { console.log('Quiz', row.courseId, e.message); }
  }
  const periods = await get('manager','/payroll-periods');
  console.log('Periods', JSON.stringify(periods.map(p=>({id:p.periodId,code:p.periodCode,from:p.startDate,to:p.endDate,status:p.status}))));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
