# Employee Workflows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Make every non-assessment employee workflow demonstrable end-to-end against the local backend, including document review and violation explanations.

**Architecture:** Extend the existing Spring Boot APIs and SQL Server schema, keeping authenticated backend data as the source of truth. Add the missing Flutter employee/reviewer surfaces and routes on the existing `EmployeeRepository`/GoRouter patterns. Finish with local demo instructions and emulator verification.

**Tech Stack:** Flutter/Dart, Riverpod, GoRouter, Spring Boot, Spring Data JPA, SQL Server, SQL Server Testcontainers, Android Emulator.

**Spec:** `docs/superpowers/specs/2026-11-03-employee-workflows-design.md`

## Global Constraints

- Keep assessment taking, score calculation, and employee score submission unchanged; trusted-LMS/manager remains the score authority.
- Derive self-service employee ownership from the authenticated security context; never accept a client employee ID to decide ownership.
- Preserve existing `DOCUMENT_REVIEW` and `VIOLATION_REVIEW` permissions and existing manager decision transitions.
- Keep explanations append-only and separate from manager `ReviewNote`; submission does not change violation status.
- Accept HR document uploads only as signature-validated PDF/JPEG/PNG/WebP up to 10 MB; keep keys private and employee-owned.
- Use the current database schema convention: `config.sql` is the DDL source, `seeddata.sql` is development/test data, and no migration file is introduced.
- Do not run `config.sql` or `seeddata.sql` against a populated database. Use an isolated local/test database.
- Use real Google OAuth Test users for app demo sign-in; do not enable or add a demo authentication bypass.
- Do not run Git/GitHub commands or change Git/GitHub state.

## Review Focus

- Employee A requests Employee B's document/violation or submits B's storage key: tests must assert denial and no data disclosure.
- Two concurrent document submissions target the same employee/type: tests must assert only one `PENDING` row can persist.
- A document is approved with no expiry, expires today, or has an expiry date before today: tests must pin the allow/block decision.
- A violation explanation is submitted after the manager has decided, or is submitted again before the decision: tests must assert closed violations reject and open violations append immutable rows.
- A validly signed-in Google user targets the local Android backend: runbook must use the same Web Client ID and `10.0.2.2`, with no password-login fallback.

---

## Dependency Map

```text
Task 1: Document backend and lifecycle ──> Task 2: Flutter documents/reviewer
Task 3: Violation explanation backend ───> Task 4: Flutter explanations/review UI
Tasks 2 + 4 ─────────────────────────────> Task 5: Navigation and existing-flow test pass
Tasks 1–5 ───────────────────────────────> Task 6: Demo runbook/data verification
Tasks 1–6 ───────────────────────────────> Task 7: Full tests and Android emulator demo
```

Tasks 1 and 3 are separate vertical slices; this plan executes them sequentially so the shared schema, repository, and API code stay easy to review.

## File Map

| Area | Files and responsibility |
|---|---|
| Document backend | `hrm-coffeeshop-backend/infra/sqlserver/config.sql` for the filtered pending index; `shared/dto/DocumentDto.java` for catalog response; `shared/service/DocumentService.java` for catalog and eligibility; `employee/controller/EmployeeDocumentController.java` for self-service route; `repository/EmployeeDocumentRepository.java` and `tools/repo_extras.py` for queries; generated entity/repository output from `tools/gen_entities.py`. |
| Document tests | Create `hrm-coffeeshop-backend/src/test/java/com/hrm/coffeeshop/it/EmployeeDocumentWorkflowIT.java`; extend `DocumentSubmitIT.java` only where its current contract needs lifecycle assertions. |
| Document Flutter | Extend `lib/data/repositories/employee_repository.dart`; add `lib/features/documents/presentation/employee_documents_tab.dart` and reviewer page; extend `lib/features/profile/presentation/employee_profile_page.dart` with personal-info, position/work, and documents tabs; add a documents deep-link route and dashboard/reviewer navigation. Use an injectable file-picker adapter so widget tests do not invoke Android's system picker. |
| Violation backend | `config.sql`; generated `domain/ViolationExplanation.java` and repository; create `shared/dto/ViolationExplanationDto.java` and `shared/service/ViolationExplanationService.java`; extend `EmployeeViolationController.java` and `SharedViolationController.java`. |
| Violation tests | Create `hrm-coffeeshop-backend/src/test/java/com/hrm/coffeeshop/it/ViolationExplanationIT.java`. |
| Violation Flutter | Extend `employee_repository.dart`; create `lib/features/violations/presentation/employee_violations_page.dart`; extend `manager_violation_review_page.dart`; add route names, routes, and dashboard links. |
| Navigation tests | Create `test/features/home/employee_dashboard_navigation_test.dart`; add focused page tests under `test/features/documents/` and `test/features/violations/`. |
| Demo instructions | Create `docs/employee-demo-runbook.md`. Edit `seeddata.sql` only if a required deterministic local/test state is proven missing. |

