import '../entities/user.dart';

abstract interface class AuthRepository {
  Future<User> signInWithGoogle();

  Future<User> getCurrentUser();

  Future<User> updateCurrentUser({String? displayName, String? phoneNumber});

  Future<void> signOut();
}
