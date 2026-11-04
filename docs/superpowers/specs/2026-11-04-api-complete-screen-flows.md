# HRM Coffee Shop — API-complete screen flow design

## Goal and source of truth

Cover the workflows in `SRS_HRM_Coffee_Shop_v2.0.docx` with reachable, understandable Flutter screens and actions for every functional endpoint in `API_REFERENCE.md`.

The SRS is a proposed business design and says HR is a permission set, not a fourth mandatory role. The API reference describes the backend currently implemented and is the contract for request names, permissions, and response behavior. Keep the existing SQL Server database and backend behavior; do not add Docker or a client-side permission bypass.

## Information architecture

### Entry and shared account flow

`Google login → fetch /users/me and effective permissions → choose an enabled workspace → role dashboard`

- Restore a valid saved session on app start; refresh access tokens through the existing API client and revoke the refresh token on sign-out.
- Show Employee, Manager, and Admin workspaces from role assignments. If the account has HR permission-set capabilities, also show an HR work queue. This does not create an HR role or change backend authorization.
- Shared account screen edits display name/phone and exposes role/workspace switching only where applicable.
- Every screen has a logical back destination; primary areas retain a consistent bottom navigation. Every write action shows API validation/business errors and refreshes the affected data after success.

### Employee workspace

Bottom navigation: **Trang chủ · Lịch · Checklist · Cá nhân**. The dashboard provides quick access to attendance, training, notifications, documents, violations, rewards, and HR tasks when the signed-in user has those permissions.

1. **Trang chủ** — employee overview, personal profile, current/next shift, unread count, checklist count, and current attendance action.
2. **Lịch** — published personal assignments; assignment detail and eligibility explain server-computed conditions.
3. **Chấm công** — current shift, device state, GPS distance/accuracy, camera/photo state, check-in or check-out result. Device registration remains PENDING until approved. History opens attendance detail and verification records. The same area links to explanation, adjustment, and overtime request forms and their statuses.
4. **Checklist** — assigned task list → task detail → start → complete items → upload evidence → submit. Show deadline, required evidence, approval state, and retry path after rejection.
5. **Đào tạo & kỹ năng** — course catalog and requirements → enroll → server-scored quiz or practical-course review → results; show employee skill history and certificates.
6. **Hồ sơ** — account and employment details, required-document catalog, upload/submit, metadata and review state.
7. **Thông báo / Vi phạm / Thưởng phạt** — read one/read all and unread count; show owned violations and explanation history; show own paginated decisions.

### Manager workspace

Bottom navigation: **Tổng quan · Nhân viên · Lịch · Duyệt · Khác**.

1. **Tổng quan** — overview, attendance statistics, employee status, operations, rewards/penalties summary, pending work, and links to reports.
2. **Nhân viên** — searchable/paged roster → employee profile, overview, attendance summary, documents, training progress, skills; permitted users can create/edit employee records and change employment status.
3. **Lịch** — work-shift catalog create/edit → date/employee assignment list → create/edit/cancel assignment → assignment detail and eligibility.
4. **Duyệt** — one queue for device approval/rejection/revocation, explanations, manager-stage attendance adjustments, overtime, submitted checklists, documents, course completion, violations, and reward/penalty decisions. A dedicated HR queue handles HR-stage adjustment decisions.
5. **Checklist vận hành** — choose active template and date/shift/employee → generate task → inspect task and evidence → reassign when necessary → review/approve/reject where configured.
6. **Khác / Báo cáo** — attendance report and detail, operations report, payroll-readiness report, payroll period confirmation/absence request, rewards, violations, and account profile.

### Admin workspace

Bottom navigation: **Tổng quan · Tài khoản · Chức vụ · Đào tạo · Khác**.

1. **Tổng quan** — real account, course, and checklist-template counts.
2. **Tài khoản** — create/list accounts, roles/status, permission catalog, effective/direct permissions.
3. **Chức vụ** — job positions, document types and per-position document requirements, per-position training requirements.
4. **Đào tạo** — course create/edit, question bank and answer key, completion review.
5. **Khác** — checklist templates/versions, store location and store settings, attendance policy, reminder rules, skill catalog, notification deliveries, audit-log search/detail/export.

### HR permission-set workspace

The HR dashboard is a permission-derived work queue, not a new backend role. It links only to actions allowed by `/users/me/permissions`:

