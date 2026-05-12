import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock%20Management/Local%20Purchase/purchase_controller.dart';

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
        const _CartHeader(),
        if (!isMobile) const _CartColumnHeader(),
        const Divider(height: 1),
        isMobile
            ? _CartList(purchaseCtrl: purchaseCtrl, isMobile: true)
            : Expanded(
                child: _CartList(purchaseCtrl: purchaseCtrl, isMobile: false),
              ),
        const Divider(height: 1),
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

class _CartHeader extends StatelessWidget {
  const _CartHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: const BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shopping_cart, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Purchase Cart Summary',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
            flex: 4,
            child: Text(
              'Item',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Warehouse',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              'Qty',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 100,
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

class _CartList extends StatelessWidget {
  final DebtorPurchaseController purchaseCtrl;
  final bool isMobile;

  const _CartList({
    required this.purchaseCtrl,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (purchaseCtrl.cartItems.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.remove_shopping_cart,
                  size: 42,
                  color: Colors.black12,
                ),
                SizedBox(height: 10),
                Text(
                  'Cart is currently empty',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }

      return ListView.separated(
        shrinkWrap: isMobile,
        physics: isMobile
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        itemCount: purchaseCtrl.cartItems.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = purchaseCtrl.cartItems[index];

          return _CartItemRow(
            item: item,
            isMobile: isMobile,
            onDelete: () => purchaseCtrl.cartItems.removeAt(index),
          );
        },
      );
    });
  }
}

class _CartItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isMobile;
  final VoidCallback onDelete;

  const _CartItemRow({
    required this.item,
    required this.isMobile,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final model = item['model']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    final stockType = item['stockType']?.toString() ??
        item['location']?.toString() ??
        'Local';
    final warehouseName = item['warehouseName']?.toString() ?? '';
    final warehouseLocation = item['warehouseLocation']?.toString() ?? '';
    final qty = _toInt(item['qty']);
    final cost = _toDouble(item['cost']);
    final subtotal = _toDouble(item['subtotal']);

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MobileItemBody(
                model: model,
                name: name,
                stockType: stockType,
                warehouseName: warehouseName,
                warehouseLocation: warehouseLocation,
                qty: qty,
                cost: cost,
                subtotal: subtotal,
              ),
            ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: _ItemTitle(
              model: model,
              name: name,
              stockType: stockType,
              cost: cost,
            ),
          ),
          Expanded(
            flex: 2,
            child: _WarehouseText(
              warehouseName: warehouseName,
              warehouseLocation: warehouseLocation,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              qty.toString(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              _money(subtotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
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

class _MobileItemBody extends StatelessWidget {
  final String model;
  final String name;
  final String stockType;
  final String warehouseName;
  final String warehouseLocation;
  final int qty;
  final double cost;
  final double subtotal;

  const _MobileItemBody({
    required this.model,
    required this.name,
    required this.stockType,
    required this.warehouseName,
    required this.warehouseLocation,
    required this.qty,
    required this.cost,
    required this.subtotal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ItemTitle(
          model: model,
          name: name,
          stockType: stockType,
          cost: cost,
        ),
        const SizedBox(height: 8),
        _WarehouseText(
          warehouseName: warehouseName,
          warehouseLocation: warehouseLocation,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _MiniPill(label: 'Qty', value: qty.toString()),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _money(subtotal),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.teal,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ItemTitle extends StatelessWidget {
  final String model;
  final String name;
  final String stockType;
  final double cost;

  const _ItemTitle({
    required this.model,
    required this.name,
    required this.stockType,
    required this.cost,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$model - $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Type: $stockType | Cost: ${_money(cost)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}

class _WarehouseText extends StatelessWidget {
  final String warehouseName;
  final String warehouseLocation;

  const _WarehouseText({
    required this.warehouseName,
    required this.warehouseLocation,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = warehouseName.trim().isEmpty ? 'Warehouse' : warehouseName;
    final displayLocation = warehouseLocation.trim().isEmpty
        ? 'No location'
        : warehouseLocation;

    return Tooltip(
      message: '$displayName\n$displayLocation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            displayLocation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final String value;

  const _MiniPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Grand Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                  ),
                ),
              ),
              Obx(() {
                final total = purchaseCtrl.cartItems.fold<double>(
                  0,
                  (sum, item) => sum + _toDouble(item['subtotal']),
                );

                return Text(
                  _money(total),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: activeAccent,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          Obx(
            () => InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate.value,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );

                if (picked != null) {
                  selectedDate.value = picked;
                }
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
          SizedBox(
            width: double.infinity,
            height: 55,
            child: Obx(
              () => ElevatedButton(
                onPressed: purchaseCtrl.isLoading.value ? null : onFinalize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeAccent,
                  disabledBackgroundColor: activeAccent.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: purchaseCtrl.isLoading.value
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Finalize & Post Purchase',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0,
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

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

String _money(dynamic value) {
  return 'Tk ${_toDouble(value).toStringAsFixed(2)}';
}