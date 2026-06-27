import '../../../../core/errors/app_exception.dart';
import '../../data/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

/// Login UseCase — validates input and delegates to repository.
/// AP-004: UI → Provider → UseCase → Repository → Supabase
class LoginUseCase {
  final AuthRepository _repository;

  const LoginUseCase(this._repository);

  Future<UserModel> call(String email, String password) async {
    // Business validations before calling repository
    if (email.trim().isEmpty) {
      throw const AppException('Email is required');
    }
    if (password.isEmpty) {
      throw const AppException('Password is required');
    }
    if (!email.contains('@')) {
      throw const AppException('Please enter a valid email address');
    }

    return _repository.signInWithEmail(email.trim(), password);
  }
}
