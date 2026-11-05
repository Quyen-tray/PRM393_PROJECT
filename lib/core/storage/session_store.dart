import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSessionStore implements SessionStore {
  final FlutterSecureStorage storage;
  // Isolate the app's keys from legacy preferences restored without their Keystore keys.
  static const _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'hrm_session_v2',
      resetOnError: true,
      migrateWithBackup: true,
    ),
  );
  const SecureSessionStore([this.storage = _defaultStorage]);
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => storage.delete(key: key);
}

String randomKey() =>
    base64UrlEncode(List<int>.generate(32, (_) => Random.secure().nextInt(256)))
        .replaceAll('=', '');

class TokenVault {
  TokenVault(this.store);
  final SessionStore store;
  String? accessToken;
  String? refreshToken;
  String? deviceCredential;
  int generation = 0;
  Future<void> load() async {
    final loadedAccess = await store.read('access');
    if (loadedAccess != accessToken) generation++;
    accessToken = loadedAccess;
    refreshToken = await store.read('refresh');
    deviceCredential = await store.read('device-credential');
    if (deviceCredential == null) {
      deviceCredential = randomKey();
      await store.write('device-credential', deviceCredential!);
    }
  }

  Future<void> save(Map<String, dynamic> tokens) async {
    generation++;
    refreshToken = tokens['refreshToken'] as String;
    accessToken = tokens['accessToken'] as String;
    await store.write('refresh', refreshToken!);
    await store.write('access', accessToken!);
  }

  Future<void> clear() async {
    generation++;
    accessToken = null;
    refreshToken = null;
    await store.delete('access');
    await store.delete('refresh');
    // Installation identity survives account switching; pending operations are user scoped.
  }
}
