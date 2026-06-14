import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Utils/app_logger.dart';
import '../../ActivityLogger/activity_logger.dart';
import '../Services/session_controller.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  RxBool isLoading = false.obs;

  @override
  void onReady() {
    super.onReady();

    Future.delayed(const Duration(milliseconds: 500), () async {
      final firebaseUser = _auth.currentUser;

      if (firebaseUser != null) {
        // ── নতুন: Refresh এ session reload করো ──────────────────────────
        final session = Get.find<SessionController>();
        await session.loadSession(firebaseUser.uid);

        AppLogger.i("Existing session found. Navigating to Home Page.");
        Get.offAllNamed('/home');
      }
    });

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

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // ── নতুন: Session load করো ───────────────────────────────────────────
      final session = Get.find<SessionController>();
      final allowed = await session.loadSession(result.user!.uid);

      if (!allowed) {
        await _auth.signOut();
        Get.snackbar(
          "Access Denied",
          "Your account has been deactivated. Contact admin.",
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
        return;
      }

      // ── নতুন: Login log করো ─────────────────────────────────────────────
      Get.find<ActivityLogger>().logLogin(session.userName);

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
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      isLoading.value = true;

      // ── নতুন: Logout log + session clear ────────────────────────────────
      final session = Get.find<SessionController>();
      await Get.find<ActivityLogger>().logLogout(session.userName);
      session.clearSession();

      await _auth.signOut();
      Get.offAllNamed('/');
    } catch (e) {
      Get.snackbar("Logout Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
