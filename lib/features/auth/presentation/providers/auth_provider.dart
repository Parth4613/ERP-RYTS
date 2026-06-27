import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gas_company/core/services/supabase_service.dart';
import 'package:gas_company/features/auth/data/models/user_model.dart';
import 'package:gas_company/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:gas_company/features/auth/domain/repositories/auth_repository.dart';
import 'package:gas_company/features/auth/domain/usecases/login_usecase.dart';
import 'package:gas_company/features/auth/domain/usecases/logout_usecase.dart';

/// Repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(supabaseClientProvider));
});

/// Auth State
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Current User
final currentUserProvider = FutureProvider.autoDispose<UserModel?>((ref) async {
  await ref.watch(authStateProvider.future);

  final repo = ref.watch(authRepositoryProvider);

  return repo.getCurrentUser();
});

/// Current Role
final currentUserRoleProvider = Provider<String?>((ref) {
  final user = Supabase.instance.client.auth.currentUser;

  return user?.appMetadata['role'] as String?;
});

/// Is Admin
final isAdminOrOwnerProvider = Provider<bool>((ref) {
  final role = ref.watch(currentUserRoleProvider);

  return role == 'admin' || role == 'owner';
});

/// Login
final loginProvider = AsyncNotifierProvider.autoDispose<LoginNotifier, void>(
  LoginNotifier.new,
);

class LoginNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final repo = ref.watch(authRepositoryProvider);

      await LoginUseCase(repo).call(email, password);
    });
  }
}

/// Logout
final logoutProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});
