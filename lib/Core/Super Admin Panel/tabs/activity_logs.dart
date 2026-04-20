import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../superadmincontroller.dart';

class ActivityLogTab extends StatelessWidget {
  const ActivityLogTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SuperAdminController>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                onPressed: ctrl.fetchActivityLogs,
                icon: const Icon(
                  Icons.refresh,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        // Log list
        Expanded(
          child: Obx(() {
            if (ctrl.isLogLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            if (ctrl.activityLogs.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'No activity logs yet',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: ctrl.activityLogs.length,
              separatorBuilder:
                  (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (context, i) => _LogTile(log: ctrl.activityLogs[i]),
            );
          }),
        ),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  final ActivityLogModel log;

  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(log.action);
    final icon = _actionIcon(log.action);
    final timeStr =
        log.timestamp != null
            ? DateFormat('dd MMM yyyy, hh:mm a').format(log.timestamp!)
            : 'Just now';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action + module
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.action,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      log.module,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Details
                Text(log.details, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),

                // User + time
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 13,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      log.userName.isNotEmpty ? log.userName : log.userEmail,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Color _actionColor(String action) {
    if (action.contains('DELETE') || action.contains('REVOKE')) {
      return Colors.redAccent;
    }
    if (action.contains('CREATE') || action.contains('GRANT')) {
      return Colors.green;
    }
    if (action.contains('DISABLE')) return Colors.orange;
    if (action.contains('ENABLE')) return Colors.teal;
    return Colors.blue;
  }
  IconData _actionIcon(String action) {
    if (action.contains('DELETE')) return Icons.delete_outline;
    if (action.contains('CREATE')) return Icons.add_circle_outline;
    if (action.contains('DISABLE')) return Icons.block_outlined;
    if (action.contains('ENABLE')) return Icons.check_circle_outline;
    if (action.contains('ROLE')) return Icons.manage_accounts_outlined;
    if (action.contains('PERMISSION') ||
        action.contains('GRANT') ||
        action.contains('REVOKE')) {
      return Icons.tune_outlined;
    }
    return Icons.history_outlined;
  }
}
