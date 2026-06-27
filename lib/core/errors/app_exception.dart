import 'package:supabase_flutter/supabase_flutter.dart';

/// Custom exception for the Gas Pipeline ERP.
/// Maps Supabase PostgrestException codes to user-friendly messages.
/// See FLUTTER_PATTERNS.md error handling section.
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => message;

  /// Maps common Postgres error codes to user-friendly messages.
  /// P0001 = custom business rule errors raised by triggers (BR-XXX).
  factory AppException.fromSupabase(PostgrestException e) {
    return switch (e.code) {
      '23505' => AppException(
          'This record already exists',
          code: e.code,
          originalError: e,
        ),
      '23503' => AppException(
          'Related record not found. It may have been deleted.',
          code: e.code,
          originalError: e,
        ),
      '23514' => AppException(
          'Data validation failed. Please check your input.',
          code: e.code,
          originalError: e,
        ),
      '42501' => AppException(
          'You do not have permission to perform this action.',
          code: e.code,
          originalError: e,
        ),
      'P0001' => AppException(
          e.message,
          code: e.code,
          originalError: e,
        ),
      'PGRST116' => AppException(
          'Record not found',
          code: e.code,
          originalError: e,
        ),
      _ => AppException(
          'An unexpected error occurred. Please try again.',
          code: e.code,
          originalError: e,
        ),
    };
  }

  /// Creates from a generic error
  factory AppException.fromError(dynamic error) {
    if (error is AppException) return error;
    if (error is PostgrestException) return AppException.fromSupabase(error);
    if (error is AuthException) {
      return AppException(
        error.message,
        code: error.statusCode,
        originalError: error,
      );
    }
    return AppException(
      error.toString(),
      originalError: error,
    );
  }
}
