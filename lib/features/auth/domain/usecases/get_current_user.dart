import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUser {
  const GetCurrentUser(this._repository);

  final AuthRepository _repository;

  Future<User> call() {
    return _repository.getCurrentUser();
  }
}