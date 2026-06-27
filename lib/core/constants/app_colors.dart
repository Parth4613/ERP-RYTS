import 'package:flutter/material.dart';

/// Design tokens from UI_SPEC.md — all color constants for the Gas Pipeline ERP.
/// Dark theme only (AD-026). Never hardcode colors in widgets.
class AppColors {
  AppColors._();

  // ─── Backgrounds ───
  static const background = Color(0xFF0F1117);
  static const surface = Color(0xFF171A21);
  static const surfaceAlt = Color(0xFF1F2430);
  static const border = Color(0xFF2D3443);

  // ─── Brand ───
  static const primary = Color(0xFF4F8CFF);
  static const primaryDim = Color(0xFF1E3A6E);

  // ─── Semantic ───
  static const success = Color(0xFF22C55E);
  static const successDim = Color(0xFF14532D);
  static const warning = Color(0xFFF59E0B);
  static const warningDim = Color(0xFF78350F);
  static const danger = Color(0xFFEF4444);
  static const dangerDim = Color(0xFF7F1D1D);
  static const info = Color(0xFF06B6D4);
  static const infoDim = Color(0xFF164E63);

  // ─── Text ───
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  // ─── Status chip colors (AD-028 — centralized, never hardcode) ───
  static Color statusColor(String status) => switch (status.toLowerCase()) {
        'active' || 'approved' || 'completed' || 'fully_issued' => success,
        'draft' || 'planning' => textMuted,
        'submitted' || 'pending' || 'ordered' => warning,
        'partially_issued' || 'partially_received' => info,
        'on_hold' || 'rejected' => danger,
        'closed' => textSecondary,
        _ => textMuted,
      };

  /// Dim background for status badges
  static Color statusDimColor(String status) => switch (status.toLowerCase()) {
        'active' || 'approved' || 'completed' || 'fully_issued' => successDim,
        'draft' || 'planning' => const Color(0xFF1E293B),
        'submitted' || 'pending' || 'ordered' => warningDim,
        'partially_issued' || 'partially_received' => infoDim,
        'on_hold' || 'rejected' => dangerDim,
        'closed' => const Color(0xFF1E293B),
        _ => const Color(0xFF1E293B),
      };
}
