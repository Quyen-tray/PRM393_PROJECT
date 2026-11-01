#!/usr/bin/env bash
# Chạy toàn bộ integration tests trên SQL Server Testcontainers.
# Yêu cầu: Docker đang chạy, Maven 3.9+, JDK 17. Chạy từ thư mục gốc backend.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! docker info >/dev/null 2>&1; then
  echo "Không kết nối được Docker. Hãy khởi động Docker rồi chạy lại." >&2
  exit 1
fi

# Failsafe nhận pattern *IT để không bỏ sót các IT mới (concurrency,
# absence, document/upload access, signed-file audit, verification attempts,
# last-admin guard, auth và payroll-period concurrency).
mvn -B verify \
  -Dtest=NONE -Dsurefire.failIfNoSpecifiedTests=false \
  -Dit.test='*IT'
