import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Shared/ph_form_widgets.dart';
import '../Views/ph_tokens.dart';
import '../purchase_controller.dart';

abstract final class PHInvoiceDetailDialog {
  static void show(
    BuildContext context,
    GlobalPurchaseHistoryController ctrl,
    PurchaseRecord record,
  ) {
    showDialog(
      context: context,
      builder: (_) => _PHInvoiceDetailContent(ctrl: ctrl, record: record),
    );
  }
}

class _PHInvoiceDetailContent extends StatefulWidget {
  const _PHInvoiceDetailContent({required this.ctrl, required this.record});

  final GlobalPurchaseHistoryController ctrl;
  final PurchaseRecord record;

  @override
  State<_PHInvoiceDetailContent> createState() =>
      _PHInvoiceDetailContentState();
}

class _PHInvoiceDetailContentState extends State<_PHInvoiceDetailContent> {
  bool _editing = false;

  late List<Map<String, dynamic>> _editedItems;
  late List<TextEditingController> _qtyCtrls;
  late List<TextEditingController> _costCtrls;

  @override
  void initState() {
    super.initState();

    _editedItems =
        widget.record.items.map((item) {
          return Map<String, dynamic>.from(item);
        }).toList();

    _initControllers();
  }

  void _initControllers() {
    _qtyCtrls =
        _editedItems.map((item) {
          return TextEditingController(text: item['qty'].toString());
        }).toList();

    _costCtrls =
        _editedItems.map((item) {
          return TextEditingController(text: item['cost'].toString());
        }).toList();
  }

  @override
  void dispose() {
    for (final controller in _qtyCtrls) {
      controller.dispose();
    }

    for (final controller in _costCtrls) {
      controller.dispose();
    }

    super.dispose();
  }

  double get _currentTotal {
    if (!_editing) return widget.record.amount;

    double sum = 0;

    for (int i = 0; i < _editedItems.length; i++) {
      final qty = int.tryParse(_qtyCtrls[i].text) ?? 0;
      final cost = double.tryParse(_costCtrls[i].text) ?? 0;
      sum += qty * cost;
    }

    return sum;
  }

  void _saveChanges() {
    for (int i = 0; i < _editedItems.length; i++) {
      final qty = int.tryParse(_qtyCtrls[i].text) ?? 0;
      final cost = double.tryParse(_costCtrls[i].text) ?? 0.0;

      _editedItems[i]['qty'] = qty;
      _editedItems[i]['cost'] = cost;
      _editedItems[i]['subtotal'] = qty * cost;

      _editedItems[i]['stockType'] =
          _editedItems[i]['stockType'] ??
          _editedItems[i]['location'] ??
          'Local';
      _editedItems[i]['location'] = _editedItems[i]['stockType'];
      _editedItems[i]['warehouseId'] = _editedItems[i]['warehouseId'] ?? 0;
      _editedItems[i]['warehouseName'] = _editedItems[i]['warehouseName'] ?? '';
      _editedItems[i]['warehouseLocation'] =
          _editedItems[i]['warehouseLocation'] ?? '';
    }

    widget.ctrl.editPurchase(
      debtorId: widget.record.debtorId,
      purchaseId: widget.record.id,
      oldItems: List<Map<String, dynamic>>.from(widget.record.items),
      newItems: _editedItems,
      oldTotal: widget.record.amount,
      newTotal: _currentTotal,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PHTokens.radiusXl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PHInvoiceHeader(
                ctrl: widget.ctrl,
                record: widget.record,
                editing: _editing,
                onEdit: () => setState(() => _editing = true),
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 18),
              Flexible(
                child: _PHInvoiceItemsTable(
                  editedItems: _editedItems,
                  qtyCtrls: _qtyCtrls,
                  costCtrls: _costCtrls,
                  editing: _editing,
                  onChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 18),
              _PHInvoiceFooter(
                ctrl: widget.ctrl,
                record: widget.record,
                editing: _editing,
                currentTotal: _currentTotal,
                onSave: _saveChanges,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PHInvoiceHeader extends StatelessWidget {
  const _PHInvoiceHeader({
    required this.ctrl,
    required this.record,
    required this.editing,
    required this.onEdit,
    required this.onClose,
  });

  final GlobalPurchaseHistoryController ctrl;
  final PurchaseRecord record;
  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: PHTokens.blueLight,
            borderRadius: BorderRadius.circular(PHTokens.radiusLg),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: PHTokens.blue,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing ? 'Edit Purchase Invoice' : 'Invoice Details',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: PHTokens.slate900,
                ),
              ),
              Obx(
                () => Text(
                  ctrl.debtorNameCache[record.debtorId] ?? '-',
                  style: const TextStyle(fontSize: 12, color: PHTokens.blue),
                ),
              ),
            ],
          ),
        ),
        if (!editing) ...[
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('Edit', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: PHTokens.slate700,
              side: const BorderSide(color: PHTokens.slate200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PHTokens.radiusMd),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        IconButton(
          icon: const Icon(Icons.close, size: 17),
          onPressed: onClose,
          color: PHTokens.slate400,
        ),
      ],
    );
  }
}

