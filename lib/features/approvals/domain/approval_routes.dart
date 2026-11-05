const approvalQueueRoutes = <String, (String, String)>{
  'devices': ('Thiết bị chờ duyệt', '/module/devices'),
  'explanations': (
    'Giải trình chờ quản lý',
    '/module/explanations?status=PENDING',
  ),
  'overtime': ('Tăng ca chờ duyệt', '/module/overtime?status=PENDING'),
  'adjustmentsAwaitingManager': (
    'Điều chỉnh · bước quản lý',
    '/module/adjustments?status=PENDING_MANAGER',
  ),
  'adjustmentsAwaitingHr': (
    'Điều chỉnh · bước nhân sự',
    '/module/adjustments?status=PENDING_HR',
  ),
  'checklistReviews': ('Checklist chờ duyệt', '/module/checklist-reviews'),
  'trainingReviews': ('Đào tạo cần xác nhận', '/module/training-reviews'),
  'documents': ('Hồ sơ chờ duyệt', '/module/documents'),
  'violations': ('Vi phạm cần xem xét', '/module/violations?status=OPEN'),
  'rewardsAndPenalties': (
    'Đề xuất thưởng / phạt',
    '/module/decisions?status=PENDING_APPROVAL',
  ),
};
