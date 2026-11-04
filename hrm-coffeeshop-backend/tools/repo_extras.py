# Truy vấn tùy biến cho từng repository (phần thân interface). Dùng bởi gen_entities.py.
EXTRAS = {
"AppUser": '''
    Optional<AppUser> findByGoogleSubject(String googleSubject);
    Optional<AppUser> findByEmail(String email);

    @Query("select u.userId from AppUser u where u.userStatus = 'ACTIVE' and u.userId in "
         + "(select ur.userId from UserRole ur where ur.roleId in (select r.roleId from Role r where r.roleCode = :code))")
    List<Long> findActiveUserIdsByRoleCode(@Param("code") String code);

    /** Người dùng ACTIVE có quyền permCode (gán trực tiếp hoặc qua role đang hoạt động). */
    @Query("select u.userId from AppUser u where u.userStatus = 'ACTIVE' and ("
         + "u.userId in (select up.userId from UserPermission up where up.permissionId in "
         + "(select p.permissionId from Permission p where p.permissionCode = :code)) "
         + "or u.userId in (select ur.userId from UserRole ur where ur.roleId in "
         + "(select rp.roleId from RolePermission rp where rp.permissionId in "
         + "(select p2.permissionId from Permission p2 where p2.permissionCode = :code)) "
         + "and ur.roleId in (select r.roleId from Role r where r.isActive = true)))")
    List<Long> findActiveUserIdsByPermissionCode(@Param("code") String code);
''',
"Role": '''
    Optional<Role> findByRoleCode(String roleCode);

    @Query("select r.roleCode from Role r where r.isActive = true and r.roleId in "
         + "(select ur.roleId from UserRole ur where ur.userId = :userId)")
    List<String> findActiveCodesByUserId(@Param("userId") Long userId);
''',
"Permission": '''
    Optional<Permission> findByPermissionCode(String permissionCode);
    List<Permission> findByPermissionCodeIn(Collection<String> codes);

    /** Quyền hiệu lực = quyền gán trực tiếp ∪ quyền của các role đang hoạt động. */
    @Query("select distinct p.permissionCode from Permission p where p.permissionId in "
         + "(select up.permissionId from UserPermission up where up.userId = :userId) "
         + "or p.permissionId in (select rp.permissionId from RolePermission rp where rp.roleId in "
         + "(select ur.roleId from UserRole ur where ur.userId = :userId) "
         + "and rp.roleId in (select r.roleId from Role r where r.isActive = true))")
    List<String> findEffectiveCodesByUserId(@Param("userId") Long userId);

    /** Chỉ các quyền gán trực tiếp (không tính quyền từ role). */
    @Query("select p.permissionCode from Permission p where p.permissionId in "
         + "(select up.permissionId from UserPermission up where up.userId = :userId)")
    List<String> findDirectCodesByUserId(@Param("userId") Long userId);
''',
"UserPermission": '''
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("delete from UserPermission up where up.userId = :userId")
    int deleteByUserId(@Param("userId") Long userId);
''',
"UserRole": '''
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("delete from UserRole ur where ur.userId = :userId")
    int deleteByUserId(@Param("userId") Long userId);
''',
"RefreshToken": '''
    Optional<RefreshToken> findByTokenHash(String tokenHash);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update RefreshToken t set t.revokedAt = :now where t.userId = :userId and t.revokedAt is null")
    int revokeAll(@Param("userId") Long userId, @Param("now") Instant now);
''',
"Store": '''
    Optional<Store> findFirstByIsActiveTrueOrderByStoreIdAsc();
''',
"Notification": '''
    boolean existsByDedupKey(String dedupKey);
    Page<Notification> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable p);
    Page<Notification> findByUserIdAndReadAtIsNullOrderByCreatedAtDesc(Long userId, Pageable p);
    long countByUserIdAndReadAtIsNull(Long userId);
    Page<Notification> findByDeliveryStatusOrderByCreatedAtDesc(String status, Pageable p);
    List<Notification> findTop100ByDeliveryStatusOrderByCreatedAtAsc(String status);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Notification n set n.readAt = :now where n.userId = :userId and n.readAt is null")
    int markAllRead(@Param("userId") Long userId, @Param("now") Instant now);
''',
"AuditLog": '''
    @Query("select a from AuditLog a where (:entityType = '' or a.entityType = :entityType) "
         + "and (:actionCode = '' or a.actionCode = :actionCode) and a.createdAt >= :from and a.createdAt < :to")
    Page<AuditLog> search(@Param("entityType") String entityType, @Param("actionCode") String actionCode,
                          @Param("from") Instant from, @Param("to") Instant to, Pageable p);
''',
"Employee": '''
    Optional<Employee> findByUserId(Long userId);
    Optional<Employee> findByEmployeeCode(String employeeCode);
    List<Employee> findByPositionId(Integer positionId);

    /** Khóa dòng nhân viên khi phân ca: hai thao tác phân ca cùng nhân viên phải xếp hàng. */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select e from Employee e where e.employeeId = :id")
    Optional<Employee> findByIdForUpdate(@Param("id") Long id);

    @Query("select e from Employee e where (:status = '' or e.employmentStatus = :status) "
         + "and (:jobTitle = '' or e.jobTitle = :jobTitle) "
         + "and (:q = '' or lower(e.employeeCode) like lower(concat('%', :q, '%')) "
         + "or exists (select 1 from AppUser u where u.userId = e.userId and lower(u.displayName) like lower(concat('%', :q, '%'))))")
    Page<Employee> search(@Param("q") String q, @Param("status") String status,
                                 @Param("jobTitle") String jobTitle, Pageable p);
''',
"DocumentType": '''
    Optional<DocumentType> findByDocumentCode(String code);

    @Query("select t from DocumentType t where t.isActive = true")
    List<DocumentType> findByIsActiveTrue();
''',
"EmployeeDocument": '''
    List<EmployeeDocument> findByEmployeeId(Long employeeId);
    List<EmployeeDocument> findByEmployeeIdOrderByUploadedAtDesc(Long employeeId);
    boolean existsByEmployeeIdAndDocumentTypeIdAndReviewStatus(Long employeeId, Integer documentTypeId, String status);
    long countByReviewStatus(String status);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update EmployeeDocument d set d.reviewStatus = 'EXPIRED' where d.reviewStatus = 'APPROVED' "
         + "and d.expiryDate is not null and d.expiryDate < :today")
    int markExpired(@Param("today") LocalDate today);
    List<EmployeeDocument> findTop100ByReviewStatusOrderByUploadedAtAsc(String status);
''',
"AttendanceDevice": '''
    boolean existsByEmployeeIdAndStatus(Long employeeId, String status);
    List<AttendanceDevice> findByEmployeeIdOrderByRequestedAtDesc(Long employeeId);
    Page<AttendanceDevice> findByStatusOrderByRequestedAtAsc(String status, Pageable p);
    long countByStatus(String status);

    @Query("select d from AttendanceDevice d where d.employeeId = :employeeId and d.status = 'ACTIVE'")
    Optional<AttendanceDevice> findActiveByEmployeeId(@Param("employeeId") Long employeeId);

    @Query("select d from AttendanceDevice d where d.deviceFingerprint = :hash and d.status = 'ACTIVE'")
    List<AttendanceDevice> findActiveByFingerprint(@Param("hash") String hash);
''',
"WorkShift": '''
    @Query("select s from WorkShift s where s.storeId = :storeId and s.isActive = true order by s.startTime")
    List<WorkShift> findByStoreIdAndIsActiveTrue(@Param("storeId") Integer storeId);

    @Query("select s from WorkShift s where s.storeId = :storeId order by s.startTime")
    List<WorkShift> findByStoreId(@Param("storeId") Integer storeId);

    Optional<WorkShift> findByStoreIdAndShiftCode(Integer storeId, String shiftCode);
''',
"ShiftAssignment": '''
    List<ShiftAssignment> findByEmployeeIdAndWorkDateBetweenOrderByPlannedStartAtAsc(Long employeeId, LocalDate from, LocalDate to);

    @Query("select s from ShiftAssignment s where s.employeeId = :employeeId and s.scheduleStatus in ('DRAFT','PUBLISHED','COMPLETED') "
         + "and s.plannedStartAt < :end and s.plannedEndAt > :start and s.shiftAssignmentId <> :excludeId")
    List<ShiftAssignment> findOverlapping(@Param("employeeId") Long employeeId, @Param("start") Instant start,
                                           @Param("end") Instant end, @Param("excludeId") Long excludeId);

    @Query("select s from ShiftAssignment s where s.workDate between :from and :to "
         + "and (:employeeId = 0L or s.employeeId = :employeeId) order by s.plannedStartAt")
    Page<ShiftAssignment> search(@Param("from") LocalDate from, @Param("to") LocalDate to,
                                  @Param("employeeId") Long employeeId, Pageable p);

    @Query("select s from ShiftAssignment s where s.scheduleStatus in ('PUBLISHED','COMPLETED') "
         + "and s.workDate between :from and :to and (:shiftId = 0 or s.workShiftId = :shiftId) "
         + "and (:employeeId = 0L or s.employeeId = :employeeId)")
    List<ShiftAssignment> findForStats(@Param("from") LocalDate from, @Param("to") LocalDate to,
                                        @Param("shiftId") Integer shiftId, @Param("employeeId") Long employeeId);

    @Query("select s from ShiftAssignment s where s.scheduleStatus = 'PUBLISHED' "
         + "and s.plannedStartAt >= :from and s.plannedStartAt <= :to")
    List<ShiftAssignment> findStartingBetween(@Param("from") Instant from, @Param("to") Instant to);
''',
"Attendance": '''
    Optional<Attendance> findByShiftAssignmentId(Long shiftAssignmentId);
    List<Attendance> findByShiftAssignmentIdIn(Collection<Long> scheduleIds);

    @Query("select count(a) from Attendance a where a.employeeId = :employeeId and a.graceApplied = true "
         + "and a.checkInAt >= :from and a.checkInAt < :to and a.attendanceId <> :excludeId")
    long countGraceUsed(@Param("employeeId") Long employeeId, @Param("from") Instant from,
                        @Param("to") Instant to, @Param("excludeId") Long excludeId);

    @Query("select a from Attendance a where (:employeeId = 0L or a.employeeId = :employeeId) "
         + "and (:status = '' or a.attendanceStatus = :status) "
         + "and a.shiftAssignmentId in (select s.shiftAssignmentId from ShiftAssignment s where s.workDate between :from and :to)")
    Page<Attendance> searchByWorkDate(@Param("employeeId") Long employeeId, @Param("status") String status,
                                            @Param("from") LocalDate from, @Param("to") LocalDate to, Pageable p);
''',
"AttendanceVerification": '''
    List<AttendanceVerification> findByAttendanceIdOrderByVerifiedAtAsc(Long attendanceId);

    @Query("select e from AttendanceVerification e where e.retainUntil is not null and e.retainUntil < :today "
         + "and e.evidenceStorageKey is not null and e.evidenceStorageKey <> 'PURGED'")
    List<AttendanceVerification> findExpired(@Param("today") LocalDate today);
''',
"AttendanceExceptionRequest": '''
    boolean existsByEmployeeIdAndShiftAssignmentIdAndRequestTypeAndRequestStatus(Long employeeId, Long shiftAssignmentId, String type, String status);
    Page<AttendanceExceptionRequest> findByRequestStatusOrderBySubmittedAtAsc(String status, Pageable p);
    List<AttendanceExceptionRequest> findByShiftAssignmentIdInAndRequestStatus(Collection<Long> scheduleIds, String status);
    long countByRequestStatus(String status);
    List<AttendanceExceptionRequest> findTop50ByEmployeeIdOrderBySubmittedAtDesc(Long employeeId);

    @Query("select e from AttendanceExceptionRequest e where e.retainUntil is not null and e.retainUntil < :today "
         + "and e.evidenceStorageKey is not null and e.evidenceStorageKey <> 'PURGED'")
    List<AttendanceExceptionRequest> findExpiredEvidence(@Param("today") LocalDate today);
''',
"AttendanceAdjustmentRequest": '''
    @Query("select case when count(a) > 0 then true else false end from AttendanceAdjustmentRequest a "
         + "where a.attendanceId = :attendanceId and (a.managerStatus = 'PENDING' or (a.managerStatus = 'APPROVED' and a.hrStatus = 'PENDING'))")
    boolean existsPending(@Param("attendanceId") Long attendanceId);

    @Query("select case when count(a) > 0 then true else false end from AttendanceAdjustmentRequest a "
         + "where a.attendanceId = :attendanceId and a.fieldName = :field "
         + "and (a.managerStatus = 'PENDING' or (a.managerStatus = 'APPROVED' and a.hrStatus = 'PENDING'))")
    boolean existsPendingField(@Param("attendanceId") Long attendanceId, @Param("field") String field);

    Page<AttendanceAdjustmentRequest> findByManagerStatus(String managerStatus, Pageable p);
    Page<AttendanceAdjustmentRequest> findByManagerStatusAndHrStatus(String managerStatus, String hrStatus, Pageable p);
    Page<AttendanceAdjustmentRequest> findByRequestedBy(Long userId, Pageable p);
    List<AttendanceAdjustmentRequest> findByAttendanceIdIn(Collection<Long> attendanceIds);
    long countByManagerStatus(String managerStatus);
    long countByManagerStatusAndHrStatus(String managerStatus, String hrStatus);

    @Query("select a from AttendanceAdjustmentRequest a where a.managerStatus = 'REJECTED' or a.hrStatus = 'REJECTED'")
    Page<AttendanceAdjustmentRequest> findRejected(Pageable p);
''',
"OvertimeRequest": '''
    List<OvertimeRequest> findByShiftAssignmentIdAndApprovalStatus(Long shiftAssignmentId, String status);
    List<OvertimeRequest> findByShiftAssignmentIdAndApprovalStatusIn(Long shiftAssignmentId, Collection<String> statuses);
    List<OvertimeRequest> findByShiftAssignmentIdInAndApprovalStatus(Collection<Long> scheduleIds, String status);
    Page<OvertimeRequest> findByApprovalStatusOrderByRequestedAtAsc(String status, Pageable p);
    long countByApprovalStatus(String status);
    List<OvertimeRequest> findTop50ByEmployeeIdOrderByRequestedAtDesc(Long employeeId);
''',
"ChecklistTemplate": '''
    @Query("select t from ChecklistTemplate t where t.storeId = :storeId and t.isActive = true order by t.checklistName")
    List<ChecklistTemplate> findByStoreIdAndIsActiveTrue(@Param("storeId") Integer storeId);

    @Query("select t from ChecklistTemplate t where t.storeId = :storeId order by t.checklistName")
    List<ChecklistTemplate> findByStoreId(@Param("storeId") Integer storeId);

    /** Mọi version của một mã mẫu (BR-CHK-01). */
    List<ChecklistTemplate> findByStoreIdAndChecklistCode(Integer storeId, String code);

    Optional<ChecklistTemplate> findFirstByStoreIdAndChecklistCodeOrderByVersionDesc(Integer storeId, String code);
''',
"ChecklistTemplateItem": '''
    List<ChecklistTemplateItem> findByChecklistTemplateIdOrderBySortOrderAsc(Integer templateId);
''',
"ChecklistTask": '''
    boolean existsByChecklistTemplateId(Integer templateId);
    boolean existsByChecklistTemplateIdAndShiftAssignmentId(Integer templateId, Long shiftAssignmentId);
    List<ChecklistTask> findByEmployeeIdAndRunStatus(Long employeeId, String status);
    long countByRunStatus(String status);
    List<ChecklistTask> findByDueAtBetween(Instant from, Instant to);

    @Query("select r from ChecklistTask r where r.employeeId = :employeeId and r.runStatus in :statuses order by r.dueAt")
    List<ChecklistTask> findMine(@Param("employeeId") Long employeeId, @Param("statuses") Collection<String> statuses);

    @Query("select r from ChecklistTask r where (:status = '' or r.runStatus = :status)")
    Page<ChecklistTask> searchByStatus(@Param("status") String status, Pageable p);

    @Query("select r from ChecklistTask r where r.runStatus in :statuses and r.dueAt >= :from and r.dueAt <= :to")
    List<ChecklistTask> findDueBetween(@Param("from") Instant from, @Param("to") Instant to,
                                      @Param("statuses") Collection<String> statuses);

    @Query("select r from ChecklistTask r where r.runStatus in :statuses and r.dueAt <= :now and r.dueAt >= :since")
    List<ChecklistTask> findOverdue(@Param("now") Instant now, @Param("since") Instant since,
                                   @Param("statuses") Collection<String> statuses);
''',
"ChecklistTaskItem": '''
    List<ChecklistTaskItem> findByChecklistTaskIdOrderByChecklistTaskItemIdAsc(Long runId);
''',
"TrainingCourse": '''
    Optional<TrainingCourse> findByCourseCode(String code);

    @Query("select c from TrainingCourse c where c.isActive = true")
    List<TrainingCourse> findByIsActiveTrue();
''',
"EmployeeTraining": '''
    List<EmployeeTraining> findByEmployeeId(Long employeeId);
    Optional<EmployeeTraining> findByEmployeeIdAndCourseId(Long employeeId, Integer courseId);

    /** Khóa đã đạt nhưng hết hạn hiệu lực: chuyển sang EXPIRED (SRS 8.5). */
    @Query("select t from EmployeeTraining t where t.trainingStatus = 'PASSED' "
         + "and t.expiresAt is not null and t.expiresAt < :now")
    List<EmployeeTraining> findExpiredPassed(@Param("now") Instant now);
''',
"RuleCatalog": '''
    Optional<RuleCatalog> findByRuleCode(String ruleCode);
''',
"ViolationEvent": '''
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select v from ViolationEvent v where v.violationEventId = :id")
    Optional<ViolationEvent> findByIdForUpdate(@Param("id") Long id);

    boolean existsByEmployeeIdAndRuleIdAndAttendanceId(Long employeeId, Integer ruleId, Long attendanceId);
    boolean existsByEmployeeIdAndRuleIdAndChecklistTaskId(Long employeeId, Integer ruleId, Long checklistTaskId);
    long countByRecordStatus(String status);

    @Query("select d from ViolationEvent d where (:status = '' or d.recordStatus = :status) "
         + "and (:employeeId = 0L or d.employeeId = :employeeId)")
    Page<ViolationEvent> search(@Param("status") String status, @Param("employeeId") Long employeeId, Pageable p);
''',
"ViolationExplanation": '''
    List<ViolationExplanation> findByViolationEventIdOrderBySubmittedAtAscViolationExplanationIdAsc(Long violationEventId);
''',
"EmployeeRewardPenalty": '''
    long countByDecisionStatus(String status);

    @Query("select r from EmployeeRewardPenalty r where r.decisionStatus in ('APPROVED','APPLIED') "
         + "and r.effectiveDate >= :from and r.effectiveDate < :to")
    List<EmployeeRewardPenalty> findApprovedBetween(@Param("from") Instant from, @Param("to") Instant to);
''',
"PayrollPeriod": '''
    List<PayrollPeriod> findAllByOrderByStartDateDesc();
    Optional<PayrollPeriod> findByPeriodCode(String code);
    boolean existsByPeriodStatusAndStartDateLessThanEqualAndEndDateGreaterThanEqual(String status, LocalDate d1, LocalDate d2);

    @Query("select case when count(p) > 0 then true else false end from PayrollPeriod p where p.startDate <= :end and p.endDate >= :start")
    boolean existsOverlap(@Param("start") LocalDate start, @Param("end") LocalDate end);
''',
"JobPosition": '''
    Optional<JobPosition> findByPositionCode(String positionCode);

    Optional<JobPosition> findByPositionName(String positionName);

    List<JobPosition> findByIsActiveTrueOrderByPositionNameAsc();
''',
"PositionDocumentRequirement": '''
    List<PositionDocumentRequirement> findByPositionIdOrderByEffectiveFromAsc(Integer positionId);

    /** Yêu cầu đang hiệu lực tại ngày d (SRS 7.4). */
    @Query("select r from PositionDocumentRequirement r where r.positionId = :positionId "
         + "and r.effectiveFrom <= :d and (r.effectiveTo is null or r.effectiveTo >= :d)")
    List<PositionDocumentRequirement> findEffective(@Param("positionId") Integer positionId, @Param("d") LocalDate d);
''',
"PositionTrainingRequirement": '''
    List<PositionTrainingRequirement> findByPositionIdOrderByEffectiveFromAsc(Integer positionId);

    /** Yêu cầu đào tạo đang hiệu lực tại ngày d. */
    @Query("select r from PositionTrainingRequirement r where r.positionId = :positionId "
         + "and r.effectiveFrom <= :d and (r.effectiveTo is null or r.effectiveTo >= :d)")
    List<PositionTrainingRequirement> findEffective(@Param("positionId") Integer positionId, @Param("d") LocalDate d);
''',
"TrainingAttempt": '''
    long countByEmployeeIdAndCourseId(Long employeeId, Integer courseId);

    List<TrainingAttempt> findByEmployeeIdAndCourseIdOrderByAttemptNoAsc(Long employeeId, Integer courseId);
''',
"TrainingQuestion": '''
    List<TrainingQuestion> findByCourseIdOrderBySortOrderAscQuestionIdAsc(Integer courseId);
    List<TrainingQuestion> findByCourseIdAndIsActiveTrueOrderBySortOrderAscQuestionIdAsc(Integer courseId);
    void deleteByCourseId(Integer courseId);
''',
"Skill": '''
    boolean existsBySkillCode(String skillCode);

    @Query("select s from Skill s where s.isActive = true order by s.skillName")
    List<Skill> findActive();
''',
"EmployeeSkill": '''
    List<EmployeeSkill> findByEmployeeIdOrderByAssessedAtDesc(Long employeeId);
''',
"ChecklistInstance": '''
    List<ChecklistInstance> findByChecklistTemplateIdAndWorkDate(Integer checklistTemplateId, LocalDate workDate);
''',
"ChecklistEvidence": '''
    boolean existsByChecklistTaskItemId(Long checklistTaskItemId);
    List<ChecklistEvidence> findByChecklistTaskId(Long checklistTaskId);
''',
"ChecklistReview": '''
    Optional<ChecklistReview> findFirstByChecklistTaskIdOrderByReviewedAtDesc(Long checklistTaskId);
''',
"ReminderRule": '''
    Optional<ReminderRule> findByRuleCode(String ruleCode);
''',
}
