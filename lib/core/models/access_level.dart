/// User access levels for the application
/// High (Admin): Full access, can approve new users, manage all settings
/// Mid (Manager): Can manage devices and automations, limited admin access
/// Low (User): Basic access to view and control assigned devices
enum AccessLevel {
  pending, // New user awaiting approval
  low, // Regular user
  mid, // Manager
  high, // Admin
}

extension AccessLevelExtension on AccessLevel {
  String get displayName {
    switch (this) {
      case AccessLevel.pending:
        return 'Pending Approval';
      case AccessLevel.low:
        return 'User';
      case AccessLevel.mid:
        return 'Manager';
      case AccessLevel.high:
        return 'Admin';
    }
  }

  String get description {
    switch (this) {
      case AccessLevel.pending:
        return 'Awaiting admin approval to access the system';
      case AccessLevel.low:
        return 'Can view and control assigned devices';
      case AccessLevel.mid:
        return 'Can manage devices, automations, and view reports';
      case AccessLevel.high:
        return 'Full system access including user management';
    }
  }

  int get priority {
    switch (this) {
      case AccessLevel.pending:
        return 0;
      case AccessLevel.low:
        return 1;
      case AccessLevel.mid:
        return 2;
      case AccessLevel.high:
        return 3;
    }
  }

  bool get canApproveUsers => this == AccessLevel.high;
  bool get canManageUsers =>
      this == AccessLevel.high || this == AccessLevel.mid;
  bool get canManageDevices => this != AccessLevel.pending;
  bool get canManageAutomations =>
      this == AccessLevel.high || this == AccessLevel.mid;
  bool get canViewReports =>
      this == AccessLevel.high || this == AccessLevel.mid;
  bool get canAccessSettings => this != AccessLevel.pending;
  bool get isApproved => this != AccessLevel.pending;

  static AccessLevel fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'high':
        return AccessLevel.high;
      case 'mid':
        return AccessLevel.mid;
      case 'low':
        return AccessLevel.low;
      case 'pending':
      default:
        return AccessLevel.pending;
    }
  }

  String toStorageString() {
    switch (this) {
      case AccessLevel.pending:
        return 'pending';
      case AccessLevel.low:
        return 'low';
      case AccessLevel.mid:
        return 'mid';
      case AccessLevel.high:
        return 'high';
    }
  }
}
