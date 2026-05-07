import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Core%20Utils/app_logger.dart';

import 'permission_model.dart';

class PermissionController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final currentUser = Rx<UserModel?>(null);
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    reloadUser();
  }

  Future<void> reloadUser() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      clearUser();
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = '';

      final doc = await _db.collection('users').doc(firebaseUser.uid).get();

      if (!doc.exists || doc.data() == null) {
        currentUser.value = _defaultViewer(firebaseUser);
      } else {
        currentUser.value = UserModel.fromMap(firebaseUser.uid, doc.data()!);
      }

      AppLogger.i(
        'Permission loaded: ${currentUser.value?.email} | ${roleDisplayName}',
      );
    } catch (e) {
      errorMessage.value = e.toString();
      AppLogger.e('Permission load failed: $e');
    } finally {
      isLoading.value = false;
    }
  }

  UserModel _defaultViewer(User firebaseUser) {
    return UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? 'User',
      role: UserRole.viewer,
      isActive: true,
      permissions: const {},
    );
  }

  void clearUser() {
    currentUser.value = null;
    isLoading.value = false;
    errorMessage.value = '';
  }

  bool get isLoggedIn => _auth.currentUser != null;
  bool get isActive => currentUser.value?.isActive == true;
  bool get isSuperAdmin => currentUser.value?.isSuperAdmin == true;
  bool get isAdmin => currentUser.value?.isAdmin == true;

  RoutePermission permissionFor(String route) {
    if (isSuperAdmin) return RoutePermission.fullAccess();
    return currentUser.value?.permissions[route] ?? RoutePermission.noAccess();
  }

  bool canView(String route) {
    if (isSuperAdmin) return true;
    if (!isActive) return false;
    return permissionFor(route).canView;
  }

  bool canCreate(String route) {
    if (isSuperAdmin) return true;
    if (!isActive) return false;
    return permissionFor(route).canCreate;
  }

  bool canEdit(String route) {
    if (isSuperAdmin) return true;
    if (!isActive) return false;
    return permissionFor(route).canEdit;
  }

  bool canDelete(String route) {
    if (isSuperAdmin) return true;
    if (!isActive) return false;
    return permissionFor(route).canDelete;
  }

  bool canAction(String route, String actionKey) {
    if (isSuperAdmin) return true;
    if (!isActive) return false;
    return permissionFor(route).canAction(actionKey);
  }

  Future<void> updateUserRoutePermission({
    required UserModel user,
    required String route,
    required RoutePermission permission,
  }) async {
    if (!isSuperAdmin) {
      throw Exception('Only Super Admin can update permissions.');
    }

    final newPermissions = {
      ...user.permissions,
      route: permission,
    };

    await _db.collection('users').doc(user.uid).set(
      {
        'permissions': newPermissions.map(
          (key, value) => MapEntry(key, value.toMap()),
        ),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateUserActionPermission({
    required UserModel user,
    required String route,
    required String actionKey,
    required bool value,
  }) async {
    if (!isSuperAdmin) {
      throw Exception('Only Super Admin can update action permissions.');
    }

    final oldPermission =
        user.permissions[route] ?? RoutePermission.noAccess();

    final newPermission = oldPermission.setAction(actionKey, value);

    await updateUserRoutePermission(
      user: user,
      route: route,
      permission: newPermission,
    );
  }

  String get userEmail => currentUser.value?.email ?? '';
  String get userName => currentUser.value?.displayName ?? '';
  UserRole get userRole => currentUser.value?.role ?? UserRole.viewer;

  String get roleDisplayName {
    switch (userRole) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.staff:
        return 'Staff';
      case UserRole.viewer:
        return 'Viewer';
    }
  }

  Color get roleBadgeColor {
    switch (userRole) {
      case UserRole.superAdmin:
        return Colors.deepPurple;
      case UserRole.admin:
        return Colors.teal;
      case UserRole.staff:
        return Colors.blue;
      case UserRole.viewer:
        return Colors.grey;
    }
  }
}
