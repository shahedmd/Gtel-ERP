import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../Views/ph_tokens.dart';
import '../purchase_controller.dart';


class PHSummaryStrip extends StatelessWidget {
  const PHSummaryStrip({super.key, required this.ctrl});

  final GlobalPurchaseHistoryController ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PHTokens.slate800,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Obx(
        () => Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: PHTokens.slate400,
              size: 13,
            ),
            const SizedBox(width: 6),
            Text(
              '${DateFormat('dd MMM yyyy').format(ctrl.dateRange.value.start)}'
              '  —  '
              '${DateFormat('dd MMM yyyy').format(ctrl.dateRange.value.end)}',
              style: const TextStyle(
                color: PHTokens.slate400,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            PHSummaryChip(
              label: 'Invoiced',
              value: ctrl.totalInvoiced.value,
              color: PHTokens.blue,
            ),
            const SizedBox(width: 24),
            PHSummaryChip(
              label: 'Paid',
              value: ctrl.totalPayments.value,
              color: PHTokens.green,
            ),
            const SizedBox(width: 24),
            PHSummaryChip(
              label: 'Net Payable',
              value: (ctrl.totalInvoiced.value - ctrl.totalPayments.value)
                  .clamp(0, double.infinity),
              color: PHTokens.amber,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY CHIP  (coloured dot + label + value)
// ─────────────────────────────────────────────────────────────────────────────

class PHSummaryChip extends StatelessWidget {
  const PHSummaryChip({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(color: PHTokens.slate400, fontSize: 12),
        ),
        Text(
          '৳${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
