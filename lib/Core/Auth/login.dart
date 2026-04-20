// lib/Core/Auth/login.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Auth/auth.dart';
import 'login_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final LoginController loginCtrl = Get.put(LoginController());
    final AuthController authCtrl = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth > 800;
            return isDesktop
                ? _DesktopLayout(loginCtrl: loginCtrl, authCtrl: authCtrl)
                : _MobileLayout(loginCtrl: loginCtrl, authCtrl: authCtrl);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Desktop Layout — দুই কলাম
// ─────────────────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final LoginController loginCtrl;
  final AuthController authCtrl;

  const _DesktopLayout({required this.loginCtrl, required this.authCtrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left side — branding
        Expanded(
          child: Container(
            color: Colors.blueAccent.shade700,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business_center, size: 100, color: Colors.white),
                  SizedBox(height: 24),
                  Text(
                    'G-Tel ERP System',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Business Management Platform',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right side — form
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: _LoginForm(loginCtrl: loginCtrl, authCtrl: authCtrl),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Mobile Layout — single column
// ─────────────────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final LoginController loginCtrl;
  final AuthController authCtrl;

  const _MobileLayout({required this.loginCtrl, required this.authCtrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_center,
              size: 80,
              color: Colors.blueAccent.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              'G-Tel ERP',
              style: TextStyle(
                color: Colors.blueAccent.shade700,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            _LoginForm(loginCtrl: loginCtrl, authCtrl: authCtrl),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Login Form — shared between desktop and mobile
// ─────────────────────────────────────────────────────────────
class _LoginForm extends StatelessWidget {
  final LoginController loginCtrl;
  final AuthController authCtrl;

  const _LoginForm({required this.loginCtrl, required this.authCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: loginCtrl.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your credentials to access the ERP',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 28),

            // Email field
            TextFormField(
              controller: loginCtrl.emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 14),
              decoration: _inputDecoration('Email', Icons.email_outlined),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!GetUtils.isEmail(v)) return 'Invalid email format';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password field
            Obx(
              () => TextFormField(
                controller: loginCtrl.passwordController,
                obscureText: loginCtrl.obscurePassword.value,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 14),
                decoration: _inputDecoration(
                  'Password',
                  Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      loginCtrl.obscurePassword.value
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: loginCtrl.toggleObscurePassword,
                  ),
                ),
                onFieldSubmitted: (_) => _handleLogin(),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 28),

            // Login button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Obx(
                () => ElevatedButton(
                  onPressed: authCtrl.isLoading.value ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.blueAccent.shade700
                        .withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child:
                      authCtrl.isLoading.value
                          ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                          : const Text(
                            'Sign In',
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
    if (loginCtrl.formKey.currentState!.validate()) {
      authCtrl.login(
        loginCtrl.emailController.text,
        loginCtrl.passwordController.text,
      );
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey),
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.blueAccent.shade700, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}