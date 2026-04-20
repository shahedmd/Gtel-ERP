// lib/Core/Permissions/permission_model.dart

enum UserRole { superAdmin, admin, staff, viewer }

// একটা single page/route-এর permission
class RoutePermission {
  final bool canView;
  final bool canEdit;
  final bool canDelete;
  final bool canCreate;

  const RoutePermission({
    this.canView = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canCreate = false,
  });

  // Firestore থেকে আসা Map convert করবে
  factory RoutePermission.fromMap(Map<String, dynamic> map) {
    return RoutePermission(
      canView: map['canView'] ?? false,
      canEdit: map['canEdit'] ?? false,
      canDelete: map['canDelete'] ?? false,
      canCreate: map['canCreate'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'canView': canView,
    'canEdit': canEdit,
    'canDelete': canDelete,
    'canCreate': canCreate,
  };

  // SuperAdmin-এর জন্য সব true
  factory RoutePermission.fullAccess() => const RoutePermission(
    canView: true,
    canEdit: true,
    canDelete: true,
    canCreate: true,
  );

  // Viewer-এর জন্য শুধু দেখতে পারবে
  factory RoutePermission.viewOnly() => const RoutePermission(
    canView: true,
    canEdit: false,
    canDelete: false,
    canCreate: false,
  );

  // কোনো access নেই
  factory RoutePermission.noAccess() => const RoutePermission();
}

// একজন user-এর পুরো profile
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
    // permissions map convert করো
    final rawPerms = map['permissions'] as Map<String, dynamic>? ?? {};
    final perms = rawPerms.map(
      (route, permMap) => MapEntry(
        route,
        RoutePermission.fromMap(permMap as Map<String, dynamic>),
      ),
    );

    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      role: _roleFromString(map['role']),
      isActive: map['isActive'] ?? true,
      permissions: perms,
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'displayName': displayName,
    'role': _roleToString(role),
    'isActive': isActive,
    'permissions': permissions.map(
      (route, perm) => MapEntry(route, perm.toMap()),
    ),
  };

  static UserRole _roleFromString(String? role) {
    switch (role) {
      case 'superadmin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      case 'viewer':
        return UserRole.viewer;
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