---

### Task 1: Employee document catalog and submission lifecycle

**Files:**
- Modify: `hrm-coffeeshop-backend/infra/sqlserver/config.sql`
- Modify: `hrm-coffeeshop-backend/src/main/java/com/hrm/coffeeshop/shared/dto/DocumentDto.java`
- Modify: `hrm-coffeeshop-backend/src/main/java/com/hrm/coffeeshop/shared/service/DocumentService.java`
- Modify: `hrm-coffeeshop-backend/src/main/java/com/hrm/coffeeshop/employee/controller/EmployeeDocumentController.java`
- Modify: `hrm-coffeeshop-backend/src/main/java/com/hrm/coffeeshop/repository/EmployeeDocumentRepository.java`
- Modify if needed for generated query support: `hrm-coffeeshop-backend/tools/repo_extras.py`
- Generate: entity/repository output using `hrm-coffeeshop-backend/tools/gen_entities.py`
- Create: `hrm-coffeeshop-backend/src/test/java/com/hrm/coffeeshop/it/EmployeeDocumentWorkflowIT.java`
- Test: `hrm-coffeeshop-backend/src/test/java/com/hrm/coffeeshop/it/DocumentSubmitIT.java`

**Interfaces:**
- Produces `GET /api/v1/employees/me/documents/catalog` returning `DocumentCatalogView(positionId, asOfDate, documents)`; each `DocumentCatalogItem` carries type ID/code/name, `isActive`, `required`, latest status, `canSubmit`, and optional `blockReason`.
- Produces `DocumentService.catalog(Long employeeId)` and server-side `DocumentService.canSubmit(Long employeeId, Integer documentTypeId, LocalDate today)` behavior.
- Existing `GET/POST /employees/me/documents` remain the list and submission interfaces; submission gets the employee ID from `SecurityUtils.requireEmployeeId()`.

- [ ] **Step 1: Add failing integration tests**

Test these named behaviors in `EmployeeDocumentWorkflowIT`:

1. `catalogReturnsOnlyActiveTypesAndEffectivePositionRequirements` asserts the employee's current effective mandatory types have `required=true`, active non-required types are optional, and inactive types are absent.
2. `catalogAndSubmitUseAuthenticatedEmployee` asserts the request has no employee ID field and another employee's catalog/history is not returned.
3. `submitBlocksPendingAndValidApprovedButAllowsRejectedAndExpiredVersions` asserts the D-02/D-03 table, including a no-expiry approval, an expiry today, and an expiry before today.
4. `concurrentSubmissionsLeaveAtMostOnePendingDocument` asserts two simultaneous requests cannot persist two pending rows.
5. `submitRejectsAnotherEmployeesStorageKey` asserts owner-prefix and blob-existence validation.

- [ ] **Step 2: Run the focused integration test and verify it fails for missing behavior**

Run: `mvn -f hrm-coffeeshop-backend/pom.xml -Dit.test=EmployeeDocumentWorkflowIT verify`

