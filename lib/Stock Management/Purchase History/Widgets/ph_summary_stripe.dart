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
      child: Obx(() {
        final range = ctrl.dateRange.value;
        final totalInvoiced = ctrl.totalInvoiced.value;
        final totalPaid = ctrl.totalPayments.value;
        final netPayable = (totalInvoiced - totalPaid).clamp(
          0,
          double.infinity,
        );

        return Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: PHTokens.slate400,
              size: 13,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${DateFormat('dd MMM yyyy').format(range.start)} - '
                '${DateFormat('dd MMM yyyy').format(range.end)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PHTokens.slate400,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(),
            PHSummaryChip(
              label: 'Invoiced',
              value: totalInvoiced,
              color: PHTokens.blue,
            ),
            const SizedBox(width: 24),
            PHSummaryChip(
              label: 'Paid',
              value: totalPaid,
              color: PHTokens.green,
            ),
            const SizedBox(width: 24),
            PHSummaryChip(
              label: 'Net Payable',
              value: netPayable.toDouble(),
              color: PHTokens.amber,
            ),
          ],
        );
      }),
    );
  }
}

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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: PHTokens.slate400, fontSize: 12),
        ),
        Text(
          'Tk ${value.toStringAsFixed(2)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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