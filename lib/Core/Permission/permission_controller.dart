// lib/Core/Permission/permission_controller.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Core%20Utils/app_logger.dart';
import 'permission_model.dart';

class PermissionController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);

  final RxBool isLoading = true.obs;

  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      final User? firebaseUser = _auth.currentUser;

      if (firebaseUser == null) {

        AppLogger.w('PermissionController: No Firebase user at load time.');
        isLoading.value = false;
        return;
      }

      AppLogger.i(
        'PermissionController: Loading user for ${firebaseUser.email}',
      );

      final doc = await _db.collection('users').doc(firebaseUser.uid).get();

      if (!doc.exists || doc.data() == null) {
        AppLogger.w(
          'PermissionController: No Firestore doc for ${firebaseUser.uid}. Using viewer default.',
        );
        currentUser.value = _createDefaultViewer(firebaseUser);
      } else {
        currentUser.value = UserModel.fromMap(firebaseUser.uid, doc.data()!);
        AppLogger.i(
          'PermissionController: Loaded ${currentUser.value?.email} | Role: ${currentUser.value?.role}',
        );
      }


      if (currentUser.value?.isActive == false) {
        AppLogger.w('PermissionController: Account is disabled.');

      }
    } catch (e) {
      AppLogger.e('PermissionController: Load error — $e');
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  UserModel _createDefaultViewer(User firebaseUser) {
    return UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName ?? 'User',
      role: UserRole.viewer,
      isActive: true,
      permissions: {},
    );
  }


  Future<void> reloadUser() => _loadCurrentUser();

  void clearUser() {
    currentUser.value = null;
    isLoading.value = false;
    errorMessage.value = '';
    AppLogger.i('PermissionController: User data cleared.');
  }

  // ── Permission getters ───────────────────────────────────────────────────

  bool get isSuperAdmin => currentUser.value?.isSuperAdmin ?? false;
  bool get isAdmin => currentUser.value?.isAdmin ?? false;

  bool canView(String route) {
    if (isSuperAdmin) return true;
    return currentUser.value?.permissions[route]?.canView ?? false;
  }

  bool canEdit(String route) {
    if (isSuperAdmin) return true;
    return currentUser.value?.permissions[route]?.canEdit ?? false;
  }

  bool canDelete(String route) {
    if (isSuperAdmin) return true;
    return currentUser.value?.permissions[route]?.canDelete ?? false;
  }

  bool canCreate(String route) {
    if (isSuperAdmin) return true;
    return currentUser.value?.permissions[route]?.canCreate ?? false;
  }

  // ── Display helpers ──────────────────────────────────────────────────────

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