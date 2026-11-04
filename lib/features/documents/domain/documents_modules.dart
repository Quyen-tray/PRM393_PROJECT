import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

final myDocumentRecordsModule = ModuleSpec(
  'my-document-records',
  'Chi tiết giấy tờ',
  '/employees/me/documents',
  'documentId',
  'fileName',
  access: (_) => true,
  detail: '/documents/{id}',
  kind: 'internal',
);

final myDocumentsModule = ModuleSpec(
  'my-documents',
  'Giấy tờ của tôi',
  '/employees/me/documents/catalog',
  'documentTypeId',
  'documentName',
  access: employee,
  icon: Icons.snippet_folder_outlined,
  kind: 'documents',
  group: 'Cá nhân',
  workspaces: [Workspace.employee],
);

final documentsModule = ModuleSpec(
  'documents',
  'Duyệt hồ sơ',
  '/documents/pending',
  'documentId',
  'employeeName',
  access: (u) => u.has('DOCUMENT_REVIEW'),
  detail: '/documents/{id}',
  icon: Icons.snippet_folder,
  group: 'Duyệt',
);

final documentTypesModule = ModuleSpec(
  'document-types',
  'Loại giấy tờ',
  '/admin/document-types',
  'documentTypeId',
  'documentName',
  access: admin,
  icon: Icons.folder_copy_outlined,
  group: 'Danh mục',
  createPath: '/admin/document-types',
  editPath: '/admin/document-types/{id}',
  createAccess: admin,
  editAccess: admin,
  fields: [
    FieldSpec('documentCode', 'Mã giấy tờ', required: true),
    FieldSpec('documentName', 'Tên giấy tờ', required: true),
    activeField,
  ],
);
