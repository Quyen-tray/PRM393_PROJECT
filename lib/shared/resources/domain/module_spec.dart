import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/domain/current_user.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

enum FieldKind {
  text,
  multiline,
  integer,
  decimal,
  date,
  dateTime,
  time,
  toggle,
  choice,
  multiple,
  lookup,
  array,
  upload,
}

class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.required = false,
    this.options = const [],
    this.source,
    this.valueKey,
    this.labelKey,
    this.fields = const [],
    this.defaultValue,
    this.min,
    this.max,
  });
  final String key, label;
  final FieldKind kind;
  final bool required;
  final List<String> options;
  final String? source, valueKey, labelKey;
  final List<FieldSpec> fields;
  final dynamic defaultValue;
  final num? min, max;
}

typedef Access = bool Function(CurrentUser user);
bool employee(CurrentUser u) => u.employeeId != null;
bool admin(CurrentUser u) => u.admin;
bool manager(CurrentUser u) => u.manager;
bool trainingManager(CurrentUser u) => u.admin || u.has('TRAINING_MANAGE');
bool canAdjust(CurrentUser u) =>
    u.manager || u.has('ATTENDANCE_ADJUST_HR') || u.has('ATTENDANCE_VIEW_ALL');

class ModuleSpec {
  const ModuleSpec(
    this.key,
    this.title,
    this.path,
    this.idKey,
    this.titleKey, {
    required this.access,
    this.icon = Icons.folder_outlined,
    this.detail,
    this.createPath,
    this.editPath,
    this.editMethod = 'PUT',
    this.fields = const [],
    this.editFields,
    this.createAccess,
    this.editAccess,
    this.filters = const [],
    this.search = false,
    this.group = 'Vận hành',
    this.workspaces = const [],
    this.kind = 'resource',
  });
  final String key, title, path, idKey, titleKey, editMethod, group, kind;
  final IconData icon;
  final String? detail, createPath, editPath;
  final List<FieldSpec> fields;
  final List<FieldSpec>? editFields;
  final List<String> filters;
  final bool search;
  final Access access;
  final Access? createAccess, editAccess;
  final List<Workspace> workspaces;
  bool visible(CurrentUser user, Workspace workspace) =>
      kind != 'internal' &&
      access(user) &&
      (workspaces.isEmpty || workspaces.contains(workspace));
  String itemPath(Object id) =>
      (detail ?? '$path/{id}').replaceAll('{id}', Uri.encodeComponent('$id'));
  String get listRoute => '/module/$key';
  String recordRoute(Object id) => '/record/$key/${Uri.encodeComponent('$id')}';
}

String recordId(ModuleSpec spec, Map<String, dynamic> row) =>
    '${row[spec.idKey]}';
