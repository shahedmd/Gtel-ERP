import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'permission_controller.dart';

enum PermissionType { canView, canEdit, canDelete, canCreate }

class PermissionButton extends StatelessWidget {
  final String route;
  final PermissionType type;
  final Widget child;

  // showDisabled: true হলে disabled button দেখাবে
  // false হলে সম্পূর্ণ hide হবে
  final bool showDisabled;

  const PermissionButton({
    super.key,
    required this.route,
    required this.type,
    required this.child,
    this.showDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final permCtrl = Get.find<PermissionController>();

    // permission check
    final bool hasPermission = _checkPermission(permCtrl);

    if (hasPermission) return child;

    // permission নেই
    if (showDisabled) {
      // Disabled tooltip সহ দেখাবে
      return Tooltip(
        message: _noPermissionMessage(),
        child: Opacity(opacity: 0.3, child: AbsorbPointer(child: child)),
      );
    }

    // সম্পূর্ণ hide
    return const SizedBox.shrink();
  }

  bool _checkPermission(PermissionController ctrl) {
    switch (type) {
      case PermissionType.canView:
        return ctrl.canView(route);
      case PermissionType.canEdit:
        return ctrl.canEdit(route);
      case PermissionType.canDelete:
        return ctrl.canDelete(route);
      case PermissionType.canCreate:
        return ctrl.canCreate(route);
    }
  }

  String _noPermissionMessage() {
    switch (type) {
      case PermissionType.canView:
        return 'You don\'t have view permission';
      case PermissionType.canEdit:
        return 'You don\'t have edit permission';
      case PermissionType.canDelete:
        return 'You don\'t have delete permission';
      case PermissionType.canCreate:
        return 'You don\'t have create permission';
    }
  }
}