import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gas_company/core/services/supabase_service.dart';
import 'package:gas_company/core/services/auth_repository.dart';
import 'package:gas_company/core/models/user_profile.dart';

/// Auth state provider - listens to Supabase auth changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

/// Current user session
final currentSessionProvider = Provider<Session?>((ref) {
  return supabase.auth.currentSession;
});

/// Current user profile
final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repo = AuthRepository();
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final profileMap = await repo.fetchProfile(user.id);
  if (profileMap == null) return null;
  try {
    return UserProfile.fromJson(profileMap);
  } catch (_) {
    return null;
  }
});

/// All profiles (for admin)
final allProfilesProvider = FutureProvider<List<UserProfile>>((ref) async {
  final response = await supabase.from('profiles').select().order('name');
  return (response as List)
      .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Engineers only (for project assignment)
final engineersProvider = FutureProvider<List<UserProfile>>((ref) async {
  final response = await supabase
      .from('profiles')
      .select()
      .eq('role', 'engineer')
      .order('name');
  return (response as List)
      .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Auth notifier for login/signup/logout
class AuthNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    state = const AsyncValue.loading();
    try {
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          // IMPORTANT: never trust client-provided role for authorization.
          // Role should be assigned server-side (admin workflow) and stored in `profiles`.
          'requested_role': role,
        },
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    final repo = AuthRepository();
    try {
      await repo.signOut();
      // Invalidate cached providers to force re-checks
      ref.invalidate(currentProfileProvider);
      ref.invalidate(allProfilesProvider);
      ref.invalidate(engineersProvider);
      // authStateProvider is a stream; downstream listeners will react.
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(
  AuthNotifier.new,
);
