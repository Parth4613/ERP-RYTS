import 'package:intl/intl.dart';

/// Common date formatting helpers.
extension AppDateUtils on DateTime {
  /// Display format: 15 Mar 2024
  String get display => DateFormat('dd MMM yyyy').format(this);

  /// Compact: 15/03/24
  String get compact => DateFormat('dd/MM/yy').format(this);

  /// Full with time: 15 Mar 2024 14:30
  String get displayWithTime => DateFormat('dd MMM yyyy HH:mm').format(this);

  /// Relative time: "2 hours ago", "Yesterday", etc.
  String get relative {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return display;
  }

  /// ISO date only: 2024-03-15
  String get isoDate => DateFormat('yyyy-MM-dd').format(this);
}
