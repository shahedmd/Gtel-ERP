import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../Permission/permission_model.dart';
import '../super_admin_controller.dart';


class UserManagementTab extends StatelessWidget {
  const UserManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SuperAdminController>();

    return Column(
      children: [
        // ── Top bar: search + add button ──
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Search
              Expanded(
                child: TextField(
                  onChanged: (v) => ctrl.searchQuery.value = v,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: Colors.grey,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Add User button
              ElevatedButton.icon(
                onPressed: () => _showCreateUserDialog(context, ctrl),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        // ── User List ──
        Expanded(
          child: Obx(() {
            if (ctrl.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            final users = ctrl.filteredUsers;

            if (users.isEmpty) {
              return const Center(
                child: Text(
                  'No users found',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: users.length,
              separatorBuilder:
                  (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder:
                  (context, i) => _UserTile(user: users[i], ctrl: ctrl),
            );
          }),
        ),
      ],
    );
  }

  void _showCreateUserDialog(BuildContext context, SuperAdminController ctrl) {
    final uidCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selectedRole = UserRole.staff.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(28),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New User',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'First create the user in Firebase Auth Console,\nthen enter their UID here.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // UID
                _dialogField(
                  controller: uidCtrl,
                  label: 'Firebase UID',
                  hint: 'Paste UID from Firebase Console',
                  validator: (v) => v!.isEmpty ? 'UID is required' : null,
                ),
                const SizedBox(height: 12),

                // Email
                _dialogField(
                  controller: emailCtrl,
                  label: 'Email',
                  hint: 'user@example.com',
                  validator:
                      (v) => !GetUtils.isEmail(v!) ? 'Invalid email' : null,
                ),
                const SizedBox(height: 12),

                // Display Name
                _dialogField(
                  controller: nameCtrl,
                  label: 'Display Name',
                  hint: 'Full name',
                  validator: (v) => v!.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),

                // Role dropdown
                const Text(
                  'Role',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Obx(
                  () => DropdownButtonFormField<UserRole>(
                    value: selectedRole.value,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.admin,
                        child: Text('Admin'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.staff,
                        child: Text('Staff'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.viewer,
                        child: Text('Viewer'),
                      ),
                    ],
                    onChanged: (v) => selectedRole.value = v ?? UserRole.staff,
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Obx(
                      () => ElevatedButton(
                        onPressed:
                            ctrl.isSaving.value
                                ? null
                                : () async {
                                  if (formKey.currentState!.validate()) {
                                    Get.back();
                                    await ctrl.createUser(
                                      uid: uidCtrl.text.trim(),
                                      email: emailCtrl.text.trim(),
                                      displayName: nameCtrl.text.trim(),
                                      role: selectedRole.value,
                                    );
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child:
                            ctrl.isSaving.value
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Create'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF3B82F6)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Single user row ──────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final UserModel user;
  final SuperAdminController ctrl;

  const _UserTile({required this.user, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.role);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            child: Text(
              user.displayName.isNotEmpty
                  ? user.displayName[0].toUpperCase()
                  : 'U',
              style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),

          // Name + email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _roleLabel(user.role),
              style: TextStyle(
                color: roleColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const SizedBox(width: 4),

          // Role change dropdown
          PopupMenuButton<UserRole>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            tooltip: 'Options',
            itemBuilder:
                (_) => [
                  const PopupMenuItem(
                    value: UserRole.admin,
                    child: Text('Set as Admin'),
                  ),
                  const PopupMenuItem(
                    value: UserRole.staff,
                    child: Text('Set as Staff'),
                  ),
                  const PopupMenuItem(
                    value: UserRole.viewer,
                    child: Text('Set as Viewer'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    onTap: () => ctrl.deleteUser(user),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ],
            onSelected: (role) => ctrl.changeUserRole(user, role),
          ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.deepPurple;
      case UserRole.admin:
        return Colors.teal;
      case UserRole.staff:
        return Colors.blue;
      case UserRole.viewer:
        return Colors.grey;
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.staff:
        return 'Staff';
      case UserRole.viewer:
        return 'Viewer';
    }
  }
}
