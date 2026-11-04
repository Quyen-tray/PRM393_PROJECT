# Training completion flows

## Quiz courses

Employees enroll in a course with `isMandatoryTest=true`, then submit answers to:

```http
POST /api/v1/training/courses/{courseId}/quiz-attempts
Authorization: Bearer <employee access token>
Content-Type: application/json

{"answers":[{"questionId":501,"selectedOption":"A"}]}
```

The backend calculates the score. A score at or above `passScore` changes the employee's training status to `PASSED` and records completion and certificate expiry. A failed attempt remains retakable. Quiz courses cannot be manually approved.

## Practical courses

Employees enroll with `POST /api/v1/training/courses/{courseId}/enroll`. They do not submit a completion request. The enrollment appears in the review queue until it has a valid pass:

```http
GET /api/v1/training/completion-reviews/pending
Authorization: Bearer <manager or system admin access token>
```

Users with `TRAINING_MANAGE` and users with the `SYSTEM_ADMIN` role can review practical enrollments. The list includes the course, employee, enrollment date, and any previous reviewer note. Quiz courses are excluded.

Confirm completion:

```http
POST /api/v1/training/completion-reviews/{employeeTrainingId}/approve
Authorization: Bearer <manager or system admin access token>
Content-Type: application/json

{"note":"Practice checked at the store."}
```

Record that the course is not complete:

```http
POST /api/v1/training/completion-reviews/{employeeTrainingId}/not-complete
Authorization: Bearer <manager or system admin access token>
Content-Type: application/json

{"reason":"Please repeat the temperature check."}
```

Approval changes the status to `PASSED` and calculates certificate expiry from course validity. Marking a course incomplete keeps it in progress and stores the note for the employee and the next review. Practical enrollments remain reviewable until approved.

Mandatory training requirements remain visible in progress reports. Training completion does not block shift assignment or check-in. Quiz courses still require a score at or above the configured `passScore`.

## Existing database setup

Apply [`2026-11-03-training-completion-review.sql`](../infra/sqlserver/migrations/2026-11-03-training-completion-review.sql) once to an existing isolated database before starting the backend. A new database created from `config.sql` already includes the review metadata schema. The legacy `PENDING_REVIEW` value remains permitted for compatibility; new enrollments are reviewed directly from the practical course queue.
