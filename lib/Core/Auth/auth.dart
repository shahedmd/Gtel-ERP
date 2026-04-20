// lib/Core/Auth/auth.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Core%20Utils/app_logger.dart';
import '../Permission/permission_controller.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RxBool isLoading = false.obs;

  @override
  void onReady() {
    super.onReady();
    _auth.authStateChanges().listen(_handleAuthStateChange);
  }

  Future<void> _handleAuthStateChange(User? user) async {
    if (user == null) {
      if (Get.currentRoute != '/') {
        AppLogger.w('Auth: Session ended. Redirecting to login.');
        _clearAllData();
        Get.offAllNamed('/');
      }
      return;
    }
    if (Get.currentRoute == '/') {
      AppLogger.i('Auth: Session found for ${user.email}. Navigating home.');
      await _navigateToHome();
    }
  }

  Future<void> _navigateToHome() async {
    try {
      Get.offAllNamed('/home');
      await _waitForPermissionsAndLoad();
    } catch (e) {
      AppLogger.e('Auth: Navigation error: $e');
    }
  }

  Future<void> _waitForPermissionsAndLoad() async {
    const maxWait = Duration(seconds: 15);
    const checkInterval = Duration(milliseconds: 150);
    var elapsed = Duration.zero;

    await Future.delayed(const Duration(milliseconds: 200));

    while (!Get.isRegistered<PermissionController>()) {
      if (elapsed >= maxWait) {
        AppLogger.e('Auth: PermissionController never registered. Giving up.');
        return;
      }
      await Future.delayed(checkInterval);
      elapsed += checkInterval;
    }

    final permCtrl = Get.find<PermissionController>();

    if (!permCtrl.isLoading.value && permCtrl.currentUser.value == null) {
      AppLogger.w('Auth: Stale controller detected. Forcing reload.');
      await permCtrl.reloadUser();
    }

   
    elapsed = Duration.zero;
    while (permCtrl.isLoading.value) {
      if (elapsed >= maxWait) {
        AppLogger.w('Auth: Permission load timed out after 15s. Continuing.');
        break;
      }
      await Future.delayed(checkInterval);
      elapsed += checkInterval;
    }

    AppLogger.i(
      'Auth: Ready — ${permCtrl.userEmail} | ${permCtrl.roleDisplayName}',
    );

    // ── STEP 6: Disabled account check ─────────────────────────────────────
    if (permCtrl.currentUser.value?.isActive == false) {
      AppLogger.w('Auth: Account is disabled.');
      await _performLogout();
      _showSnackbar(
        title: 'Account Disabled',
        message: 'Your account has been disabled. Contact Super Admin.',
        isError: true,
      );
    }
  }

  Future<void> login(String email, String password) async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // authStateChanges listener handles navigation automatically.
      // No manual Get.offAllNamed here — avoids double navigation.
      _showSnackbar(
        title: 'Welcome Back',
        message: 'Successfully logged into G-Tel ERP',
        isError: false,
      );
    } on FirebaseAuthException catch (e) {
      _showSnackbar(
        title: 'Login Failed',
        message: _handleAuthError(e.code),
        isError: true,
      );
    } catch (e) {
      AppLogger.e('Login error: $e');
      _showSnackbar(
        title: 'Error',
        message: 'Something went wrong. Please try again.',
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void logout() {
    Get.defaultDialog(
      title: 'Logout',
      middleText: 'Are you sure you want to log out of G-Tel ERP?',
      titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      textConfirm: 'Logout',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: Colors.redAccent,
      cancelTextColor: Colors.black87,
      onConfirm: () async {
        Get.back();
        await _performLogout();
        _showSnackbar(
          title: 'Logged Out',
          message: 'You have been successfully logged out.',
          isError: false,
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      isLoading.value = true;
      _clearAllData(); // delete the controller BEFORE signOut
      await _auth.signOut();
      // authStateChanges fires null → _handleAuthStateChange navigates to '/'
    } catch (e) {
      AppLogger.e('Logout error: $e');
      _showSnackbar(
        title: 'Logout Error',
        message: 'Failed to log out. Please try again.',
        isError: true,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _clearAllData() {
    // ── THE CORE FIX ───────────────────────────────────────────────────────
    // We DELETE the controller entirely instead of just calling clearUser().
    //
    // WHY: clearUser() only sets currentUser=null and isLoading=false but
    // leaves the controller registered in GetX memory. On the next login,
    // GetX finds it already registered and skips creating a new instance,
    // meaning onInit() → _loadCurrentUser() is NEVER called again.
    //
    // By deleting it here, the home route binding creates a fresh instance
    // on the next navigation, onInit runs, and _loadCurrentUser() fires. ✓
    if (Get.isRegistered<PermissionController>()) {
      Get.delete<PermissionController>(force: true);
      AppLogger.i(
        'Auth: PermissionController deleted. Fresh load on next login.',
      );
    }
  }

  String _handleAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact admin.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please double check.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Account temporarily locked. Try again later.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'This login method is not enabled. Contact admin.';
      default:
        AppLogger.e('Unhandled Firebase error code: $code');
        return 'An unexpected error occurred. Please try again.';
    }
  }

  void _showSnackbar({
    required String title,
    required String message,
    required bool isError,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: isError ? SnackPosition.BOTTOM : SnackPosition.TOP,
      backgroundColor:
          isError ? Colors.redAccent : Colors.green.withValues(alpha: 0.85),
      colorText: Colors.white,
      maxWidth: 420,
      margin: const EdgeInsets.all(16),
      icon: Icon(
        isError ? Icons.error_outline : Icons.check_circle_outline,
        color: Colors.white,
      ),
      duration: const Duration(seconds: 3),
    );
  }

  User? get currentFirebaseUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
}