Expected: the new test class is discovered and fails on the absent catalog, approved-valid eligibility guard, and database concurrency constraint. If Docker/Testcontainers is unavailable, record that environmental failure; do not replace it with a passing claim.

- [ ] **Step 3: Add the employee-safe catalog and lifecycle checks**

Derive the current employee with `SecurityUtils.requireEmployeeId()`. In `DocumentService.catalog`, use the employee's current position and `PositionDocumentRequirementRepository.findEffective(positionId, today)`, return all active types, and calculate required/optional plus current eligibility. In `submit`, block a same-type `PENDING` row and a still-valid `APPROVED` row; permit a new row after `REJECTED`/`EXPIRED`/expired approval without updating or deleting old rows. Add a SQL Server filtered unique index on `(EmployeeId, DocumentTypeId)` where `ReviewStatus = 'PENDING'`; translate a concurrent unique-index violation to the same `CONFLICT` response as the ordinary pending duplicate.

- [ ] **Step 4: Regenerate schema entities and run the focused integration tests**

Run: `python hrm-coffeeshop-backend/tools/gen_entities.py`

Run: `mvn -f hrm-coffeeshop-backend/pom.xml -Dit.test=EmployeeDocumentWorkflowIT verify`

Run: `mvn -f hrm-coffeeshop-backend/pom.xml -Dit.test=DocumentSubmitIT verify`

Expected: catalog, status eligibility, history retention, ownership, and concurrency assertions pass on a fresh Testcontainers database.

---

### Task 2: Flutter employee documents and reviewer flow

**Files:**
- Modify: `lib/data/repositories/employee_repository.dart`
- Modify: `lib/data/repositories/employee_providers.dart` only if a dedicated provider is needed
- Create: `lib/features/documents/presentation/employee_documents_tab.dart`
- Create: `lib/features/documents/presentation/manager_document_review_page.dart`
- Modify: `lib/features/profile/presentation/employee_profile_page.dart`
- Modify: `lib/app/router/route_names.dart`
- Modify: `lib/app/router/app_router.dart`
- Modify: `lib/features/home/presentation/employee_dashboard_page.dart`
- Modify: `lib/features/home/presentation/manager_dashboard_page.dart`
- Modify: `pubspec.yaml` and `pubspec.lock` to add `file_picker: ^13.3.2` for PDF/JPEG/PNG/WebP selection on Android
- Create: `test/features/documents/employee_documents_tab_test.dart`
- Create: `test/features/documents/manager_document_review_page_test.dart`
- Create: `test/data/repositories/employee_document_repository_test.dart`

**Interfaces:**
- Consumes Task 1's `DocumentCatalogView` and existing employee document list/submit, upload, pending, detail/view, approve, and reject APIs.
- Produces employee route `RouteNames.employeeDocuments = '/employee/documents'`, which opens the profile's documents tab, and reviewer route `RouteNames.managerDocumentReview = '/manager/documents'`.
- Repository methods: `Future<Map<String, dynamic>> getMyDocumentCatalog()`, `Future<List<Map<String, dynamic>>> getMyDocuments()`, `Future<String> uploadDocument({required Uint8List bytes, required String contentType})`, `Future<Map<String, dynamic>> submitDocument({required int documentTypeId, required String storageKey, DateTime? issuedAt, DateTime? expiresAt})`, `Future<List<Map<String, dynamic>>> getPendingDocuments()`, `Future<Map<String, dynamic>> getDocument(int documentId)`, `Future<Map<String, dynamic>> approveDocument(int documentId)`, and `Future<Map<String, dynamic>> rejectDocument({required int documentId, required String reason})`.
- File picker adapter contract: `Future<PickedDocument?> pickDocument()` where `PickedDocument` carries `name`, `contentType`, and `Uint8List bytes`; inject it in widget tests.

- [ ] **Step 1: Add failing repository and widget tests**

