import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Permission/permission_model.dart';
import 'super_admin_controller.dart';

class PermissionMatrixTab extends StatelessWidget {
  const PermissionMatrixTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SuperAdminController>();

    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
      }

      final users =
          controller.filteredUsers
              .where((user) => user.role != UserRole.superAdmin)
              .toList();

      if (users.isEmpty) {
        return const Center(
          child: Text(
            'No users available for permission management.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        );
      }

      return Column(
        children: [
          _PermissionToolbar(controller: controller),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                return _UserPermissionCard(
                  user: users[index],
                  controller: controller,
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

class _PermissionToolbar extends StatelessWidget {
  final SuperAdminController controller;

  const _PermissionToolbar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        onChanged: (value) => controller.searchQuery.value = value,
        decoration: const InputDecoration(
          hintText: 'Search user by name, email or role...',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
    );
  }
}

class _UserPermissionCard extends StatelessWidget {
  final UserModel user;
  final SuperAdminController controller;

  const _UserPermissionCard({required this.user, required this.controller});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          title: _UserHeader(user: user),
          trailing: _BulkActions(user: user, controller: controller),
          children: [
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 10),
            _PermissionHeader(),
            const SizedBox(height: 4),
            ...controller.allRoutes.map((route) {
              return _RoutePermissionRow(
                user: user,
                route: route,
                controller: controller,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final UserModel user;

  const _UserHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFEFF6FF),
          child: Text(
            user.displayName.isNotEmpty
                ? user.displayName[0].toUpperCase()
                : 'U',
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName.isEmpty ? 'Unnamed User' : user.displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusBadge(isActive: user.isActive),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.green : Colors.redAccent;
    final label = isActive ? 'Active' : 'Disabled';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues( alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BulkActions extends StatelessWidget {
  final UserModel user;
  final SuperAdminController controller;

  const _BulkActions({required this.user, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => controller.grantAllPermissions(user),
          child: const Text('Grant All'),
        ),
        TextButton(
          onPressed: () => controller.revokeAllPermissions(user),
          child: const Text(
            'Revoke All',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
        const Icon(Icons.keyboard_arrow_down_rounded),
      ],
    );
  }
}

class _PermissionHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            'Page / Action',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        _HeaderCell(label: 'View'),
        _HeaderCell(label: 'Create'),
        _HeaderCell(label: 'Edit'),
        _HeaderCell(label: 'Delete'),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _RoutePermissionRow extends StatelessWidget {
  final UserModel user;
  final String route;
  final SuperAdminController controller;

  const _RoutePermissionRow({
    required this.user,
    required this.route,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final permission = user.permissions[route] ?? RoutePermission.noAccess();
    final actions = controller.actionLabelsForRoute(route);

    return Column(
      children: [
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  controller.routeDisplayName(route),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _PermissionToggle(
                value: permission.canView,
                color: Colors.blue,
                onTap:
                    () => controller.togglePermission(
                      user: user,
                      route: route,
                      permType: 'canView',
                    ),
              ),
              _PermissionToggle(
                value: permission.canCreate,
                color: Colors.green,
                onTap:
                    () => controller.togglePermission(
                      user: user,
                      route: route,
                      permType: 'canCreate',
                    ),
              ),
              _PermissionToggle(
                value: permission.canEdit,
                color: Colors.orange,
                onTap:
                    () => controller.togglePermission(
                      user: user,
                      route: route,
                      permType: 'canEdit',
                    ),
              ),
              _PermissionToggle(
                value: permission.canDelete,
                color: Colors.redAccent,
                onTap:
                    () => controller.togglePermission(
                      user: user,
                      route: route,
                      permType: 'canDelete',
                    ),
              ),
            ],
          ),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 4, bottom: 8),
            child: Column(
              children:
                  actions.entries.map((entry) {
                    final enabled = permission.actions[entry.key] == true;

                    return _ActionPermissionRow(
                      label: entry.value,
                      value: enabled,
                      onTap:
                          () => controller.toggleActionPermission(
                            user: user,
                            route: route,
                            actionKey: entry.key,
                          ),
                    );
                  }).toList(),
            ),
          ),
      ],
    );
  }
}

class _ActionPermissionRow extends StatelessWidget {
  final String label;
  final bool value;
  final VoidCallback onTap;

  const _ActionPermissionRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          const Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 17,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            ),
          ),
          SizedBox(
            width: 68,
            child: Center(child: _SmallCheckBox(value: value, onTap: onTap)),
          ),
          const SizedBox(width: 204),
        ],
      ),
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  final bool value;
  final Color color;
  final VoidCallback onTap;

  const _PermissionToggle({
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Center(
        child: _SmallCheckBox(value: value, activeColor: color, onTap: onTap),
      ),
    );
  }
}

class _SmallCheckBox extends StatelessWidget {
  final bool value;
  final Color activeColor;
  final VoidCallback onTap;

  const _SmallCheckBox({
    required this.value,
    required this.onTap,
    this.activeColor = const Color(0xFF2563EB),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: value ? activeColor.withValues( alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: value ? activeColor : const Color(0xFFD1D5DB),
            width: 1.4,
          ),
        ),
        child:
            value
                ? Icon(Icons.check_rounded, size: 17, color: activeColor)
                : null,
      ),
    );
  }
}