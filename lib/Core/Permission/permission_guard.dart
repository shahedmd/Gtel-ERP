// lib/Core/Permissions/permission_guard.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'permission_controller.dart';

class PermissionGuard extends StatelessWidget {
  final String route;
  final Widget child;

  const PermissionGuard({super.key, required this.route, required this.child});

  @override
  Widget build(BuildContext context) {
    final PermissionController permCtrl = Get.find<PermissionController>();

    return Obx(() {
      // এখনো loading হলে spinner দেখাও
      if (permCtrl.isLoading.value) {
        return const _LoadingView();
      }

      // SuperAdmin সব page দেখতে পারবে — কোনো check লাগবে না
      if (permCtrl.isSuperAdmin) {
        return child;
      }

      // Permission আছে কিনা check করো
      if (permCtrl.canView(route)) {
        return child;
      }

      // Permission নেই — Access Denied দেখাও
      return _AccessDeniedView(route: route);
    });
  }
}

// ─────────────────────────────────────────────────────────────
// Loading View — permission load হওয়ার সময়
// ─────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF3B82F6), strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Access Denied View
// ─────────────────────────────────────────────────────────────
class _AccessDeniedView extends StatelessWidget {
  final String route;

  const _AccessDeniedView({required this.route});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 48,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Access Denied',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              'You don\'t have permission to view this page.\nContact your Super Admin to get access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Go back button
            SizedBox(
              width: 160,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}