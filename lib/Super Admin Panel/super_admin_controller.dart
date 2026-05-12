import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Core%20Utils/app_logger.dart';
import '../Menubar and Navigation/app_pages.dart';
import '../Permission/permission_controller.dart';
import '../Permission/permission_model.dart';

class SuperAdminController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final allUsers = <UserModel>[].obs;
  final activityLogs = <ActivityLogModel>[].obs;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final isLogLoading = false.obs;
  final searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAllUsers();
    fetchActivityLogs();
  }

  Future<void> fetchAllUsers() async {
    try {
      isLoading.value = true;

      final snapshot = await _db.collection('users').get();

      final users =
          snapshot.docs
              .map((doc) => UserModel.fromMap(doc.id, doc.data()))
              .toList();

      users.sort((a, b) => a.email.compareTo(b.email));
      allUsers.assignAll(users);
    } catch (e) {
      AppLogger.e('fetchAllUsers error: $e');
      _showError('Failed to load users');
    } finally {
      isLoading.value = false;
    }
  }

  List<UserModel> get filteredUsers {
    final q = searchQuery.value.trim().toLowerCase();

    if (q.isEmpty) return allUsers;

    return allUsers.where((user) {
      return user.email.toLowerCase().contains(q) ||
          user.displayName.toLowerCase().contains(q) ||
          roleToString(user.role).toLowerCase().contains(q);
    }).toList();
  }

  Future<void> createUser({
    required String uid,
    required String email,
    required String displayName,
    required UserRole role,
  }) async {
    try {
      isSaving.value = true;

      await _db.collection('users').doc(uid).set({
        'email': email.trim(),
        'displayName': displayName.trim(),
        'role': roleToString(role),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'permissions': _defaultPermissionsForNewUser(),
      }, SetOptions(merge: true));

      await fetchAllUsers();

      await logActivity(
        action: 'CREATE_USER',
        module: 'User Management',
        details: 'Created user: $email | role: ${roleToString(role)}',
      );

      _showSuccess('User created successfully');
    } catch (e) {
      AppLogger.e('createUser error: $e');
      _showError('Failed to create user');
    } finally {
      isSaving.value = false;
    }
  }

  Map<String, dynamic> _defaultPermissionsForNewUser() {
    return {
      for (final route in allRoutes) route: RoutePermission.noAccess().toMap(),
    };
  }

  Map<String, bool> _allEnabledActionsForRoute(String route) {
    final actions = actionLabelsForRoute(route);
    return actions.map((key, value) => MapEntry(key, true));
  }

  List<String> get allRoutes => AppRouteRegistry.permissionRouteNames;

  String routeDisplayName(String route) {
    return AppRouteRegistry.routeDisplayName(route);
  }

  Map<String, String> actionLabelsForRoute(String route) {
    return AppRouteRegistry.actionLabelsForRoute(route);
  }




  Future<void> toggleUserStatus(UserModel user) async {
    if (user.isSuperAdmin) {
      _showError('Super Admin status cannot be changed');
      return;
    }

    try {
      final newStatus = !user.isActive;

      await _db.collection('users').doc(user.uid).update({
        'isActive': newStatus,
      });

      _replaceUser(user.copyWith(isActive: newStatus));

      await logActivity(
        action: newStatus ? 'ENABLE_USER' : 'DISABLE_USER',
        module: 'User Management',
        details: '${newStatus ? "Enabled" : "Disabled"}: ${user.email}',
      );

      _showSuccess('User ${newStatus ? "enabled" : "disabled"}');
    } catch (e) {
      AppLogger.e('toggleUserStatus error: $e');
      _showError('Failed to update user status');
    }
  }

  Future<void> changeUserRole(UserModel user, UserRole newRole) async {
    if (user.isSuperAdmin) {
      _showError('Super Admin role cannot be changed here');
      return;
    }

    try {
      await _db.collection('users').doc(user.uid).update({
        'role': roleToString(newRole),
      });

      _replaceUser(user.copyWith(role: newRole));

      await logActivity(
        action: 'CHANGE_ROLE',
        module: 'User Management',
        details:
            '${user.email}: ${roleToString(user.role)} to ${roleToString(newRole)}',
      );

      _showSuccess('Role updated');
    } catch (e) {
      AppLogger.e('changeUserRole error: $e');
      _showError('Failed to update role');
    }
  }

  Future<void> deleteUser(UserModel user) async {
    if (user.isSuperAdmin) {
      _showError('Super Admin cannot be deleted');
      return;
    }

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete "${user.displayName}"?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.collection('users').doc(user.uid).delete();

      allUsers.removeWhere((u) => u.uid == user.uid);

      await logActivity(
        action: 'DELETE_USER',
        module: 'User Management',
        details: 'Deleted: ${user.email}',
      );

      _showSuccess('User deleted');
    } catch (e) {
      AppLogger.e('deleteUser error: $e');
      _showError('Failed to delete user');
    }
  }

  Future<void> togglePermission({
    required UserModel user,
    required String route,
    required String permType,
  }) async {
    if (user.isSuperAdmin) return;

    try {
      final current = user.permissions[route] ?? RoutePermission.noAccess();

      final updated = current.copyWith(
        canView: permType == 'canView' ? !current.canView : current.canView,
        canEdit: permType == 'canEdit' ? !current.canEdit : current.canEdit,
        canDelete:
            permType == 'canDelete' ? !current.canDelete : current.canDelete,
        canCreate:
            permType == 'canCreate' ? !current.canCreate : current.canCreate,
      );

      await _saveUserPermission(user: user, route: route, permission: updated);
    } catch (e) {
      AppLogger.e('togglePermission error: $e');
      _showError('Failed to update permission');
    }
  }

  Future<void> toggleActionPermission({
    required UserModel user,
    required String route,
    required String actionKey,
  }) async {
    if (user.isSuperAdmin) return;

    try {
      final current = user.permissions[route] ?? RoutePermission.noAccess();
      final currentValue = current.actions[actionKey] == true;

      final updated = current.setAction(actionKey, !currentValue);

      await _saveUserPermission(user: user, route: route, permission: updated);
    } catch (e) {
      AppLogger.e('toggleActionPermission error: $e');
      _showError('Failed to update action permission');
    }
  }

  Future<void> grantAllPermissions(UserModel user) async {
    if (user.isSuperAdmin) return;

    try {
      isSaving.value = true;

      final permissions = {
        for (final route in allRoutes)
          route:
              RoutePermission.fullAccess()
                  .copyWith(actions: _allEnabledActionsForRoute(route))
                  .toMap(),
      };

      await _db.collection('users').doc(user.uid).update({
        'permissions': permissions,
      });

      await fetchAllUsers();

      await logActivity(
        action: 'GRANT_ALL',
        module: 'Permissions',
        details: 'Granted all permissions to ${user.email}',
      );

      _showSuccess('All permissions granted');
    } catch (e) {
      AppLogger.e('grantAllPermissions error: $e');
      _showError('Failed to grant permissions');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> revokeAllPermissions(UserModel user) async {
    if (user.isSuperAdmin) return;

    try {
      isSaving.value = true;

      final permissions = {
        for (final route in allRoutes)
          route: RoutePermission.noAccess().toMap(),
      };

      await _db.collection('users').doc(user.uid).update({
        'permissions': permissions,
      });

      await fetchAllUsers();

      await logActivity(
        action: 'REVOKE_ALL',
        module: 'Permissions',
        details: 'Revoked all permissions from ${user.email}',
      );

      _showSuccess('All permissions revoked');
    } catch (e) {
      AppLogger.e('revokeAllPermissions error: $e');
      _showError('Failed to revoke permissions');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _saveUserPermission({
    required UserModel user,
    required String route,
    required RoutePermission permission,
  }) async {
    final updatedPermissions = Map<String, RoutePermission>.from(
      user.permissions,
    );

    updatedPermissions[route] = permission;

    await _db.collection('users').doc(user.uid).update({
      'permissions': updatedPermissions.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
    });

    _replaceUser(user.copyWith(permissions: updatedPermissions));
  }

  void _replaceUser(UserModel updatedUser) {
    final index = allUsers.indexWhere((u) => u.uid == updatedUser.uid);
    if (index == -1) return;
    allUsers[index] = updatedUser;
  }

  Future<void> fetchActivityLogs() async {
    try {
      isLogLoading.value = true;

      final snapshot =
          await _db
              .collection('activity_logs')
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();

      activityLogs.assignAll(
        snapshot.docs.map((doc) {
          return ActivityLogModel.fromMap(doc.id, doc.data());
        }).toList(),
      );
    } catch (e) {
      AppLogger.e('fetchActivityLogs error: $e');
    } finally {
      isLogLoading.value = false;
    }
  }

  Future<void> logActivity({
    required String action,
    required String module,
    required String details,
  }) async {
    try {
      final permissionController = Get.find<PermissionController>();

      await _db.collection('activity_logs').add({
        'userEmail': permissionController.userEmail,
        'userName': permissionController.userName,
        'action': action,
        'module': module,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.e('logActivity error: $e');
    }
  }

  String roleToString(UserRole role) {
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

  void _showSuccess(String message) {
    Get.snackbar(
      'Success',
      message,
      backgroundColor: Colors.green.shade600,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
    );
  }

  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
    );
  }
}

class ActivityLogModel {
  final String id;
  final String userEmail;
  final String userName;
  final String action;
  final String module;
  final String details;
  final DateTime? timestamp;

  const ActivityLogModel({
    required this.id,
    required this.userEmail,
    required this.userName,
    required this.action,
    required this.module,
    required this.details,
    this.timestamp,
  });

  factory ActivityLogModel.fromMap(String id, Map<String, dynamic> map) {
    return ActivityLogModel(
      id: id,
      userEmail: map['userEmail']?.toString() ?? '',
      userName: map['userName']?.toString() ?? '',
      action: map['action']?.toString() ?? '',
      module: map['module']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}
