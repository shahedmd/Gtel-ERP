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
      DocumentSnapshot debtorSnap =
          await _db.collection('debatorbody').doc(debtorId).get();
      if (!debtorSnap.exists) throw "Debtor not found";

      // Cast the Object? to Map<String, dynamic>
      Map<String, dynamic> debtorData =
          debtorSnap.data() as Map<String, dynamic>;
      String debtorName = debtorData['name'] ?? 'Unknown';

      // =========================================================
      // 1. CALCULATE SPLIT: OLD DUE FIRST, THEN RUNNING DUE
      // =========================================================
      Map<String, double> breakdown = await debtorCtrl
          .getInstantDebtorBreakdown(debtorId);
      double currentOldDue = breakdown['loan'] ?? 0.0;

      double amountToOldDue = 0.0;
      double amountToRunningDue = 0.0;

      if (currentOldDue > 0) {
        if (amount >= currentOldDue) {
          // Pays off entire Old Due, remainder goes to Running Due
          amountToOldDue = currentOldDue;
          amountToRunningDue = amount - currentOldDue;
        } else {
          // Adjustment is smaller than Old Due, everything goes to Old Due
          amountToOldDue = amount;
          amountToRunningDue = 0.0;
        }
      } else {
        // No Old Due, everything goes to Running Due
        amountToRunningDue = amount;
      }

      dynamic dateField =
          customDate != null
              ? Timestamp.fromDate(customDate)
              : FieldValue.serverTimestamp();

      // =========================================================
      // 2. RECORD ADJUSTMENT IN PURCHASES
      // =========================================================
      DocumentReference purchaseAdjRef =
          _db
              .collection('debatorbody')
              .doc(debtorId)
              .collection('purchases')
              .doc();
      batch.set(purchaseAdjRef, {
        'date': dateField,
        'type': 'adjustment',
        'amount': amount,
        'method': 'Contra Adjustment',
        'note':
            'Adjusted Sales Due (Old: $amountToOldDue, Running: $amountToRunningDue)',
        'isAdjustment': true,
      });

      // =========================================================
      // 3. CREATE DEBTOR TRANSACTIONS (BASED ON SPLIT)
      // =========================================================

      // A. Pay Off Old Due (Uses 'loan_payment' type)
      if (amountToOldDue > 0) {
        DocumentReference oldDueTxRef =
            _db
                .collection('debatorbody')
                .doc(debtorId)
                .collection('transactions')
                .doc();
        batch.set(oldDueTxRef, {
          'transactionId': oldDueTxRef.id,
          'amount': amountToOldDue,
          'type': 'loan_payment',
          'date': dateField,
          'note': 'Contra Adjustment - Old Due',
          'paymentMethod': {'type': 'Contra'},
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // B. Pay Off Running Due (Uses 'debit' type)
      String? runningTxId;
      if (amountToRunningDue > 0) {
        DocumentReference runningTxRef =
            _db
                .collection('debatorbody')
                .doc(debtorId)
                .collection('transactions')
                .doc();
        runningTxId = runningTxRef.id;
        batch.set(runningTxRef, {
          'transactionId': runningTxId,
          'amount': amountToRunningDue,
          'type': 'debit',
          'date': dateField,
          'note': 'Contra Adjustment - Running Due',
          'paymentMethod': {'type': 'Contra'},
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // =========================================================
      // 4. UPDATE MAIN DEBTOR BALANCES
      // =========================================================
      DocumentReference debtorRef = _db.collection('debatorbody').doc(debtorId);
      batch.update(debtorRef, {
        'purchaseDue': FieldValue.increment(-amount),
        'balance': FieldValue.increment(-amount),
      });

      // =========================================================
      // 5. BILL ALLOCATION LOGIC (ONLY APPLIES TO RUNNING DUE)
      // =========================================================
      if (amountToRunningDue > 0) {
        double remainingToAllocate = amountToRunningDue;

        // ID দিয়ে sales_orders থেকে আনলে নাম পরিবর্তনের সমস্যা হবে না
        QuerySnapshot ordersSnap =
            await _db
                .collection('sales_orders')
                .where('debtorId', isEqualTo: debtorId)
                .get();

        List<DocumentSnapshot> pendingOrders =
            ordersSnap.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              double pending = 0.0;
              if (data['paymentDetails'] != null &&
                  data['paymentDetails']['due'] != null) {
                pending =
                    double.tryParse(data['paymentDetails']['due'].toString()) ??
                    0.0;
              } else {
                pending =
                    (double.tryParse(data['grandTotal']?.toString() ?? '0') ??
                        0.0) -
                    (double.tryParse(data['paid']?.toString() ?? '0') ?? 0.0);
              }
              return pending > 0.5;
            }).toList();

        // Sort by date (পুরনো বিল আগে ক্লিয়ার হবে)
        pendingOrders.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          Timestamp t1 =
              dataA['timestamp'] is Timestamp
                  ? dataA['timestamp']
                  : Timestamp.now();
          Timestamp t2 =
              dataB['timestamp'] is Timestamp
                  ? dataB['timestamp']
                  : Timestamp.now();
          return t1.compareTo(t2);
        });

        if (pendingOrders.isNotEmpty) {
          for (var orderDoc in pendingOrders) {
            if (remainingToAllocate <= 0.01) break;

            Map<String, dynamic> oData =
                orderDoc.data() as Map<String, dynamic>;
            String saleTxId = oData['invoiceId'] ?? orderDoc.id;

            // Daily Sales থেকে আসল বকেয়া চেক (Ghost Due Check)
            QuerySnapshot dailySnap =
                await _db
                    .collection('daily_sales')
                    .where('transactionId', isEqualTo: saleTxId)
                    .limit(1)
                    .get();

            double currentPendingD = 0.0;
            double currentPaidD = 0.0;
            double currentLedgerPaidD = 0.0;
            DocumentSnapshot? dailyDoc;

            if (dailySnap.docs.isNotEmpty) {
              dailyDoc = dailySnap.docs.first;
              Map<String, dynamic> dData =
                  dailyDoc.data() as Map<String, dynamic>;
              currentPendingD =
                  double.tryParse(dData['pending'].toString()) ?? 0.0;
              currentPaidD = double.tryParse(dData['paid'].toString()) ?? 0.0;
              currentLedgerPaidD =
                  double.tryParse(dData['ledgerPaid']?.toString() ?? '0') ??
                  0.0;
            }

            double salesOrderPending =
                oData['paymentDetails'] != null &&
                        oData['paymentDetails']['due'] != null
                    ? (double.tryParse(
                          oData['paymentDetails']['due'].toString(),
                        ) ??
                        0.0)
                    : ((double.tryParse(
                              oData['grandTotal']?.toString() ?? '0',
                            ) ??
                            0.0) -
                        (double.tryParse(oData['paid']?.toString() ?? '0') ??
                            0.0));

            // 👉 TRUE PENDING
            double actualPending =
                dailyDoc != null ? currentPendingD : salesOrderPending;

            if (actualPending <= 0.5) {
              // 🚑 AUTO-HEAL: Daily Sales-এ পেইড থাকলে Sales Orders-এর Ghost Due ফিক্স করে স্কিপ করবে
              if (salesOrderPending > 0.5) {
                batch.update(orderDoc.reference, {
                  "paid":
                      double.tryParse(oData['grandTotal']?.toString() ?? '0') ??
                      0.0,
                  "paymentDetails.due": 0.0,
                  "isFullyPaid": true,
                  "status": "completed",
                });
              }
              continue; // টাকা কাটবে না, পরের বিলে চলে যাবে!
            }

            double take =
                (remainingToAllocate >= actualPending)
                    ? actualPending
                    : remainingToAllocate;
            bool isNowFullyPaid = (actualPending - take) <= 0.5;

            // A. Update Sales Order
            Map<String, dynamic> orderUpdate = {
              "paid": FieldValue.increment(take),
              "paymentDetails.due": FieldValue.increment(-take),
            };

            if (oData['customerName'] != debtorName) {
              orderUpdate['customerName'] = debtorName;
            }

            if (isNowFullyPaid) {
              orderUpdate["isFullyPaid"] = true;
              orderUpdate["status"] = "completed";
            }
            batch.update(orderDoc.reference, orderUpdate);

            // B. Update Daily Sales
            if (dailyDoc != null) {
              final newHistoryEntry = {
                'type': 'Contra Adjustment',
                'amount': take,
                'paidAt': Timestamp.now(),
                'sourceTxId': runningTxId ?? purchaseAdjRef.id,
              };

              Map<String, dynamic> dailyUpdate = {
                "paid": currentPaidD + take,
                "pending": currentPendingD - take,
                "ledgerPaid": currentLedgerPaidD + take,
                "status": isNowFullyPaid ? "paid" : "partial",
                "paymentHistory": FieldValue.arrayUnion([newHistoryEntry]),
              };

              if (dailyDoc.get('name') != debtorName) {
                dailyUpdate['name'] = debtorName;
              }

              batch.update(dailyDoc.reference, dailyUpdate);
            }

            remainingToAllocate -= take;
          }
        }
      }

      await batch.commit();

      // Refresh Purchases and Transaction views
      await loadPurchases(debtorId);
      debtorCtrl.loadTxPage(debtorId, debtorCtrl.currentTxPage.value);
      debtorCtrl.calculateTotalOutstanding(); // Sync Overall Market State

      Get.back();
      Get.snackbar(
        "Success",
        "Adjusted! Old Due: $amountToOldDue, Running: $amountToRunningDue",
      );
    } catch (e) {
      Get.snackbar("Error", e.toString());
      print("Contra Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

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
