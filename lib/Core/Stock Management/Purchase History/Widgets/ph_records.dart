import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Views/ph_tokens.dart';
import '../purchase_controller.dart';
import 'ph_recond_rows.dart';


// ─────────────────────────────────────────────────────────────────────────────
// RECORDS LIST  (main scrollable area)
// ─────────────────────────────────────────────────────────────────────────────

class PHRecordsList extends StatelessWidget {
  const PHRecordsList({super.key, required this.ctrl});

  final GlobalPurchaseHistoryController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isLoading.value && ctrl.records.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(
            color: PHTokens.blue,
            strokeWidth: 2,
          ),
        );
      }

      if (ctrl.records.isEmpty) {
        return const PHEmptyState();
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        itemCount: ctrl.records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder:
            (ctx, i) => PHRecordRow(
              record: ctrl.records[i],
              ctrl: ctrl,
            ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class PHEmptyState extends StatelessWidget {
  const PHEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: PHTokens.slate100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: PHTokens.slate400,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No records found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: PHTokens.slate700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting your date range or supplier filter.',
            style: TextStyle(fontSize: 13, color: PHTokens.slate400),
          ),
        ],
      ),
    );
  }
}