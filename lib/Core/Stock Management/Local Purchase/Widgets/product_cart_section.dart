import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Stock%20Management/Local%20Purchase/purchase_controller.dart';
import '../local_purchase_page.dart';

class PurchaseCartSection extends StatelessWidget {
  final DebtorPurchaseController purchaseCtrl;
  final TextEditingController noteController;
  final Rx<DateTime> selectedDate;
  final bool isMobile;
  final Future<void> Function() onFinalize;

  const PurchaseCartSection({
    super.key,
    required this.purchaseCtrl,
    required this.noteController,
    required this.selectedDate,
    required this.isMobile,
    required this.onFinalize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cart header
        const _CartHeader(),

        // Column headers
        const _CartColumnHeader(),

        const Divider(height: 1),

        // Cart items list
        isMobile
            ? _CartList(purchaseCtrl: purchaseCtrl, isMobile: true)
            : Expanded(
              child: _CartList(purchaseCtrl: purchaseCtrl, isMobile: false),
            ),

        const Divider(height: 1, thickness: 1),

        // Footer — total, note, finalize
        _CartFooter(
          purchaseCtrl: purchaseCtrl,
          noteController: noteController,
          selectedDate: selectedDate,
          onFinalize: onFinalize,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cart Header
// ─────────────────────────────────────────────────────────────
class _CartHeader extends StatelessWidget {
  const _CartHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shopping_cart, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text(
            'Purchase Cart Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Column Header Row
// ─────────────────────────────────────────────────────────────
class _CartColumnHeader extends StatelessWidget {
  const _CartColumnHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgGrey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Item',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Qty',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Subtotal',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cart List
// ─────────────────────────────────────────────────────────────
class _CartList extends StatelessWidget {
  final DebtorPurchaseController purchaseCtrl;
  final bool isMobile;

  const _CartList({required this.purchaseCtrl, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (purchaseCtrl.cartItems.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ), // was: EdgeInsets.all(40)
            child: Column(
              mainAxisSize: MainAxisSize.min, // ADD THIS
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.remove_shopping_cart,
                  size: 40,
                  color: Colors.black12,
                ), // was: size: 60
                SizedBox(height: 8), // was: 16
                Text(
                  'Cart is currently empty',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ), // was: 16
              ],
            ),
          ),
        );
      }

      return ListView.separated(
        shrinkWrap: isMobile,
        physics:
            isMobile
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
        itemCount: purchaseCtrl.cartItems.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = purchaseCtrl.cartItems[index];
          return _CartItemRow(
            item: item,
            onDelete: () => purchaseCtrl.cartItems.removeAt(index),
          );
        },
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// Cart Item Row
// ─────────────────────────────────────────────────────────────
class _CartItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;

  const _CartItemRow({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['model']} - ${item['name']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Loc: ${item['location']} | Cost: ৳${item['cost']}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item['qty']}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '৳${item['subtotal']}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.teal,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.redAccent,
              size: 20,
            ),
            onPressed: onDelete,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cart Footer — grand total, date, note, finalize
// ─────────────────────────────────────────────────────────────
class _CartFooter extends StatelessWidget {
  final DebtorPurchaseController purchaseCtrl;
  final TextEditingController noteController;
  final Rx<DateTime> selectedDate;
  final Future<void> Function() onFinalize;

  const _CartFooter({
    required this.purchaseCtrl,
    required this.noteController,
    required this.selectedDate,
    required this.onFinalize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // Grand total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              Obx(() {
                final total = purchaseCtrl.cartItems.fold<double>(
                  0,
                  (sum, item) => sum + (item['subtotal'] as num).toDouble(),
                );
                return Text(
                  '৳${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: activeAccent,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // Date picker
          Obx(
            () => InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate.value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) selectedDate.value = picked;
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Purchase Date',
                  labelStyle: const TextStyle(fontSize: 11),
                  prefixIcon: const Icon(
                    Icons.calendar_today,
                    color: textLight,
                    size: 18,
                  ),
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
                child: Text(
                  '${selectedDate.value.day}/${selectedDate.value.month}/${selectedDate.value.year}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Note field
          TextField(
            controller: noteController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Purchase Note / Invoice No. (Optional)',
              labelStyle: const TextStyle(fontSize: 11),
              prefixIcon: const Icon(Icons.note_alt_outlined, color: textLight),
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
          ),
          const SizedBox(height: 20),

          // Finalize button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: Obx(
              () => ElevatedButton(
                onPressed: purchaseCtrl.isLoading.value ? null : onFinalize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:
                    purchaseCtrl.isLoading.value
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'Finalize & Post Purchase',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
