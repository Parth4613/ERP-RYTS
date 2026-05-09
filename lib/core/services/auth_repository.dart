import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'supabase_service.dart';

class AuthRepository {
  final _secure = const FlutterSecureStorage();

  Future<Session?> currentSession() async {
    return supabase.auth.currentSession;
  }

  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    try {
      final res = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (res == null) return null;
      if (res is Map<String, dynamic>) return res;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearLocalStorage() async {
    try {
      await _secure.deleteAll();
    } catch (_) {}
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    await clearLocalStorage();
  }
}
