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

  // ==========================================
  // 1. PAGINATION STATE (MATCHING DEBTOR CONTROLLER)
  // ==========================================
  final int _purchaseLimit = 20; // 20 Rows Per Page
  List<DocumentSnapshot?> purchasePageCursors = [null];
  RxInt currentPurchasePage = 1.obs;
  RxBool hasMorePurchases = true.obs;

  void clearPurchaseState() {
    purchases.clear();
    purchasePageCursors = [null];
    currentPurchasePage.value = 1;
    hasMorePurchases.value = true;
    isLoading.value = false;
  }

  Future<void> loadPurchases(String debtorId) async {
    clearPurchaseState();
    await loadPurchasePage(debtorId, 1);
    await _fetchAccurateStats(debtorId);
  }

  void nextPurchasePage(String debtorId) {
    if (!hasMorePurchases.value) return;
    loadPurchasePage(debtorId, currentPurchasePage.value + 1);
  }

  void prevPurchasePage(String debtorId) {
    if (currentPurchasePage.value <= 1) return;
    loadPurchasePage(debtorId, currentPurchasePage.value - 1);
  }

  Future<void> loadPurchasePage(String debtorId, int pageIndex) async {
    if (pageIndex < 1) return;
    if (pageIndex > purchasePageCursors.length) return;

    isLoading.value = true;
    try {
      Query query = _db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('purchases')
          .orderBy('date', descending: true)
          .limit(_purchaseLimit);

      DocumentSnapshot? startAfterDoc = purchasePageCursors[pageIndex - 1];
      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      QuerySnapshot snap = await query.get();

      if (snap.docs.isNotEmpty) {
        purchases.value =
            snap.docs.map((d) {
              var data = d.data() as Map<String, dynamic>;
              data['id'] = d.id;
              data['snapshot'] = d;
              return data;
            }).toList();

        if (snap.docs.length < _purchaseLimit) {
          hasMorePurchases.value = false;
        } else {
          hasMorePurchases.value = true;
          // Store cursor for the NEXT page
          if (purchasePageCursors.length <= pageIndex) {
            purchasePageCursors.add(snap.docs.last);
          } else {
            purchasePageCursors[pageIndex] = snap.docs.last;
          }
        }
        currentPurchasePage.value = pageIndex;
      } else {
        if (pageIndex == 1) purchases.clear();
        hasMorePurchases.value = false;
      }
    } catch (e) {
      Get.snackbar("Error", "Could not load data: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchAccurateStats(String debtorId) async {
    try {
      DocumentSnapshot parentSnap =
          await _db.collection('debatorbody').doc(debtorId).get();
      if (parentSnap.exists) {
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

  Future<void> finalizePurchase(
    String debtorId,
    String note, {
    DateTime? customDate,
  }) async {
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

      dynamic dateField =
          customDate != null
              ? Timestamp.fromDate(customDate)
              : FieldValue.serverTimestamp();

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
        'date': dateField,
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
      // Reload page 1 and recalculate stats immediately
      await loadPurchases(debtorId);

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
    DateTime? customDate,
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

      dynamic dateField =
          customDate != null
              ? Timestamp.fromDate(customDate)
              : FieldValue.serverTimestamp();

      batch.set(histRef, {
        'date': dateField,
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
          date: customDate ?? DateTime.now(),
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
    DateTime? customDate,
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

      dynamic dateField =
          customDate != null
              ? Timestamp.fromDate(customDate)
              : FieldValue.serverTimestamp();

      batch.set(purchaseAdjRef, {
        'date': dateField,
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
        'date': dateField,
        'note': 'Contra Adjustment (Ref Purchase)',
        'paymentMethod': {'type': 'Contra'},
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(debtorRef, {'balance': FieldValue.increment(-amount)});

      await batch.commit();

      await loadPurchases(debtorId);
      debtorCtrl.loadTxPage(
        debtorId,
        debtorCtrl.currentTxPage.value,
      ); // Reloads the current transaction page

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