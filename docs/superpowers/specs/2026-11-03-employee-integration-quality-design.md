# Employee Integration and Profile Design

## Intent

Make the employee flows render the intended Vietnamese UI after they consume backend data, and provide one self-profile experience to every signed-in account. The current employee mock/demo shape and backend response shape drifted at several boundaries.

## Current findings

- `/profile` and `/employee/profile` both open a page that requires `/employees/me`; accounts without a linked Employee row cannot use a general profile screen.
- `AppUser` and `Employee` represent distinct data: identity/account data is shared; employment data and documents are optional extensions.
- The checklist self endpoint omits run items although Flutter renders them; Flutter retains only one run.
- Employee dashboard/profile render raw backend status codes instead of existing localized labels.
- Notification UI reads a key that the backend does not serialize and only requests the first page.
- Employee navigation is duplicated, and two destinations do not provide a return path.
- `EmployeeRepository` also owns account, manager, admin, and payroll requests. Move account operations to the auth/account boundary now; plan the wider repository split incrementally after behavior is stable.

## Approaches

1. **Shared account profile with optional employee details (selected).** Load account identity from `/users/me` for every account. Load `/employees/me` and employee documents only when `employeeId` is present. Keep the database/API concepts separate and compose them in one profile screen. This avoids employee-only assumptions while reusing the existing HR fields.
2. **Separate profile screen per role.** Preserve the employee page and add different manager/admin pages. This keeps role-specific layouts simple but duplicates account fields, edit behavior, and navigation.

The user approved the shared profile approach and asked for a broader integration/code-quality review.

## Goals

- Let any signed-in account open and edit its account profile without requiring an Employee record.
- Show employment, position, and documents only for accounts linked to Employee.
- Return checklist run summaries efficiently, load item details for the selected run, and let employees switch among every assigned run.
- Localize employment/profile/eligibility codes in dashboard and profile UI.
- Read notification type according to the backend contract and expose pagination beyond the first page.
- Give employee pages consistent navigation and a reliable path back to the employee home.
- Keep account endpoints in the auth/account repository boundary and use the existing typed user domain contract.
- Add regression coverage at API/UI boundaries.

## Non-goals and constraints

- Do not merge AppUser and Employee in the database or change authentication/authorization rules.
- Do not add an auth bypass, seed credentials, or change production fixture data.
- Do not change training assessment, score calculation, or the Manager/trusted-LMS authority.
- Do not rewrite the entire 1,675-line shared repository in this change; extract account ownership now and use the audit to stage remaining bounded-context splits.
- Do not run Git/GitHub commands.

## Acceptance criteria

- A signed-in account with no employeeId can load `/profile`, view/edit account fields, and does not call employee-only endpoints.
- A linked employee sees account fields plus employment and document sections, with the same saved account data after refresh.
- Employee dashboard/profile show Vietnamese values for backend status codes.
- The checklist list exposes all assigned run summaries; selecting a run loads its item details, and every returned run is reachable.
- Notification type filters/icons use the backend field, and the UI can load later pages.
- Attendance history and violations have a visible route back; shared employee navigation does not diverge across pages.
- Existing training assessment behavior remains unchanged.
