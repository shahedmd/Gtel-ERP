enum UserRole { superAdmin, admin, staff, viewer }

class RoutePermission {
  final bool canView;
  final bool canEdit;
  final bool canDelete;
  final bool canCreate;

  /// Example:
  /// {
  ///   'sale.delete': true,
  ///   'sale.reprint': true,
  ///   'sale.discount': false,
  /// }
  final Map<String, bool> actions;

  const RoutePermission({
    this.canView = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canCreate = false,
    this.actions = const {},
  });

  factory RoutePermission.fromMap(Map<String, dynamic> map) {
    final rawActions = map['actions'] as Map<String, dynamic>? ?? {};

    return RoutePermission(
      canView: map['canView'] == true,
      canEdit: map['canEdit'] == true,
      canDelete: map['canDelete'] == true,
      canCreate: map['canCreate'] == true,
      actions: rawActions.map(
        (key, value) => MapEntry(key, value == true),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'canView': canView,
      'canEdit': canEdit,
      'canDelete': canDelete,
      'canCreate': canCreate,
      'actions': actions,
    };
  }

  RoutePermission copyWith({
    bool? canView,
    bool? canEdit,
    bool? canDelete,
    bool? canCreate,
    Map<String, bool>? actions,
  }) {
    return RoutePermission(
      canView: canView ?? this.canView,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      canCreate: canCreate ?? this.canCreate,
      actions: actions ?? this.actions,
    );
  }

  RoutePermission setAction(String actionKey, bool value) {
    return copyWith(
      actions: {
        ...actions,
        actionKey: value,
      },
    );
  }

  bool canAction(String actionKey) {
    return actions[actionKey] == true;
  }

  factory RoutePermission.fullAccess() {
    return const RoutePermission(
      canView: true,
      canEdit: true,
      canDelete: true,
      canCreate: true,
    );
  }

  factory RoutePermission.viewOnly() {
    return const RoutePermission(
      canView: true,
      canEdit: false,
      canDelete: false,
      canCreate: false,
    );
  }

  factory RoutePermission.noAccess() {
    return const RoutePermission();
  }
}

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final bool isActive;
  final Map<String, RoutePermission> permissions;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.permissions,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    final rawPermissions = map['permissions'] as Map<String, dynamic>? ?? {};

    final permissions = rawPermissions.map(
      (route, value) {
        final permissionMap = Map<String, dynamic>.from(value as Map);
        return MapEntry(route, RoutePermission.fromMap(permissionMap));
      },
    );

    return UserModel(
      uid: uid,
      email: map['email']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      role: _roleFromString(map['role']?.toString()),
      isActive: map['isActive'] != false,
      permissions: permissions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': _roleToString(role),
      'isActive': isActive,
      'permissions': permissions.map(
        (route, permission) => MapEntry(route, permission.toMap()),
      ),
    };
  }

  UserModel copyWith({
    String? email,
    String? displayName,
    UserRole? role,
    bool? isActive,
    Map<String, RoutePermission>? permissions,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
    );
  }

  static UserRole _roleFromString(String? role) {
    switch (role) {
      case 'superadmin':
      case 'superAdmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      default:
        return UserRole.viewer;
    }
  }

  static String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'superadmin';
      case UserRole.admin:
        return 'admin';
      case UserRole.staff:
        return 'staff';
      case UserRole.viewer:
        return 'viewer';
    }
  }

  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;
}
