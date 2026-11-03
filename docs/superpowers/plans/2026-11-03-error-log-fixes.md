# HRM Error Log Follow-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the confirmed manager violation-list failure, make sign-out and employee-role testing usable, and resolve the reported Flutter lifecycle assertion after its actual source is captured.

**Architecture:** Preserve the Flutter/Riverpod/GoRouter client and the Spring Boot/JPA backend. Correct the invalid JPA sort property at the controller boundary and cover the endpoint with an integration test. Add UI access to the existing sign-out operation. Treat the repeated Flutter assertion as an investigation gate: capture its full Dart stack and request outcomes before changing widget lifecycle code.

**Tech Stack:** Flutter 3.47.2 / Dart 3.13.2, Riverpod, GoRouter, Dio, Spring Boot 3.3.5, Java 17, Spring Data JPA, SQL Server, JUnit 5, MockMvc, Testcontainers.

**Spec:** `D:\Content\Documents\log báo lỗi.docx`; `hrm-coffeeshop-backend/docs/SRS_ALIGNMENT.md`; `hrm-coffeeshop-backend/docs/GOOGLE_LOGIN.md`.

## Global Constraints

- Keep the existing `/api/v1` response shape, filters, page semantics, and `VIOLATION_REVIEW` authorization.
- Do not change the database schema for the violation sort; `ViolationEvent.occurredAt` maps to database column `OccurredAt`.
- Sign-out must clear local access/refresh tokens and the Google session even when the remote logout request fails, then return to login.
- An employee test account needs an active `AppUser` with role `EMPLOYEE`, the matching Google email, and a linked `Employee` record.
- Do not change Flutter SDK/framework code or suppress the `_dependents.isEmpty` assertion. Fix only the application source identified by the captured stack.
- Do not combine unrelated fixes in one change.

## Review Focus

- A default `GET /api/v1/violations` request must not generate an HQL sort for a property absent from `ViolationEvent`; test both successful response and descending `occurredAt` order.
- The violation endpoint must retain status/employee filters and permission checks after correcting its default sort; cover filters in the endpoint integration test.
- The three reported Flutter actions must capture full Dart stacks and HTTP results so a client lifecycle exception is separated from a failed server mutation.
- Cancelling account creation must not call `POST /admin/users`; saving permissions must be checked by reading permissions back from the API.
- Sign-out must complete local cleanup and navigate to login when the remote logout endpoint is unavailable.

---

### Task 1: Correct violation-list default sorting

**Files:**
- Modify: `hrm-coffeeshop-backend/src/main/java/com/hrm/coffeeshop/manager/controller/ManagerViolationController.java`
- Create: `hrm-coffeeshop-backend/src/test/java/com/hrm/coffeeshop/it/ViolationListIT.java`

**Interfaces:**
- Consumes: `ViolationEvent.occurredAt`, the existing `GET /api/v1/violations` endpoint, and `IntegrationTestBase` / MockMvc test patterns.
- Produces: the endpoint's default page ordered by the mapped entity property `occurredAt` descending.

- [x] **Step 1: Write the failing endpoint integration test**

Add `listsViolationsByOccurredAtWhenSortIsOmitted` to `ViolationListIT`. Authenticate as a user with `VIOLATION_REVIEW`, insert two violations with distinct `OccurredAt` values, then call `GET /api/v1/violations?page=0&size=20` without `sort`. Assert HTTP 200, both rows present, and newer `occurredAt` first. Add a status-filter assertion to ensure filtering remains intact.

- [ ] **Step 2: Run the test and confirm it exposes the logged error**

Run from `hrm-coffeeshop-backend`: `mvn -Dit.test=ViolationListIT verify`

Expected before the fix: the default request fails with the same invalid `incidentAt` HQL path recorded in the log.

- [x] **Step 3: Change the controller's default sort property**

In `ManagerViolationController.list`, change `@PageableDefault(sort = "incidentAt", ...)` to use the Java entity property `occurredAt`; retain `Sort.Direction.DESC`.

- [ ] **Step 4: Re-run the focused integration test**

Run: `mvn -Dit.test=ViolationListIT verify`

Expected: HTTP 200, newest violation first, filters still applied, and no `UnknownPathException`.

- [ ] **Step 5: Run the backend integration suite**

Run: `./scripts/run-integration-tests.sh` from the backend directory in a Bash environment with Docker available, then run `mvn -B verify`.

Expected: all existing unit and integration tests pass.

### Task 2: Add a usable sign-out path and enable employee-role testing

**Files:**
- Modify: `lib/features/admin/presentation/widgets/admin_more_menu.dart`
- Modify: `lib/features/admin/presentation/admin_dashboard_page.dart`
- Modify: `lib/features/home/presentation/widgets/manager_more_menu.dart`
- Modify: `lib/features/home/presentation/manager_dashboard_page.dart`
- Modify: `lib/features/profile/presentation/employee_profile_page.dart`
- Create: `test/features/auth/logout_flow_test.dart`
- Create: `test/features/auth/employee_login_route_test.dart`

