import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'permission_controller.dart';

class PermissionGuard extends StatelessWidget {
  final String route;
  final Widget child;

  const PermissionGuard({super.key, required this.route, required this.child});

  @override
  Widget build(BuildContext context) {
    final permissionController = Get.find<PermissionController>();

    return Obx(() {
      if (permissionController.isLoading.value) {
        return const _PermissionLoadingView();
      }

      if (!permissionController.isLoggedIn) {
        return const _AccessDeniedView(
          title: 'Session Required',
          message: 'Please sign in again to continue.',
        );
      }

      if (!permissionController.isActive) {
        return const _AccessDeniedView(
          title: 'Account Disabled',
          message: 'Your account is disabled. Contact Super Admin.',
        );
      }

      if (permissionController.canView(route)) {
        return child;
      }

      return const _AccessDeniedView(
        title: 'Access Denied',
        message: 'You do not have permission to view this page.',
      );
    });
  }
}

class _PermissionLoadingView extends StatelessWidget {
  const _PermissionLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}

class _AccessDeniedView extends StatelessWidget {
  final String title;
  final String message;

  const _AccessDeniedView({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 44,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: Get.back,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
