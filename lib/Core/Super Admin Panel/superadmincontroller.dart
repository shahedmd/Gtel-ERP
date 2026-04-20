// lib/Core/SuperAdmin/superadmin_controller.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/app_pages.dart';

import 'package:gtel_erp/Core/Core%20Utils/app_logger.dart';

import '../Permission/permission_controller.dart';
import '../Permission/permission_model.dart';

class SuperAdminController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxList<UserModel> allUsers = <UserModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString searchQuery = ''.obs;
  final RxList<ActivityLogModel> activityLogs = <ActivityLogModel>[].obs;
  final RxBool isLogLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAllUsers();
    fetchActivityLogs();
  }

  // ─────────────────────────────────────────────────────────────
  // USER MANAGEMENT
  // ─────────────────────────────────────────────────────────────

  Future<void> fetchAllUsers() async {
    try {
      isLoading.value = true;
      final snapshot = await _db.collection('users').get();
      allUsers.value =
          snapshot.docs
              .map((doc) => UserModel.fromMap(doc.id, doc.data()))
              .toList();
    } catch (e) {
      AppLogger.e('fetchAllUsers error: $e');
      _showError('Failed to load users');
    } finally {
      isLoading.value = false;
    }
  }

  List<UserModel> get filteredUsers {
    if (searchQuery.value.isEmpty) return allUsers;
    final q = searchQuery.value.toLowerCase();
    return allUsers
        .where(
          (u) =>
              u.email.toLowerCase().contains(q) ||
              u.displayName.toLowerCase().contains(q),
        )
        .toList();
  }

  // Firestore-এ user document create করো
  // NOTE: Firebase Auth user create করতে হলে Render server লাগবে
  // এখন শুধু Firestore document create হবে, existing Auth user-এর জন্য
  Future<void> createUser({
    required String uid,
    required String email,
    required String displayName,
    required UserRole role,
  }) async {
    try {
      isSaving.value = true;

      final defaultPerms = {
        for (final route in allRoutes)
          route: RoutePermission.viewOnly().toMap(),
      };

      await _db.collection('users').doc(uid).set({
        'email': email,
        'displayName': displayName,
        'role': roleToString(role),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'permissions': defaultPerms,
      });

      await fetchAllUsers();

      await logActivity(
        action: 'CREATE_USER',
        module: 'User Management',
        details: 'Created user: $email | role: ${roleToString(role)}',
      );

      _showSuccess('User created successfully');
    } catch (e) {
      AppLogger.e('createUser error: $e');
      _showError('Failed to create user. Check UID is valid.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> toggleUserStatus(UserModel user) async {
    try {
      final newStatus = !user.isActive;
      await _db.collection('users').doc(user.uid).update({
        'isActive': newStatus,
      });

      final i = allUsers.indexWhere((u) => u.uid == user.uid);
      if (i != -1) {
        allUsers[i] = UserModel(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          role: user.role,
          isActive: newStatus,
          permissions: user.permissions,
        );
      }

      await logActivity(
        action: newStatus ? 'ENABLE_USER' : 'DISABLE_USER',
        module: 'User Management',
        details: '${newStatus ? "Enabled" : "Disabled"}: ${user.email}',
      );

      _showSuccess('User ${newStatus ? "enabled" : "disabled"}');
    } catch (e) {
      _showError('Failed to update user status');
    }
  }

  Future<void> changeUserRole(UserModel user, UserRole newRole) async {
    try {
      await _db.collection('users').doc(user.uid).update({
        'role': roleToString(newRole),
      });

      final i = allUsers.indexWhere((u) => u.uid == user.uid);
      if (i != -1) {
        allUsers[i] = UserModel(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          role: newRole,
          isActive: user.isActive,
          permissions: user.permissions,
        );
      }

      await logActivity(
        action: 'CHANGE_ROLE',
        module: 'User Management',
        details:
            '${user.email}: ${roleToString(user.role)} → ${roleToString(newRole)}',
      );

      _showSuccess('Role updated');
    } catch (e) {
      _showError('Failed to update role');
    }
  }

  Future<void> deleteUser(UserModel user) async {
    final confirm = await Get.defaultDialog<bool>(
      title: 'Delete User',
      middleText: 'Delete "${user.displayName}"?\nThis cannot be undone.',
      textConfirm: 'Delete',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      onConfirm: () => Get.back(result: true),
      onCancel: () => Get.back(result: false),
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
      _showError('Failed to delete user');
    }
  }

  Future<void> togglePermission({
    required UserModel user,
    required String route,
    required String permType,
  }) async {
    try {
      final i = allUsers.indexWhere((u) => u.uid == user.uid);
      if (i == -1) return;

      // current permission নাও
      final current =
          allUsers[i].permissions[route] ?? RoutePermission.noAccess();

      // কোন field toggle হবে সেটা বের করো
      final updatedPerm = RoutePermission(
        canView: permType == 'canView' ? !current.canView : current.canView,
        canEdit: permType == 'canEdit' ? !current.canEdit : current.canEdit,
        canDelete:
            permType == 'canDelete' ? !current.canDelete : current.canDelete,
        canCreate:
            permType == 'canCreate' ? !current.canCreate : current.canCreate,
      );

      // পুরো permissions map বানাও
      final updatedPerms = Map<String, RoutePermission>.from(
        allUsers[i].permissions,
      );
      updatedPerms[route] = updatedPerm;

      // Firestore-এ পুরো permissions map একসাথে save করো
      // slash আছে বলে dot notation কাজ করে না
      // তাই পুরো map replace করতে হবে
      await _db.collection('users').doc(user.uid).update({
        'permissions': updatedPerms.map((k, v) => MapEntry(k, v.toMap())),
      });

      // Local state update
      allUsers[i] = UserModel(
        uid: allUsers[i].uid,
        email: allUsers[i].email,
        displayName: allUsers[i].displayName,
        role: allUsers[i].role,
        isActive: allUsers[i].isActive,
        permissions: updatedPerms,
      );
    } catch (e) {
      AppLogger.e('togglePermission error: $e');
      _showError('Failed to update permission');
    }
  }

  Future<void> grantAllPermissions(UserModel user) async {
    try {
      isSaving.value = true;
      final fullPerms = {
        for (final r in allRoutes) r: RoutePermission.fullAccess().toMap(),
      };
      await _db.collection('users').doc(user.uid).update({
        'permissions': fullPerms,
      });
      await fetchAllUsers();
      await logActivity(
        action: 'GRANT_ALL',
        module: 'Permissions',
        details: 'Granted all permissions to ${user.email}',
      );
      _showSuccess('All permissions granted');
    } catch (e) {
      _showError('Failed to grant permissions');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> revokeAllPermissions(UserModel user) async {
    try {
      isSaving.value = true;
      final noPerms = {
        for (final r in allRoutes) r: RoutePermission.noAccess().toMap(),
      };
      await _db.collection('users').doc(user.uid).update({
        'permissions': noPerms,
      });
      await fetchAllUsers();
      await logActivity(
        action: 'REVOKE_ALL',
        module: 'Permissions',
        details: 'Revoked all permissions from ${user.email}',
      );
      _showSuccess('All permissions revoked');
    } catch (e) {
      _showError('Failed to revoke permissions');
    } finally {
      isSaving.value = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ACTIVITY LOG
  // ─────────────────────────────────────────────────────────────

  Future<void> fetchActivityLogs() async {
    try {
      isLogLoading.value = true;
      final snapshot =
          await _db
              .collection('activity_logs')
              .orderBy('timestamp', descending: true)
              .limit(100)
              .get();

      activityLogs.value =
          snapshot.docs
              .map((doc) => ActivityLogModel.fromMap(doc.id, doc.data()))
              .toList();
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
      final permCtrl = Get.find<PermissionController>();
      await _db.collection('activity_logs').add({
        'userEmail': permCtrl.userEmail,
        'userName': permCtrl.userName,
        'action': action,
        'module': module,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.e('logActivity error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  List<String> get allRoutes => [
    Routes.dashboard,
    Routes.debtor,
    Routes.dailyexpenses,
    Routes.monthlyexpense,
    Routes.dailysales,
    Routes.monthlysalespage,
    Routes.stock,
    Routes.profitloss,
    Routes.staff,
    Routes.liveorder,
    Routes.cash,
    Routes.service,
    Routes.salereturn,
    Routes.shipment,
    Routes.conditionpage,
    Routes.vendor,
    Routes.overviewaccount,
    Routes.customeroverview,
    Routes.staffsalesreport,
    Routes.productoverview,
    Routes.purchase,
    Routes.orderlist,
    Routes.localpurchase,
  ];

  String routeDisplayName(String route) {
    const names = {
      Routes.dashboard: 'Daily Ledger',
      Routes.debtor: 'Debtor Account',
      Routes.dailyexpenses: 'Daily Expenses',
      Routes.monthlyexpense: 'Monthly Expenses',
      Routes.dailysales: 'Daily Sales',
      Routes.monthlysalespage: 'Monthly Sales',
      Routes.stock: 'Stock Management',
      Routes.profitloss: 'Profit & Loss',
      Routes.staff: 'Staff Members',
      Routes.liveorder: 'Live Orders',
      Routes.cash: 'Cash Drawer',
      Routes.service: 'Service Products',
      Routes.salereturn: 'Sale Return',
      Routes.shipment: 'Shipment',
      Routes.conditionpage: 'Condition Sale',
      Routes.vendor: 'Vendor',
      Routes.overviewaccount: 'Overview Dashboard',
      Routes.customeroverview: 'Customer Overview',
      Routes.staffsalesreport: 'Staff Sales Report',
      Routes.productoverview: 'Product Overview',
      Routes.purchase: 'Purchase History',
      Routes.orderlist: 'Order List',
      Routes.localpurchase: 'Local Purchase',
    };
    return names[route] ?? route;
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

  void _showSuccess(String msg) => Get.snackbar(
    'Success',
    msg,
    backgroundColor: Colors.green.withValues(alpha: 0.85),
    colorText: Colors.white,
    snackPosition: SnackPosition.TOP,
    duration: const Duration(seconds: 2),
    margin: const EdgeInsets.all(16),
  );

  void _showError(String msg) => Get.snackbar(
    'Error',
    msg,
    backgroundColor: Colors.redAccent,
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 3),
    margin: const EdgeInsets.all(16),
  );
}

// Activity Log Model
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
      userEmail: map['userEmail'] ?? '',
      userName: map['userName'] ?? '',
      action: map['action'] ?? '',
      module: map['module'] ?? '',
      details: map['details'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}
