import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_exception.dart';
import '../network/api_providers.dart';
import '../network/authenticated_api.dart';

class UploadSelection {
  const UploadSelection(this.name, this.bytes, this.mime);
  final String name, mime;
  final Uint8List bytes;
}

class EvidenceService {
  EvidenceService(this.api);
  final AuthenticatedApi api;
  Future<UploadSelection?> choose(String purpose) async {
    final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: purpose == 'DOCUMENT'
            ? ['pdf', 'jpg', 'jpeg', 'png', 'webp']
            : ['jpg', 'jpeg', 'png', 'webp']);
    if (result == null) return null;
    final file = result;
    final max = purpose == 'DOCUMENT' ? 10 * 1024 * 1024 : 8 * 1024 * 1024;
    if ((await file.length() ?? max + 1) > max) {
      throw ApiException(
          message:
              'Tệp vượt quá ${max ~/ 1024 ~/ 1024} MiB. Chọn tệp nhỏ hơn.');
    }
    final bytes = await file.readAsBytes();
    final mime = switch (file.extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg'
    };
    return UploadSelection(file.name, bytes, mime);
  }

  Future<String> upload(UploadSelection file, String purpose,
          {int? employeeId}) =>
      api.upload(file.bytes, file.mime, purpose, employeeId: employeeId);
}

final evidenceServiceProvider =
    Provider((ref) => EvidenceService(ref.watch(authenticatedApiProvider)));
