import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../stock_controller.dart';

typedef ReturnConfirmCallback = Future<void> Function(
  int logId,
  int qty, {
  int? warehouseId,
  String warehouseLocation,
});

class ReturnStockDialog extends StatefulWidget {
  const ReturnStockDialog({
    super.key,
    required this.logId,
    required this.modelName,
    required this.maxQty,
    required this.controller,
    required this.onConfirm,
  });

  final int logId;
  final String modelName;
  final int maxQty;
  final ProductController controller;
  final ReturnConfirmCallback onConfirm;

  @override
  State<ReturnStockDialog> createState() => _ReturnStockDialogState();
}

class _ReturnStockDialogState extends State<ReturnStockDialog> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _locationCtrl;
  final RxnInt _warehouseId = RxnInt();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.maxQty.toString());
    _locationCtrl = TextEditingController();

    final warehouses = widget.controller.activeWarehouses;
    if (warehouses.isNotEmpty) {
      _warehouseId.value = _parseInt(warehouses.first['id']);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final warehouseId = _warehouseId.value;

    if (qty <= 0) {
      _showError('Quantity must be at least 1.');
      return;
    }

    if (qty > widget.maxQty) {
      _showError('Cannot return more than ${widget.maxQty}.');
      return;
    }

    if (warehouseId == null || warehouseId <= 0) {
      _showError('Please select a warehouse.');
      return;
    }

    setState(() => _submitting = true);

    await widget.onConfirm(
      widget.logId,
      qty,
      warehouseId: warehouseId,
      warehouseLocation: _locationCtrl.text.trim(),
    );

    if (mounted) Get.back();
  }

  void _showError(String msg) {
    Get.snackbar(
      'Validation Error',
      msg,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Return to Stock',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Return "${widget.modelName}" from service?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Max available: ${widget.maxQty}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Obx(() {
              final warehouses = widget.controller.activeWarehouses;

              return DropdownButtonFormField<int>(
                value: _warehouseId.value,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Return to warehouse',
                  prefixIcon: Icon(Icons.warehouse_rounded),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: warehouses.map((warehouse) {
                  final id = _parseInt(warehouse['id']);
                  final name = warehouse['name']?.toString() ?? 'Warehouse $id';

                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) => _warehouseId.value = value,
              );
            }),
            const SizedBox(height: 12),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Warehouse location',
                hintText: 'Example: Rack A-3, Box 12',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : Get.back,
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}
