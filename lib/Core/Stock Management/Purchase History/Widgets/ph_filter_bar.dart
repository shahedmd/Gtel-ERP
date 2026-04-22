import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Stock%20Management/Purchase%20History/Widgets/ph_suppliers.dart';
import '../Dialog/ph_make_payments.dart';
import '../Views/ph_tokens.dart';
import '../purchase_controller.dart';

class PHFilterBar extends StatelessWidget {
  const PHFilterBar({super.key, required this.ctrl});

  final GlobalPurchaseHistoryController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: PHTokens.surface,
        border: const Border(bottom: BorderSide(color: PHTokens.slate200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Removed the Obx from here, as the observable is not read in this scope.
          PHFilterPills(ctrl: ctrl),
          const Spacer(),
          PHSupplierSearchField(ctrl: ctrl),
          const SizedBox(width: 12),
          PHActionButton(
            label: 'Make Payment',
            icon: Icons.payments_outlined,
            color: PHTokens.green,
            onTap: () => PHMakePaymentDialog.show(ctrl),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER PILLS  (Daily / Monthly / Yearly / Custom)
// ─────────────────────────────────────────────────────────────────────────────

class PHFilterPills extends StatelessWidget {
  const PHFilterPills({super.key, required this.ctrl});

  final GlobalPurchaseHistoryController ctrl;

  static const _filters = [
    (label: 'Daily', type: HistoryFilter.daily),
    (label: 'Monthly', type: HistoryFilter.monthly),
    (label: 'Yearly', type: HistoryFilter.yearly),
    (label: 'Custom', type: HistoryFilter.custom),
  ];

  @override
  Widget build(BuildContext context) {
    // 2. Added the Obx here, tightly wrapping the widget that actually
    //    reads the observable variable (ctrl.activeFilter.value).
    return Obx(() {
      return Row(
        children:
            _filters.map((f) {
              // GetX now successfully registers this read operation:
              final isActive = ctrl.activeFilter.value == f.type;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () => ctrl.applyFilter(f.type),
                  borderRadius: BorderRadius.circular(PHTokens.radiusMd),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? PHTokens.slate900 : PHTokens.surface,
                      border: Border.all(
                        color: isActive ? PHTokens.slate900 : PHTokens.slate200,
                      ),
                      borderRadius: BorderRadius.circular(PHTokens.radiusMd),
                    ),
                    child: Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : PHTokens.slate700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION BUTTON  (reusable coloured elevated button)
// ─────────────────────────────────────────────────────────────────────────────

class PHActionButton extends StatelessWidget {
  const PHActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PHTokens.radiusMd),
        ),
      ),
    );
  }
}