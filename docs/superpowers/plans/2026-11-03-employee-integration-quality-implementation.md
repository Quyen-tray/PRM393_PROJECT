# Employee Integration and Profile Implementation Plan

> **For agentic execution:** Follow the test-first loop for each behavior slice. Do not run Git/GitHub commands. Keep training scoring untouched.

**Goal:** Correct the verified API/UI contract mismatches, make self-profile work for every account, and reduce employee navigation/account coupling without changing training assessment.

**Architecture:** Treat `/users/me` as the shared account profile and `/employees/me` as an optional linked HR record. Keep server identity and role authorization as the source of truth. Normalize API values at repository/domain boundaries and share the employee navigation widget.

**Stack:** Flutter, Riverpod, GoRouter, Dart widget/repository tests; Spring Boot/Maven service tests.

### Task 1: Make the auth user contract typed and own account profile operations (complete)

**Files:** `lib/features/auth/domain/entities/user.dart`, `lib/features/auth/domain/repositories/auth_repository.dart`, `lib/features/auth/data/auth_repository.dart`, `lib/data/repositories/employee_repository.dart`, auth/profile tests.

- Add failing model/repository tests for `UserView` fields and optional `employeeId`.
- Make the concrete auth repository implement the domain contract, map `UserView` to a typed user, and add `updateCurrentUser`.
- Move `/users/me` read/update operations out of EmployeeRepository; migrate manager/profile callers.
- Keep Google sign-in token flow and server-side identity checks unchanged.

### Task 2: Compose one profile for account-only and linked-employee users (complete)

**Files:** `lib/features/profile/presentation/account_profile_page.dart` (renamed from employee-only page), `lib/app/router/app_router.dart`, `lib/app/router/route_names.dart`, `manager_more_menu.dart`, `admin_more_menu.dart`, related tests.

- Add failing widget tests for unlinked and linked accounts.
- Load User first; only fetch `/employees/me` and employee documents when `employeeId` exists.
- Keep the account section usable if the optional employee request fails; present retry on the employee section.
- Point `/profile`, `/employee/profile`, and employee-document entry to the same profile page with the appropriate initial tab.
- Add a profile entry to manager/admin more menus.

### Task 3: Restore checklist detail and show multiple runs (complete)

**Files:** `ChecklistService.java`, employee checklist repository/page, checklist service and Flutter tests.

- Add service coverage asserting self-service includes submitted/approved outcomes while skipping item/evidence/review detail queries in the list response.
- Return all employee-owned run summaries without loading each run's detail.
- Load the existing task detail endpoint for the selected run; preserve its status, review reason, items, and submission flow.
- Cover multiple runs, optional checklist items, and returned work; keep item actions scoped to the selected run.

### Task 4: Correct employee-facing labels and navigation (complete)

**Files:** `lib/core/utils/formatters.dart`, dashboard/profile, `employee_bottom_navigation.dart`, schedule/checklist/profile/dashboard pages, attendance-history/violations pages, widget tests.

- Add failing widget expectations for localized employment status/type/profile/eligibility values.
- Reuse shared formatter functions and add localized labels for profile completeness/shift eligibility.
- Replace duplicate employee bottom navigation definitions with the shared widget where applicable.
- Add an explicit employee-home/back action to attendance history and violation pages.

### Task 5: Align notifications with backend and expose all pages (complete)

**Files:** employee notification repository methods/page and tests.

- Add failing tests for notification `type` rendering/filtering and loading later pages.
- Normalize the backend `type` field once at the repository boundary.
- Load additional pages as the list approaches the end and preserve read-state on refresh.

### Task 6: Audit and verify the integrated employee surface (complete)

**Files:** `progress.md` and relevant tests only if a newly confirmed regression requires them.

- Run focused tests for each changed slice, then the full Flutter suite and backend unit suite.
- Run analyzer and report pre-existing info-level findings separately from new issues.
- Run the updated app on the Android emulator if configured; distinguish launch verification from authenticated API/E2E verification.
- Leave Docker-backed integration limitations and OAuth/database setup explicit in the runbook.
