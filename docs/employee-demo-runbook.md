# Employee demo runbook (Android Emulator)

This runbook uses the employee, manager, and admin workflows against an isolated local SQL Server database. It uses real Google OAuth test accounts and includes an employee-scored training quiz flow.

## Before you start

- Android Studio with an Android Emulator that includes Google Play services.
- JDK 17, Maven, Flutter, and SQL Server.
- A Google OAuth project with a Web OAuth client ID and an Android OAuth client ID.
- Six Google accounts added to the OAuth consent screen's **Test users** list: one admin, one store manager, one HR reviewer account, and three employees. The HR account is optional for the Employee/Manager/Admin demo paths below. Keep the email addresses and OAuth client IDs out of source control.

The Android application ID in this checkout is `com.example.hrm_coffee_shop_flutter`. The Android OAuth client must use that exact application ID and the debug signing SHA-1 from this machine. From the `android` directory, get the SHA-1 with:

```powershell
.\gradlew signingReport
```

The app's `GOOGLE_CLIENT_ID` is the **Web client ID**. Configure the same Web client ID in the backend's `GOOGLE_CLIENT_ID`; it is used as the Google Sign-In server client ID so the backend can validate the resulting ID token. The Android client ID is for Google's Android app/package/SHA-1 validation.

## Prepare an isolated demo database

The backend schema is managed by `hrm-coffeeshop-backend/infra/sqlserver/config.sql`. There is no general-purpose migration system for an already populated database. **Do not run `config.sql` or `seeddata.sql` against a database that contains data you need to keep.** `config.sql` stops if `HRM_CoffeeShop` already exists. Use a clean local SQL Server instance for this demo; if your existing database must be preserved, have a DBA prepare a separately isolated demo database before continuing.

For an already isolated demo database, apply `hrm-coffeeshop-backend/infra/sqlserver/migrations/2026-11-03-training-quiz-and-nonblocking.sql` and `hrm-coffeeshop-backend/infra/sqlserver/migrations/2026-11-03-training-completion-review.sql` once before starting the backend. The first creates the quiz question table, seeds five questions for Employee A's `BARISTA_BASIC` course if empty, permits quiz attempt records, and clears training-based shift restrictions. The second adds review metadata for practical courses. On a clean database, `config.sql` already includes both schema changes and `seeddata.sql` seeds questions for all four demo courses.

Before the first seed, open `hrm-coffeeshop-backend/infra/sqlserver/seeddata.sql` and replace every occurrence of these sample email addresses with the matching Google OAuth test account. Use **Find All / Replace All** for each complete address so the account lookup references continue to match the inserted rows:

| Seed email | Demo identity |
|---|---|
| `baonvhe181955@fpt.edu.vn` | System admin |
| `quanly@hrm.test` | Store manager / document and violation reviewer |
| `hr@hrm.test` | HR reviewer and employee with returned checklist data |
| `nv.an@hrm.test` | Employee A (`NV001`): active device, current shift, open violations, training progress, checklist, notifications, and optional document type |
| `nv.binh@hrm.test` | Employee B (`NV002`): pending documents/device and a different ownership scope |
| `nv.chi@hrm.test` | Employee C (`NV003`): rejected document, failed/incomplete training, and returned work scenarios |

Do not replace only the account insert values: replace all occurrences of each address in the file. Then, in SSMS, run the whole `config.sql` file once followed by the whole `seeddata.sql` file once. These are development fixtures; do not use them in production.

## Start the backend

Set the local database and OAuth values in the PowerShell window used to start the backend. Use your own SQL password, JWT secret, and Web client ID; do not paste them into project files.

```powershell
Set-Location hrm-coffeeshop-backend
$env:DB_URL = 'jdbc:sqlserver://localhost:1433;databaseName=HRM_CoffeeShop;encrypt=true;trustServerCertificate=true'
$env:DB_USERNAME = 'sa'
$env:DB_PASSWORD = 'YOUR_LOCAL_SQL_PASSWORD'
$env:JWT_SECRET = 'YOUR_RANDOM_SECRET_AT_LEAST_32_CHARACTERS'
$env:STORAGE_SIGNING_SECRET = 'YOUR_RANDOM_SECRET_AT_LEAST_32_CHARACTERS'
$env:GOOGLE_CLIENT_ID = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com'
mvn spring-boot:run
```

Wait for Spring Boot to report that it started on port `8080` and that Google login accepts the configured client ID. Keep this process running. Local uploaded files are stored under `hrm-coffeeshop-backend/data/storage` by default.

## Start Flutter on the emulator

The Android main manifest now declares Internet access. Debug/profile builds allow HTTP only so the emulator can reach the local backend; release builds do not enable cleartext traffic.

