import 'package:gas_company/features/auth/data/models/user_model.dart';

/// Abstract auth repository interface.
/// AD-012: UI → Provider → UseCase → Repository → Supabase
abstract class AuthRepository {
  Future<UserModel> signInWithEmail(String email, String password);
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
  Future<UserModel> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  });
  String? getCurrentRole();
  Stream<bool> watchAuthState();
}
