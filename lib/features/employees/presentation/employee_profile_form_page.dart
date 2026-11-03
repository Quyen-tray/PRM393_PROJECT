import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';

/// Loại hợp đồng theo EmploymentType trong backend (EmployeeDto).
const _employmentTypes = ['FULL_TIME', 'PART_TIME', 'TEMPORARY', 'PROBATION'];

/// Form dùng chung để tạo và sửa hồ sơ nhân viên.
///
/// - Tạo: `EmployeeProfileFormPage.create(userId: ...)` — chỉ mở từ Quản lý tài khoản (SYSTEM_ADMIN),
///   vì backend chỉ cho Admin liệt kê tài khoản và chức vụ.
/// - Sửa: `EmployeeProfileFormPage.edit(employeeId: ...)` — mở từ chi tiết nhân viên khi có EMPLOYEE_MANAGE.
///   Chỉ gửi các trường đã đổi (PATCH).
class EmployeeProfileFormPage extends ConsumerStatefulWidget {
  const EmployeeProfileFormPage.create({
    this.userId,
    this.displayName,
    this.email,
    super.key,
  }) : isEdit = false,
       employeeId = null;

  const EmployeeProfileFormPage.edit({this.employeeId, super.key})
    : isEdit = true,
      userId = null,
      displayName = null,
      email = null;

  final bool isEdit;
  final int? userId;
  final int? employeeId;
  final String? displayName;
  final String? email;

  @override
  ConsumerState<EmployeeProfileFormPage> createState() =>
      _EmployeeProfileFormPageState();
}

