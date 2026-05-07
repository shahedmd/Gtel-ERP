import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Core%20Utils/app_logger.dart';

import '../Permission/permission_controller.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final authUser = Rxn<User>();

  StreamSubscription<User?>? _authSub;

  @override
  void onReady() {
    super.onReady();
    _authSub = _auth.authStateChanges().listen(_handleAuthStateChange);
  }

  @override
  void onClose() {
    _authSub?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<void> _handleAuthStateChange(User? user) async {
    authUser.value = user;

    if (user == null) {
      _clearSessionData();

      if (Get.currentRoute != '/') {
        Get.offAllNamed('/');
      }
      return;
    }

    await _prepareUserSession();

    if (Get.currentRoute == '/') {
      Get.offAllNamed('/home');
    }
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (isLoading.value) return;

    if (email.isEmpty || password.isEmpty) {
      _showSnackbar(
        title: 'Missing Information',
        message: 'Please enter your email and password.',
        isError: true,
      );
      return;
    }

    try {
      isLoading.value = true;

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      _showSnackbar(
        title: 'Welcome Back',
        message: 'Successfully logged into G-Tel ERP.',
        isError: false,
      );
    } on FirebaseAuthException catch (e) {
      _showSnackbar(
        title: 'Login Failed',
        message: _authErrorMessage(e.code),
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

  Future<void> logout() async {
    if (isLoading.value) return;

    final shouldLogout = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out of G-Tel ERP?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      isLoading.value = true;
      await _auth.signOut();

      _showSnackbar(
        title: 'Logged Out',
        message: 'You have been successfully logged out.',
        isError: false,
      );
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

  Future<void> _prepareUserSession() async {
    if (!Get.isRegistered<PermissionController>()) return;

    final permissionController = Get.find<PermissionController>();
    await permissionController.reloadUser();

    if (permissionController.currentUser.value?.isActive == false) {
      await _auth.signOut();

      _showSnackbar(
        title: 'Account Disabled',
        message: 'Your account has been disabled. Contact Super Admin.',
        isError: true,
      );
    }
  }

  void _clearSessionData() {
    clearLoginForm();

    if (Get.isRegistered<PermissionController>()) {
      Get.find<PermissionController>().clearUser();
    }
  }

  void clearLoginForm() {
    emailController.clear();
    passwordController.clear();
    isPasswordVisible.value = false;
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact admin.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password. Please double check.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'operation-not-allowed':
        return 'This login method is not enabled. Contact admin.';
      default:
        AppLogger.e('Unhandled Firebase auth error: $code');
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
      backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
      colorText: Colors.white,
      maxWidth: 420,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
      icon: Icon(
        isError ? Icons.error_outline : Icons.check_circle_outline,
        color: Colors.white,
      ),
    );
  }

  User? get currentFirebaseUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
}
