import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/ActivityLogger/activity_logger.dart';
import 'package:gtel_erp/SuperAdmin/super_admin_controller.dart';
import 'package:intl/intl.dart';

// ── Light Theme Colors ────────────────────────────────────────────────────────
const Color _bg = Color(0xFFF3F4F6);
const Color _white = Colors.white;
const Color _dark = Color(0xFF111827);
const Color _blue = Color(0xFF3B82F6);
const Color _green = Color(0xFF10B981);
const Color _red = Color(0xFFEF4444);
const Color _orange = Color(0xFFF59E0B);
const Color _textGrey = Color(0xFF6B7280);
const Color _border = Color(0xFFE5E7EB);

class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({super.key});

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SuperAdminController _ctrl = Get.put(SuperAdminController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _UserListTab(db: _db, ctrl: _ctrl),
                _ActivityLogTab(db: _db),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      color: _white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              FontAwesomeIcons.userShield,
              color: _blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Super Admin Panel',
                style: TextStyle(
                  color: _dark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Manage users & monitor activity',
                style: TextStyle(color: _textGrey, fontSize: 13),
              ),
            ],
          ),
          const Spacer(),

          // ── Add New User Button ───────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: () => _showCreateUserDialog(context),
            icon: const Icon(Icons.person_add, size: 16, color: Colors.white),
            label: const Text(
              'Add New User',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ─────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: _blue,
        unselectedLabelColor: _textGrey,
        indicatorColor: _blue,
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(FontAwesomeIcons.users, size: 14),
            text: 'User Management',
          ),
          Tab(
            icon: Icon(FontAwesomeIcons.clockRotateLeft, size: 14),
            text: 'Activity Log',
          ),
        ],
      ),
    );
  }

  // ── Create User Dialog ───────────────────────────────────────────────────────
  void _showCreateUserDialog(BuildContext context) {
    final nameC = TextEditingController();
    final emailC = TextEditingController();
    final phoneC = TextEditingController();

    final passwordC = TextEditingController();
    final RxString selectedRole = 'cashier'.obs;
    final RxBool obscurePassword = true.obs;

    final List<Map<String, dynamic>> roles = [
      {'value': 'super_admin', 'label': 'Super Admin', 'color': _red},
      {'value': 'manager', 'label': 'Manager', 'color': _blue},
      {'value': 'cashier', 'label': 'Cashier', 'color': _green},
      {'value': 'viewer', 'label': 'Viewer', 'color': _textGrey},
    ];

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 480,
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Dialog Header ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      FontAwesomeIcons.userPlus,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Create New User',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // ── Form ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogField(
                      controller: nameC,
                      hint: 'Full Name',
                      icon: FontAwesomeIcons.user,
                    ),
                    const SizedBox(height: 16),
                    _dialogField(
                      controller: emailC,
                      hint: 'Email Address',
                      icon: FontAwesomeIcons.envelope,
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _dialogField(
                      controller: phoneC,
                      hint: 'Phone Number',
                      icon: FontAwesomeIcons.phone,
                      type: TextInputType.phone,
                    ),

                    const SizedBox(height: 16),
                    Obx(
                      () => TextField(
                        controller: passwordC,
                        obscureText: obscurePassword.value,
                        style: const TextStyle(fontSize: 14, color: _dark),
                        decoration: InputDecoration(
                          hintText: 'Password (min 6 characters)',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: _textGrey,
                          ),
                          prefixIcon: const Icon(
                            FontAwesomeIcons.lock,
                            size: 14,
                            color: Colors.blueGrey,
                          ),
                          suffixIcon: IconButton(
                            onPressed:
                                () =>
                                    obscurePassword.value =
                                        !obscurePassword.value,
                            icon: Icon(
                              obscurePassword.value
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 18,
                              color: _textGrey,
                            ),
                          ),
                          filled: true,
                          fillColor: _bg,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: _blue,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Role selector
                    const Text(
                      'SELECT ROLE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _textGrey,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Obx(
                      () => Row(
                        children:
                            roles.map((r) {
                              final isSelected =
                                  selectedRole.value == r['value'];
                              final color = r['color'] as Color;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => selectedRole.value = r['value'],
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? color.withValues(alpha: 0.1)
                                              : _bg,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? color : _border,
                                        width: isSelected ? 1.8 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          FontAwesomeIcons.userShield,
                                          size: 14,
                                          color: isSelected ? color : _textGrey,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          r['label'],
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight:
                                                isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                            color:
                                                isSelected ? color : _textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Footer ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: _textGrey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Obx(
                      () => ElevatedButton.icon(
                        onPressed:
                            _ctrl.isCreating.value
                                ? null
                                : () => _ctrl.createUser(
                                  name: nameC.text,
                                  email: emailC.text,
                                  password: passwordC.text,
                                  role: selectedRole.value,
                                  phone: phoneC.text, // ← নতুন
                                ),
                        icon:
                            _ctrl.isCreating.value
                                ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        label: Text(
                          _ctrl.isCreating.value
                              ? 'Creating...'
                              : 'Create User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  // ── Dialog Field Helper ───────────────────────────────────────────────────────
  Widget _dialogField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(fontSize: 14, color: _dark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: _textGrey),
        prefixIcon: Icon(icon, size: 14, color: Colors.blueGrey),
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — USER LIST
// ─────────────────────────────────────────────────────────────────────────────
class _UserListTab extends StatelessWidget {
  final FirebaseFirestore db;
  final SuperAdminController ctrl;

  const _UserListTab({required this.db, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('users').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _blue));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(
            child: Text('No users found', style: TextStyle(color: _textGrey)),
          );
        }

        final users = snap.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildStatsRow(users),
            const SizedBox(height: 24),
            const Text(
              'ALL USERS',
              style: TextStyle(
                color: _textGrey,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ...users.map((doc) => _UserCard(doc: doc, db: db, ctrl: ctrl)),
          ],
        );
      },
    );
  }

  Widget _buildStatsRow(List<QueryDocumentSnapshot> users) {
    final total = users.length;
    final active =
        users.where((u) => (u.data() as Map)['isActive'] == true).length;
    final inactive = total - active;

    return Row(
      children: [
        Expanded(
          child: _StatCard(label: 'Total Users', value: '$total', color: _blue),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(label: 'Active', value: '$active', color: _green),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(label: 'Inactive', value: '$inactive', color: _red),
        ),
      ],
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              label == 'Total Users'
                  ? FontAwesomeIcons.users
                  : label == 'Active'
                  ? FontAwesomeIcons.circleCheck
                  : FontAwesomeIcons.circleMinus,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: _textGrey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── User Card ─────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final FirebaseFirestore db;
  final SuperAdminController ctrl;

  const _UserCard({required this.doc, required this.db, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? '';
    final role = data['role'] ?? 'viewer';
    final isActive = data['isActive'] ?? true;

    final Color roleColor =
        role == 'super_admin'
            ? _red
            : role == 'manager'
            ? _blue
            : role == 'cashier'
            ? _green
            : _textGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          CircleAvatar(
            radius: 24,
            backgroundColor: roleColor.withValues(alpha: 0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: roleColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // ── Info ────────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _dark,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(color: _textGrey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Badge(
                      label: role.toUpperCase().replaceAll('_', ' '),
                      color: roleColor,
                    ),
                    const SizedBox(width: 8),
                    _Badge(
                      label: isActive ? 'ACTIVE' : 'INACTIVE',
                      color: isActive ? _green : _red,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Buttons (only for non super_admin) ───────────────────────────
          if (role != 'super_admin') ...[
            // Permissions button
            GestureDetector(
              onTap:
                  () => Get.dialog(
                    _PermissionMatrixDialog(
                      uid: doc.id,
                      name: name,
                      ctrl: ctrl,
                    ),
                    barrierDismissible: false,
                  ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _blue.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Permissions',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Activate/Deactivate button
            GestureDetector(
              onTap: () => _toggleActive(doc.id, name, isActive),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? _red.withValues(alpha: 0.08)
                          : _green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isActive
                            ? _red.withValues(alpha: 0.3)
                            : _green.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isActive ? 'Deactivate' : 'Activate',
                  style: TextStyle(
                    color: isActive ? _red : _green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleActive(String uid, String name, bool currentStatus) {
    Get.dialog(
      AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          currentStatus ? 'Deactivate User?' : 'Activate User?',
          style: const TextStyle(color: _dark, fontWeight: FontWeight.bold),
        ),
        content: Text(
          currentStatus
              ? '$name will not be able to login.'
              : '$name will be able to login again.',
          style: const TextStyle(color: _textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: _textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await db.collection('users').doc(uid).update({
                'isActive': !currentStatus,
              });

              Get.find<ActivityLogger>().log(
                module: LogModule.admin,
                action: currentStatus ? 'DEACTIVATE' : 'ACTIVATE',
                description:
                    currentStatus
                        ? 'User deactivated: $name'
                        : 'User activated: $name',
                targetId: uid,
              );

              Get.snackbar(
                'Updated',
                '$name has been ${currentStatus ? 'deactivated' : 'activated'}',
                backgroundColor: currentStatus ? _red : _green,
                colorText: Colors.white,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: currentStatus ? _red : _green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              currentStatus ? 'Deactivate' : 'Activate',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — ACTIVITY LOG
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityLogTab extends StatefulWidget {
  final FirebaseFirestore db;
  const _ActivityLogTab({required this.db});

  @override
  State<_ActivityLogTab> createState() => _ActivityLogTabState();
}

class _ActivityLogTabState extends State<_ActivityLogTab> {
  String _selectedModule = 'all';
  String _selectedAction = 'all';

  final List<String> _modules = [
    'all',
    'auth',
    'staff',
    'cash',
    'inventory',
    'sales',
    'admin',
  ];

  final List<String> _actions = [
    'all',
    'LOGIN',
    'LOGOUT',
    'CREATE',
    'UPDATE',
    'DELETE',
    'PAYMENT',
    'EXPORT',
    'ACTIVATE',
    'DEACTIVATE',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filters ─────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          color: _white,
          child: Row(
            children: [
              const Icon(FontAwesomeIcons.filter, size: 14, color: _textGrey),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: 'Module',
                  value: _selectedModule,
                  items: _modules,
                  onChanged: (v) => setState(() => _selectedModule = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: 'Action',
                  value: _selectedAction,
                  items: _actions,
                  onChanged: (v) => setState(() => _selectedAction = v!),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _border),

        // ── Log List ─────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                widget.db
                    .collection('activity_logs')
                    .orderBy('timestamp', descending: true)
                    .limit(200)
                    .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _blue),
                );
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No activity logs found',
                    style: TextStyle(color: _textGrey),
                  ),
                );
              }

              var logs =
                  snap.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final moduleOk =
                        _selectedModule == 'all' ||
                        data['module'] == _selectedModule;
                    final actionOk =
                        _selectedAction == 'all' ||
                        data['action'] == _selectedAction;
                    return moduleOk && actionOk;
                  }).toList();

              if (logs.isEmpty) {
                return const Center(
                  child: Text(
                    'No logs match your filter',
                    style: TextStyle(color: _textGrey),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _LogTile(doc: logs[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: _white,
      style: const TextStyle(color: _dark, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textGrey, fontSize: 12),
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
      ),
      items:
          items
              .map(
                (e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())),
              )
              .toList(),
      onChanged: onChanged,
    );
  }
}

// ── Log Tile ──────────────────────────────────────────────────────────────────
class _LogTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _LogTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final action = data['action'] ?? '';
    final module = data['module'] ?? '';
    final description = data['description'] ?? '';
    final userName = data['userName'] ?? 'Unknown';
    final userRole = data['userRole'] ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final timeStr =
        timestamp != null
            ? DateFormat('dd MMM yyyy  hh:mm a').format(timestamp.toDate())
            : '—';

    final Color actionColor = _actionColor(action);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Action badge ─────────────────────────────────────────────────
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: actionColor.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: Text(
              action,
              style: TextStyle(
                color: actionColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // ── Details ──────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 12,
                      color: _textGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$userName • ${userRole.toUpperCase().replaceAll('_', ' ')}',
                      style: const TextStyle(color: _textGrey, fontSize: 11),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.folder_outlined,
                      size: 12,
                      color: _textGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      module.toUpperCase(),
                      style: const TextStyle(color: _textGrey, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Timestamp ────────────────────────────────────────────────────
          Text(timeStr, style: const TextStyle(color: _textGrey, fontSize: 11)),
        ],
      ),
    );
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'CREATE':
        return _green;
      case 'UPDATE':
        return _blue;
      case 'DELETE':
        return _red;
      case 'LOGIN':
        return _orange;
      case 'LOGOUT':
        return _textGrey;
      case 'PAYMENT':
        return _green;
      case 'EXPORT':
        return _orange;
      case 'ACTIVATE':
        return _green;
      case 'DEACTIVATE':
        return _red;
      default:
        return _textGrey;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERMISSION MATRIX DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _PermissionMatrixDialog extends StatefulWidget {
  final String uid;
  final String name;
  final SuperAdminController ctrl;

  const _PermissionMatrixDialog({
    required this.uid,
    required this.name,
    required this.ctrl,
  });

  @override
  State<_PermissionMatrixDialog> createState() =>
      _PermissionMatrixDialogState();
}

class _PermissionMatrixDialogState extends State<_PermissionMatrixDialog> {
  Map<String, Map<String, bool>> perms = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPerms();
  }

  Future<void> _loadPerms() async {
    final loaded = await widget.ctrl.loadPermissions(widget.uid);
    if (mounted) {
      setState(() {
        perms = loaded;
        isLoading = false;
      });
    }
  }

  void _toggle(String module, String action) {
    setState(() {
      perms[module]![action] = !(perms[module]![action] ?? false);
    });
  }

  void _toggleAll(String module, bool value) {
    setState(() {
      for (final action in SuperAdminController.permissionActions) {
        perms[module]![action] = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        height: 620,
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    FontAwesomeIcons.tableColumns,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Permission Matrix',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'User: ${widget.name}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // ── Matrix ────────────────────────────────────────────────────
            isLoading
                ? const Expanded(
                  child: Center(child: CircularProgressIndicator(color: _blue)),
                )
                : Expanded(child: _buildMatrix()),

            // ── Footer ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: _textGrey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Obx(
                    () => ElevatedButton.icon(
                      onPressed:
                          widget.ctrl.isSavingPermissions.value
                              ? null
                              : () => widget.ctrl.savePermissions(
                                widget.uid,
                                widget.name,
                                perms,
                              ),
                      icon:
                          widget.ctrl.isSavingPermissions.value
                              ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(
                                Icons.save,
                                size: 16,
                                color: Colors.white,
                              ),
                      label: Text(
                        widget.ctrl.isSavingPermissions.value
                            ? 'Saving...'
                            : 'Save Permissions',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatrix() {
    final actions = SuperAdminController.permissionActions;
    final modules = SuperAdminController.moduleLabels;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Column Headers ───────────────────────────────────────────────
          Row(
            children: [
              const SizedBox(
                width: 170,
                child: Text(
                  'MODULE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _textGrey,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              ...actions.map(
                (action) => Expanded(
                  child: Center(
                    child: Text(
                      action.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _textGrey,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 60,
                child: Center(
                  child: Text(
                    'ALL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _textGrey,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(color: _border),
          const SizedBox(height: 4),

          // ── Module Rows ──────────────────────────────────────────────────
          ...modules.entries.map((entry) {
            final module = entry.key;
            final label = entry.value;
            final modPerms = perms[module] ?? {};
            final allOn = actions.every((a) => modPerms[a] == true);
            final anyOn = actions.any((a) => modPerms[a] == true);

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color:
                    allOn
                        ? _blue.withValues(alpha: 0.05)
                        : anyOn
                        ? _blue.withValues(alpha: 0.02)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      allOn ? _blue.withValues(alpha: 0.2) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  // Module label
                  SizedBox(
                    width: 170,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: anyOn ? FontWeight.w600 : FontWeight.w400,
                        color: anyOn ? _dark : _textGrey,
                      ),
                    ),
                  ),

                  // Checkboxes
                  ...actions.map(
                    (action) => Expanded(
                      child: Center(
                        child: _CheckCell(
                          value: modPerms[action] ?? false,
                          onChanged: () => _toggle(module, action),
                        ),
                      ),
                    ),
                  ),

                  // All/None toggle
                  SizedBox(
                    width: 60,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _toggleAll(module, !allOn),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                allOn
                                    ? _red.withValues(alpha: 0.08)
                                    : _green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color:
                                  allOn
                                      ? _red.withValues(alpha: 0.3)
                                      : _green.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            allOn ? 'None' : 'All',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: allOn ? _red : _green,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Checkbox Cell ─────────────────────────────────────────────────────────────
class _CheckCell extends StatelessWidget {
  final bool value;
  final VoidCallback onChanged;

  const _CheckCell({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: value ? _blue : _white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: value ? _blue : _border, width: 1.5),
          boxShadow:
              value
                  ? [
                    BoxShadow(
                      color: _blue.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ]
                  : [],
        ),
        child:
            value
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
      ),
    );
  }
}
