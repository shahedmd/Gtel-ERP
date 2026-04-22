import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Views/ph_tokens.dart';
import '../purchase_controller.dart';

class PHPaginationBar extends StatelessWidget {
  const PHPaginationBar({super.key, required this.ctrl});

  final GlobalPurchaseHistoryController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: PHTokens.surface,
        border: Border(top: BorderSide(color: PHTokens.slate200)),
      ),
      // 1. Removed Obx from here
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _PrevButton(ctrl: ctrl),
          const SizedBox(width: 10),
          _NextButton(ctrl: ctrl),
        ],
      ),
    );
  }
}

class _PrevButton extends StatelessWidget {
  const _PrevButton({required this.ctrl});
  final GlobalPurchaseHistoryController ctrl;

  @override
  Widget build(BuildContext context) {
    // 2. Added Obx here because ctrl.isFirstPage.value is read here
    return Obx(() {
      return OutlinedButton.icon(
        onPressed: ctrl.isFirstPage.value ? null : ctrl.prevPage,
        icon: const Icon(Icons.chevron_left_rounded, size: 18),
        label: const Text('Previous', style: TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: PHTokens.slate700,
          side: const BorderSide(color: PHTokens.slate200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PHTokens.radiusMd),
          ),
        ),
      );
    });
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.ctrl});
  final GlobalPurchaseHistoryController ctrl;

  @override
  Widget build(BuildContext context) {
    // 3. Added Obx here because ctrl.hasMore.value is read here
    return Obx(() {
      return ElevatedButton.icon(
        onPressed: ctrl.hasMore.value ? ctrl.nextPage : null,
        icon: const Text('Next', style: TextStyle(fontSize: 13)),
        label: const Icon(Icons.chevron_right_rounded, size: 18),
        style: ElevatedButton.styleFrom(
          backgroundColor: PHTokens.slate900,
          foregroundColor: Colors.white,
          disabledBackgroundColor: PHTokens.slate200,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PHTokens.radiusMd),
          ),
        ),
      );
    });
  }
}