import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'auth_controller.dart';

class LoginPage extends GetView<AuthController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF3F4F6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: _LoginCard(),
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends GetView<AuthController> {
  const _LoginCard();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints( maxWidth : 420),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                const SizedBox(height: 28),
                TextField(
                  controller: controller.emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                Obx(
                  () => TextField(
                    controller: controller.passwordController,
                    obscureText: !controller.isPasswordVisible.value,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => controller.login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip:
                            controller.isPasswordVisible.value
                                ? 'Hide password'
                                : 'Show password',
                        onPressed: controller.togglePasswordVisibility,
                        icon: Icon(
                          controller.isPasswordVisible.value
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Obx(
                  () => SizedBox(
                    height: 46,
                    child: FilledButton(
                      onPressed:
                          controller.isLoading.value ? null : controller.login,
                      child:
                          controller.isLoading.value
                              ? const SizedBox(
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color: Colors.white,
                                ),
                              )
                              : const Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Logo(),
        SizedBox(height: 22),
        Text(
          'Sign in to G-Tel ERP',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Access your business control panel.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.4,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 38,
          width: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'G',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'G-Tel ERP',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}