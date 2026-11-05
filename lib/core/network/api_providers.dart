import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'authenticated_api.dart';
import '../storage/session_store.dart';

final sessionStoreProvider =
    Provider<SessionStore>((ref) => const SecureSessionStore());
final authenticatedApiProvider = Provider<AuthenticatedApi>((ref) =>
    AuthenticatedApi(vault: TokenVault(ref.watch(sessionStoreProvider))));

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