class _PHInvoiceItemsTable extends StatelessWidget {
  const _PHInvoiceItemsTable({
    required this.editedItems,
    required this.qtyCtrls,
    required this.costCtrls,
    required this.editing,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> editedItems;
  final List<TextEditingController> qtyCtrls;
  final List<TextEditingController> costCtrls;
  final bool editing;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: PHTokens.slate200),
        borderRadius: BorderRadius.circular(PHTokens.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TableHeaderRow(),
          const Divider(height: 1, color: PHTokens.slate200),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: editedItems.length,
              separatorBuilder:
                  (_, __) => const Divider(height: 1, color: PHTokens.slate200),
              itemBuilder: (_, index) {
                return _PHItemRow(
                  item: editedItems[index],
                  qtyCtrl: qtyCtrls[index],
                  costCtrl: costCtrls[index],
                  editing: editing,
                  onChanged: onChanged,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: PHTokens.slate100,
        borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 4,
            child: Text('ITEM', style: PHTokens.tableHeaderCell),
          ),
          Expanded(
            flex: 2,
            child: Text('TYPE', style: PHTokens.tableHeaderCell),
          ),
          Expanded(
            flex: 3,
            child: Text('WAREHOUSE', style: PHTokens.tableHeaderCell),
          ),
          Expanded(
            flex: 2,
            child: Text('QTY', style: PHTokens.tableHeaderCell),
          ),
          Expanded(
            flex: 2,
            child: Text('COST', style: PHTokens.tableHeaderCell),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'SUBTOTAL',
              textAlign: TextAlign.right,
              style: PHTokens.tableHeaderCell,
            ),
          ),
        ],
      ),
    );
  }
}

class _PHItemRow extends StatelessWidget {
  const _PHItemRow({
    required this.item,
    required this.qtyCtrl,
    required this.costCtrl,
    required this.editing,
    required this.onChanged,
  });

  final Map<String, dynamic> item;
  final TextEditingController qtyCtrl;
  final TextEditingController costCtrl;
  final bool editing;
  final VoidCallback onChanged;

  double get _subtotal {
    if (editing) {
      return (int.tryParse(qtyCtrl.text) ?? 0) *
          (double.tryParse(costCtrl.text) ?? 0);
    }

    return _toDouble(item['subtotal']);
  }

  @override
  Widget build(BuildContext context) {
    final stockType = GlobalPurchaseHistoryController.stockTypeOf(item);
    final warehouse = GlobalPurchaseHistoryController.warehouseNameOf(item);
    final location = GlobalPurchaseHistoryController.warehouseLocationOf(item);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PHTokens.slate900,
                  ),
                ),
                Text(
                  item['model']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: PHTokens.slate400,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              stockType,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PHTokens.blue,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Tooltip(
              message: '$warehouse\n$location',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warehouse,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: PHTokens.slate700,
                    ),
                  ),
                  Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PHTokens.slate400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child:
                editing
                    ? PHInlineField(
                      controller: qtyCtrl,
                      onChanged: (_) => onChanged(),
                    )
                    : Text(
                      item['qty'].toString(),
                      style: const TextStyle(fontSize: 13),
                    ),
          ),
          Expanded(
            flex: 2,
            child:
                editing
                    ? PHInlineField(
                      controller: costCtrl,
                      onChanged: (_) => onChanged(),
                    )
                    : Text(
                      GlobalPurchaseHistoryController.money(item['cost']),
                      style: const TextStyle(fontSize: 13),
                    ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              GlobalPurchaseHistoryController.money(_subtotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PHTokens.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PHInvoiceFooter extends StatelessWidget {
  const _PHInvoiceFooter({
    required this.ctrl,
    required this.record,
    required this.editing,
    required this.currentTotal,
    required this.onSave,
  });

  final GlobalPurchaseHistoryController ctrl;
  final PurchaseRecord record;
  final bool editing;
  final double currentTotal;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Grand Total: ${GlobalPurchaseHistoryController.money(currentTotal)}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: PHTokens.slate900,
            ),
          ),
        ),
        if (editing)
          _SaveButton(onSave: onSave)
        else
          _DownloadButton(ctrl: ctrl, record: record),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onSave});

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onSave,
      icon: const Icon(Icons.save_outlined, size: 15, color: Colors.white),
      label: const Text(
        'Save Changes',
        style: TextStyle(color: Colors.white, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: PHTokens.green,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PHTokens.radiusMd),
        ),
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.ctrl, required this.record});

  final GlobalPurchaseHistoryController ctrl;
  final PurchaseRecord record;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ElevatedButton.icon(
        onPressed:
            ctrl.isSinglePdfLoading.value
                ? null
                : () => ctrl.generateSingleInvoicePdf(record),
        icon:
            ctrl.isSinglePdfLoading.value
                ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const Icon(
                  Icons.download_outlined,
                  size: 15,
                  color: Colors.white,
                ),
        label: const Text(
          'Download Bill',
          style: TextStyle(color: Colors.white, fontSize: 13),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: PHTokens.slate900,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PHTokens.radiusMd),
          ),
        ),
      ),
    );
  }
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}