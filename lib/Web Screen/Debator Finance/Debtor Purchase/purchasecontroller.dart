// ignore_for_file: avoid_print, empty_catches, deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/debatorcontroller.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DebtorPurchaseController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Dependencies
  final ProductController stockCtrl = Get.find<ProductController>();
  final DebatorController debtorCtrl = Get.find<DebatorController>();
  final DailyExpensesController dailyExpenseCtrl =
      Get.isRegistered<DailyExpensesController>()
          ? Get.find<DailyExpensesController>()
          : Get.put(DailyExpensesController());

  // --- STATE VARIABLES ---
  var purchases = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;
  var isGeneratingPdf = false.obs;

  // Cart & Search
  var productSearchList = <Map<String, dynamic>>[].obs;
  var cartItems = <Map<String, dynamic>>[].obs;

  // Stats (Observables)
  var totalPurchased = 0.0.obs;
  var totalPaid = 0.0.obs;
  double get currentPayable => totalPurchased.value - totalPaid.value;

  // --- PAGINATION STATE ---
  final int _pageSize = 10;
  DocumentSnapshot? _lastDocument;
  var hasMore = true.obs;
  var isFirstPage = true.obs;
  // Stack to store the first document of previous pages to allow "Back" navigation
  final List<DocumentSnapshot?> _pageStartStack = [];

  // ----------------------------------------------------------------
  // 1. DATA LOADING & PAGINATION
  // ----------------------------------------------------------------

  // Initial Load (First Page)
  Future<void> loadPurchases(String debtorId) async {
    _pageStartStack.clear();
    _lastDocument = null;
    isFirstPage.value = true;
    await _fetchPage(debtorId);
    await _fetchAccurateStats(debtorId); // Calc totals via Aggregation
  }

  // Next Page
  Future<void> nextPage(String debtorId) async {
    if (!hasMore.value || isLoading.value) return;
    if (purchases.isNotEmpty && _lastDocument != null) {
      _pageStartStack.add(
        purchases.first['snapshot'],
      ); // Save current start for back nav
      isFirstPage.value = false;
      await _fetchPage(debtorId, startAfter: _lastDocument);
    }
  }

  // Previous Page
  Future<void> previousPage(String debtorId) async {
    if (_pageStartStack.isEmpty || isLoading.value) return;

    // Pop the previous start point
    DocumentSnapshot? prevStart = _pageStartStack.removeLast();

    if (_pageStartStack.isEmpty) {
      isFirstPage.value = true; // We are back at start
    }

    // To go back effectively in Firestore without 'endBefore' complexity,
    // we simply reload starting AT the popped snapshot.
    // Note: We need to use startAtDocument for the prev page's first item.
    await _fetchPage(debtorId, startAt: prevStart);
  }

  // Core Fetch Logic
  Future<void> _fetchPage(
    String debtorId, {
    DocumentSnapshot? startAfter,
    DocumentSnapshot? startAt,
  }) async {
    isLoading.value = true;
    try {
      Query query = _db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('purchases')
          .orderBy('date', descending: true)
          .limit(_pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      } else if (startAt != null) {
        query = query.startAtDocument(startAt);
      }

      QuerySnapshot snap = await query.get();

      if (snap.docs.isNotEmpty) {
        _lastDocument = snap.docs.last;
        hasMore.value = snap.docs.length == _pageSize;

        purchases.value =
            snap.docs.map((d) {
              var data = d.data() as Map<String, dynamic>;
              data['id'] = d.id;
              data['snapshot'] = d; // Keep ref for internal use
              return data;
            }).toList();
      } else {
        hasMore.value = false;
        // If we tried to go next but failed, don't clear list, just stay.
        // But for initial load, clear.
        if (startAfter == null && startAt == null) purchases.clear();
      }
    } catch (e) {
      Get.snackbar("Error", "Could not load data: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // Calculate Accurate Stats using Server-Side Aggregation
  // (Since we are paginating, we can't sum the list locally)
  Future<void> _fetchAccurateStats(String debtorId) async {
    try {
      // Note: Firestore Aggregation is cheapest way to sum if many docs.
      // If you don't have Aggregation enabled or it's complex, we can read the parent doc.
      // Assuming parent doc 'purchaseDue' is accurate for the balance.
      // We will try to rely on parent doc for "Due", but getting "Total Purchased" history
      // requires summing. For now, I will simulate it by reading the parent doc if you stored fields there.
      // If not, we have to run a full query (expensive) or just show the Due.

      // Let's rely on the parent document for the "Balance" which is most important.
      DocumentSnapshot parentSnap =
          await _db.collection('debatorbody').doc(debtorId).get();
      if (parentSnap.exists) {
        // If you saved 'purchaseDue' in parent

        // Back-calculate: We can't easily know Total Purchased vs Paid without reading all.
        // For UI purposes, we might just show "Current Due".
        // HOWEVER, to keep your UI working:
        // Let's do a lightweight read of all docs JUST for fields 'amount' and 'type'.
        QuerySnapshot allDocs =
            await _db
                .collection('debatorbody')
                .doc(debtorId)
                .collection('purchases')
                .get();
        double p = 0;
        double paid = 0;
        for (var doc in allDocs.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          double amt =
              (data['totalAmount'] ?? data['amount'] ?? 0)
                  .toString()
                  .toDouble();
          if (data['type'] == 'invoice') {
            p += amt;
          } else {
            paid += amt;
          }
        }
        totalPurchased.value = p;
        totalPaid.value = paid;
      }
    } catch (e) {
      print("Stats error: $e");
    }
  }

  // ----------------------------------------------------------------
  // 2. PURCHASE LOGIC
  // ----------------------------------------------------------------
  void addToCart(
    Map<String, dynamic> product,
    int qty,
    double cost,
    String location,
  ) {
    String pid = product['id'].toString();
    int index = cartItems.indexWhere(
      (e) => e['productId'] == pid && e['location'] == location,
    );

    if (index >= 0) {
      var item = cartItems[index];
      item['qty'] += qty;
      item['subtotal'] = item['qty'] * cost;
      cartItems[index] = item;
      cartItems.refresh();
    } else {
      cartItems.add({
        'productId': pid,
        'name': product['name'],
        'model': product['model'],
        'qty': qty,
        'cost': cost,
        'location': location,
        'subtotal': qty * cost,
      });
    }
  }

  Future<void> finalizePurchase(String debtorId, String note) async {
    if (cartItems.isEmpty) return;
    isLoading.value = true;
    try {
      double grandTotal = cartItems.fold(
        0,
        (sumv, item) => sumv + item['subtotal'],
      );
      WriteBatch batch = _db.batch();

      DocumentReference purchaseRef =
          _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('purchases')
              .doc();

      // Convert cart items to a clean list for Firestore
      List<Map<String, dynamic>> finalItems =
          cartItems
              .map(
                (e) => {
                  'productId': e['productId'],
                  'name': e['name'],
                  'model': e['model'],
                  'qty': e['qty'],
                  'cost': e['cost'],
                  'location': e['location'],
                  'subtotal': e['subtotal'],
                },
              )
              .toList();

      batch.set(purchaseRef, {
        'date': FieldValue.serverTimestamp(),
        'type': 'invoice',
        'items': finalItems,
        'totalAmount': grandTotal,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
      });

      DocumentReference debtorRef = _db.collection('debatorbody').doc(debtorId);
      batch.update(debtorRef, {
        'purchaseDue': FieldValue.increment(grandTotal),
      });

      await batch.commit();

      // Stock Update
      List<Future> stockUpdates = [];
      for (var item in cartItems) {
        int pid = int.tryParse(item['productId'].toString()) ?? 0;
        String loc = item['location'];
        int qty = item['qty'];
        double cost = item['cost'];
        stockUpdates.add(
          stockCtrl.addMixedStock(
            productId: pid,
            localQty: loc == "Local" ? qty : 0,
            airQty: loc == "Air" ? qty : 0,
            seaQty: loc == "Sea" ? qty : 0,
            localUnitPrice: cost,
          ),
        );
      }
      await Future.wait(stockUpdates);

      cartItems.clear();
      await loadPurchases(debtorId); // Refresh list
      Get.back();
      Get.snackbar("Success", "Purchase Recorded.");
    } catch (e) {
      Get.snackbar("Error", "Transaction Failed: $e");
    } finally {
      isLoading.value = false;
    }
  }

  // ----------------------------------------------------------------
  // 3. PAYMENT LOGIC
  // ----------------------------------------------------------------
  Future<void> makePayment({
    required String debtorId,
    required String debtorName,
    required double amount,
    required String method,
    String? note,
  }) async {
    if (amount <= 0) return;
    isLoading.value = true;
    try {
      WriteBatch batch = _db.batch();
      DocumentReference histRef =
          _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('purchases')
              .doc();

      batch.set(histRef, {
        'date': FieldValue.serverTimestamp(),
        'type': 'payment',
        'amount': amount,
        'method': method,
        'note': note,
        'isAdjustment': false,
      });

      DocumentReference debtorRef = _db.collection('debatorbody').doc(debtorId);
      batch.update(debtorRef, {'purchaseDue': FieldValue.increment(-amount)});

      await batch.commit();

      try {
        await dailyExpenseCtrl.addDailyExpense(
          "Payment to $debtorName",
          amount.toInt(),
          note: "Debtor Payment. Method: $method. ${note ?? ''}",
          date: DateTime.now(),
        );
      } catch (e) {
        print("Expense Auto-add failed: $e");
      }

      await loadPurchases(debtorId);
      Get.back();
      Get.snackbar("Success", "Payment Recorded.");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> processContraAdjustment({
    required String debtorId,
    required double amount,
  }) async {
    if (amount <= 0) return;
    isLoading.value = true;
    WriteBatch batch = _db.batch();

    try {
      DocumentReference purchaseAdjRef =
          _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('purchases')
              .doc();
      batch.set(purchaseAdjRef, {
        'date': FieldValue.serverTimestamp(),
        'type': 'adjustment',
        'amount': amount,
        'method': 'Contra Adjustment',
        'note': 'Adjusted against Sales Due',
        'isAdjustment': true,
      });

      DocumentReference debtorRef = _db.collection('debatorbody').doc(debtorId);
      batch.update(debtorRef, {'purchaseDue': FieldValue.increment(-amount)});

      DocumentReference ledgerRef =
          _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('transactions')
              .doc();
      batch.set(ledgerRef, {
        'transactionId': ledgerRef.id,
        'amount': amount,
        'type': 'debit',
        'date': FieldValue.serverTimestamp(),
        'note': 'Contra Adjustment (Ref Purchase)',
        'paymentMethod': {'type': 'Contra'},
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(debtorRef, {'balance': FieldValue.increment(-amount)});

      await batch.commit();
      await loadPurchases(debtorId);
      debtorCtrl.loadDebtorTransactions(debtorId);

      Get.back();
      Get.snackbar("Success", "Contra Adjusted.");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // ----------------------------------------------------------------
  // 4. PDF GENERATION
  // ----------------------------------------------------------------
  Future<void> generatePurchasePdf(
    Map<String, dynamic> data,
    String debtorName,
  ) async {
    isGeneratingPdf.value = true;
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final bold = await PdfGoogleFonts.robotoBold();

      final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
      final date =
          data['date'] is Timestamp
              ? (data['date'] as Timestamp).toDate()
              : DateTime.now();
      final total = double.tryParse(data['totalAmount'].toString()) ?? 0.0;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "PURCHASE INVOICE",
                        style: pw.TextStyle(font: bold, fontSize: 20),
                      ),
                      pw.Text(
                        "GTEL ERP",
                        style: pw.TextStyle(font: bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Supplier (Debtor):",
                          style: pw.TextStyle(font: bold),
                        ),
                        pw.Text(debtorName, style: pw.TextStyle(font: font)),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          "Date: ${DateFormat('dd-MMM-yyyy').format(date)}",
                          style: pw.TextStyle(font: font),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          "Ref ID: ${data['id'] ?? 'N/A'}",
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Table.fromTextArray(
                  headers: [
                    'Item Name',
                    'Model',
                    'Location',
                    'Qty',
                    'Cost',
                    'Total',
                  ],
                  data:
                      items
                          .map(
                            (e) => [
                              e['name'],
                              e['model'] ?? '-',
                              e['location'] ?? '-',
                              e['qty'].toString(),
                              e['cost'].toString(),
                              e['subtotal'].toString(),
                            ],
                          )
                          .toList(),
                  headerStyle: pw.TextStyle(font: bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey800,
                  ),
                  cellStyle: pw.TextStyle(font: font, fontSize: 10),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    "Grand Total: ${total.toStringAsFixed(2)}",
                    style: pw.TextStyle(font: bold, fontSize: 14),
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) {
      Get.snackbar("PDF Error", e.toString());
    } finally {
      isGeneratingPdf.value = false;
    }
  }

  // Helper
  Future<void> loadProductsForSearch() async {
    if (stockCtrl.allProducts.isEmpty) await stockCtrl.fetchProducts();
    productSearchList.value =
        stockCtrl.allProducts
            .map(
              (product) => {
                'id': product.id,
                'name': product.name,
                'model': product.model,
                'buyingPrice': product.avgPurchasePrice,
              },
            )
            .toList();
  }
}

extension StringExtension on String {
  double toDouble() => double.tryParse(this) ?? 0.0;
}
