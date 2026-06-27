import 'package:intl/intl.dart';

/// Indian Rupee currency formatting (AD-027).
/// Full format: ₹12,50,000.00 (Indian grouping: ##,##,##0)
/// Compact: ₹12.5L for dashboard KPIs
extension CurrencyFormat on num {
  /// Full format: ₹12,50,000.00
  String get inr => '₹${NumberFormat('#,##,##0.00', 'en_IN').format(this)}';

  /// Integer format: ₹12,50,000
  String get inrInt => '₹${NumberFormat('#,##,##0', 'en_IN').format(this)}';

  /// Compact format: ₹12.5L, ₹1.2Cr
  String get inrCompact =>
      '₹${NumberFormat.compact(locale: 'en_IN').format(this)}';
}