```powershell
flutter devices
flutter run -d YOUR_EMULATOR_ID --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

`10.0.2.2` is the Android Emulator route to the development computer. Sign in with a Google account from the OAuth **Test users** list whose email was mapped to the corresponding seeded account above. If Google returns `ApiException: 10`, check the Android OAuth package ID and debug SHA-1. If the app says it cannot get an ID token or the backend rejects the token audience, make sure the Web client ID passed to Flutter and backend is the same.

## Screen flow and navigation

After Google sign-in, a user with more than one enabled role sees **Chọn không gian làm việc**. The profile screen also offers **Chuyển vai trò sử dụng** so the same account can move between workspaces without signing out. A saved session is restored on the next launch.

- **Employee:** Trang chủ → Lịch / Checklist / Cá nhân from the bottom bar. Check-in, Đào tạo, Thông báo, Lịch sử công, Hồ sơ giấy tờ, Vi phạm, and Thưởng/phạt are reachable from quick links. Check-in requires a published shift, an approved device, an in-radius GPS fix, and a fresh camera photo. Training quiz courses pass at their configured score; practical courses wait for Admin/Manager review. Training progress does not block shift assignment or attendance.
- **Manager:** Tổng quan / Nhân viên / Lịch / Duyệt / Khác from the shared bottom bar. The Khác sheet opens the profile, attendance report, reward and penalty review, payroll periods, violation review, checklist review, course-completion review, and sign-out. Managers can approve a newly registered employee device from Duyệt → Thiết bị.
- **Admin:** Tổng quan / Tài khoản / Chức vụ / Đào tạo / Khác from the shared bottom bar. Configure the store's GPS from Khác → Cấu hình hệ thống → GPS và bán kính chấm công while standing at the shop; the form reads the current device location and saves the coordinates and radius. Course questions are managed from each course's quiz action, and practical completions from the review action on the training screen.

Secondary pages include an app-bar back action and keep the role's bottom navigation where it is useful. Attendance device registration is restricted to Android/iOS; use an Android/iOS device or emulator to complete the check-in flow.

## Demo sequence

1. **Admin:** sign in, review accounts, positions, courses, and checklist templates. Open **Cấu hình hệ thống → GPS và bán kính chấm công**, stand at the shop, tap **Lấy GPS hiện tại**, set a radius that matches the test device accuracy, and save.
2. **Employee A (`NV001`)**: sign in, open the employee dashboard, view today's shift, schedule, checklist, training progress, notifications, profile, rewards, and violations.
3. **Checklist**: open the due checklist, start it, complete the required items, attach evidence where required, and submit. Sign in as the manager to approve it.
4. **Documents**: Employee A can submit the active food-safety document type as an optional document for the barista position. Employee C has a rejected resume that can be resubmitted. Use an actual PDF/JPEG/PNG/WebP file no larger than 10 MB. Sign in as the manager and open **Documents** to approve or reject. Return to the employee profile to refresh and see the persisted status. Seeded file keys are metadata and may not have matching local file bytes, so upload a new file when demonstrating preview.
5. **Attendance and device approval**: on the Android emulator, grant location and camera permissions. In Extended Controls → **Location**, set the emulator close to the saved shop coordinates (or the seeded coordinates `21.0278, 105.8342`); the seeded radius is 30 m. Employee A has a seeded active device and current shift, so can check in/out during the configured attendance window and capture a live camera photo. To demonstrate device approval, register Employee B's device, switch to Manager → **Duyệt → Thiết bị**, approve it, then switch back to Employee B. The app refreshes GPS immediately before submission and the capture screen has a front/back camera switch. If GPS accuracy is poor or the emulator is outside the geofence, update its location and retry.
6. **Training quiz**: Employee A opens **Đào tạo & kỹ năng**, selects the enrolled **Kỹ thuật pha chế cơ bản** course, and answers its five multiple-choice questions. Four correct answers reach the 70-point passing score; the backend calculates and stores the score and marks the course **Đạt** immediately. A failed attempt can be retaken. Training completion does not gate shift assignment or check-in. As Admin, open **Quản lý đào tạo** and use a course's quiz action to add, edit, or remove its questions and answer key.
7. **Practical training review**: use an active course with **Bài kiểm tra: Không**. The employee enrolls and sees that Admin/Manager must confirm completion. Sign in as the manager or system admin, open **Duyệt hoàn thành khóa học**, and either confirm the course or record that it is not complete with a note. Confirmed courses change to **Đã đạt**; incomplete courses remain in progress and stay in the review list. Quiz courses continue to use their configured passing score and cannot be manually approved.
8. **Ownership check**: sign in as Employee B or C and verify their pages show only their own documents, violations, and decisions. Employee B must not be able to read or explain Employee A's violation.
9. **Notifications and rewards**: mark a notification read, refresh the page, and confirm it remains read. Browse the employee's paged reward/penalty decisions.

## Verification already available locally

From the project root:

```powershell
flutter test
flutter analyze
```

From `hrm-coffeeshop-backend`:

```powershell
mvn test
```

Backend integration tests require Docker for SQL Server Testcontainers. Do not treat a Docker startup failure as an integration-test pass. The focused/full test and emulator outcomes from a particular machine should be recorded separately from this reusable setup guide.