Test `employeeRepositorySendsDocumentBytesAsDocumentPurposeAndSubmitsReturnedKey`, `pickerCancellationLeavesDocumentsTabUnchanged`, `documentsTabShowsRequiredOptionalAndPersistedStatuses`, `documentsTabShowsRetryAndDoesNotShowStorageKey`, `profileOpensDocumentsTabFromDeepLink`, and `reviewerCanViewApproveOrRejectPendingDocument`. Assert rejected documents show the reason and submission does not disappear after refresh.

- [ ] **Step 2: Run the focused Flutter tests and verify they fail**

Run: `flutter test test/data/repositories/employee_document_repository_test.dart test/features/documents/employee_documents_tab_test.dart test/features/documents/manager_document_review_page_test.dart`

Expected: the repository methods, routes, and pages are not yet implemented.

- [ ] **Step 3: Implement employee and reviewer document surfaces**

Build the documents tab inside `EmployeeProfilePage` and initialize it from either the profile tab or `/employee/documents`. Add the picker adapter using `FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'])`, then `PlatformFile.readAsBytes()`. Treat an unreadable/null file length as a picker error; backend signature/size checks remain authoritative. Upload with the existing `DOCUMENT` endpoint, keep the returned key in request state only, then submit. Read status and eligibility from backend responses. Reviewer actions use the existing `DOCUMENT_REVIEW` endpoints; the detail API's signed URL is used to view the uploaded blob. Show loading, empty, error/retry, submission, pending, approved, rejected/reason, and expired states.

- [ ] **Step 4: Add routes and permission-aware entry points**

Add employee document access to dashboard quick access. Add the reviewer page to the manager/reviewer dashboard only when the signed-in access data includes `DOCUMENT_REVIEW`. Do not add document approval endpoints.

- [ ] **Step 5: Run focused Flutter tests and analyzer**

Run: `flutter test test/data/repositories/employee_document_repository_test.dart test/features/documents/employee_documents_tab_test.dart test/features/documents/manager_document_review_page_test.dart`

Run: `flutter analyze`

Expected: focused tests pass and analyzer reports no new issue from the document flow.

---

### Task 3: Violation explanation persistence and APIs

**Files:**
- Modify: `hrm-coffeeshop-backend/infra/sqlserver/config.sql`
- Generate: `hrm-coffeeshop-backend/src/main/java/com/hrm/coffeeshop/domain/ViolationExplanation.java` and repository using `tools/gen_entities.py`
- Create: `hrm-coffeeshop-backend/src/main/java/com/hrm/coffeeshop/shared/dto/ViolationExplanationDto.java`
- Create: `hrm-coffeeshop-backend/src/main/java/com/hrm/coffeeshop/shared/service/ViolationExplanationService.java`
- Modify: `hrm-coffeeshop-backend/src/main/java/com/hrm/coffeeshop/employee/controller/EmployeeViolationController.java`
- Modify: `hrm-coffeeshop-backend/src/main/java/com/hrm/coffeeshop/shared/controller/SharedViolationController.java`
- Create: `hrm-coffeeshop-backend/src/test/java/com/hrm/coffeeshop/it/ViolationExplanationIT.java`

**Interfaces:**
- Produces `GET /api/v1/employees/me/violations` and employee `GET/POST /api/v1/employees/me/violations/{violationId}/explanations`.
- Produces reviewer `GET /api/v1/violations/{violationId}/explanations`, guarded by `VIOLATION_REVIEW`.
- Request is `ViolationExplanationRequest(explanation, evidenceStorageKey?)`; response is `ViolationExplanationView(explanationId, violationId, explanation, submittedAt, evidenceViewUrl?)`. Neither DTO contains a client-selected employee ID or returns a raw storage key.
- Service methods: `List<ViolationExplanationView> listMine(long employeeId, long violationId)`, `ViolationExplanationView submitMine(long employeeId, long violationId, ViolationExplanationRequest request)`, and `List<ViolationExplanationView> listForReview(long violationId, long reviewerUserId)`.

- [ ] **Step 1: Add failing integration tests**

