import 'package:flutter/material.dart';
import 'package:get/get.dart';

typedef ReturnConfirmCallback = Future<void> Function(int logId, int qty);

/// Stateful dialog for returning service items to stock.
///
/// Accepts a [ReturnConfirmCallback] instead of a direct controller reference,
/// making it easy to test and reuse.
class ReturnStockDialog extends StatefulWidget {
  const ReturnStockDialog({
    super.key,
    required this.logId,
    required this.modelName,
    required this.maxQty,
    required this.onConfirm,
  });

  final int                   logId;
  final String                modelName;
  final int                   maxQty;
  final ReturnConfirmCallback onConfirm;

  @override
  State<ReturnStockDialog> createState() => _ReturnStockDialogState();
}

class _ReturnStockDialogState extends State<ReturnStockDialog> {
  late final TextEditingController _qtyCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.maxQty.toString());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;

    if (qty <= 0) {
      _showError('Quantity must be at least 1.');
      return;
    }
    if (qty > widget.maxQty) {
      _showError('Cannot return more than ${widget.maxQty}.');
      return;
    }

    setState(() => _submitting = true);
    Get.back(); // close dialog before async work
    await widget.onConfirm(widget.logId, qty);
  }

  void _showError(String msg) => Get.snackbar(
        'Validation Error',
        msg,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text(
        'Return to Stock',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
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
      ]),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
          ),
          child: _submitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirm'),
        ),
      ],
    );
  }
}