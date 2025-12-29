// ignore_for_file: deprecated_member_use

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Web Screen/homepage.dart'; // Adjust path to your AdminHomepage

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  RxBool isLoading = false.obs;

  // Professional Error Handler
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

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Success: Clear fields and navigate
      Get.offAll(() => const AdminHomepage());

      Get.snackbar(
        "Welcome Back",
        "Successfully logged into G-Tel ERP",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.withOpacity(0.7),
        colorText: Colors.white,
        maxWidth: 400,
      );
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Errors professionally
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

  void logout() async {
    await _auth.signOut();
    Get.offAllNamed('/login'); // Make sure to define this route in main.dart
  }
}
