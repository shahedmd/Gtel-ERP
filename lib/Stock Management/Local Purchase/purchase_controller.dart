
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/gteldebtorcontroller.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Daily%20Expense/dailyexpensecontroller.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Monthly%20Expense/montlyexpensecontroller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../stock_controller.dart';

class DebtorPurchaseController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final ProductController stockCtrl =
      Get.isRegistered<ProductController>()
          ? Get.find<ProductController>()
          : Get.put(ProductController());

  final DebatorController debtorCtrl =
      Get.isRegistered<DebatorController>()
          ? Get.find<DebatorController>()
          : Get.put(DebatorController());

  DailyExpensesController get dailyExpenseCtrl {
    if (!Get.isRegistered<MonthlyExpensesController>()) {
      Get.put(MonthlyExpensesController());
    }
    if (!Get.isRegistered<DailyExpensesController>()) {
      Get.put(DailyExpensesController());
    }
    return Get.find<DailyExpensesController>();
  }

  final purchases = <Map<String, dynamic>>[].obs;
  final productSearchList = <Map<String, dynamic>>[].obs;
  final cartItems = <Map<String, dynamic>>[].obs;

  final isLoading = false.obs;
  final isGeneratingPdf = false.obs;

  final totalPurchased = 0.0.obs;
  final totalPaid = 0.0.obs;

  double get currentPayable => totalPurchased.value - totalPaid.value;

  final int _purchaseLimit = 20;
  List<DocumentSnapshot?> purchasePageCursors = [null];
  final currentPurchasePage = 1.obs;
  final hasMorePurchases = true.obs;

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

      final startAfterDoc = purchasePageCursors[pageIndex - 1];
      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snap = await query.get();

      if (snap.docs.isEmpty) {
        if (pageIndex == 1) purchases.clear();
        hasMorePurchases.value = false;
        return;
      }

      purchases.value = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['snapshot'] = doc;
        return data;
      }).toList();

      hasMorePurchases.value = snap.docs.length >= _purchaseLimit;

      if (hasMorePurchases.value) {
        if (purchasePageCursors.length <= pageIndex) {
          purchasePageCursors.add(snap.docs.last);
        } else {
          purchasePageCursors[pageIndex] = snap.docs.last;
        }
      }

      currentPurchasePage.value = pageIndex;
    } catch (e) {
      Get.snackbar('Error', 'Could not load purchases: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fixPayableBalance(String debtorId) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator(color: Colors.blue)),
        barrierDismissible: false,
      );

      final snap = await _db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('purchases')
          .get();

      double accuratePayable = 0.0;

      for (final doc in snap.docs) {
        final data = doc.data();
        final type = (data['type'] ?? '').toString().toLowerCase();
        final amount = _toDouble(data['totalAmount'] ?? data['amount']);

        if (type == 'invoice') {
          accuratePayable += amount;
        } else if (type == 'payment' || type == 'adjustment') {
          accuratePayable -= amount;
        }
      }

      await _db.collection('debatorbody').doc(debtorId).update({
        'purchaseDue': accuratePayable,
      });

      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        'Synced',
        'Payable balance corrected to Tk ${accuratePayable.toStringAsFixed(2)}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      await loadPurchases(debtorId);
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Error',
        'Could not sync balance: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _fetchAccurateStats(String debtorId) async {
    try {
      final allDocs = await _db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('purchases')
          .get();

      double purchased = 0;
      double paid = 0;

      for (final doc in allDocs.docs) {
        final data = doc.data();
        final type = (data['type'] ?? '').toString().toLowerCase();
        final amount = _toDouble(data['totalAmount'] ?? data['amount']);

        if (type == 'invoice') {
          purchased += amount;
        } else {
          paid += amount;
        }
      }

      totalPurchased.value = purchased;
      totalPaid.value = paid;
    } catch (e) {
      print('Purchase stats error: $e');
    }
  }

  void addToCart({
    required Map<String, dynamic> product,
    required int qty,
    required double cost,
    required String stockType,
    int? warehouseId,
    String warehouseName = '',
    String warehouseLocation = '',
  }) {
    final pid = product['id'].toString();
    final whId = warehouseId ?? 0;
    final cleanLocation = warehouseLocation.trim();

    final index = cartItems.indexWhere((item) {
      return item['productId'].toString() == pid &&
          item['stockType'] == stockType &&
          _toInt(item['warehouseId']) == whId &&
          (item['warehouseLocation'] ?? '').toString() == cleanLocation;
    });

    if (index >= 0) {
      final item = Map<String, dynamic>.from(cartItems[index]);
      item['qty'] = _toInt(item['qty']) + qty;
      item['subtotal'] = _toInt(item['qty']) * _toDouble(item['cost']);
      cartItems[index] = item;
      cartItems.refresh();
      return;
    }

    cartItems.add({
      'productId': pid,
      'name': product['name'],
      'model': product['model'],
      'qty': qty,
      'cost': cost,
      'stockType': stockType,
      'location': stockType,
      'warehouseId': whId,
      'warehouseName': warehouseName,
      'warehouseLocation': cleanLocation,
      'subtotal': qty * cost,
    });
  }

  Future<void> finalizePurchase(
    String debtorId,
    String note, {
    DateTime? customDate,
  }) async {
    if (cartItems.isEmpty) return;

    isLoading.value = true;

    try {
      final grandTotal = cartItems.fold<double>(
        0,
        (sum, item) => sum + _toDouble(item['subtotal']),
      );

      final purchaseRef = _db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('purchases')
          .doc();

      final debtorRef = _db.collection('debatorbody').doc(debtorId);

      final dateField = customDate != null
          ? Timestamp.fromDate(customDate)
          : FieldValue.serverTimestamp();

      final finalItems = cartItems.map((item) {
        return {
          'productId': item['productId'],
          'name': item['name'],
          'model': item['model'],
          'qty': item['qty'],
          'cost': item['cost'],
          'stockType': item['stockType'] ?? item['location'] ?? 'Local',
          'location': item['stockType'] ?? item['location'] ?? 'Local',
          'warehouseId': item['warehouseId'] ?? 0,
          'warehouseName': item['warehouseName'] ?? '',
          'warehouseLocation': item['warehouseLocation'] ?? '',
          'subtotal': item['subtotal'],
        };
      }).toList();

      final batch = _db.batch();

      batch.set(purchaseRef, {
        'date': dateField,
        'type': 'invoice',
        'items': finalItems,
        'totalAmount': grandTotal,
        'note': note.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(debtorRef, {
        'purchaseDue': FieldValue.increment(grandTotal),
      });

      await batch.commit();

      final stockUpdates = <Future>[];

      for (final item in cartItems) {
        final pid = _toInt(item['productId']);
        final stockType = (item['stockType'] ?? item['location'] ?? 'Local').toString();
        final qty = _toInt(item['qty']);
        final cost = _toDouble(item['cost']);
        final warehouseId = _toInt(item['warehouseId']);
        final warehouseLocation = (item['warehouseLocation'] ?? '').toString();

        stockUpdates.add(
          stockCtrl.addMixedStock(
            productId: pid,
            localQty: stockType == 'Local' ? qty : 0,
            airQty: stockType == 'Air' ? qty : 0,
            seaQty: stockType == 'Sea' ? qty : 0,
            localUnitPrice: cost,
            warehouseId: warehouseId > 0 ? warehouseId : null,
            warehouseLocation: warehouseLocation,
          ),
        );
      }

      await Future.wait(stockUpdates);

      cartItems.clear();
      await loadPurchases(debtorId);

      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        'Success',
        'Purchase recorded and stock updated.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Transaction failed: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

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
      final batch = _db.batch();

      final histRef = _db
          .collection('debatorbody')
          .doc(debtorId)
          .collection('purchases')
          .doc();

      final debtorRef = _db.collection('debatorbody').doc(debtorId);

      batch.set(histRef, {
        'date': customDate != null
            ? Timestamp.fromDate(customDate)
            : FieldValue.serverTimestamp(),
        'type': 'payment',
        'amount': amount,
        'method': method,
        'note': note ?? '',
        'isAdjustment': false,
      });

      batch.update(debtorRef, {
        'purchaseDue': FieldValue.increment(-amount),
      });

      await batch.commit();

      try {
        await dailyExpenseCtrl.addDailyExpense(
          'Payment to $debtorName',
          amount,
          note: 'Debtor Payment. Method: $method. ${note ?? ''}',
          date: customDate ?? DateTime.now(),
        );
      } catch (e) {
        print('Expense auto-add failed: $e');
      }

      await loadPurchases(debtorId);

      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        'Success',
        'Payment recorded.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', e.toString());
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

    try {
      final debtorSnap = await _db.collection('debatorbody').doc(debtorId).get();
      if (!debtorSnap.exists) throw 'Debtor not found';

      final debtorData = debtorSnap.data() as Map<String, dynamic>;
      final debtorName = debtorData['name'] ?? 'Unknown';

      final breakdown = await debtorCtrl.getInstantDebtorBreakdown(debtorId);
      final currentOldDue = breakdown['loan'] ?? 0.0;

      double amountToOldDue = 0.0;
      double amountToRunningDue = 0.0;

      if (currentOldDue > 0) {
        if (amount >= currentOldDue) {
          amountToOldDue = currentOldDue;
          amountToRunningDue = amount - currentOldDue;
        } else {
          amountToOldDue = amount;
        }
      } else {
        amountToRunningDue = amount;
      }

      final batch = _db.batch();
      final dateField = customDate != null
          ? Timestamp.fromDate(customDate)
          : FieldValue.serverTimestamp();

      final purchaseAdjRef = _db
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

      if (amountToOldDue > 0) {
        final oldDueTxRef = _db
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

      String? runningTxId;

      if (amountToRunningDue > 0) {
        final runningTxRef = _db
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

      final debtorRef = _db.collection('debatorbody').doc(debtorId);

      batch.update(debtorRef, {
        'purchaseDue': FieldValue.increment(-amount),
        'balance': FieldValue.increment(-amount),
      });

      if (amountToRunningDue > 0) {
        double remainingToAllocate = amountToRunningDue;

        final ordersSnap = await _db
            .collection('sales_orders')
            .where('debtorId', isEqualTo: debtorId)
            .get();

        final pendingOrders = ordersSnap.docs.where((doc) {
          final data = doc.data();
          final pending = _salesOrderPending(data);
          return pending > 0.5;
        }).toList();

        pendingOrders.sort((a, b) {
          final dataA = a.data();
          final dataB = b.data();
          final t1 = dataA['timestamp'] is Timestamp
              ? dataA['timestamp'] as Timestamp
              : Timestamp.now();
          final t2 = dataB['timestamp'] is Timestamp
              ? dataB['timestamp'] as Timestamp
              : Timestamp.now();
          return t1.compareTo(t2);
        });

        for (final orderDoc in pendingOrders) {
          if (remainingToAllocate <= 0.01) break;

          final orderData = orderDoc.data();
          final saleTxId = orderData['invoiceId'] ?? orderDoc.id;

          final dailySnap = await _db
              .collection('daily_sales')
              .where('transactionId', isEqualTo: saleTxId)
              .limit(1)
              .get();

          DocumentSnapshot? dailyDoc;
          double currentPendingDaily = 0.0;
          double currentPaidDaily = 0.0;
          double currentLedgerPaidDaily = 0.0;

          if (dailySnap.docs.isNotEmpty) {
            dailyDoc = dailySnap.docs.first;
            final dailyData = dailyDoc.data() as Map<String, dynamic>;

            currentPendingDaily = _toDouble(dailyData['pending']);
            currentPaidDaily = _toDouble(dailyData['paid']);
            currentLedgerPaidDaily = _toDouble(dailyData['ledgerPaid']);
          }

          final salesOrderPending = _salesOrderPending(orderData);
          final actualPending =
              dailyDoc != null ? currentPendingDaily : salesOrderPending;

          if (actualPending <= 0.5) {
            if (salesOrderPending > 0.5) {
              batch.update(orderDoc.reference, {
                'paid': _toDouble(orderData['grandTotal']),
                'paymentDetails.due': 0.0,
                'isFullyPaid': true,
                'status': 'completed',
              });
            }
            continue;
          }

          final take = remainingToAllocate >= actualPending
              ? actualPending
              : remainingToAllocate;

          final isNowFullyPaid = (actualPending - take) <= 0.5;

          final orderUpdate = <String, dynamic>{
            'paid': FieldValue.increment(take),
            'paymentDetails.due': FieldValue.increment(-take),
          };

          if (orderData['customerName'] != debtorName) {
            orderUpdate['customerName'] = debtorName;
          }

          if (isNowFullyPaid) {
            orderUpdate['isFullyPaid'] = true;
            orderUpdate['status'] = 'completed';
          }

          batch.update(orderDoc.reference, orderUpdate);

          if (dailyDoc != null) {
            final dailyUpdate = {
              'paid': currentPaidDaily + take,
              'pending': currentPendingDaily - take,
              'ledgerPaid': currentLedgerPaidDaily + take,
              'status': isNowFullyPaid ? 'paid' : 'partial',
              'paymentHistory': FieldValue.arrayUnion([
                {
                  'type': 'Contra Adjustment',
                  'amount': take,
                  'paidAt': Timestamp.now(),
                  'sourceTxId': runningTxId ?? purchaseAdjRef.id,
                }
              ]),
            };

            final dailyData = dailyDoc.data() as Map<String, dynamic>;
            if (dailyData['name'] != debtorName) {
              dailyUpdate['name'] = debtorName;
            }

            batch.update(dailyDoc.reference, dailyUpdate);
          }

          remainingToAllocate -= take;
        }
      }

      await batch.commit();

      await loadPurchases(debtorId);
      debtorCtrl.loadTxPage(debtorId, debtorCtrl.currentTxPage.value);
      debtorCtrl.calculateTotalOutstanding();

      if (Get.isDialogOpen ?? false) Get.back();

      Get.snackbar(
        'Success',
        'Adjusted. Old Due: $amountToOldDue, Running: $amountToRunningDue',
      );
    } catch (e) {
      Get.snackbar('Error', e.toString());
      print('Contra Error: $e');
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
      final date = data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now();
      final total = _toDouble(data['totalAmount']);

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
                        'PURCHASE INVOICE',
                        style: pw.TextStyle(font: bold, fontSize: 20),
                      ),
                      pw.Text(
                        'GTEL ERP',
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
                        pw.Text('Supplier:', style: pw.TextStyle(font: bold)),
                        pw.Text(debtorName, style: pw.TextStyle(font: font)),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Date: ${DateFormat('dd-MMM-yyyy').format(date)}',
                          style: pw.TextStyle(font: font),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Ref ID: ${data['id'] ?? 'N/A'}',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Table.fromTextArray(
                  headers: [
                    'Item',
                    'Model',
                    'Type',
                    'Warehouse',
                    'Location',
                    'Qty',
                    'Cost',
                    'Total',
                  ],
                  data: items.map((item) {
                    return [
                      item['name'] ?? '',
                      item['model'] ?? '-',
                      item['stockType'] ?? item['location'] ?? '-',
                      item['warehouseName'] ?? '-',
                      item['warehouseLocation'] ?? '-',
                      item['qty'].toString(),
                      _money(item['cost']),
                      _money(item['subtotal']),
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(font: bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey800,
                  ),
                  cellStyle: pw.TextStyle(font: font, fontSize: 9),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Grand Total: ${_money(total)}',
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
      Get.snackbar('PDF Error', e.toString());
    } finally {
      isGeneratingPdf.value = false;
    }
  }

  Future<void> loadProductsForSearch() async {
    if (stockCtrl.allProducts.isEmpty) await stockCtrl.fetchProducts();

    productSearchList.value = stockCtrl.allProducts.map((product) {
      return {
        'id': product.id,
        'name': product.name,
        'model': product.model,
        'buyingPrice': product.avgPurchasePrice,
        'warehouseStocks':
            product.warehouseStocks.map((stock) => stock.toJson()).toList(),
      };
    }).toList();
  }

  double _salesOrderPending(Map<String, dynamic> data) {
    if (data['paymentDetails'] != null &&
        data['paymentDetails']['due'] != null) {
      return _toDouble(data['paymentDetails']['due']);
    }

    return _toDouble(data['grandTotal']) - _toDouble(data['paid']);
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static String _money(dynamic value) {
    return 'Tk ${_toDouble(value).toStringAsFixed(2)}';
  }
}

extension StringExtension on String {
  double toDouble() => double.tryParse(this) ?? 0.0;
}
