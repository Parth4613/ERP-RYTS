/// User roles in the system
enum UserRole {
  admin,
  engineer,
  store,
  purchase;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.engineer:
        return 'Project Engineer';
      case UserRole.store:
        return 'Store Department';
      case UserRole.purchase:
        return 'Purchase Department';
    }
  }

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => UserRole.engineer,
    );
  }
}

/// Material Request statuses
enum MRStatus {
  pending,
  approved,
  partiallyIssued,
  fullyIssued,
  waitingProcurement,
  completed,
  rejected;

  String get displayName {
    switch (this) {
      case MRStatus.pending:
        return 'Pending';
      case MRStatus.approved:
        return 'Approved';
      case MRStatus.partiallyIssued:
        return 'Partially Issued';
      case MRStatus.fullyIssued:
        return 'Fully Issued';
      case MRStatus.waitingProcurement:
        return 'Waiting Procurement';
      case MRStatus.completed:
        return 'Completed';
      case MRStatus.rejected:
        return 'Rejected';
    }
  }

  static MRStatus fromString(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'partial') return MRStatus.partiallyIssued;
    if (normalized == 'issued') return MRStatus.fullyIssued;
    if (normalized == 'partially_issued') return MRStatus.partiallyIssued;
    if (normalized == 'fully_issued') return MRStatus.fullyIssued;
    if (normalized == 'waiting_procurement') return MRStatus.waitingProcurement;
    return MRStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => MRStatus.pending,
    );
  }

  String get databaseValue {
    switch (this) {
      case MRStatus.partiallyIssued:
        return 'partially_issued';
      case MRStatus.fullyIssued:
        return 'fully_issued';
      case MRStatus.waitingProcurement:
        return 'waiting_procurement';
      default:
        return name;
    }
  }
}

/// Purchase Request statuses
enum PRStatus {
  draft,
  pending,
  approved,
  ordered,
  delivered,
  converted,
  rejected;

  String get displayName {
    switch (this) {
      case PRStatus.draft:
        return 'Draft';
      case PRStatus.pending:
        return 'Pending';
      case PRStatus.approved:
        return 'Approved';
      case PRStatus.ordered:
        return 'Ordered';
      case PRStatus.delivered:
        return 'Delivered';
      case PRStatus.converted:
        return 'Converted to PO';
      case PRStatus.rejected:
        return 'Rejected';
    }
  }

  static PRStatus fromString(String value) {
    return PRStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => PRStatus.pending,
    );
  }
}

/// Purchase Order statuses
enum POStatus {
  draft,
  ordered,
  delivered;

  String get displayName {
    switch (this) {
      case POStatus.draft:
        return 'Draft';
      case POStatus.ordered:
        return 'Ordered';
      case POStatus.delivered:
        return 'Delivered';
    }
  }

  static POStatus fromString(String value) {
    return POStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => POStatus.draft,
    );
  }
}

/// Project statuses
enum ProjectStatus {
  active,
  completed,
  // ignore: constant_identifier_names
  on_hold;

  String get displayName {
    switch (this) {
      case ProjectStatus.active:
        return 'Active';
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.on_hold:
        return 'On Hold';
    }
  }

  static ProjectStatus fromString(String value) {
    return ProjectStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => ProjectStatus.active,
    );
  }
}
