import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'permission_controller.dart';

enum PermissionType {
  canView,
  canCreate,
  canEdit,
  canDelete,
  action,
}

class PermissionButton extends StatelessWidget {
  final String route;
  final PermissionType type;
  final String? actionKey;
  final Widget child;
  final bool showDisabled;

  const PermissionButton({
    super.key,
    required this.route,
    required this.type,
    required this.child,
    this.actionKey,
    this.showDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final permissionController = Get.find<PermissionController>();

    return Obx(() {
      final allowed = _isAllowed(permissionController);

      if (allowed) return child;

      if (!showDisabled) return const SizedBox.shrink();

      return Tooltip(
        message: 'You do not have permission for this action.',
        child: Opacity(
          opacity: 0.38,
          child: AbsorbPointer(child: child),
        ),
      );
    });
  }

  bool _isAllowed(PermissionController controller) {
    switch (type) {
      case PermissionType.canView:
        return controller.canView(route);
      case PermissionType.canCreate:
        return controller.canCreate(route);
      case PermissionType.canEdit:
        return controller.canEdit(route);
      case PermissionType.canDelete:
        return controller.canDelete(route);
      case PermissionType.action:
        final key = actionKey;
        if (key == null || key.trim().isEmpty) return false;
        return controller.canAction(route, key);
    }
  }
}
