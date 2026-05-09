import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gas_company/core/services/supabase_service.dart';

final _secure = const FlutterSecureStorage();

/// Clears local secure storage and Supabase session. Call from UI/dev tools.
Future<void> resetAppSession(WidgetRef ref) async {
  try {
    await supabase.auth.signOut();
  } catch (_) {}
  try {
    await _secure.deleteAll();
  } catch (_) {}

  // Invalidate common auth-related providers so the app re-evaluates state.
  try {
    ref.invalidate(Provider((_) => null));
  } catch (_) {}
}
