import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Utils/app_logger.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  RxBool isLoading = false.obs;

  final Rxn<User> _firebaseUser = Rxn<User>();
  User? get user => _firebaseUser.value;

  @override
  void onInit() {
    super.onInit();
    _firebaseUser.bindStream(_auth.authStateChanges());
  }

  @override
  void onReady() {
    super.onReady();
    ever(_firebaseUser, _initialScreen);
  }

  // ==========================================
  // THE TRAFFIC COP (Handles all routing & dialog closing)
  // ==========================================
  void _initialScreen(User? user) {
    // 1. SAFELY CLOSE ANY OPEN LOADING DIALOGS FIRST
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    // 2. ROUTE THE USER
    if (user == null) {
      AppLogger.w("User is not logged in. Navigating to Login Page.");
      // Prevents routing to '/' if we are already on '/'
      if (Get.currentRoute != '/') {
        Get.offAllNamed('/');
      }
    } else {
      AppLogger.i(
        "User is logged in as ${user.email}. Navigating to Home Page.",
      );
      // Prevents routing to '/home' if we are already on '/home'
      if (Get.currentRoute != '/home') {
        Get.offAllNamed('/home');
      }
    }
  }

  String _handleAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
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
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  // ==========================================
  // LOGIN LOGIC
  // ==========================================
  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // This triggers authStateChanges, which triggers _initialScreen
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );


      Get.snackbar(
        "Welcome Back",
        "Successfully logged into G-Tel ERP",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.withValues(alpha: 0.7),
        colorText: Colors.white,
        maxWidth: 400,
      );
    } on FirebaseAuthException catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        "Login Failed",
        _handleAuthError(e.code),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        maxWidth: 400,
        margin: const EdgeInsets.all(20),
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        "Error",
        "Something went wrong. Please try again.",
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================================
  // LOGOUT LOGIC
  // ==========================================
  void logout() async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      await _auth.signOut();
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar("Logout Error", e.toString());
    }
  }
}
