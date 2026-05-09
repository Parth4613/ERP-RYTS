import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final _secureStorage = const FlutterSecureStorage();

/// Initialize Supabase and attach auth listeners that help detect invalid
/// or expired sessions and clear local storage when necessary.
Future<void> initSupabaseAndMonitor({
  required String url,
  required String anonKey,
}) async {
  await Supabase.initialize(url: url, anonKey: anonKey);

  // Listen for auth state changes to catch invalid sessions or sign-outs
  Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
    final AuthChangeEvent ev = event.event;
    final Session? session = event.session;
    // If signed out or session cleared, remove any stored secrets
    if (ev == AuthChangeEvent.signedOut || session == null) {
      try {
        await _secureStorage.deleteAll();
      } catch (_) {}
    }
  });
}

/// Global Supabase client accessor
final supabase = Supabase.instance.client;

/// Supabase configuration constants
class SupabaseConfig {
  /// Provide values at build time:
  /// - `--dart-define=SUPABASE_URL=...`
  /// - `--dart-define=SUPABASE_ANON_KEY=...`
  static String url = const String.fromEnvironment('SUPABASE_URL');
  static String anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Ensure keys are available either from dart-define or from a .env file.
  static Future<void> ensureLoaded({String envFile = '.env'}) async {
    if (url.isEmpty || anonKey.isEmpty) {
      try {
        await dotenv.load(fileName: envFile);
      } catch (_) {}
      try {
        url = url.isNotEmpty ? url : (dotenv.env['SUPABASE_URL'] ?? '');
      } catch (_) {
        // dotenv not initialized; leave url as-is
      }
      try {
        anonKey = anonKey.isNotEmpty
            ? anonKey
            : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');
      } catch (_) {
        // dotenv not initialized; leave anonKey as-is
      }
    }

    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'Missing Supabase configuration. Provide via --dart-define or a .env file with SUPABASE_URL and SUPABASE_ANON_KEY',
      );
    }
  }
}
