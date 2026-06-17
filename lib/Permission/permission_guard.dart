import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/controller.dart';
import 'permission_controller.dart';

class PermissionGuard extends StatelessWidget {
  final String moduleKey;
  final Widget child;

  const PermissionGuard({
    super.key,
    required this.moduleKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final roleCtrl = Get.find<RoleController>();

    // Super admin সব দেখতে পারবে
    if (roleCtrl.isSuperAdmin) return child;

    final permCtrl =
        Get.isRegistered<PermissionController>()
            ? Get.find<PermissionController>()
            : Get.put(PermissionController(), permanent: true);

    return Obx(() {
      // Permission লোড হওয়া পর্যন্ত loading দেখাও
      if (!permCtrl.isReady.value) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
        );
      }

      // Permission আছে কিনা চেক করো
      if (permCtrl.can(moduleKey, 'view')) {
        return child;
      }

      // Permission নেই — Access Denied দেখাও
      return _AccessDeniedPage(moduleKey: moduleKey);
    });
  }
}

// ── Access Denied Page ────────────────────────────────────────────────────────
class _AccessDeniedPage extends StatelessWidget {
  final String moduleKey;

  const _AccessDeniedPage({required this.moduleKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Icon ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                FontAwesomeIcons.lock,
                size: 48,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 24),

            // ── Title ─────────────────────────────────────────────────────
            const Text(
              'Access Denied',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // ── Message ───────────────────────────────────────────────────
            Text(
              'You do not have permission to view this page.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Module: ${moduleKey.toUpperCase().replaceAll('_', ' ')}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
            const SizedBox(height: 32),

            // ── Contact Admin ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF3B82F6)),
                  SizedBox(width: 8),
                  Text(
                    'Contact your Super Admin to get access.',
                    style: TextStyle(color: Color(0xFF374151), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}