**Interfaces:**
- Consumes: `authRepositoryProvider`, `AuthRepository.signOut()`, `RouteNames.login`, the existing admin/manager bottom-sheet functions, and LoginPage's role-based routing.
- Produces: a visible sign-out action for Admin, Manager, and Employee; local session cleanup followed by navigation to login; a regression test for routing an `EMPLOYEE` role to `/employee`.

- [x] **Step 1: Write failing UI tests for sign-out visibility and navigation**

Use a fake `AuthRepository` provider. Verify each role has a reachable `Đăng xuất` action; selecting it calls `signOut()` and replaces the current route with login. Cover a remote logout failure and assert navigation still happens after the repository's `finally` cleanup.

- [x] **Step 2: Write a failing employee-role routing test**

Stub Google sign-in to return a user whose roles contain `EMPLOYEE`; assert successful login opens the employee dashboard at `/employee`.

- [x] **Step 3: Wire sign-out into each role's existing navigation**

Add the action to the Admin and Manager more menus and the Employee profile screen. Pass an explicit callback from the Riverpod consumer pages so menu widgets do not reach into providers implicitly. Call `AuthRepository.signOut()`, catch a remote error after local cleanup, and navigate to `RouteNames.login` if the route context is still mounted.

- [x] **Step 4: Run the focused Flutter tests**

Run: `flutter test test/features/auth/logout_flow_test.dart test/features/auth/employee_login_route_test.dart`

Expected: all role flows can return to login; failed remote logout does not keep the user in the authenticated UI; an employee role reaches the employee dashboard.

- [ ] **Step 5: Verify the employee test account prerequisites**

Use the existing Admin flow to create an active `EMPLOYEE` account with the exact Google email and create its Employee profile. Verify the same account can sign out of a manager/admin session, sign in with Google, and load the employee dashboard. Do not treat an AppUser without an Employee profile as a valid attendance/schedule test fixture.

### Task 3: Trace and fix the Flutter `_dependents.isEmpty` failures

**Reported actions:** saving Admin permissions; cancelling the create-account dialog; rejecting a reward/penalty decision.

**Candidate files to inspect after capturing stacks:**
- `lib/features/admin/presentation/admin_account_permissions_page.dart`
- `lib/features/admin/presentation/admin_account_management_page.dart`
- `lib/features/rewards/presentation/manager_reward_penalty_page.dart`
- `lib/features/approvals/presentation/manager_review_items.dart`

**Test files:**
- Create: `test/features/admin/admin_account_permissions_page_test.dart`
- Create: `test/features/admin/admin_account_management_page_test.dart`
- Create: `test/features/rewards/manager_reward_penalty_page_test.dart`

**Interfaces:**
- Consumes: the exact user action, complete Dart exception stack, Flutter/device versions, and HTTP request/response outcome for each failure.
- Produces: one regression test per confirmed failure source and a minimal fix at the application widget/state boundary identified by the evidence.

- [ ] **Step 1: Reproduce each action and capture diagnostic evidence**

On the same target platform as the screenshots, record Flutter/Dart and OS versions, the full first-thrown Dart stack, route before/after, and API request status/body. For permission save, read permissions back after the request. For account cancellation, confirm whether a create request was sent. For reward rejection, capture the reject response and subsequent list refresh. Do not infer a failed API call from the red Flutter screen alone.

- [ ] **Step 2: Compare the three stacks and trace the first application frame**

Determine whether they share a lifecycle source. Trace from `InheritedElement.debugDeactivated` to the first application frame and the specific context/element removed while still depended upon. If the stacks identify different sources, split this task into one fix per source before editing.

- [x] **Step 3: Add regression widget tests for the confirmed source(s)**

The tests must exercise the exact action, fail on an uncaught Flutter framework error, and assert the expected API call/result. In particular, assert that cancel sends no create request and that permission/rejection flows display or preserve the server result.

- [x] **Step 4: Implement only the minimal source-level lifecycle fix**

Change the widget/state/context ownership identified in Step 2. Do not change backend permission or decision behavior unless the captured HTTP response proves a separate server defect.

- [ ] **Step 5: Run the focused widget tests and all Flutter tests**

Run the three focused test files, then `flutter test` and `flutter analyze` from the Flutter project root.

Expected: no `_dependents.isEmpty` error on the reproduced flows; API results and cancel semantics remain correct; analyzer and tests pass.

### Task 4: Replace the obsolete Flutter counter smoke test and run acceptance checks

**Files:**
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: the current `BeanHubApp` initial route and the regression tests from Tasks 2–3.
- Produces: a smoke test for the current login screen instead of the removed template counter behavior.

- [x] **Step 1: Replace the counter assertion**

Remove the generated test that expects a `0`/`1` counter. Assert that `BeanHubApp` builds its current login screen and that the widget tree reports no framework exception.

- [ ] **Step 2: Run final verification**

Run: `flutter analyze`, `flutter test`, `mvn test`, `./scripts/run-integration-tests.sh`, and `mvn -B verify` in their respective project roots.

Expected: all commands complete successfully; if Testcontainers cannot start because Docker is unavailable, report that environmental block separately and do not claim the backend integration suite passed.

