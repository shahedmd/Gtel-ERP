// lib/Core/SuperAdmin/superadmin_page.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Permission/permission_controller.dart';
import 'superadmincontroller.dart';
import 'tabs/activity_logs.dart';
import 'tabs/permission_mattrix.dart';
import 'tabs/user_management.dart';


class SuperAdminPage extends StatelessWidget {
  const SuperAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    // SuperAdmin ছাড়া কেউ এই page দেখতে পাবে না
    final permCtrl = Get.find<PermissionController>();
    if (!permCtrl.isSuperAdmin) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.redAccent),
            SizedBox(height: 16),
            Text(
              'SuperAdmin Access Only',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // Controller initialize করো
    Get.put(SuperAdminController());

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          _buildHeader(),

          // ── Tab Bar ─────────────────────────────────────────
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Color(0xFF3B82F6),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF3B82F6),
              indicatorWeight: 2.5,
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: [
                Tab(icon: Icon(Icons.people_outline, size: 20), text: 'Users'),
                Tab(
                  icon: Icon(Icons.tune_outlined, size: 20),
                  text: 'Permissions',
                ),
                Tab(
                  icon: Icon(Icons.history_outlined, size: 20),
                  text: 'Activity Log',
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // ── Tab Content ──────────────────────────────────────
          const Expanded(
            child: TabBarView(
              children: [
                UserManagementTab(),
                PermissionMatrixTab(),
                ActivityLogTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.deepPurple,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SuperAdmin Panel',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manage users, permissions and activity',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
