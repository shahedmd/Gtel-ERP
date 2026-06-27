import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/ActivityLogger/activity_logger.dart';
import 'package:gtel_erp/firebase_options.dart';

class SuperAdminController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Observables ───────────────────────────────────────────────────────────
  var isCreating = false.obs;
  var isSavingPermissions = false.obs;

  static const Map<String, String> moduleLabels = {
    'new_order': 'New Order (Live Order)',
    'daily_sales': 'Daily Sales',
    'monthly_sales': 'Monthly Sales',
    'condition_sale': 'Condition Sale',
    'sale_return': 'Sale Return',
    'staff_overview': 'Staff Sales Overview',
    'product_overview': 'Product Overview',
    'stock': 'Stock Management',
    'service': 'Service Products',
    'shipment': 'Shipment',
    'order_list': 'China Order List',
    'local_purchase': 'Local Purchase',
    'purchase_history': 'Local Purchase History',
    'daily_expenses': 'Daily Expenses',
    'monthly_expenses': 'Monthly Expenses',
    'staff': 'Staff Members',
    'cash': 'Cash Drawer',
    'vendor': 'Vendor',
    'debtor': 'Debtor/Agent',
    'customer': 'G-TEL Customer',
    'profit_loss': 'Profit & Loss',
    'daily_ledger': 'Daily Ledger',
    'overview': 'Overview Dashboard',
  };

  static const List<String> permissionActions = [
    'view',
    'create',
    'edit',
    'delete',
    'export',
    'sync',
    'report'
  ];

  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phone, // ← নতুন
  }) async {
    if (name.trim().isEmpty) {
      Get.snackbar(
        'Missing Info',
        'Please enter a name.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    if (email.trim().isEmpty) {
      Get.snackbar(
        'Missing Info',
        'Please enter an email.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    if (phone.trim().isEmpty) {
      Get.snackbar(
        'Missing Info',
        'Please enter a phone number.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }
    if (password.trim().length < 6) {
      Get.snackbar(
        'Weak Password',
        'Password must be at least 6 characters.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isCreating.value = true;

      FirebaseApp secondaryApp;
      try {
        secondaryApp = await Firebase.initializeApp(
          name: 'secondary',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (_) {
        secondaryApp = Firebase.app('secondary');
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final result = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // ── নতুন: displayName set করো "Name | Phone" format এ ───────────────
      await result.user!.updateDisplayName('${name.trim()} | ${phone.trim()}');

      final String uid = result.user!.uid;
      await secondaryAuth.signOut();

      await _db.collection('users').doc(uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(), // ← Firestore এও রাখো
        'role': role,
        'isActive': true,
        'permissions': {},
        'createdAt': FieldValue.serverTimestamp(),
      });

      Get.find<ActivityLogger>().logCreate(
        LogModule.admin,
        'New user created: ${name.trim()} ($role)',
        targetId: uid,
      );

      Get.back();
      Get.snackbar(
        'Success',
        '${name.trim()} has been added as $role',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Could not create user.';
      if (e.code == 'email-already-in-use') {
        msg = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        msg = 'Password must be at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        msg = 'Invalid email address.';
      }
      Get.snackbar(
        'Error',
        msg,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Something went wrong: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isCreating.value = false;
    }
  }

  // ── 2. LOAD PERMISSIONS ───────────────────────────────────────────────────
  Future<Map<String, Map<String, bool>>> loadPermissions(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final rawPerms = data['permissions'] as Map<String, dynamic>? ?? {};

      final Map<String, Map<String, bool>> perms = {};

      for (final module in moduleLabels.keys) {
        perms[module] = {};
        for (final action in permissionActions) {
          final val =
              (rawPerms[module] as Map<String, dynamic>?)?[action] as bool? ??
              false;
          perms[module]![action] = val;
        }
      }
      return perms;
    } catch (e) {
      // Default সব false
      final Map<String, Map<String, bool>> perms = {};
      for (final module in moduleLabels.keys) {
        perms[module] = {for (final a in permissionActions) a: false};
      }
      return perms;
    }
  }

  // ── 3. SAVE PERMISSIONS ───────────────────────────────────────────────────
  Future<void> savePermissions(
    String uid,
    String name,
    Map<String, Map<String, bool>> permissions,
  ) async {
    try {
      isSavingPermissions.value = true;

      // Dart typed map → Firestore compatible map
      final Map<String, dynamic> firestorePerms = {};
      permissions.forEach((module, actions) {
        firestorePerms[module] = Map<String, bool>.from(actions);
      });

      await _db.collection('users').doc(uid).update({
        'permissions': firestorePerms,
      });

      // ── Activity log ──────────────────────────────────────────────────────
      Get.find<ActivityLogger>().logUpdate(
        LogModule.admin,
        'Permissions updated for: $name',
        targetId: uid,
      );

      Get.back();
      Get.snackbar(
        'Saved',
        'Permissions updated for $name',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not save permissions: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isSavingPermissions.value = false;
    }
  }
}
