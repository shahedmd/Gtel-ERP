import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Auth/auth.dart';
import 'login_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loginController = Get.put(LoginController());

    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Light professional grey
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;
            return isDesktop
                ? _buildDesktopLayout(context, loginController, authController)
                : _buildMobileLayout(context, loginController, authController);
          },
        ),
      ),
    );
  }

  // Layout for wide screens (Desktop / Web / Large Tablet)
  Widget _buildDesktopLayout(
    BuildContext context,
    LoginController loginController,
    AuthController authController,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 1, // left side
          child: Container(
            color: Colors.blueAccent.shade700,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.business_center,
                    size: 100, // Hardcoded for desktop, ok here
                    color: Colors.white,
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    "G tel ERP System",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32.sp, // Scaled with ScreenUtil
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1, // right side
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: _buildLoginForm(context, loginController, authController),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    LoginController loginController,
    AuthController authController,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 450;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
                fontSize: isMobile ? 24 : 28.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 40.h),

            _buildLoginForm(context, loginController, authController),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(
    BuildContext context,
    LoginController loginController,
    AuthController authController,
  ) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 450;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: loginController.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Login",
              style: TextStyle(
                fontSize: isMobile ? 20 : 24.sp,
                fontWeight: FontWeight.bold,

                color: theme.colorScheme.onSurface.withValues(alpha: 0.87),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              "Enter your credentials to access the ERP",
              style: TextStyle(
                fontSize: isMobile ? 12 : 14.sp,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 30.h),

            TextFormField(
              controller: loginController.emailController,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: isMobile ? 13 : 17.sp,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                "Email",
                Icons.email_outlined,
                context,
              ),
              validator: (v) {
                if (v!.isEmpty) return "Email required";
                if (!GetUtils.isEmail(v)) return "Invalid email format";
                return null;
              },
            ),
            SizedBox(height: 20.h),

            Obx(
              () => TextFormField(
                controller: loginController.passwordController,
                obscureText: loginController.obscurePassword.value,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: isMobile ? 13 : 17.sp,
                ),
                textInputAction: TextInputAction.done,
                decoration: _inputDecoration(
                  "Password",
                  Icons.lock_outline,
                  context,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      loginController.obscurePassword.value
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () => loginController.toggleObscurePassword(),
                  ),
                ),
                onFieldSubmitted:
                    (_) => _handleLogin(loginController, authController),
                validator: (v) {
                  if (v!.isEmpty) return "Password required";
                  if (v.length < 6) {
                    return "Password must be at least 6 characters";
                  }
                  return null;
                },
              ),
            ),
            SizedBox(height: 30.h),

            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: Obx(
                () => ElevatedButton(
                  onPressed:
                      authController.isLoading.value
                          ? null
                          : () => _handleLogin(loginController, authController),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      authController.isLoading.value
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

  void _handleLogin(
    LoginController loginController,
    AuthController authController,
  ) {
    if (loginController.formKey.currentState!.validate()) {
      authController.login(
        loginController.emailController.text,
        loginController.passwordController.text,
      );
    }
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
    BuildContext context,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 450;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      labelStyle: TextStyle(
        color: Colors.grey,
        fontSize: isMobile ? 12 : 14.sp,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
