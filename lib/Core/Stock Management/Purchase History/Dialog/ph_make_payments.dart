import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Shared/ph_form_widgets.dart';
import '../Views/ph_tokens.dart';
import '../purchase_controller.dart';

abstract final class PHMakePaymentDialog {
  static void show(GlobalPurchaseHistoryController ctrl) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PHTokens.radiusXl),
        ),
        child: _PHMakePaymentContent(ctrl: ctrl),
      ),
    );
  }
}

class _PHMakePaymentContent extends StatefulWidget {
  const _PHMakePaymentContent({required this.ctrl});
  final GlobalPurchaseHistoryController ctrl;

  @override
  State<_PHMakePaymentContent> createState() => _PHMakePaymentContentState();
}

class _PHMakePaymentContentState extends State<_PHMakePaymentContent> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _method = 'Cash'.obs;
  Map<String, dynamic>? _selectedSupplier;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedSupplier == null) {
      Get.snackbar('Validation', 'Please select a supplier.');
      return;
    }
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amt <= 0) {
      Get.snackbar('Validation', 'Enter a valid amount.');
      return;
    }
    widget.ctrl.makePayment(
      debtorId: _selectedSupplier!['id'],
      debtorName: _selectedSupplier!['name'],
      amount: amt,
      method: _method.value,
      note: _noteCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 440,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogHeader(
              icon: Icons.payments_outlined,
              iconBg: PHTokens.greenLight,
              iconColor: PHTokens.green,
              title: 'Make Payment',
            ),
            const SizedBox(height: 6),
            const Divider(color: PHTokens.slate200),
            const SizedBox(height: 16),

            PHDialogSection(
              label: 'Supplier',
              child: PHDialogSupplierSearch(
                ctrl: widget.ctrl,
                onSelect: (s) => _selectedSupplier = s,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: PHDialogSection(
                    label: 'Amount (৳)',
                    child: PHDialogTextField(
                      controller: _amountCtrl,
                      hint: '0.00',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PHDialogSection(
                    label: 'Method',
                    child: Obx(
                      () => PHDialogDropdown<String>(
                        value: _method.value,
                        items: const ['Cash', 'Bank', 'Bkash', 'Nagad'],
                        onChanged: (v) => _method.value = v!,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            PHDialogSection(
              label: 'Note / Reference',
              child: PHDialogTextField(
                controller: _noteCtrl,
                hint: 'Optional…',
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: Get.back,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: PHTokens.slate400, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PHTokens.green,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PHTokens.radiusMd),
                    ),
                  ),
                  child: const Text(
                    'Confirm Payment',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG SUPPLIER SEARCH  (inline list, no overlay needed inside a dialog)
// ─────────────────────────────────────────────────────────────────────────────

class PHDialogSupplierSearch extends StatefulWidget {
  const PHDialogSupplierSearch({
    super.key,
    required this.ctrl,
    required this.onSelect,
  });

  final GlobalPurchaseHistoryController ctrl;
  final void Function(Map<String, dynamic> supplier) onSelect;

  @override
  State<PHDialogSupplierSearch> createState() => _PHDialogSupplierSearchState();
}

class _PHDialogSupplierSearchState extends State<PHDialogSupplierSearch> {
  final _textCtrl = TextEditingController();
  bool _showList = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _textCtrl,
          style: const TextStyle(fontSize: 13),
          decoration: PHTokens.inputDecoration(
            hint: 'Search by name or phone…',
            prefix: const Icon(
              Icons.business_outlined,
              size: 16,
              color: PHTokens.slate400,
            ),
          ),
          onChanged: (v) {
            widget.ctrl.searchSupplier(v);
            setState(() => _showList = v.trim().isNotEmpty);
          },
        ),
        if (_showList) ...[
          const SizedBox(height: 4),
          Obx(() {
            if (widget.ctrl.isSearchingSupplier.value) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PHTokens.blue,
                  ),
                ),
              );
            }
            if (widget.ctrl.searchedSuppliers.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'No results found.',
                  style: TextStyle(fontSize: 12, color: PHTokens.slate400),
                ),
              );
            }
            return Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                border: Border.all(color: PHTokens.slate200),
                borderRadius: BorderRadius.circular(PHTokens.radiusMd),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: widget.ctrl.searchedSuppliers.length,
                separatorBuilder:
                    (_, __) =>
                        const Divider(height: 1, color: PHTokens.slate200),
                itemBuilder: (_, i) {
                  final s = widget.ctrl.searchedSuppliers[i];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(
                      s['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle:
                        (s['phone']?.toString().isNotEmpty ?? false)
                            ? Text(
                              s['phone'],
                              style: const TextStyle(
                                fontSize: 11,
                                color: PHTokens.slate400,
                              ),
                            )
                            : null,
                    onTap: () {
                      _textCtrl.text = s['name'] ?? '';
                      widget.onSelect(s);
                      setState(() => _showList = false);
                    },
                  );
                },
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED DIALOG HEADER  (reused by both dialogs)
// ─────────────────────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onClose,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(PHTokens.radiusLg),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: PHTokens.slate900,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: PHTokens.blue),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 17),
          onPressed: onClose ?? Get.back,
          color: PHTokens.slate400,
        ),
      ],
    );
  }
}