Test `employeeListsOnlyOwnViolations`, `employeeCannotReadOrSubmitForAnotherEmployeesViolation`, `submitRequiresOpenViolationAndDoesNotChangeViolationStatus`, `additionalSubmissionAppendsImmutableHistory`, `reviewerPermissionControlsExplanationRead`, and `evidenceMustBeAnExistingPrivateKeyOwnedByEmployee`. Assert confirm/dismiss remains the only status-changing transition.

- [ ] **Step 2: Run the focused integration test and verify it fails**

Run: `mvn -f hrm-coffeeshop-backend/pom.xml -Dit.test=ViolationExplanationIT verify`

Expected: test discovery succeeds and fails because the entity, APIs, and ownership/lifecycle behavior are missing.

- [ ] **Step 3: Add the append-only schema and generated model**

In `config.sql`, add `ViolationExplanation` with identity ID, FK to `ViolationEvent`, FK to `Employee`, required `NVARCHAR(2000)` explanation, nullable evidence key, submitted and created timestamps, and index `(ViolationEventId, SubmittedAt)`. Regenerate its entity/repository from the DDL; do not hand-edit generated files.

- [ ] **Step 4: Implement employee and reviewer service/controller paths**

Fill `EmployeeId` only from `SecurityUtils.requireEmployeeId()`. Verify the violation belongs to that employee and maps to API status `OPEN` before each insert. Validate optional evidence belongs to that employee's `private-documents/employee-{id}/` namespace and exists. Save a new row for every submission and log `VIOLATION_EXPLANATION_SUBMITTED`; never mutate `ViolationEvent.RecordStatus` or `ReviewNote`. Reviewer reads require `VIOLATION_REVIEW` and may receive a short-lived signed evidence URL after the same permission check.

- [ ] **Step 5: Run focused tests and inspect status/audit evidence**

Run: `mvn -f hrm-coffeeshop-backend/pom.xml -Dit.test=ViolationExplanationIT verify`

Run: `mvn -f hrm-coffeeshop-backend/pom.xml -Dit.test=ViolationListIT verify`

Expected: ownership, append-only history, closed-state rejection, no status mutation, permission, and current manager transition tests pass on a fresh database.

---

### Task 4: Flutter employee explanations and manager review

**Files:**
- Modify: `lib/data/repositories/employee_repository.dart`
- Create: `lib/features/violations/presentation/employee_violations_page.dart`
- Modify: `lib/features/violations/presentation/manager_violation_review_page.dart`
- Modify: `lib/app/router/route_names.dart`
- Modify: `lib/app/router/app_router.dart`
- Modify: `lib/features/home/presentation/employee_dashboard_page.dart`
- Create: `test/features/violations/employee_violations_page_test.dart`
- Modify/create: `test/features/violations/manager_violation_review_page_test.dart`

**Interfaces:**
- Consumes Task 3's employee list/explanation and reviewer explanation APIs, plus existing `getViolations`, `confirmViolation`, and `dismissViolation` repository methods.
- Produces `RouteNames.employeeViolations = '/employee/violations'`.
- Repository methods: `getMyViolations()`, `getMyViolationExplanations(violationId)`, `submitViolationExplanation(violationId, explanation, evidenceStorageKey?)`, and `getViolationExplanationsForReview(violationId)`.

- [ ] **Step 1: Add failing employee and manager widget tests**

Test `employeeSeesOwnOpenViolationAndCanExplain`, `employeeCannotSubmitAfterFinalDecision`, `additionalExplanationAppearsWithoutChangingStatus`, `employeePageShowsRetryAndEmptyStates`, and `managerSeesEmployeeExplanationSeparatelyFromReviewNote`. Assert manager confirm/dismiss calls still use existing repository methods.

- [ ] **Step 2: Run focused Flutter tests and verify they fail**

Run: `flutter test test/features/violations/employee_violations_page_test.dart test/features/violations/manager_violation_review_page_test.dart`

Expected: route, repository methods, and explanation presentation are missing.

- [ ] **Step 3: Implement employee violation list and explanation submission**

Display the API's status and details. Allow text and optional evidence upload only while status is `OPEN`; show submitted records as read-only and append new submissions as separate rows. Refresh from the backend after success; never locally mark a violation confirmed/dismissed.

