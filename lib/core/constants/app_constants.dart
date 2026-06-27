/// Application constants, enums, and configuration values.
/// Thresholds are defaults — runtime values come from app_settings table.
class AppConstants {
  AppConstants._();

  // ─── Roles (matches auth.users.raw_app_meta_data->>'role') ───
  static const roleAdmin = 'admin';
  static const roleOwner = 'owner';
  static const roleEngineer = 'engineer';
  static const roleStore = 'store';
  static const rolePurchase = 'purchase';

  static const allRoles = [
    roleAdmin,
    roleOwner,
    roleEngineer,
    roleStore,
    rolePurchase,
  ];

  // ─── Animation Durations (UI_SPEC.md — 200-300ms only) ───
  static const animDurationFast = Duration(milliseconds: 200);
  static const animDurationNormal = Duration(milliseconds: 300);

  // ─── Responsive Breakpoints ───
  static const breakpointMobile = 600.0;
  static const breakpointTablet = 900.0;
  static const breakpointDesktop = 1200.0;

  // ─── Default Thresholds (AD-022 — overridden by app_settings) ───
  static const defaultPoApprovalThreshold = 100000.0;
  static const defaultPrApprovalThreshold = 50000.0;
  static const defaultWastageAlertPct = 5.0;
  static const defaultBoqOverrunPct = 80.0;

  // ─── Pagination ───
  static const defaultPageSize = 20;

  // ─── Date Formats ───
  static const dateFormatDisplay = 'dd MMM yyyy';
  static const dateFormatCompact = 'dd/MM/yy';
  static const dateTimeFormatDisplay = 'dd MMM yyyy HH:mm';
}

/// Project status values and valid transitions
class ProjectStatus {
  static const planning = 'planning';
  static const active = 'active';
  static const onHold = 'on_hold';
  static const completed = 'completed';
  static const closed = 'closed';
}

/// Material Request status values
class MrStatus {
  static const draft = 'draft';
  static const submitted = 'submitted';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const partiallyIssued = 'partially_issued';
  static const fullyIssued = 'fully_issued';
  static const closed = 'closed';
}

/// Priority levels
class Priority {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';
  static const urgent = 'urgent';
}
