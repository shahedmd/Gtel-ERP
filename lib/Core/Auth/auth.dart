import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ActivityLogger/activity_logger.dart';
import '../Services/session_controller.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  RxBool isLoading = false.obs;

  // এই দুইটা flag দিয়ে double fire আটকাবো
  bool _done = false;
  bool _busy = false;

  @override
  void onReady() {
    super.onReady();

    _auth.authStateChanges().listen((User? user) async {
      if (_done || _busy) return; // double fire আটকাও
      _done = true;

      if (user != null) {
        await _loadAndGo(user.uid);
      } else {
        Get.offAllNamed('/');
      }
    });
  }

  Future<void> _loadAndGo(String uid) async {
    _busy = true;
    final session = Get.find<SessionController>();
    final allowed = await session.loadSession(uid);

    if (!allowed) {
      await _auth.signOut();
      Get.offAllNamed('/');
      _busy = false;
      return;
    }

    Get.offAllNamed('/home');
    _busy = false;
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

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

      _done = false;
      _busy = false;

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
      final session = Get.find<SessionController>();
      await Get.find<ActivityLogger>().logLogout(session.userName);
      session.clearSession();

      _done = false;
      _busy = false;

      await _auth.signOut();
      Get.offAllNamed('/');
    } catch (e) {
      Get.snackbar("Logout Error", e.toString());
    } finally {
      isLoading.value = false;
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
        return 'Invalid email or password.';
      case 'network-request-failed':
        return 'Network error.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'An unexpected error occurred.';
    }
  }
}