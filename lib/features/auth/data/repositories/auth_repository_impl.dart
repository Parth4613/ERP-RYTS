import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

/// Concrete auth repository implementation.
/// AP-004: Repository → Supabase. Never call Supabase from UI.
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client;

  AuthRepositoryImpl(this._client);

  @override
  Future<UserModel> signInWithEmail(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const AppException('Login failed. Please check your credentials.');
      }

      // Fetch user profile from public.users
      final profile = await _fetchProfile(response.user!.id);
      return profile;
    } on AuthException catch (e) {
      throw AppException(
        _mapAuthError(e.message),
        code: e.statusCode,
        originalError: e,
      );
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      return await _fetchProfile(user.id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserModel> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AppException('Not authenticated');
    }

    try {
      final updates = <String, dynamic>{
        'updated_by': userId,
      };
      if (fullName != null) updates['full_name'] = fullName;
      if (phone != null) updates['phone'] = phone;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      final data = await _client
          .from('users')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      return UserModel.fromJson({
        ...data,
        'role': getCurrentRole(),
        'email': _client.auth.currentUser?.email,
      });
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  @override
  String? getCurrentRole() {
    // AD-008: Role from app_metadata only, never user_metadata
    return _client.auth.currentUser?.appMetadata['role'] as String?;
  }

  @override
  Stream<bool> watchAuthState() {
    return _client.auth.onAuthStateChange.map(
      (state) => state.session != null,
    );
  }

  /// Fetches user profile from public.users table and enriches with auth data
  Future<UserModel> _fetchProfile(String userId) async {
    try {
      final data = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      final authUser = _client.auth.currentUser;

      if (data != null) {
        return UserModel.fromJson({
          ...data,
          'role': authUser?.appMetadata['role'],
          'email': authUser?.email,
        });
      }

      // If profile doesn't exist yet (auto-create trigger may not have fired),
      // return a minimal model
      return UserModel(
        id: userId,
        fullName: authUser?.userMetadata?['full_name'] as String? ??
            authUser?.email?.split('@').first ??
            'User',
        email: authUser?.email,
        role: authUser?.appMetadata['role'] as String?,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on PostgrestException catch (e) {
      throw AppException.fromSupabase(e);
    }
  }

  String _mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Invalid email or password. Please try again.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Please verify your email address first.';
    }
    if (message.contains('rate limit')) {
      return 'Too many attempts. Please try again later.';
    }
    return message;
  }
}
