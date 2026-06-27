import '../../domain/repositories/auth_repository.dart';

/// Logout UseCase — simple delegation.
class LogoutUseCase {
  final AuthRepository _repository;

  const LogoutUseCase(this._repository);

  Future<void> call() => _repository.signOut();
}