class _EmployeeProfileFormPageState
    extends ConsumerState<EmployeeProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _identity = TextEditingController();
  final _address = TextEditingController();
  final _emergency = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  /// Danh sách chức vụ đã tải thành công. Không có quyền hoặc lỗi thì false và không đổi được chức vụ.
  bool _positionsReady = false;
  String? _positionNote;
  List<Map<String, dynamic>> _positions = [];

  int? _positionId;
  String? _employmentType;
  DateTime? _hireDate;
  DateTime? _dateOfBirth;

  /// Sửa: ngày sinh đã có thì không xóa được (PATCH không gửi được null để xóa).
  bool _dateOfBirthFixed = false;

  /// Sửa: dữ liệu gốc từ máy chủ, dùng để chỉ gửi các trường đã đổi.
  Map<String, dynamic> _original = {};

  /// Lỗi theo trường trả về từ máy chủ sau lần lưu gần nhất (VALIDATION_ERROR).
  Map<String, String> _serverErrors = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final controller in [
      _code,
      _fullName,
      _phone,
      _identity,
      _address,
      _emergency,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    final repo = ref.read(employeeRepositoryProvider);
    try {
      final access = await repo.getCurrentAccess();

      Map<String, dynamic> employee = {};
      if (widget.isEdit) {
        final id = widget.employeeId;
        if (id == null) {
          throw const ApiException(message: 'Mã nhân viên không hợp lệ.');
        }
        employee = await repo.getEmployeeById(id);
      } else if (widget.userId == null) {
        throw const ApiException(message: 'Tài khoản không hợp lệ.');
      }

      // Chức vụ: tạo mới luôn cần; sửa chỉ khi là SYSTEM_ADMIN (GET /admin/job-positions).
      var positionsReady = false;
      var positions = <Map<String, dynamic>>[];
      String? positionNote;
      if (!widget.isEdit || access.isSystemAdmin) {
        try {
          positions = await repo.getAdminJobPositions();
          positionsReady = true;
        } on ApiException catch (e) {
          positionNote = e.message;
        }
      } else {
        positionNote = 'Chỉ Quản trị viên mới đổi được chức vụ.';
      }

      if (!mounted) return;

      if (widget.isEdit) {
        _original = employee;
        _code.text = _s(employee['employeeCode']);
        _fullName.text = _s(employee['fullName']);
        _phone.text = _s(employee['phone']);
        _identity.text = _s(employee['identityNumber']);
        _address.text = _s(employee['address']);
        _emergency.text = _s(employee['emergencyContact']);
        _positionId = _intOf(employee['positionId']);
        _employmentType = _nonEmpty(employee['employmentType']);
        _hireDate = _parseIsoDate(employee['hireDate']);
        _dateOfBirth = _parseIsoDate(employee['dateOfBirth']);
        _dateOfBirthFixed = _dateOfBirth != null;

        // Chức vụ hiện tại có thể đã ngưng nên không nằm trong danh sách đang dùng: thêm để dropdown hiển thị đúng.
        final current = _positionId;
        if (positionsReady &&
            current != null &&
            positions.every((p) => _intOf(p['positionId']) != current)) {
          positions = [
            ...positions,
            {
              'positionId': current,
              'positionName': '${_s(employee['jobTitle'])} (đã ngưng)',
            },
          ];
        }
      } else {
        _employmentType = 'FULL_TIME';
        _hireDate = DateTime.now();
      }

      setState(() {
        _positions = positions;
        _positionsReady = positionsReady;
        _positionNote = positionNote;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Không tải được dữ liệu hồ sơ.';
        _loading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _init();
  }

  // ---------- Lưu ----------

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _serverErrors = {});

    if (!widget.isEdit && !_positionsReady) {
      _snack('Chưa tải được danh sách chức vụ nên chưa thể tạo hồ sơ.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(employeeRepositoryProvider);
    setState(() => _saving = true);
    try {
      if (widget.isEdit) {
        final changes = _buildChanges();
        if (changes.isEmpty) {
          setState(() => _saving = false);
          _snack('Không có thay đổi nào để lưu.');
          return;
        }
        await repo.updateEmployee(widget.employeeId!, changes);
      } else {
        await repo.createEmployee(_buildCreateBody());
      }
      if (!mounted) return;
      context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _serverErrors = _fieldErrors(e.details);
      });
      if (_serverErrors.isNotEmpty) _formKey.currentState?.validate();
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Không lưu được hồ sơ. Vui lòng thử lại.');
    }
  }

  Map<String, dynamic> _buildCreateBody() {
    final identity = _identity.text.trim();
    final address = _address.text.trim();
    final emergency = _emergency.text.trim();
    return {
      'userId': widget.userId,
      'employeeCode': _code.text.trim(),
      'positionId': _positionId,
      if (_employmentType != null) 'employmentType': _employmentType,
      'hireDate': _isoDate(_hireDate!),
      if (_dateOfBirth != null) 'dateOfBirth': _isoDate(_dateOfBirth!),
      if (identity.isNotEmpty) 'identityNumber': identity,
      if (address.isNotEmpty) 'address': address,
      if (emergency.isNotEmpty) 'emergencyContact': emergency,
    };
  }

  /// Chỉ đưa vào các trường khác với dữ liệu gốc.
  ///
  /// Số giấy tờ: máy chủ che số (vd `***123`) với người không có EMPLOYEE_PII_VIEW. Nếu người dùng không sửa
  /// thì giá trị che bằng với gốc nên không gửi, tránh ghi đè số thật bằng chuỗi che.
  Map<String, dynamic> _buildChanges() {
    final changes = <String, dynamic>{};

    final fullName = _fullName.text.trim();
    if (fullName != _s(_original['fullName'])) changes['fullName'] = fullName;

    final phone = _phone.text.trim();
    if (phone != _s(_original['phone'])) changes['phone'] = phone;

    final positionId = _positionId;
    if (_positionsReady &&
        positionId != null &&
        positionId != _intOf(_original['positionId'])) {
      changes['positionId'] = positionId;
    }

    final employmentType = _employmentType;
    if (employmentType != null &&
        employmentType != _nonEmpty(_original['employmentType'])) {
      changes['employmentType'] = employmentType;
    }

    final dateOfBirth = _dateOfBirth;
    if (dateOfBirth != null &&
        _isoDate(dateOfBirth) !=
            _isoOrEmpty(_parseIsoDate(_original['dateOfBirth']))) {
      changes['dateOfBirth'] = _isoDate(dateOfBirth);
    }

    final identity = _identity.text.trim();
    if (identity != _s(_original['identityNumber'])) {
      changes['identityNumber'] = identity;
    }

    final address = _address.text.trim();
    if (address != _s(_original['address'])) changes['address'] = address;

    final emergency = _emergency.text.trim();
    if (emergency != _s(_original['emergencyContact'])) {
      changes['emergencyContact'] = emergency;
    }

    return changes;
  }

  Map<String, String> _fieldErrors(Map<String, dynamic>? details) {
    if (details == null) return {};
    return {
      for (final entry in details.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
  }

  void _clearServerError(String key) {
    if (!_serverErrors.containsKey(key)) return;
    setState(
      () =>
          _serverErrors = Map<String, String>.from(_serverErrors)..remove(key),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- Giao diện ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Sửa hồ sơ nhân viên' : 'Tạo hồ sơ nhân viên',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _LoadError(message: _loadError!, onRetry: _retry)
          : Form(
              key: _formKey,
              // Column thay vì ListView: ListView chỉ dựng các mục gần màn hình nên Form.validate()
              // sẽ bỏ qua trường ở xa. Ở đây mọi trường luôn được dựng và kiểm tra.
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section(
                      'Tài khoản',
                      widget.isEdit
                          ? _editAccountFields()
                          : _createAccountFields(),
                    ),
                    _section('Công việc', _jobFields()),
                    _section('Thông tin cá nhân', _personalFields()),
                    _section('Địa chỉ và liên hệ khẩn cấp', _addressFields()),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.isEdit ? 'Lưu thay đổi' : 'Tạo hồ sơ'),
                ),
              ),
            ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 12),
            for (final child in children) ...[
              child,
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _createAccountFields() {
    final name = widget.displayName?.trim();
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (name == null || name.isEmpty) ? 'Chưa có tên' : name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.email ?? '—',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
      const Text(
        'Hồ sơ sẽ được gắn với tài khoản này. Mỗi tài khoản chỉ có một hồ sơ.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    ];
  }

  List<Widget> _editAccountFields() {
    return [
      _textField(
        controller: _fullName,
        label: 'Họ và tên *',
        serverKey: 'fullName',
        required: true,
        maxLength: 150,
      ),
      _textField(
        controller: _phone,
        label: 'Số điện thoại',
        serverKey: 'phone',
        maxLength: 20,
        keyboardType: TextInputType.phone,
        helper: 'Để trống để xóa số điện thoại.',
      ),
      Text(
        "Email: ${_s(_original['email'])}  (email thuộc tài khoản, không sửa tại đây)",
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    ];
  }

  List<Widget> _jobFields() {
    final codeReadOnly = widget.isEdit;
    final hireReadOnly = widget.isEdit;
    final employmentType = _employmentTypes.contains(_employmentType)
        ? _employmentType
        : null;
    return [
      _textField(
        controller: _code,
        label: 'Mã nhân viên *',
        serverKey: 'employeeCode',
        required: !codeReadOnly,
        enabled: !codeReadOnly,
        maxLength: 30,
        helper: codeReadOnly ? 'Mã nhân viên không sửa được tại đây.' : null,
      ),
      _positionField(),
      DropdownButtonFormField<String>(
        initialValue: employmentType,
        isExpanded: true,
        hint: const Text('Chưa cập nhật'),
        decoration: const InputDecoration(labelText: 'Loại hợp đồng *'),
        items: [
          for (final type in _employmentTypes)
            DropdownMenuItem(
              value: type,
              child: Text(employmentTypeLabel(type)),
            ),
        ],
        onChanged: (value) {
          setState(() => _employmentType = value);
          _clearServerError('employmentType');
        },
        validator: (value) {
          final server = _serverErrors['employmentType'];
          if (server != null) return server;
          if (!widget.isEdit && value == null) {
            return 'Vui lòng chọn loại hợp đồng.';
          }
          return null;
        },
      ),
      _dateField(
        label: 'Ngày vào làm *',
        value: _hireDate,
        readOnly: hireReadOnly,
        clearable: false,
        error: _serverErrors['hireDate'],
        helper: hireReadOnly ? 'Ngày vào làm không sửa được tại đây.' : null,
        onChanged: (date) => setState(() => _hireDate = date),
      ),
    ];
  }

  Widget _positionField() {
    if (_positionsReady) {
      return DropdownButtonFormField<int>(
        initialValue: _positionId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Chức vụ *'),
        items: [
          for (final position in _positions)
            DropdownMenuItem<int>(
              value: _intOf(position['positionId']),
              child: Text(_s(position['positionName'])),
            ),
        ],
        onChanged: (value) {
          setState(() => _positionId = value);
          _clearServerError('positionId');
        },
        validator: (value) {
          final server = _serverErrors['positionId'];
          if (server != null) return server;
          return value == null ? 'Vui lòng chọn chức vụ.' : null;
        },
      );
    }

    final current = widget.isEdit ? _s(_original['jobTitle']) : '';
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Chức vụ',
        helperText: _positionNote ?? 'Không tải được danh sách chức vụ.',
      ),
      child: Text(current.isEmpty ? 'Chưa cập nhật' : current),
    );
  }

  List<Widget> _personalFields() {
    final masked = _s(_original['identityNumber']).startsWith('***');
    return [
      _dateField(
        label: 'Ngày sinh',
        value: _dateOfBirth,
        clearable: !_dateOfBirthFixed,
        helper: _dateOfBirthFixed
            ? 'Đã có ngày sinh nên không xóa được tại đây.'
            : null,
        error: _serverErrors['dateOfBirth'],
        onChanged: (date) {
          setState(() => _dateOfBirth = date);
          _clearServerError('dateOfBirth');
        },
      ),
      _textField(
        controller: _identity,
        label: 'Số CCCD / giấy tờ tùy thân',
        serverKey: 'identityNumber',
        maxLength: 50,
        helper: masked ? 'Số đang được che. Nhập số mới để thay đổi.' : null,
      ),
    ];
  }

  List<Widget> _addressFields() {
    return [
      _textField(
        controller: _address,
        label: 'Địa chỉ',
        serverKey: 'address',
        maxLength: 300,
        maxLines: 2,
      ),
      _textField(
        controller: _emergency,
        label: 'Liên hệ khẩn cấp',
        serverKey: 'emergencyContact',
        maxLength: 150,
        helper: 'Họ tên và số điện thoại người thân.',
      ),
    ];
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String serverKey,
    bool enabled = true,
    bool required = false,
    int maxLength = 150,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? helper,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, helperText: helper),
      onChanged: (_) => _clearServerError(serverKey),
      validator: (value) {
        final server = _serverErrors[serverKey];
        if (server != null) return server;
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) return 'Không được để trống.';
        if (text.length > maxLength) return 'Tối đa $maxLength ký tự.';
        return null;
      },
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    bool readOnly = false,
    bool clearable = true,
    String? helper,
    String? error,
  }) {
    final showClear = !readOnly && clearable && value != null;
    return InkWell(
      onTap: readOnly
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(1940),
                lastDate: DateTime(2100),
              );
              if (picked != null && mounted) onChanged(picked);
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          errorText: error,
          suffixIcon: showClear
              ? IconButton(
                  tooltip: 'Xóa ngày',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value == null ? 'Chưa chọn' : _displayDate(value)),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

// ---------- Tiện ích ----------

String _s(Object? value) => value?.toString().trim() ?? '';

String? _nonEmpty(Object? value) {
  final text = _s(value);
  return text.isEmpty ? null : text;
}

int? _intOf(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(_s(value));
}

/// yyyy-MM-dd, định dạng LocalDate của backend.
String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _isoOrEmpty(DateTime? date) => date == null ? '' : _isoDate(date);

/// dd/MM/yyyy để hiển thị.
String _displayDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

/// Đọc LocalDate ISO (yyyy-MM-dd...) từ máy chủ, bỏ phần giờ và múi giờ.
DateTime? _parseIsoDate(Object? value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(_s(value));
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}
