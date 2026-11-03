import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../data/auth_providers.dart';

Future<void> signOutAndReturnToLogin(
    BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(authRepositoryProvider).signOut();
  } catch (_) {
    // Local session cleanup runs in AuthRepository.signOut's finally block.
  }

  if (context.mounted) context.go(RouteNames.login);
}
