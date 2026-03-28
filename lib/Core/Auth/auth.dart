import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Utils/app_logger.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  RxBool isLoading = false.obs;

  @override
  void onReady() {
    super.onReady();

    // 1. CHECK ON APP BOOT (Delayed slightly so the screen exists before routing)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_auth.currentUser != null) {
        AppLogger.i("Existing session found. Navigating to Home Page.");
        Get.offAllNamed('/home');
      }
    });

    // 2. PASSIVE BACKGROUND LISTENER
    // (Only used to kick users back to login if their token expires or they are deleted)
    _auth.authStateChanges().listen((User? user) {
      if (user == null && Get.currentRoute != '/') {
        AppLogger.w("Auth state null. Redirecting to Login.");
        Get.offAllNamed('/');
      }
    });
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
      // This will automatically show the spinner INSIDE your button on the UI
      isLoading.value = true;

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // EXPLICIT ROUTING: Guarantees the page changes even if the stream gets cached
      Get.offAllNamed('/home');

      Get.snackbar(
        "Welcome Back",
        "Successfully logged into G-Tel ERP",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.withValues(alpha: 0.7),
        colorText: Colors.white,
        maxWidth: 400,
      );
    } on FirebaseAuthException catch (e) {
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
      Get.snackbar(
        "Error",
        "Something went wrong. Please try again.",
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      // Hides the button spinner
      isLoading.value = false;
    }
  }

  // ==========================================
  // LOGOUT LOGIC
  // ==========================================
  Future<void> logout() async {
    try {
      isLoading.value = true;
      await _auth.signOut();

      // Explicitly route back to login
      Get.offAllNamed('/');
    } catch (e) {
      Get.snackbar("Logout Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}