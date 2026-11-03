# Employee demo runbook (Android Emulator)

This runbook uses the existing employee, manager, and admin workflows against an isolated local SQL Server database. It uses real Google OAuth test accounts. It does not add a test login or change training assessment authority.

## Before you start

- Android Studio with an Android Emulator that includes Google Play services.
- JDK 17, Maven, Flutter, and SQL Server.
- A Google OAuth project with a Web OAuth client ID and an Android OAuth client ID.
- Five Google accounts added to the OAuth consent screen's **Test users** list: one admin, one store manager, and three employees. Keep the email addresses and OAuth client IDs out of source control.

The Android application ID in this checkout is `com.example.hrm_coffee_shop_flutter`. The Android OAuth client must use that exact application ID and the debug signing SHA-1 from this machine. From the `android` directory, get the SHA-1 with:

```powershell
.\gradlew signingReport
```

The app's `GOOGLE_CLIENT_ID` is the **Web client ID**. Configure the same Web client ID in the backend's `GOOGLE_CLIENT_ID`; it is used as the Google Sign-In server client ID so the backend can validate the resulting ID token. The Android client ID is for Google's Android app/package/SHA-1 validation.

## Prepare an isolated demo database

The backend schema is managed by `hrm-coffeeshop-backend/infra/sqlserver/config.sql`. This project does not include a migration for an already populated database. **Do not run `config.sql` or `seeddata.sql` against a database that contains data you need to keep.** `config.sql` stops if `HRM_CoffeeShop` already exists. Use a clean local SQL Server instance for this demo; if your existing database must be preserved, have a DBA prepare a separately isolated demo database before continuing.

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

## Demo sequence

1. **Employee A (`NV001`)**: sign in, open the employee dashboard, view today's shift, schedule, checklist, training progress, notifications, profile, rewards, and violations.
2. **Checklist**: open the due checklist, start it, complete the required items, attach evidence where required, and submit. Sign in as the manager to approve it. Use the HR employee's seeded returned checklist to demonstrate rework and resubmission.
3. **Documents**: Employee A can submit the active food-safety document type as an optional document for the barista position. Employee C has a rejected resume that can be resubmitted. Use an actual PDF/JPEG/PNG/WebP file no larger than 10 MB. Sign in as the manager and open **Documents** to approve or reject, or sign in as the HR employee and open **Duyệt hồ sơ** from its employee dashboard. Return to the employee profile to refresh and see the persisted status. Seeded file keys are metadata and may not have matching local file bytes, so upload a new file when demonstrating preview.
4. **Violation explanation**: Employee A opens a `PENDING` violation and submits an explanation, optionally with evidence. The explanation appears as a separate history item. The manager can review it and use the existing confirm/dismiss action; the employee submission itself does not decide the violation.
5. **Attendance**: on the emulator, grant location and camera permissions. In Extended Controls → **Location**, set the emulator close to the seeded store coordinates (`21.0278, 105.8342`). The seeded store radius is 30 m. Employee A has a seeded active device and current shift; use check-in/out during the backend's configured attendance window and capture a live camera photo. If the emulator is outside the geofence or reports poor GPS accuracy, update its location and retry.
6. **Training**: view course, skill, and certificate information and enroll in an eligible course. Employee assessment submission and score calculation remain unchanged; the Manager/trusted-LMS flow retains authority over scores.
7. **Ownership check**: sign in as Employee B or C and verify their pages show only their own documents, violations, and decisions. Employee B must not be able to read or explain Employee A's violation.
8. **Notifications and rewards**: mark a notification read, refresh the page, and confirm it remains read. Browse the employee's paged reward/penalty decisions.

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
