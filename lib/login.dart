// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final AuthController _authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    // Determine if the screen is desktop/tablet or mobile
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Light professional grey
      body: SafeArea(
        child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      ),
    );
  }

  // Layout for wide screens (Desktop / Web / Large Tablet)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          child: Container(
            color: Colors.blueAccent.shade700,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.business_center,
                    size: 100,
                    color: Colors.white,
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    "G tel ERP System",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: Center(child: _buildLoginForm())),
      ],
    );
  }

  // Layout for narrow screens (Mobile)
  Widget _buildMobileLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mobile Branding / Logo
            Icon(
              Icons.business_center,
              size: 80,
              color: Colors.blueAccent.shade700,
            ),
            SizedBox(height: 16.h),
            Text(
              "G tel ERP",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blueAccent.shade700,
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 40.h),

            // The Form
            _buildLoginForm(),
          ],
        ),
      ),
    );
  }

  // Refactored the form into its own widget to avoid code duplication
  Widget _buildLoginForm() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: 400,
      ), // Max width for larger screens
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Login",
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "Enter your credentials to access the ERP",
              style: TextStyle(fontSize: 14.sp, color: Colors.grey),
            ),
            SizedBox(height: 30.h),
            TextFormField(
              controller: _emailController,
              style: const TextStyle(color: Colors.black),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration("Email", Icons.email_outlined),
              validator: (v) => v!.isEmpty ? "Email required" : null,
            ),
            SizedBox(height: 20.h),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.black),
              textInputAction: TextInputAction.done,
              decoration: _inputDecoration(
                "Password",
                Icons.lock_outline,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed:
                      () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              onFieldSubmitted: (_) => _handleLogin(),
              validator: (v) => v!.isEmpty ? "Password required" : null,
            ),
            SizedBox(height: 30.h),

            // Login Button
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: Obx(
                () => ElevatedButton(
                  onPressed:
                      _authController.isLoading.value ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _authController.isLoading.value
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            "Sign In",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      _authController.login(_emailController.text, _passwordController.text);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      labelStyle: const TextStyle(color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}