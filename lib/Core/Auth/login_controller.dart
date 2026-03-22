import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginController extends GetxController {
  final obscurePassword = true.obs;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void toggleObscurePassword() {
    obscurePassword.value = !obscurePassword.value;
  }
}