- [ ] **Step 4: Extend existing manager review UI**

Load the explanation history for the selected violation, present employee explanation/evidence separately from manager review note, and preserve existing confirm/dismiss actions and permission gating.

- [ ] **Step 5: Run focused Flutter tests and analyzer**

Run: `flutter test test/features/violations/employee_violations_page_test.dart test/features/violations/manager_violation_review_page_test.dart`

Run: `flutter analyze`

Expected: all focused tests pass with no new analyzer issue.

---

### Task 5: Employee navigation and existing-flow regression coverage

**Files:**
- Modify if required: `lib/features/home/presentation/employee_dashboard_page.dart`
- Modify if required: `lib/app/router/app_router.dart` and `lib/app/router/route_names.dart`
- Modify if required: `lib/features/checklist/presentation/employee_checklist_page.dart`
- Modify if required: `lib/features/schedule/presentation/employee_schedule_page.dart`
- Create: `test/features/home/employee_dashboard_navigation_test.dart`
- Create: `test/features/schedule/employee_schedule_page_test.dart`
- Create: `test/features/checklist/employee_checklist_page_test.dart`
- Create: `test/features/training/employee_training_page_test.dart`
- Create: `test/features/attendance/employee_attendance_flow_test.dart`
- Create: `test/features/profile/employee_profile_page_test.dart`
- Create: `test/features/rewards/employee_rewards_page_test.dart`
- Create: `test/features/notifications/employee_notifications_page_test.dart`

**Interfaces:**
- Consumes Task 2 and Task 4 routes.
- Dashboard quick access routes to schedule, check-in/history, documents, training, checklist, violations, rewards, notifications, and profile. Keep the existing four-item bottom navigation.
- `/profile` redirects to `/employee/profile` or is removed; no navigation path renders the old placeholder.

- [ ] **Step 1: Add failing navigation and existing-flow state tests**

Test `dashboardShowsGreetingShiftAndCheckInAction`, `dashboardLinksEveryEmployeeWorkflow`, `legacyProfileRouteOpensRealEmployeeProfile`, `checkInShowsGpsPhotoRetryAndConfirm`, `scheduleSwitchesWeekMonthAndShowsApiShifts`, `checklistShowsProgressEvidenceSubmitAndReturnedWork`, `trainingShowsCourseSkillCertificateViewsWithoutEmployeeAssessment`, `profileShowsInformationPositionAndDocumentsTabs`, and `notificationsPersistReadStateAfterRefresh`. Add focused empty/error/retry and persisted-status assertions to rewards and attendance-history tests. For checklist, pin returned/rework actions to the actual API status mapping.

- [ ] **Step 2: Run the focused Flutter tests and verify missing route/coverage failures**

Run: `flutter test test/features/home/employee_dashboard_navigation_test.dart test/features/schedule/employee_schedule_page_test.dart test/features/checklist/employee_checklist_page_test.dart test/features/training/employee_training_page_test.dart test/features/attendance/employee_attendance_flow_test.dart test/features/profile/employee_profile_page_test.dart test/features/rewards/employee_rewards_page_test.dart test/features/notifications/employee_notifications_page_test.dart`

Expected: newly added tests expose any missing links, placeholder route, or broken state rendering. Existing screens that already satisfy a case should stay unchanged.

- [ ] **Step 3: Add only the navigation/status fixes demonstrated by the tests**

Expose all employee routes from dashboard quick access and resolve `/profile` to the real employee profile. Adjust an existing screen only when a failing test shows a user cannot recover, identify an API status, or proceed with returned work.

- [ ] **Step 4: Re-run the focused Flutter suite**

Run: `flutter test test/features/home/employee_dashboard_navigation_test.dart test/features/schedule/employee_schedule_page_test.dart test/features/checklist/employee_checklist_page_test.dart test/features/training/employee_training_page_test.dart test/features/attendance/employee_attendance_flow_test.dart test/features/profile/employee_profile_page_test.dart test/features/rewards/employee_rewards_page_test.dart test/features/notifications/employee_notifications_page_test.dart`

