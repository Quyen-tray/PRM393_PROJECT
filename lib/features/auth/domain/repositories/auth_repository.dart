import '../entities/user.dart';

abstract interface class AuthRepository {
  Future<User> signInWithGoogle();

  Future<User> getCurrentUser();

  Future<void> signOut();
}