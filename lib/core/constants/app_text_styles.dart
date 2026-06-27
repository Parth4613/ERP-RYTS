import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography tokens from UI_SPEC.md.
/// Every text style used across the ERP is defined here.
class AppTextStyles {
  AppTextStyles._();

  // ─── KPI values on dashboard ───
  static const kpiValue = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  // ─── Page titles ───
  static const pageTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // ─── Section headers ───
  static const sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );

  // ─── Body text ───
  static const body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  // ─── Table cells ───
  static const tableCell = TextStyle(
    fontSize: 13,
    color: AppColors.textPrimary,
  );

  static const tableHeader = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );

  // ─── Currency (₹ amounts) ───
  static const currency = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ─── Form labels ───
  static const formLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // ─── Chip text ───
  static const chipText = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
}
