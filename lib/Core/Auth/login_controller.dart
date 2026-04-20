// lib/Core/Auth/login_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginController extends GetxController {
  final obscurePassword = true.obs;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  void toggleObscurePassword() {
    obscurePassword.value = !obscurePassword.value;
  }

  void clearForm() {
    emailController.clear();
    passwordController.clear();
    obscurePassword.value = true;
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}