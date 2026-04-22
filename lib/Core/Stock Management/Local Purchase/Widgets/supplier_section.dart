import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/debtordartmodel.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/gteldebtorcontroller.dart';
import '../local_purchase_page.dart';
import 'add_suppliers_dialog.dart';

class SupplierSection extends StatelessWidget {
  final DebatorController debtorCtrl;
  final Rx<DebtorModel?> selectedSupplier;
  final void Function(TextEditingController) onSupplierFieldReady;

  const SupplierSection({
    super.key,
    required this.debtorCtrl,
    required this.selectedSupplier,
    required this.onSupplierFieldReady,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _StepLabel(step: '1', title: 'Select Supplier'),
              ElevatedButton.icon(
                onPressed:
                    () => Get.dialog(AddSupplierDialog(debtorCtrl: debtorCtrl)),
                icon: const Icon(
                  Icons.person_add,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'New Supplier',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkSlate,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Supplier search
          Autocomplete<DebtorModel>(
            displayStringForOption: (o) => '${o.name} (${o.phone})',
            optionsBuilder: (textEditingValue) async {
              final q = textEditingValue.text.trim();
              if (q.isEmpty) return const [];

              final qLower = q.toLowerCase();
              final terms = qLower.split(RegExp(r'\s+'));

              final Map<String, DebtorModel> results = {};

              // Firestore keyword search
              try {
                final snap =
                    await debtorCtrl.db
                        .collection('debatorbody')
                        .where('searchKeywords', arrayContains: terms.first)
                        .limit(20)
                        .get();
                for (final doc in snap.docs) {
                  results[doc.id] = DebtorModel.fromFirestore(doc);
                }
              } catch (_) {}

              // Local cache search
              for (final d in debtorCtrl.bodies) {
                results[d.id] = d;
              }

              return results.values.where((d) {
                final combined =
                    '${d.name} ${d.phone} ${d.nid} ${d.address}'.toLowerCase();
                return terms.every((t) => combined.contains(t));
              });
            },
            onSelected: (s) => selectedSupplier.value = s,
            fieldViewBuilder: (ctx, ctrl, focus, _) {
              onSupplierFieldReady(ctrl);
              return TextField(
                controller: ctrl,
                focusNode: focus,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Search Supplier by Name, Phone, NID...',
                  labelStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(Icons.business, color: textLight),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: bgGrey,
                ),
              );
            },
          ),

          // Selected supplier info
          Obx(() {
            final s = selectedSupplier.value;
            if (s == null) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: activeAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Selected: ${s.name}  |  '
                      'Current Payable: ৳${s.purchaseDue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: activeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Step label — shared between sections
// ─────────────────────────────────────────────────────────────
class _StepLabel extends StatelessWidget {
  final String step;
  final String title;

  const _StepLabel({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: activeAccent,
          child: Text(
            step,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
      ],
    );
  }
}