- employee management and employee document review;
- HR-stage attendance adjustment approval/rejection;
- payroll period creation, readiness review, finalization, and authorized reopen;
- attendance and payroll-readiness reports;
- training progress and any separately granted device/document/reward review permissions.

The backend remains authoritative; hiding a link is usability only.

## API-to-screen coverage map

Every API reference endpoint belongs to one of these flows. Alias paths share one action and do not get duplicate UI. Binary signed-file viewing and automatic token refresh are shared infrastructure.

| API group | Screen/action |
|---|---|
| Auth, current user, profile, permissions | Login/session restore, profile edit, workspace selection/switch, sign-out |
| Current store, store settings, attendance policies, reminder rules | Employee/attendance context; Admin → Cấu hình hệ thống |
| Employee list/detail/create/update/status/overview/documents/training/attendance summary/skills | Manager and HR → Nhân viên → Hồ sơ nhân viên and tabs |
| Work-shift catalog and shift assignments (list/create/update/cancel/detail/eligibility) | Manager → Lịch; Employee → Lịch |
| Attendance check-in/out/current/history/list/summary/detail/verifications | Employee → Chấm công; Manager/HR → Chấm công and report detail |
| Device register/list/pending/approve/reject/revoke/list by employee | Employee → Thiết bị chấm công; Manager/authorized HR → Duyệt thiết bị |
| Explanation, overtime, manager adjustment, HR adjustment | Employee request/history; Manager/HR approval queues |
| Checklist template CRUD/activate, generate, employee task/detail/start/complete/evidence/submit, manager instance/detail/reassign/pending/approve/reject | Admin → Checklist templates; Employee → Checklist; Manager → Checklist vận hành/Duyệt |
| Course catalog/admin CRUD/position requirements/enroll/quiz and attempts/completion review/progress | Employee → Đào tạo; Admin → Đào tạo; Manager/HR → Duyệt đào tạo and progress |
| Skills catalog/create/assessment/history | Admin → Kỹ năng; Manager/HR → Employee detail → Kỹ năng |
| Employee documents/types/requirements/submit/review/detail/upload/signed view | Employee → Hồ sơ; Admin → Chức vụ/Loại hồ sơ; Manager/HR → Duyệt hồ sơ |
| Violations list/detail/confirm/dismiss and employee explanation history | Employee → Vi phạm; Manager/authorized HR → Duyệt vi phạm |
| Reward rule catalog/propose/list/approve/reject/cancel/employee decisions | Manager/authorized HR → Thưởng phạt; Employee → Thưởng phạt của tôi |
| Manager/employee dashboards and attendance/operations/rewards reports | Role dashboard and Manager → Báo cáo |
| Notifications list/unread/read/read-all and admin delivery list | Employee → Thông báo; Admin → Giao nhận thông báo |
| Audit list/detail/export | Admin → Nhật ký hệ thống |
| Payroll period list/create/readiness/manager confirm/absence request/HR finalize/reopen | Manager → Kỳ công; HR → Đối soát/chốt kỳ công |
| Upload bytes and signed file view | Shared upload controls in attendance, checklist, and documents; signed evidence/file viewers |

## Existing implementation gaps to close

- Add an HR permission-set entry/landing and links based on the effective permission set.
- Add explicit Admin attendance-policy and document-type create/update flows.
- Add Admin audit detail and CSV export actions.
- Add work-shift template create/update, assignment detail/eligibility, and manager checklist generate/reassign flows.
- Add attendance detail/verification and summary screens/actions; expose employee attendance summaries in employee detail.
- Add the missing manager employee-status, operations, and reward-summary dashboard data and the operations/payroll-readiness reports.
- Add explicit route coverage for pending checklist reviews and HR-stage attendance adjustment decisions.
- Keep shared behavior for auth refresh/logout, binary uploads, and signed URL viewing; do not invent extra APIs for aliases.

## Demo acceptance plan

Use the local SQL Server database and configured test users. Test Admin → Manager → Employee/HR permission workspaces with refreshed API data after each mutation. Exercise a happy path and an allowed rejection/retry branch for attendance device approval, attendance exceptions, checklist review, course review, documents, violations, rewards, and payroll. Verify that role/permission-limited accounts see their permitted actions and backend-denied actions show a useful error.

Device GPS, device fingerprint, and camera check-in/out require Android or iOS. A Windows/Chrome build may validate the rest of the API-driven screens, but must not be reported as an end-to-end attendance test. Do not use a real production database or report a flow as passed without actually performing it.
