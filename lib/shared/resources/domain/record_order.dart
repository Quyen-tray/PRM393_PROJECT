int compareRecords(Map<String, dynamic> a, Map<String, dynamic> b,
    {required String sortField, required String idKey}) {
  final primary = _compareValues(a[sortField], b[sortField]);
  return primary != 0 ? primary : _compareValues(a[idKey], b[idKey]);
}

int _compareValues(Object? a, Object? b) {
  if (a == b) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  final firstNumber = num.tryParse('$a');
  final secondNumber = num.tryParse('$b');
  if (firstNumber != null && secondNumber != null) {
    return firstNumber.compareTo(secondNumber);
  }
  final firstDate = DateTime.tryParse('$a');
  final secondDate = DateTime.tryParse('$b');
  if (firstDate != null && secondDate != null) {
    return firstDate.compareTo(secondDate);
  }
  return '$a'.compareTo('$b');
}
