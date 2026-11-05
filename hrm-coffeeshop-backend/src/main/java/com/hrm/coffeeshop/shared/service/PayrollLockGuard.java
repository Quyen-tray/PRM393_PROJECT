package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.domain.PayrollPeriod;
import com.hrm.coffeeshop.repository.PayrollPeriodRepository;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

/**
 * Chặn mọi thay đổi dữ liệu công (check-in, check-out, điều chỉnh, OT, giải trình)
 * thuộc một ngày nằm trong kỳ công đã chốt (LOCKED).
 *
 * Trước đây chỉ bản ghi Attendance đã tồn tại mới được khóa khi chốt, nên nhân viên
 * chưa có bản ghi công vẫn có thể check-in vào kỳ đã chốt. Guard này kiểm tra theo
 * NGÀY LÀM VIỆC của ca, không phụ thuộc vào việc bản ghi công đã tồn tại hay chưa.
 *
 * Kiểm tra theo kiểu "khóa rồi đọc": guard khóa dòng kỳ công (UPDLOCK) và giữ khóa đến hết
 * transaction của người gọi. hrFinalize khóa cùng dòng đó, nên hai bên xếp hàng: check-in đang
 * chạy thì chốt phải chờ, còn chốt đã commit thì check-in đọc được trạng thái LOCKED và bị từ chối.
 * Người gọi phải gọi guard TRƯỚC khi nạp hoặc ghi bản ghi công.
 */
@Component
public class PayrollLockGuard {

    private final PayrollPeriodRepository periods;

    public PayrollLockGuard(PayrollPeriodRepository periods) {
        this.periods = periods;
    }

    public void assertWorkDateOpen(LocalDate workDate) {
        if (workDate == null) return;
        for (PayrollPeriod p : periods.findCoveringForUpdate(workDate))   // khóa trước
            if ("LOCKED".equals(p.getPeriodStatus()))                     // rồi mới đọc trạng thái
                throw new BusinessException(ErrorCode.PAYROLL_PERIOD_LOCKED,
                        "Ngày " + workDate + " thuộc kỳ công đã chốt, không thể thay đổi");
    }
}
