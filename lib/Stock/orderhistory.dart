import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gtel_erp/Stock/controller.dart';

class OrderHistoryPage extends StatelessWidget {
  const OrderHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Purchase Order History",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('order_history')
                .orderBy('date', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading order history."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No order history found.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;

              // Handle Timestamp formatting safely
              String dateStr = "Unknown Date";
              if (data['date'] != null) {
                DateTime dt = (data['date'] as Timestamp).toDate();
                dateStr =
                    "${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
              }

              final totalItems = data['total_items'] ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEFF6FF),
                    child: const Icon(
                      Icons.assignment,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  title: Text(
                    "Order Date: $dateStr",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    "Total Unique Models: $totalItems",
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                  trailing: ElevatedButton.icon(
                    onPressed: () => _showOrderDetails(context, doc.id),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text("View / Edit"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- Order Details Dialog (Edit / Delete / Add / Print) ---
  void _showOrderDetails(BuildContext context, String docId) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 700,
          constraints: const BoxConstraints(maxHeight: 800),
          padding: const EdgeInsets.all(24),
          child: StreamBuilder<DocumentSnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('order_history')
                    .doc(docId)
                    .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final List items = data['items'] ?? [];

              String dateStr = "";
              if (data['date'] != null) {
                DateTime dt = (data['date'] as Timestamp).toDate();
                dateStr = "${dt.day}/${dt.month}/${dt.year}";
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order Details - $dateStr",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Get.back(),
                      ),
                    ],
                  ),
                  const Divider(thickness: 1),

                  // Action Buttons (Add New Product & Print PDF)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showAddProductDialog(docId, items),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add New Product"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed:
                            items.isEmpty
                                ? null
                                : () => HistoryPdfGenerator.generateHistoryPdf(
                                  items,
                                  dateStr,
                                ),
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text("Reprint PDF"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Order Items List
                  Expanded(
                    child:
                        items.isEmpty
                            ? const Center(
                              child: Text(
                                "No items in this order.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                            : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    item['model'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(item['name']),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Edit Quantity Button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_square,
                                          color: Colors.blueGrey,
                                        ),
                                        tooltip: "Edit Qty",
                                        onPressed:
                                            () => _editItemQuantity(
                                              docId,
                                              items,
                                              index,
                                              item['order_qty'],
                                            ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Text(
                                          "${item['order_qty']}",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Delete Item Button
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        tooltip: "Remove Product",
                                        onPressed:
                                            () => _deleteItem(
                                              docId,
                                              items,
                                              index,
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- Functions to Update Firestore ---

  void _editItemQuantity(
    String docId,
    List currentItems,
    int index,
    int currentQty,
  ) {
    TextEditingController qtyCtrl = TextEditingController(
      text: currentQty.toString(),
    );
    Get.dialog(
      AlertDialog(
        title: const Text("Edit Quantity"),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: "New Quantity",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              int newQty = int.tryParse(qtyCtrl.text) ?? 0;
              if (newQty > 0) {
                currentItems[index]['order_qty'] = newQty;
                await FirebaseFirestore.instance
                    .collection('order_history')
                    .doc(docId)
                    .update({'items': currentItems});
                Get.back(); // close dialog
                Get.snackbar(
                  "Updated",
                  "Quantity updated successfully",
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteItem(String docId, List currentItems, int index) {
    Get.defaultDialog(
      title: "Remove Item?",
      middleText:
          "Are you sure you want to remove this product from the order?",
      textConfirm: "Yes, Remove",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        currentItems.removeAt(index);

        // If list is empty after removing, delete the whole document, else update it
        if (currentItems.isEmpty) {
          await FirebaseFirestore.instance
              .collection('order_history')
              .doc(docId)
              .delete();
          Get.back(); // close confirm dialog
          Get.back(); // close order details dialog
          Get.snackbar(
            "Deleted",
            "Order deleted because it was empty.",
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        } else {
          await FirebaseFirestore.instance
              .collection('order_history')
              .doc(docId)
              .update({
                'items': currentItems,
                'total_items': currentItems.length,
              });
          Get.back(); // close confirm dialog
        }
      },
    );
  }

  // --- Add New Product using ProductController ---
  void _showAddProductDialog(String docId, List currentItems) {
    final ProductController prodCtrl = Get.find<ProductController>();
    RxList<Map<String, dynamic>> searchResults = <Map<String, dynamic>>[].obs;
    RxBool isSearching = false.obs;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Search & Add Product",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  hintText: "Type Model or Name to search...",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) async {
                  if (val.length < 2) {
                    searchResults.clear();
                    return;
                  }
                  isSearching.value = true;
                  // Use your existing ProductController method
                  var results = await prodCtrl.searchProductsForDropdown(val);
                  searchResults.assignAll(results);
                  isSearching.value = false;
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  if (isSearching.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (searchResults.isEmpty) {
                    return const Center(
                      child: Text("No results. Type to search."),
                    );
                  }

                  return ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final productMap = searchResults[index];
                      return ListTile(
                        title: Text(
                          productMap['model'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(productMap['name']),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                          onPressed:
                              () => _promptQtyAndAdd(
                                docId,
                                currentItems,
                                productMap,
                              ),
                          child: const Text("Select"),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _promptQtyAndAdd(
    String docId,
    List currentItems,
    Map<String, dynamic> selectedProduct,
  ) {
    TextEditingController qtyCtrl = TextEditingController(text: "1");
    Get.dialog(
      AlertDialog(
        title: Text("Add ${selectedProduct['model']}"),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: "Order Quantity",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              int qty = int.tryParse(qtyCtrl.text) ?? 0;
              if (qty > 0) {
                // Check if item already exists in the order to prevent duplicates
                int existingIndex = currentItems.indexWhere(
                  (item) => item['product_id'] == selectedProduct['id'],
                );

                if (existingIndex != -1) {
                  // Add to existing quantity
                  currentItems[existingIndex]['order_qty'] += qty;
                } else {
                  // Add new item to the list
                  currentItems.add({
                    'product_id': selectedProduct['id'],
                    'model': selectedProduct['model'],
                    'name': selectedProduct['name'],
                    'order_qty': qty,
                  });
                }

                // Update Firestore
                await FirebaseFirestore.instance
                    .collection('order_history')
                    .doc(docId)
                    .update({
                      'items': currentItems,
                      'total_items': currentItems.length,
                    });

                Get.back(); // close Qty dialog
                Get.back(); // close Search dialog
                Get.snackbar(
                  "Added",
                  "${selectedProduct['model']} added to order.",
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text("Add to Order"),
          ),
        ],
      ),
    );
  }
}

// --- Professional Order PDF Generator for History --- //
class HistoryPdfGenerator {
  static Future<void> generateHistoryPdf(
    List<dynamic> items,
    String orderDate,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "PURCHASE ORDER LIST",
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.Text(
                    "Order Date: $orderDate",
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              "Reprinted Order Report",
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),

            // Structured specifically: No. -> Product Name -> Model -> Order Quantity
            pw.TableHelper.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue100,
              ),
              headerHeight: 40,
              cellHeight: 30,
              headerStyle: pw.TextStyle(
                color: PdfColors.black,
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headers: ['No.', 'Product Name', 'Model', 'Order Quantity'],
              data: List<List<String>>.generate(
                items.length,
                (index) => [
                  (index + 1).toString(),
                  items[index]['name'] ?? '-',
                  items[index]['model'] ?? '-',
                  items[index]['order_qty'].toString(),
                ],
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  "Total Ordered Models: ${items.length}",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Reprint_Order_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}