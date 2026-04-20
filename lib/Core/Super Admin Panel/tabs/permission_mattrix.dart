// lib/Core/SuperAdmin/tabs/permission_matrix_tab.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Permission/permission_model.dart';
import '../superadmincontroller.dart';


class PermissionMatrixTab extends StatelessWidget {
  const PermissionMatrixTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SuperAdminController>();

    return Obx(() {
      if (ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      // SuperAdmin ছাড়া বাকি users
      final users = ctrl.allUsers
          .where((u) => u.role != UserRole.superAdmin)
          .toList();

      if (users.isEmpty) {
        return const Center(
          child: Text('No users to manage permissions for.',
              style: TextStyle(color: Colors.grey)),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: users.length,
        itemBuilder: (context, i) =>
            _UserPermissionCard(user: users[i], ctrl: ctrl),
      );
    });
  }
}

class _UserPermissionCard extends StatelessWidget {
  final UserModel user;
  final SuperAdminController ctrl;

  const _UserPermissionCard(
      {required this.user, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Theme(
        data:
            Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Row(
            children: [
              Text(user.displayName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(user.email,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.blue)),
              ),
            ],
          ),
          // Grant/Revoke all buttons
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => ctrl.grantAllPermissions(user),
                child: const Text('Grant All',
                    style: TextStyle(
                        color: Colors.green, fontSize: 12)),
              ),
              TextButton(
                onPressed: () => ctrl.revokeAllPermissions(user),
                child: const Text('Revoke All',
                    style: TextStyle(
                        color: Colors.redAccent, fontSize: 12)),
              ),
              const Icon(Icons.keyboard_arrow_down,
                  color: Colors.grey),
            ],
          ),
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text('Page',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.grey)),
                  ),
                  ..._permHeaders(),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            // Route rows
            ...ctrl.allRoutes.map((route) => _PermissionRow(
                  user: user,
                  route: route,
                  ctrl: ctrl,
                )),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<Widget> _permHeaders() {
    const labels = ['View', 'Edit', 'Delete', 'Create'];
    return labels
        .map((l) => SizedBox(
              width: 60,
              child: Center(
                child: Text(l,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.grey)),
              ),
            ))
        .toList();
  }
}

class _PermissionRow extends StatelessWidget {
  final UserModel user;
  final String route;
  final SuperAdminController ctrl;

  const _PermissionRow(
      {required this.user, required this.route, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final perm = user.permissions[route] ?? RoutePermission.noAccess();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(ctrl.routeDisplayName(route),
                style: const TextStyle(fontSize: 13)),
          ),
          _PermToggle(
            value: perm.canView,
            onChanged: () => ctrl.togglePermission(
                user: user, route: route, permType: 'canView'),
            color: Colors.blue,
          ),
          _PermToggle(
            value: perm.canEdit,
            onChanged: () => ctrl.togglePermission(
                user: user, route: route, permType: 'canEdit'),
            color: Colors.orange,
          ),
          _PermToggle(
            value: perm.canDelete,
            onChanged: () => ctrl.togglePermission(
                user: user, route: route, permType: 'canDelete'),
            color: Colors.red,
          ),
          _PermToggle(
            value: perm.canCreate,
            onChanged: () => ctrl.togglePermission(
                user: user, route: route, permType: 'canCreate'),
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}

class _PermToggle extends StatelessWidget {
  final bool value;
  final VoidCallback onChanged;
  final Color color;

  const _PermToggle({
    required this.value,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: Center(
        child: GestureDetector(
          onTap: onChanged,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: value
                  ? color.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? color : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: value
                ? Icon(Icons.check, size: 16, color: color)
                : null,
          ),
        ),
      ),
    );
  }
}