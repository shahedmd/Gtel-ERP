// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controller.dart';
import '../Stock/model.dart';

class PurchasePage extends StatelessWidget {
  PurchasePage({super.key});

  final PurchaseController c = Get.put(PurchaseController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDE: Cart and Table (Invoice Area)
          Expanded(
            flex: 3,
            child: _buildInvoiceArea(),
          ),
         
          // RIGHT SIDE: Product Selection & Vendor Info (Sidebar Area)
          Expanded(
            flex: 2,
            child: _buildSidebar(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomSummary(),
    );
  }

  // ====================== APP BAR ======================
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.blue[900],
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text('PURCHASE TERMINAL', style: TextStyle(fontSize: 16, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
      actions: [
        TextButton.icon(
          onPressed: () => c.clearAll(),
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('RESET', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  // ====================== LEFT: INVOICE AREA ======================
  Widget _buildInvoiceArea() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _invoiceHeader(),
          const Divider(height: 1),
          Expanded(child: _cartTable()),
        ],
      ),
    );
  }

  Widget _invoiceHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("ITEM DETAILS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          Obx(() => Text("ITEMS: ${c.cart.length}", style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _cartTable() {
    return Obx(() {
      if (c.cart.isEmpty) {
        return const Center(child: Text("Cart is empty. Add products from the sidebar."));
      }
      return SingleChildScrollView(
        child: DataTable(
          headingRowHeight: 40,
          columnSpacing: 12,
          columns: const [
            DataColumn(label: Text('MODEL')),
            DataColumn(label: Text('PRICE')),
            DataColumn(label: Text('QTY')),
            DataColumn(label: Text('TOTAL')),
            DataColumn(label: Text('')),
          ],
          rows: c.cart.map((item) {
            final total = item.product.sea * item.qty.value;
            return DataRow(cells: [
              DataCell(Text(item.product.model, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              DataCell(Text(item.product.sea.toStringAsFixed(0))),
              DataCell(
                Row(
                  children: [
                    _qtyBtn(Icons.remove, () => c.decreaseQty(item)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text("${item.qty.value}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    _qtyBtn(Icons.add, () => c.increaseQty(item)),
                  ],
                ),
              ),
              DataCell(Text(total.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
              DataCell(IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 18), onPressed: () => c.removeItem(item))),
            ]);
          }).toList(),
        ),
      );
    });
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, size: 14),
      ),
    );
  }

  // ====================== RIGHT: SIDEBAR ======================
  Widget _buildSidebar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
      child: Column(
        children: [
          _vendorBox(),
          const SizedBox(height: 16),
          _productSearchBox(),
        ],
      ),
    );
  }

  Widget _vendorBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("VENDOR SELECTION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          TextField(
            controller: c.phoneC,
            onChanged: c.searchVendorByPhone,
            decoration: const InputDecoration(labelText: "Phone Number", prefixIcon: Icon(Icons.phone, size: 18), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Obx(() => Text(
                c.vendorExists.value ? "Vendor: ${c.vendorNameC.text}" : "New Vendor Mode",
                style: TextStyle(color: c.vendorExists.value ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
              )),
          Text(c.shopNameC.text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _productSearchBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("QUICK PRODUCT ADD", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => c.productC.search(v),
            decoration: const InputDecoration(hintText: "Search model...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Obx(() {
            final results = c.productC.allProducts; // Updated controller uses allProducts
            return Column(
              children: results.take(5).map((p) => _searchResultItem(p)).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _searchResultItem(Product p) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(p.model, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      subtitle: Text("Price: ${p.sea} | Stock: ${p.stockQty}", style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.add_circle, color: Colors.blue),
      onTap: () => c.addProduct(p),
    );
  }

  // ====================== BOTTOM: SUMMARY ======================
  Widget _buildBottomSummary() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          // TOTAL CALCULATION
          Expanded(
            child: Obx(() {
              double total = c.cart.fold(0, (sum, item) => sum + (item.qty.value * item.product.sea));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("GRAND TOTAL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text("${total.toStringAsFixed(0)} BDT", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              );
            }),
          ),
         
          // ACTION BUTTON
          SizedBox(
            width: 250,
            height: 60,
            child: Obx(() => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: (c.cart.isEmpty || c.isProcessing.value) ? null : () => _confirmPurchase(),
                  child: c.isProcessing.value
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("COMPLETE PURCHASE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                )),
          ),
        ],
      ),
    );
  }

  void _confirmPurchase() {
    Get.defaultDialog(
      title: "Confirm Purchase",
      middleText: "Are you sure you want to complete this transaction and update stock?",
      textConfirm: "YES, PROCESS",
      textCancel: "CANCEL",
      confirmTextColor: Colors.white,
      buttonColor: Colors.blue[900],
      onConfirm: () {
        Get.back();
        c.completePurchase();
      },
    );
  }
}