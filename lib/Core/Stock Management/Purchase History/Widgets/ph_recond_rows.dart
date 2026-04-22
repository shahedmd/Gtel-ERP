import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../Dialog/ph_invoice_details.dart';
import '../Views/ph_tokens.dart';
import '../purchase_controller.dart';


// ─────────────────────────────────────────────────────────────────────────────
// RECORD ROW  (one row in the purchase/payment list)
// ─────────────────────────────────────────────────────────────────────────────

class PHRecordRow extends StatelessWidget {
  const PHRecordRow({super.key, required this.record, required this.ctrl});

  final PurchaseRecord record;
  final GlobalPurchaseHistoryController ctrl;

  // Map each record type to its badge styling.
  static const _typeStyle = <String, ({Color bg, Color fg, IconData icon})>{
    'invoice': (
      bg: PHTokens.blueLight,
      fg: PHTokens.blue,
      icon: Icons.inventory_2_outlined,
    ),
    'payment': (
      bg: PHTokens.greenLight,
      fg: PHTokens.green,
      icon: Icons.payments_outlined,
    ),
    'adjustment': (
      bg: PHTokens.amberLight,
      fg: PHTokens.amber,
      icon: Icons.sync_alt_rounded,
    ),
  };

  static const _fallbackStyle = (
    bg: PHTokens.slate100,
    fg: PHTokens.slate700,
    icon: Icons.circle_outlined,
  );

  @override
  Widget build(BuildContext context) {
    final style = _typeStyle[record.type] ?? _fallbackStyle;

    return Container(
      decoration: BoxDecoration(
        color: PHTokens.surface,
        borderRadius: BorderRadius.circular(PHTokens.radiusLg),
        border: Border.all(color: PHTokens.slate200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          _DateCell(date: record.date),
          _SupplierCell(record: record, ctrl: ctrl),
          _TypeBadge(style: style, type: record.type),
          _AmountCell(record: record),
          _ActionCell(record: record, ctrl: ctrl, context: context),
        ],
      ),
    );
  }
}

// ── Sub-cells ─────────────────────────────────────────────────────────────────

class _DateCell extends StatelessWidget {
  const _DateCell({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('dd MMM yyyy').format(date),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PHTokens.slate700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('hh:mm a').format(date),
            style: const TextStyle(fontSize: 11, color: PHTokens.slate400),
          ),
        ],
      ),
    );
  }
}

class _SupplierCell extends StatelessWidget {
  const _SupplierCell({required this.record, required this.ctrl});
  final PurchaseRecord record;
  final GlobalPurchaseHistoryController ctrl;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Obx(
        () => Text(
          ctrl.debtorNameCache[record.debtorId] ?? '—',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: PHTokens.slate900,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.style, required this.type});

  final ({Color bg, Color fg, IconData icon}) style;
  final String type;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(PHTokens.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(style.icon, size: 11, color: style.fg),
                const SizedBox(width: 5),
                Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: style.fg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountCell extends StatelessWidget {
  const _AmountCell({required this.record});
  final PurchaseRecord record;

  Color get _color {
    return switch (record.type) {
      'invoice' => PHTokens.slate700,
      'payment' => PHTokens.green,
      _ => PHTokens.amber,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 2,
      child: Text(
        '৳${record.amount.toStringAsFixed(2)}',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _color,
        ),
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({
    required this.record,
    required this.ctrl,
    required this.context,
  });

  final PurchaseRecord record;
  final GlobalPurchaseHistoryController ctrl;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    if (record.type != 'invoice') return const SizedBox(width: 72);

    return SizedBox(
      width: 72,
      child: Center(
        child: Tooltip(
          message: 'View / Edit Invoice',
          child: InkWell(
            onTap: () => PHInvoiceDetailDialog.show(context, ctrl, record),
            borderRadius: BorderRadius.circular(PHTokens.radiusMd),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: PHTokens.blueLight,
                borderRadius: BorderRadius.circular(PHTokens.radiusMd),
              ),
              child: const Icon(
                Icons.visibility_outlined,
                color: PHTokens.blue,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