Expected: all affected employee navigation and status tests pass.

---

### Task 6: Deterministic local demo runbook

**Files:**
- Create: `docs/employee-demo-runbook.md`
- Modify only if source audit/runbook verification proves an existing demo state missing: `hrm-coffeeshop-backend/infra/sqlserver/seeddata.sql`

**Interfaces:**
- Documents Employee A, Employee B, and reviewer personas using existing seeded records and permission grants.
- Gives local backend and emulator startup instructions without storing secrets, passwords, or Google credentials.

- [ ] **Step 1: Verify required demo states in the current seed**

Check for two employee personas, a reviewer with `DOCUMENT_REVIEW` and `VIOLATION_REVIEW`, required and optional document types, pending/rejected/expired documents, an open violation, assigned checklist, training enrollment, and a seeded shift. Record which real Google test-user accounts must map to each persona; do not copy credentials into source.

- [ ] **Step 2: Confirm current seed states before editing seed data**

Use the existing persona mapping: `NV001` for open violation/attendance, `NV002`/`NV003` for document states, `QL001` for reviewer actions, and `NV004` for HR permissions. Reuse existing scheduled shifts, checklists, and training enrollment. Add an idempotent development/test row only if a required acceptance state is absent; never add credentials or production seed behavior.

- [ ] **Step 3: Write and verify `docs/employee-demo-runbook.md`**

Use `mvn -f hrm-coffeeshop-backend/pom.xml spring-boot:run` with local environment variables already set outside source. Run Flutter on the connected Android emulator with `--dart-define=GOOGLE_CLIENT_ID=<Web-Client-ID>` and `--dart-define=API_BASE_URL=http://10.0.2.2:8080`. State that three actual OAuth Test-user accounts must map to the two employee personas and reviewer in the isolated local database. Do not use `DEV_PASSWORD_LOGIN_ENABLED`.

- [ ] **Step 4: Verify the runbook against source and seeded records**

Expected: a reader can sign in as Employee A, sign in separately as Employee B, use QL001/HR reviewer permissions, upload an actual file, approve/reject it, submit a violation explanation, and exercise attendance/checklist/training without production services or an auth bypass.

---

### Task 7: Full automated verification and Android emulator demo

**Files:**
- Test: all changed Flutter test files and backend integration tests
- Run: `flutter analyze`, `flutter test`, `mvn -f hrm-coffeeshop-backend/pom.xml verify`
- Manual: `docs/employee-demo-runbook.md` on Android Emulator

**Interfaces:**
- Consumes all routes, APIs, permissions, schema, tests, and demo identities from Tasks 1–6.
- Produces a short verification report listing commands, emulator/device, flow outcomes, and any environment limitation.

- [ ] **Step 1: Run all relevant Flutter tests and analyzer**

Run: `flutter test`

Run: `flutter analyze`

Expected: both exit successfully with no new analysis issue.

- [ ] **Step 2: Run backend unit and integration suites**

Run: `mvn -f hrm-coffeeshop-backend/pom.xml verify`

Expected: unit and Testcontainers integration suites pass on a fresh test database. If Docker/Maven is unavailable, report the exact failure and do not claim the backend suite passed.

- [ ] **Step 3: Exercise the demo on Android Emulator**

Start the local backend with the isolated demo database, connect a real Google OAuth Test-user account, then run the app using the runbook's `API_BASE_URL` and `GOOGLE_CLIENT_ID`. Demonstrate employee navigation, schedule/check-in/out, document upload/review/rejection/resubmission, training without assessment submission, checklist completion/rework, violation explanation and manager decision, rewards, notifications, and profile.

- [ ] **Step 4: Record actual verification evidence**

Expected: the report distinguishes passed flows from blocked ones, records the emulator ID and backend/test commands, and identifies any required owner-supplied OAuth account or existing-database setup. Do not run any Git/GitHub command.
