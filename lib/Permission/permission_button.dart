import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/controller.dart';
import 'permission_controller.dart';

class PermissionButton extends StatelessWidget {
  final String moduleKey;
  final String action;
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final bool isIconButton;
  final bool hideIfNoPermission; // false হলে disabled দেখাবে

  const PermissionButton({
    super.key,
    required this.moduleKey,
    required this.action,
    required this.onPressed,
    required this.child,
    this.style,
    this.isIconButton = false,
    this.hideIfNoPermission = true,
  });

  @override
  Widget build(BuildContext context) {
    final roleCtrl = Get.find<RoleController>();

    // Super Admin → সরাসরি দেখাও
    if (roleCtrl.isSuperAdmin) {
      return _buildButton(enabled: true);
    }

    final permCtrl =
        Get.isRegistered<PermissionController>()
            ? Get.find<PermissionController>()
            : Get.put(PermissionController(), permanent: true);

    return Obx(() {
      final hasPermission = permCtrl.can(moduleKey, action);

      if (!hasPermission && hideIfNoPermission) {
        return const SizedBox.shrink(); // ← hide করো
      }

      return _buildButton(enabled: hasPermission);
    });
  }

  Widget _buildButton({required bool enabled}) {
    if (isIconButton) {
      return IconButton(
        onPressed: enabled ? onPressed : null,
        icon: child,
        style: style,
      );
    }

    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: style,
      child: child,
    );
  }
}

// ── Permission Icon Button (shortcut) ────────────────────────────────────────
class PermissionIconButton extends StatelessWidget {
  final String moduleKey;
  final String action;
  final VoidCallback? onPressed;
  final Icon icon;
  final String? tooltip;
  final Color? color;

  const PermissionIconButton({
    super.key,
    required this.moduleKey,
    required this.action,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final roleCtrl = Get.find<RoleController>();

    if (roleCtrl.isSuperAdmin) {
      return IconButton(
        onPressed: onPressed,
        icon: icon,
        tooltip: tooltip,
        color: color,
      );
    }

    final permCtrl =
        Get.isRegistered<PermissionController>()
            ? Get.find<PermissionController>()
            : Get.put(PermissionController(), permanent: true);

    return Obx(() {
      if (!permCtrl.can(moduleKey, action)) {
        return const SizedBox.shrink();
      }
      return IconButton(
        onPressed: onPressed,
        icon: icon,
        tooltip: tooltip,
        color: color,
      );
    });
  }
}

// ── Permission Visibility (any widget hide/show) ──────────────────────────────
// Button ছাড়া অন্য যেকোনো widget hide করতে
class PermissionVisibility extends StatelessWidget {
  final String moduleKey;
  final String action;
  final Widget child;

  const PermissionVisibility({
    super.key,
    required this.moduleKey,
    required this.action,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final roleCtrl = Get.find<RoleController>();

    if (roleCtrl.isSuperAdmin) return child;

    final permCtrl =
        Get.isRegistered<PermissionController>()
            ? Get.find<PermissionController>()
            : Get.put(PermissionController(), permanent: true);

    return Obx(() {
      if (!permCtrl.can(moduleKey, action)) {
        return const SizedBox.shrink();
      }
      return child;
    });
  }
}
