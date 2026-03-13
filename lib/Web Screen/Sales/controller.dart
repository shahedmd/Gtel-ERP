// ignore_for_file: prefer_interpolation_to_compose_strings, empty_catches

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/controller.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/conditioncontroller.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'model.dart';

class DailySalesController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Rx<DateTime> selectedDate = DateTime.now().obs;
  final RxList<SaleModel> salesList = <SaleModel>[].obs;
  final RxList<SaleModel> filteredList = <SaleModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString filterQuery = "".obs;

  final RxDouble revNormalAgent = 0.0.obs;
  final RxDouble colNormalAgent = 0.0.obs;
  final RxDouble dueNormalAgent = 0.0.obs;
  final RxDouble extraNormalAgent = 0.0.obs;

  final RxDouble revCondition = 0.0.obs;
  final RxDouble colCondition = 0.0.obs;
  final RxDouble dueCondition = 0.0.obs;
  final RxDouble extraCondition = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    loadDailySales();
    ever(selectedDate, (_) => loadDailySales());
    ever(filterQuery, (_) => _applyFilter());
  }

  double _round(double val) {
    return double.parse(val.toStringAsFixed(2));
  }

  void changeDate(DateTime date) {
    selectedDate.value = date;

    // 🔥 THE FIX: Tell ConditionSalesController to load the same date instantly!
    // This stops you from having to go to Condition Sales and scroll down.
    try {
      if (Get.isRegistered<ConditionSalesController>()) {
        final condCtrl = Get.find<ConditionSalesController>();
        condCtrl.customDateRange.value = DateTimeRange(
          start: DateTime(date.year, date.month, date.day, 0, 0, 0),
          end: DateTime(date.year, date.month, date.day, 23, 59, 59),
        );
        condCtrl.selectedFilter.value = "Custom";
        condCtrl.fetchReportData();
      }
    } catch (e) {}
  }

  // ==========================================
  // 1. LOAD DATA & COMPUTE ERP METRICS
  // ==========================================
  Future<void> loadDailySales() async {
    isLoading.value = true;
    try {
      final start = DateTime(
        selectedDate.value.year,
        selectedDate.value.month,
        selectedDate.value.day,
      );
      final end = start.add(const Duration(days: 1));

      // 1. Fetch Daily Sales (This gets normal sales & condition advances)
      final snap =
          await _db
              .collection("daily_sales")
              .where(
                "timestamp",
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              )
              .where("timestamp", isLessThan: Timestamp.fromDate(end))
              .orderBy("timestamp", descending: true)
              .get();

      salesList.value =
          snap.docs.map((doc) => SaleModel.fromFirestore(doc)).toList();

      double dailyCondRev = 0.0;
      List<String> todayCondInvIds = [];
      Set<String> historicalConditionInvIds = {};

      // 2. Force fetch all Master Orders using the EXACT query that Condition Sales uses.
      // This guarantees we find 0-advance sales.
      try {
        final ordersSnap =
            await _db
                .collection('sales_orders')
                .where(
                  'timestamp',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(start),
                )
                .where(
                  'timestamp',
                  isLessThanOrEqualTo: Timestamp.fromDate(end),
                )
                .orderBy('timestamp', descending: true)
                .get();

        for (var doc in ordersSnap.docs) {
          final data = doc.data();
          if (data['isCondition'] == true) {
            todayCondInvIds.add(doc.id);
            double gTotal = (data['grandTotal'] as num?)?.toDouble() ?? 0.0;
            if (gTotal <= 0.0) {
              List items = data['items'] ?? [];
              double sub = 0.0;
              for (var item in items) {
                if (item is Map) {
                  sub +=
                      double.tryParse(item['subtotal']?.toString() ?? '0') ??
                      0.0;
                }
              }
              double disc = (data['discount'] as num?)?.toDouble() ?? 0.0;
              gTotal = sub - disc;
            }
            dailyCondRev += gTotal;
          }
        }
      } catch (e) {
        // Fallback for cache mode
      }

      // 3. Check for any historical payments collected today
      Set<String> involvedIds = {};
      for (var doc in snap.docs) {
        final data = doc.data();
        String invId =
            (data['transactionId'] ?? data['invoiceId'] ?? '').toString();
        if (invId.isNotEmpty && !todayCondInvIds.contains(invId)) {
          involvedIds.add(invId);
        }
      }

      if (involvedIds.isNotEmpty) {
        List<String> idList = involvedIds.toList();
        for (var i = 0; i < idList.length; i += 10) {
          var chunk = idList.sublist(
            i,
            i + 10 > idList.length ? idList.length : i + 10,
          );

          var chunkSnap =
              await _db
                  .collection("sales_orders")
                  .where(FieldPath.documentId, whereIn: chunk)
                  .get();

          for (var doc in chunkSnap.docs) {
            final data = doc.data();
            if (data['isCondition'] == true &&
                !todayCondInvIds.contains(doc.id)) {
              historicalConditionInvIds.add(doc.id);
            }
          }
        }
      }

      _applyFilter();
      _computeTotals(
        dailyCondRev,
        todayCondInvIds,
        historicalConditionInvIds,
        snap.docs,
      );
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void _computeTotals(
    double conditionRevenue,
    List<String> todayCondInvIds,
    Set<String> historicalConditionInvIds,
    List<QueryDocumentSnapshot> rawDocs,
  ) {
    double rNA = 0.0, cNA = 0.0, dNA = 0.0, eNA = 0.0;
    double rC = conditionRevenue, cC = 0.0, advC = 0.0, eC = 0.0;

    for (var doc in rawDocs) {
      final data = doc.data() as Map<String, dynamic>;
      String type = (data['customerType'] ?? '').toString().toLowerCase();
      String source = (data['source'] ?? '').toString().toLowerCase();
      String invId =
          (data['transactionId'] ?? data['invoiceId'] ?? doc.id).toString();

      bool isConditionRelated =
          type.contains('condition') ||
          source.contains('condition') ||
          type.contains('courier') ||
          todayCondInvIds.contains(invId) ||
          historicalConditionInvIds.contains(invId);

      double invAmt = (data['amount'] as num?)?.toDouble() ?? 0.0;
      double paidAmt = (data['paid'] as num?)?.toDouble() ?? 0.0;
      double ledgerPaidAmt = (data['ledgerPaid'] as num?)?.toDouble() ?? 0.0;

      if (isConditionRelated) {
        if (source.contains('recovery') ||
            source.contains('payment') ||
            (invAmt <= 0.01 && paidAmt > 0)) {
          cC += paidAmt;
          if (todayCondInvIds.contains(invId)) {
            advC += paidAmt;
          } else {
            eC += paidAmt;
          }
        } else {
          advC += paidAmt;
          cC += paidAmt;
        }
      } else {
        if (source.contains('recovery') ||
            source.contains('payment') ||
            (invAmt <= 0.01 && paidAmt > 0)) {
          cNA += paidAmt;
          eNA += paidAmt;
        } else {
          rNA += invAmt;
          cNA += paidAmt;

          if (invAmt > paidAmt) {
            dNA += (invAmt - paidAmt);
          }

          if (ledgerPaidAmt > 0) {
            cNA += ledgerPaidAmt;
            eNA += ledgerPaidAmt;
            dNA -= ledgerPaidAmt;
            if (dNA < 0) dNA = 0;
          }
        }
      }
    }

    double dC = rC - advC;
    if (dC < 0) dC = 0;

    revNormalAgent.value = _round(rNA);
    colNormalAgent.value = _round(cNA);
    dueNormalAgent.value = _round(dNA);
    extraNormalAgent.value = _round(eNA);

    revCondition.value = _round(rC);
    colCondition.value = _round(cC);
    dueCondition.value = _round(dC);
    extraCondition.value = _round(eC);
  }

  void _applyFilter() {
    if (filterQuery.value.isEmpty) {
      filteredList.assignAll(salesList);
    } else {
      String query = filterQuery.value.toLowerCase();
      filteredList.assignAll(
        salesList.where((sale) {
          final name = sale.name.toLowerCase();
          final trxId = (sale.transactionId ?? "").toLowerCase();
          return name.contains(query) || trxId.contains(query);
        }).toList(),
      );
    }
  }

  String formatPaymentMethod(
    dynamic pm,
    double paidAmount, [
    double? totalAmount,
  ]) {
    if (paidAmount <= 0.01) return "CREDIT / DUE";
    if (pm == null || pm == "") return "CREDIT / DUE";
    if (pm is! Map) return pm.toString().toUpperCase();

    String toMoney(dynamic val) =>
        double.parse(val.toString()).toStringAsFixed(0);

    double cash = double.tryParse(pm['cash'].toString()) ?? 0;
    double bkash = double.tryParse(pm['bkash'].toString()) ?? 0;
    double nagad = double.tryParse(pm['nagad'].toString()) ?? 0;
    double bank = double.tryParse(pm['bank'].toString()) ?? 0;

    if (cash == 0 && bank == 0 && bkash == 0 && nagad == 0) {
      double effectiveTotal =
          (totalAmount != null && totalAmount > 0) ? totalAmount : paidAmount;
      String type = (pm['type'] ?? '').toString().toLowerCase();

      if (type.isEmpty || type == 'cash') {
        if (pm['bankName'].toString().isNotEmpty) type = 'bank';
        if (pm['bkashNumber'].toString().isNotEmpty) type = 'bkash';
        if (pm['nagadNumber'].toString().isNotEmpty) type = 'nagad';
      }

      if (type.contains('bank')) {
        bank = effectiveTotal;
      } else if (type.contains('bkash')) {
        bkash = effectiveTotal;
      } else if (type.contains('nagad')) {
        nagad = effectiveTotal;
      } else {
        cash = effectiveTotal;
      }
    }

    List<String> parts = [];

    if (cash > 0) parts.add("Cash: ${toMoney(cash)}");
    if (bkash > 0) {
      String num = (pm['bkashNumber'] ?? pm['number'] ?? "").toString();
      String line = "Bkash: ${toMoney(bkash)}";
      if (num.isNotEmpty && num.length > 3) line += " ($num)";
      parts.add(line);
    }
    if (nagad > 0) {
      String num = (pm['nagadNumber'] ?? pm['number'] ?? "").toString();
      String line = "Nagad: ${toMoney(nagad)}";
      if (num.isNotEmpty && num.length > 3) line += " ($num)";
      parts.add(line);
    }
    if (bank > 0) {
      String myBankName = (pm['bankName'] ?? "Bank").toString();
      String custTrxInfo =
          (pm['accountNumber'] ?? pm['accountNo'] ?? "").toString();

      String line = "$myBankName: ${toMoney(bank)}";
      if (custTrxInfo.isNotEmpty) line += "\nInfo: $custTrxInfo";
      parts.add(line);
    }

    if (parts.isEmpty && pm['type'] != null) {
      String type = pm['type'].toString().toUpperCase();
      if (type == "BANK") {
        String myBankName = (pm['bankName'] ?? "BANK").toString();
        return myBankName;
      }
      return type;
    }

    return parts.isEmpty ? "MULTI-PAY" : parts.join("\n");
  }

  Future<void> addSale({
    required String name,
    required double amount,
    required String customerType,
    required DateTime date,
    String source = "direct",
    bool isPaid = false,
    Map<String, dynamic>? paymentMethod,
    List<Map<String, dynamic>>? appliedDebits,
    String? transactionId,
  }) async {
    try {
      final paidPart = (customerType == "debtor" && !isPaid) ? 0.0 : amount;
      List<Map<String, dynamic>> initialHistory = [];

      if (paidPart > 0 && paymentMethod != null) {
        Map<String, dynamic> historyEntry = {
          'type': paymentMethod['type'] ?? 'cash',
          'amount': paidPart,
          'timestamp': Timestamp.fromDate(date),
        };

        if (paymentMethod.containsKey('number')) {
          historyEntry['number'] = paymentMethod['number'];
        }
        if (paymentMethod.containsKey('bankName')) {
          historyEntry['bankName'] = paymentMethod['bankName'];
        }
        if (paymentMethod.containsKey('accountNumber')) {
          historyEntry['accountNumber'] = paymentMethod['accountNumber'];
        }

        initialHistory.add(historyEntry);
      }

      final entry = {
        "name": name,
        "amount": _round(amount),
        "paid": _round(paidPart),
        "ledgerPaid": 0.0,
        "customerType": customerType,
        "timestamp": Timestamp.fromDate(date),
        "paymentMethod": paymentMethod,
        "paymentHistory": initialHistory,
        "createdAt": FieldValue.serverTimestamp(),
        "source": source,
        "appliedDebits": appliedDebits ?? [],
        "transactionId": transactionId,
      };

      await _db.collection("daily_sales").add(entry);
      await loadDailySales();
    } catch (e) {
      Get.snackbar("Error", "Failed to add sale: $e");
    }
  }

  Future<void> applyDebtorPayment(
    String debtorName,
    double paymentAmount,
    Map<String, dynamic> paymentMethod, {
    required DateTime date,
    String? transactionId,
  }) async {
    try {
      double remaining = _round(paymentAmount);
      final DateTime startOfDay = DateTime(date.year, date.month, date.day);
      final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      final snap =
          await _db
              .collection("daily_sales")
              .where("customerType", isEqualTo: "debtor")
              .where("name", isEqualTo: debtorName)
              .where(
                "timestamp",
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where("timestamp", isLessThan: Timestamp.fromDate(endOfDay))
              .orderBy("timestamp", descending: false)
              .get();

      final batch = _db.batch();

      for (var doc in snap.docs) {
        if (remaining <= 0) break;
        final data = doc.data();
        final double amt = (data['amount'] as num).toDouble();
        final double alreadyPaid = (data['paid'] as num).toDouble();
        final double due = _round(amt - alreadyPaid);

        if (due > 0) {
          final double toApply = remaining >= due ? due : remaining;
          List applied = List.from(data['appliedDebits'] ?? []);

          if (transactionId != null) {
            applied.add({"id": transactionId, "amount": toApply});
          }

          final newHistoryEntry = {
            'type': paymentMethod['type'] ?? 'cash',
            'amount': toApply,
            'paidAt': Timestamp.now(),
            'appliedTo': doc.id,
            'number': paymentMethod['number'],
            'bankName': paymentMethod['bankName'],
            'accountNumber': paymentMethod['accountNumber'],
          };
          newHistoryEntry.removeWhere((key, value) => value == null);

          batch.update(doc.reference, {
            "paid": _round(alreadyPaid + toApply),
            "paymentMethod": paymentMethod,
            "lastPaymentAt": FieldValue.serverTimestamp(),
            "appliedDebits": applied,
            "paymentHistory": FieldValue.arrayUnion([newHistoryEntry]),
          });
          remaining = _round(remaining - toApply);
        }
      }

      if (remaining > 0) {
        await addSale(
          name: debtorName,
          amount: remaining,
          customerType: "debtor",
          isPaid: true,
          date: date,
          paymentMethod: paymentMethod,
          source: "advance_payment",
          transactionId: transactionId,
          appliedDebits:
              transactionId != null
                  ? [
                    {"id": transactionId, "amount": remaining},
                  ]
                  : [],
        );
      }

      await batch.commit();
      await loadDailySales();
    } catch (e) {
      Get.snackbar("Payment Error", "Could not process daily payment.");
    }
  }

  Future<void> reverseDebtorPayment(
    String debtorName,
    double amount,
    DateTime date,
  ) async {
    try {
      final salesSnap =
          await _db
              .collection('daily_sales')
              .where('name', isEqualTo: debtorName)
              .where('customerType', isEqualTo: 'debtor')
              .orderBy('timestamp', descending: true)
              .get();

      double remainingToReverse = _round(amount);
      final batch = _db.batch();

      for (var doc in salesSnap.docs) {
        if (remainingToReverse <= 0) break;
        final data = doc.data();
        double currentPaid = _round((data['paid'] as num).toDouble());
        double ledgerPart = _round(
          (data['ledgerPaid'] as num?)?.toDouble() ?? 0.0,
        );

        if (currentPaid > 0) {
          double toSubtract =
              remainingToReverse >= currentPaid
                  ? currentPaid
                  : remainingToReverse;
          toSubtract = _round(toSubtract);

          double newPaid = _round(currentPaid - toSubtract);
          double newLedgerPaid = ledgerPart;

          if (newPaid < ledgerPart) {
            newLedgerPaid = newPaid;
          }

          batch.update(doc.reference, {
            'paid': newPaid,
            'ledgerPaid': newLedgerPaid,
            'lastReversalAt': FieldValue.serverTimestamp(),
            'reversalHistory': FieldValue.arrayUnion([
              {
                'amount': toSubtract,
                'date': Timestamp.now(),
                'reason': 'Manual Reversal',
              },
            ]),
          });
          remainingToReverse = _round(remainingToReverse - toSubtract);
        }
      }
      await batch.commit();
      await loadDailySales();
    } catch (e) {
      Get.snackbar("Reversal Error", e.toString());
    }
  }

  Future<void> deleteSale(String saleId) async {
    isLoading.value = true;
    try {
      DocumentSnapshot dailySnap =
          await _db.collection('daily_sales').doc(saleId).get();
      if (!dailySnap.exists) throw "Daily entry does not exist!";

      final saleData = dailySnap.data() as Map<String, dynamic>;
      String customerType =
          (saleData['customerType'] ?? '').toString().toLowerCase();

      if (customerType.contains('debtor')) {
        Get.snackbar(
          "Access Denied",
          "Debtor sales must be managed in the Debtor Ledger.",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        isLoading.value = false;
        return;
      }

      String? invoiceId = saleData['transactionId'] ?? saleData['invoiceId'];

      if (invoiceId != null && invoiceId.isNotEmpty) {
        DocumentSnapshot invSnap =
            await _db.collection("sales_orders").doc(invoiceId).get();

        if (invSnap.exists) {
          final invData = invSnap.data() as Map<String, dynamic>;
          final List<dynamic> items = invData['items'] ?? [];

          if (invData['status'] != 'deleted') {
            List<Map<String, dynamic>> returnAdditions = [];

            for (var item in items) {
              String pIdStr =
                  (item['productId'] ?? item['id'] ?? '').toString();
              int safePidInt = int.tryParse(pIdStr) ?? 0;
              int qty = (item['qty'] as num?)?.toInt() ?? 0;
              double cRate = (item['costRate'] as num?)?.toDouble() ?? 0.0;

              if (safePidInt > 0 && qty > 0) {
                returnAdditions.add({
                  'id': safePidInt,
                  'sea_qty': qty,
                  'air_qty': 0,
                  'local_qty': 0,
                  'local_price': cRate,
                });
              }
            }

            if (returnAdditions.isNotEmpty) {
              bool restockSuccess = await Get.find<ProductController>()
                  .bulkAddStockMixed(returnAdditions);

              if (!restockSuccess) {
                Get.snackbar(
                  "Error",
                  "Failed to restore stock to Sea. Sale not deleted.",
                );
                return;
              }
            }
          }

          await _db.runTransaction((transaction) async {
            DocumentReference invRef = _db
                .collection("sales_orders")
                .doc(invoiceId);
            transaction.delete(invRef);

            String? custPhone = invData['customerPhone'];
            if (custPhone != null && custPhone.isNotEmpty) {
              DocumentReference custHistRef = _db
                  .collection('customers')
                  .doc(custPhone)
                  .collection('orders')
                  .doc(invoiceId);
              transaction.delete(custHistRef);
            }
            transaction.delete(dailySnap.reference);
          });
        }
      } else {
        await dailySnap.reference.delete();
      }

      await loadDailySales();
      Get.snackbar(
        "Deleted Successfully",
        "Sale deleted & Stock restored to SEA.",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar("Error", "Could not delete: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> reprintInvoice(String invoiceId) async {
    isLoading.value = true;
    try {
      DocumentSnapshot doc =
          await _db.collection('sales_orders').doc(invoiceId).get();
      if (!doc.exists) {
        Get.snackbar("Error", "Invoice not found in master records.");
        return;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      bool isCond = data['isCondition'] ?? false;

      Map<String, dynamic> payMap = Map<String, dynamic>.from(
        data['paymentDetails'] ?? {},
      );

      if (isCond) {
        payMap['due'] =
            double.tryParse(data['courierDue']?.toString() ?? '0') ?? 0.0;
      } else {
        QuerySnapshot dailySnap =
            await _db
                .collection('daily_sales')
                .where('transactionId', isEqualTo: invoiceId)
                .limit(1)
                .get();

        if (dailySnap.docs.isNotEmpty) {
          var dailyData = dailySnap.docs.first.data() as Map<String, dynamic>;

          double realTimePaid = (dailyData['paid'] as num?)?.toDouble() ?? 0.0;
          List<dynamic> paymentHistory = dailyData['paymentHistory'] ?? [];

          List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
            data['items'] ?? [],
          );
          double subTotal = items.fold(
            0.0,
            (sumv, item) => sumv + (item['subtotal'] ?? 0),
          );
          double discountVal = (data['discount'] as num?)?.toDouble() ?? 0.0;
          double grandTotal = subTotal - discountVal;
          payMap['paidForInvoice'] = realTimePaid;
          double newDue = grandTotal - realTimePaid;
          payMap['due'] = newDue < 0 ? 0 : newDue;
          payMap.remove('cash');
          payMap.remove('bank');
          payMap.remove('bkash');
          payMap.remove('nagad');
          payMap.remove('bkashNumber');
          payMap.remove('nagadNumber');
          payMap.remove('bankName');
          payMap.remove('accountNumber');
          if (paymentHistory.isNotEmpty) {
            for (var h in paymentHistory) {
              if (h is Map) {
                String type = (h['type'] ?? '').toString().toLowerCase();
                String bankVal = (h['bankName'] ?? '').toString();

                if (type.isEmpty || type == 'cash') {
                  if (bankVal.isNotEmpty) type = 'bank';
                }
                if (type.isEmpty) type = 'cash';

                double amt = (h['amount'] as num?)?.toDouble() ?? 0.0;

                double current =
                    double.tryParse(payMap[type]?.toString() ?? '0') ?? 0.0;
                payMap[type] = current + amt;

                if (h['number'] != null) payMap['${type}Number'] = h['number'];
                if (h['bankName'] != null) payMap['bankName'] = h['bankName'];
                if (h['accountNumber'] != null) {
                  payMap['accountNumber'] = h['accountNumber'];
                }
              }
            }
          } else if (realTimePaid > 0) {
            var pm = dailyData['paymentMethod'];
            if (pm != null && pm is Map) {
              String detectedType = 'cash';
              String valBank = (pm['bankName'] ?? '').toString().trim();
              String valBkash = (pm['bkashNumber'] ?? '').toString().trim();
              String valNagad = (pm['nagadNumber'] ?? '').toString().trim();
              String explicitType =
                  (pm['type'] ?? '').toString().trim().toLowerCase();
              if (valBank.isNotEmpty) {
                detectedType = 'bank';
              } else if (valBkash.isNotEmpty) {
                detectedType = 'bkash';
              } else if (valNagad.isNotEmpty) {
                detectedType = 'nagad';
              } else if (explicitType.isNotEmpty && explicitType != 'cash') {
                detectedType = explicitType;
              }
              payMap[detectedType] = realTimePaid;
              if (pm['number'] != null) {
                payMap['${detectedType}Number'] = pm['number'];
              }
              if (valBank.isNotEmpty) payMap['bankName'] = valBank;
              if (valBkash.isNotEmpty) payMap['bkashNumber'] = valBkash;
              if (valNagad.isNotEmpty) payMap['nagadNumber'] = valNagad;

              if (pm['accountNumber'] != null) {
                payMap['accountNumber'] = pm['accountNumber'];
              }
            } else {
              payMap['cash'] = realTimePaid;
            }
          }
        }
      }

      String name = data['customerName'] ?? "";
      String phone = data['customerPhone'] ?? "";
      String shop = data['shopName'] ?? "";
      String address = data['deliveryAddress'] ?? "";
      String? courier = data['courierName'];
      int cartons = data['cartons'] ?? 0;
      String challan = data['challanNo'] ?? "";
      String packagerName = data['packagerName'] ?? '';

      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
        data['items'] ?? [],
      );

      double snapOld = (data['snapshotOldDue'] as num?)?.toDouble() ?? 0.0;
      double snapRun = (data['snapshotRunningDue'] as num?)?.toDouble() ?? 0.0;
      double discountVal = (data['discount'] as num?)?.toDouble() ?? 0.0;

      DateTime invoiceDate = DateTime.now();
      if (data['timestamp'] != null) {
        try {
          invoiceDate = data['timestamp'].toDate();
        } catch (_) {}
      } else if (data['date'] != null) {
        try {
          invoiceDate = DateTime.parse(data['date'].toString());
        } catch (_) {}
      }

      String sellerName = "Joynal Abedin";
      String sellerPhone = "01720677206";
      if (data['soldBy'] != null) {
        var soldByData = data['soldBy'];
        if (soldByData is Map) {
          sellerName = soldByData['name'] ?? sellerName;
          sellerPhone = soldByData['phone'] ?? sellerPhone;
        } else if (soldByData is String) {
          sellerName = soldByData;
        }
      }

      await _generatePdf(
        invoiceId,
        name,
        phone,
        payMap,
        items,
        isCondition: isCond,
        challan: challan,
        address: address,
        courier: courier,
        cartons: cartons,
        shopName: shop,
        oldDueSnap: snapOld,
        runningDueSnap: snapRun,
        authorizedName: sellerName,
        authorizedPhone: sellerPhone,
        discount: discountVal,
        packagerName: packagerName,
        invoiceDate: invoiceDate,
      );
    } catch (e) {
      Get.snackbar("Error", "Could not reprint: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _generatePdf(
    String invId,
    String name,
    String phone,
    Map<String, dynamic> payMap,
    List<Map<String, dynamic>> items, {
    bool isCondition = false,
    String challan = "",
    String address = "",
    String? courier,
    int? cartons,
    String shopName = "",
    double oldDueSnap = 0.0,
    double runningDueSnap = 0.0,
    required String authorizedName,
    required String authorizedPhone,
    double discount = 0.0,
    String? packagerName,
    required DateTime invoiceDate,
  }) async {
    final pdf = pw.Document();

    final boldFont = await PdfGoogleFonts.robotoBold();
    final regularFont = await PdfGoogleFonts.robotoRegular();
    final italicFont = await PdfGoogleFonts.robotoItalic();

    double paidOld = double.tryParse(payMap['paidForOldDue'].toString()) ?? 0.0;
    double paidPrevRun =
        double.tryParse(payMap['paidForPrevRunning'].toString()) ?? 0.0;
    double invDue = double.tryParse(payMap['due'].toString()) ?? 0.0;
    double totalPaidForInvoice =
        double.tryParse(payMap['paidForInvoice']?.toString() ?? '0') ?? 0.0;

    List<String> methodsUsed = [];
    if ((double.tryParse(payMap['cash']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Cash');
    }
    if ((double.tryParse(payMap['bkash']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Bkash');
    }
    if ((double.tryParse(payMap['nagad']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Nagad');
    }
    if ((double.tryParse(payMap['bank']?.toString() ?? '0') ?? 0) > 0) {
      methodsUsed.add('Bank');
    }

    String paymentMethodsStr =
        methodsUsed.isNotEmpty ? methodsUsed.join(', ') : "None/Credit";

    double subTotal = items.fold(
      0,
      (sumv, item) =>
          sumv + (double.tryParse(item['subtotal'].toString()) ?? 0),
    );

    double remainingOldDue = oldDueSnap - paidOld;
    if (remainingOldDue < 0) remainingOldDue = 0;

    double remainingPrevRunning = runningDueSnap - paidPrevRun;
    if (remainingPrevRunning < 0) remainingPrevRunning = 0;

    double netTotalDue = remainingOldDue + remainingPrevRunning + invDue;

    // 🌟 FIX: Deduct the surplus payments from Previous Balance for perfect reprinting math!
    double totalPreviousBalance = remainingOldDue + remainingPrevRunning;

    double currentInvTotal = subTotal - discount;

    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
        italic: italicFont,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        footer: (pw.Context context) => _buildNewFooter(context, regularFont),
        build: (pw.Context context) {
          return [
            _buildNewHeader(
              boldFont,
              regularFont,
              invId,
              "Sales Invoice",
              packagerName,
              authorizedName,
              invDue,
              false,
              null,
              "",
              paymentMethodsStr,
              invoiceDate,
            ),
            _buildNewCustomerBox(
              name,
              address,
              phone,
              shopName,
              regularFont,
              boldFont,
            ),
            pw.SizedBox(height: 5),
            _buildNewTable(items, boldFont, regularFont),
            _buildNewSummary(
              subTotal,
              discount,
              currentInvTotal,
              totalPaidForInvoice,
              paymentMethodsStr,
              items,
              boldFont,
              regularFont,
            ),
            pw.SizedBox(height: 5),
            _buildNewDues(totalPreviousBalance, netTotalDue, regularFont),
            if (invDue <= 0 && !isCondition)
              _buildPaidStamp(boldFont, regularFont, invoiceDate),
            if (invDue > 0 || isCondition) pw.SizedBox(height: 15),
            _buildWordsBox(currentInvTotal, boldFont),
            pw.SizedBox(height: 40),
            _buildNewSignatures(regularFont),
          ];
        },
      ),
    );

    if (isCondition) {
      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          footer: (pw.Context context) => _buildNewFooter(context, regularFont),
          build: (context) {
            return [
              _buildNewHeader(
                boldFont,
                regularFont,
                invId,
                "CONDITION CHALLAN",
                packagerName,
                authorizedName,
                invDue,
                isCondition,
                courier,
                challan,
                paymentMethodsStr,
                invoiceDate,
              ),
              _buildNewCustomerBox(
                name,
                address,
                phone,
                shopName,
                regularFont,
                boldFont,
              ),
              pw.SizedBox(height: 5),
              _buildNewTable(items, boldFont, regularFont),
              _buildNewSummary(
                subTotal,
                discount,
                currentInvTotal,
                totalPaidForInvoice,
                paymentMethodsStr,
                items,
                boldFont,
                regularFont,
              ),
              pw.SizedBox(height: 15),
              _buildConditionBox(boldFont, regularFont, invDue),
              pw.SizedBox(height: 15),
              _buildWordsBox(currentInvTotal, boldFont),
              pw.SizedBox(height: 40),
              _buildNewSignatures(regularFont),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (f) => pdf.save());
  }

  pw.Widget _buildNewHeader(
    pw.Font bold,
    pw.Font reg,
    String invId,
    String title,
    String? packager,
    String authorizedName,
    double invDue,
    bool isCondition,
    String? courier,
    String challan,
    String paymentMethodsStr,
    DateTime invoiceDate,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "G TEL",
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 24,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                "6/24A(7th Floor) Gulistan Shopping Complex (Hall Market)\n2 Bangabandu Avenue, Dhaka 1000",
                style: pw.TextStyle(font: reg, fontSize: 9),
              ),
              pw.Text(
                "Cell : 01720677206, 01911026222",
                style: pw.TextStyle(font: reg, fontSize: 9),
              ),
              pw.Text(
                "E-mail : gtel01720677206@gmail.com",
                style: pw.TextStyle(font: reg, fontSize: 9),
              ),
              pw.SizedBox(height: 15),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.only(right: 40),
                child: pw.Center(
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 16,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
            ],
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 4,
          child: pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
            padding: const pw.EdgeInsets.all(5),
            child: pw.Column(
              children: [
                _infoRow("Invoice No.", ": $invId", reg, bold),
                _infoRow(
                  "Date",
                  ": ${DateFormat('dd/MM/yyyy').format(invoiceDate)}",
                  reg,
                  bold,
                ),
                _infoRow("Ref: No", ": ", reg, bold),
                _infoRow(
                  "Prepared/Packged By",
                  ": ${packager ?? 'Admin'}",
                  reg,
                  bold,
                ),
                _infoRow(
                  "Entry Time",
                  ": ${DateFormat('h:mm:ss a').format(invoiceDate)}",
                  reg,
                  bold,
                ),
                _infoRow(
                  "Bill Type",
                  ": ${invDue <= 0 ? 'PAID' : 'DUE'}",
                  reg,
                  bold,
                ),
                _infoRow("Payment Via", ": $paymentMethodsStr", reg, bold),
                _infoRow("Sales Person", ": $authorizedName", reg, bold),
                if (isCondition) ...[
                  _infoRow("Courier", ": ${courier ?? 'N/A'}", reg, bold),
                  _infoRow("Challan No", ": $challan", reg, bold),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPaidStamp(pw.Font bold, pw.Font reg, DateTime invoiceDate) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 20),
      alignment: pw.Alignment.center,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.blue800, width: 2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              "P A I D",
              style: pw.TextStyle(
                color: PdfColors.blue800,
                font: bold,
                fontSize: 24,
                letterSpacing: 2,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              DateFormat('dd MMM yyyy').format(invoiceDate),
              style: pw.TextStyle(
                color: PdfColors.blue800,
                font: bold,
                fontSize: 12,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              "G TEL JOY EXPRESS",
              style: pw.TextStyle(
                color: PdfColors.blue800,
                font: bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildNewCustomerBox(
    String name,
    String address,
    String phone,
    String shopName,
    pw.Font reg,
    pw.Font bold,
  ) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _infoRow("To", ": $name", reg, bold, col1Width: 60),
          _infoRow("Address", address, reg, bold, col1Width: 60),
          _infoRow("Contact No.", ": $phone", reg, bold, col1Width: 60),
        ],
      ),
    );
  }

  pw.Widget _buildNewTable(
    List<Map<String, dynamic>> items,
    pw.Font bold,
    pw.Font reg,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(40),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(70),
      },
      children: [
        pw.TableRow(
          children: [
            _th("SL", bold),
            _th("Product Description", bold, align: pw.TextAlign.left),
            _th("Qty", bold),
            _th("Unit Price", bold),
            _th("Amount", bold),
          ],
        ),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return pw.TableRow(
            children: [
              _td((index + 1).toString(), reg, align: pw.TextAlign.center),
              _td(
                "${item['name']}${item['model'] != null ? ' - ' + item['model'] : ''}",
                reg,
              ),
              _td(item['qty'].toString(), reg, align: pw.TextAlign.center),
              _td(
                double.parse(item['saleRate'].toString()).toStringAsFixed(2),
                reg,
                align: pw.TextAlign.right,
              ),
              _td(
                double.parse(item['subtotal'].toString()).toStringAsFixed(2),
                reg,
                align: pw.TextAlign.right,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildNewSummary(
    double subTotal,
    double discount,
    double currentInvTotal,
    double paidForInvoice,
    String paymentMethodsStr,
    List items,
    pw.Font bold,
    pw.Font reg,
  ) {
    int totalQty = items.fold(
      0,
      (sumv, item) => sumv + ((item['qty'] as num?)?.toInt() ?? 0),
    );
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(width: 0.5),
          right: pw.BorderSide(width: 0.5),
          bottom: pw.BorderSide(width: 0.5),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Total Qty : $totalQty",
                    style: pw.TextStyle(font: bold, fontSize: 9),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Narration:",
                    style: pw.TextStyle(font: reg, fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Column(
                children: [
                  _sumRow(
                    "Total Amount",
                    subTotal.toStringAsFixed(2),
                    bold,
                    reg,
                  ),
                  _sumRow(
                    "Less Discount",
                    discount.toStringAsFixed(2),
                    reg,
                    reg,
                  ),
                  _sumRow("Add VAT", "0.00", reg, reg),
                  _sumRow("Add Extra Charges", "0.00", reg, reg),
                  pw.Divider(thickness: 0.5, height: 8),
                  _sumRow(
                    "Net Payable Amount",
                    currentInvTotal.toStringAsFixed(2),
                    bold,
                    bold,
                  ),
                  pw.SizedBox(height: 2),
                  _sumRow(
                    "Paid Amount",
                    paidForInvoice.toStringAsFixed(2),
                    reg,
                    bold,
                  ),
                  if (paymentMethodsStr != "None/Credit")
                    _sumRow("Payment Method", paymentMethodsStr, reg, reg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildNewDues(double prevDue, double netDue, pw.Font reg) {
    return pw.Container(
      width: 200,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        children: [
          _sumRow(
            "Previous Due Amount :",
            prevDue.toStringAsFixed(2),
            reg,
            reg,
          ),
          pw.Divider(thickness: 0.5, height: 5),
          _sumRow("Present Due Amount :", netDue.toStringAsFixed(2), reg, reg),
        ],
      ),
    );
  }

  pw.Widget _buildWordsBox(double currentInvTotal, pw.Font bold) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        "Taka in word : ${_numberToWords(currentInvTotal)} Only",
        style: pw.TextStyle(font: bold, fontSize: 9),
      ),
    );
  }

  String _numberToWords(double number) {
    if (number == 0) return "Zero";
    int num = number.floor();
    if (num < 0) return "Negative ${_numberToWords(-number)}";

    const units = [
      "",
      "One",
      "Two",
      "Three",
      "Four",
      "Five",
      "Six",
      "Seven",
      "Eight",
      "Nine",
      "Ten",
      "Eleven",
      "Twelve",
      "Thirteen",
      "Fourteen",
      "Fifteen",
      "Sixteen",
      "Seventeen",
      "Eighteen",
      "Nineteen",
    ];
    const tens = [
      "",
      "",
      "Twenty",
      "Thirty",
      "Forty",
      "Fifty",
      "Sixty",
      "Seventy",
      "Eighty",
      "Ninety",
    ];

    String convertLessThanOneThousand(int n) {
      String result = "";
      if (n >= 100) {
        result += "${units[n ~/ 100]} Hundred ";
        n %= 100;
      }
      if (n >= 20) {
        result += "${tens[n ~/ 10]} ";
        n %= 10;
      }
      if (n > 0) result += "${units[n]} ";
      return result;
    }

    String result = "";
    int crore = num ~/ 10000000;
    num %= 10000000;
    int lakh = num ~/ 100000;
    num %= 100000;
    int thousand = num ~/ 1000;
    num %= 1000;
    int remainder = num;

    if (crore > 0) result += "${convertLessThanOneThousand(crore)}Crore ";
    if (lakh > 0) result += "${convertLessThanOneThousand(lakh)}Lakh ";
    if (thousand > 0) {
      result += "${convertLessThanOneThousand(thousand)}Thousand ";
    }
    if (remainder > 0) result += convertLessThanOneThousand(remainder);

    return result.trim();
  }

  pw.Widget _buildNewSignatures(pw.Font reg) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Container(width: 120, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              "Client Signature",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 120, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              "Goods Delivery/Prepare",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 120, height: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              "Authorized Signature",
              style: pw.TextStyle(font: reg, fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildNewFooter(pw.Context context, pw.Font reg) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            "Terms & Conditions: 1. Goods once sold will not be refunded and changed, 2. Warranty will be void if any sticker removed, physically damaged and burn case, 3. Please keep this invoice/bill for warranty support.",
            style: pw.TextStyle(font: reg, fontSize: 7),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "Sales Billing Software By G TEL : 01720677206",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
            pw.Text(
              "Print Date & Time : ${DateFormat('dd/MM/yyyy h:mm a').format(DateTime.now())}",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
            pw.Text(
              "Page ${context.pageNumber} of ${context.pagesCount}",
              style: pw.TextStyle(font: reg, fontSize: 7),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildConditionBox(pw.Font bold, pw.Font reg, double due) {
    if (due <= 0) return pw.SizedBox();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.deepOrange700, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        color: PdfColors.deepOrange50,
      ),
      child: pw.Column(
        children: [
          pw.Text(
            "CONDITION PAYMENT INSTRUCTION FOR COURIER",
            style: pw.TextStyle(
              font: reg,
              fontSize: 11,
              color: PdfColors.deepOrange800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                "PLEASE COLLECT: ",
                style: pw.TextStyle(font: bold, fontSize: 16),
              ),
              pw.Text(
                "BDT${due.toStringAsFixed(0)}",
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 24,
                  color: PdfColors.deepOrange900,
                ),
              ),
              pw.Text(
                " + Courier Charges",
                style: pw.TextStyle(font: bold, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _infoRow(
    String label,
    String value,
    pw.Font reg,
    pw.Font bold, {
    double col1Width = 75,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: col1Width,
            child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 8)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(font: reg, fontSize: 8)),
          ),
        ],
      ),
    );
  }

  pw.Widget _sumRow(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valFont,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: labelFont, fontSize: 9)),
          pw.Text(value, style: pw.TextStyle(font: valFont, fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _th(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }

  pw.Widget _td(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 9),
      ),
    );
  }

  Future<void> collectNormalCustomerDue({
    required String transactionId,
    required double currentPending,
    required double collectedAmount,
    required String method,
    String? refNumber,
  }) async {
    if (collectedAmount <= 0) {
      Get.snackbar("Error", "Please enter a valid amount");
      return;
    }
    if (collectedAmount > currentPending + 1.0) {
      Get.snackbar("Error", "Collected amount cannot exceed the pending due");
      return;
    }

    isLoading.value = true;
    try {
      WriteBatch batch = _db.batch();
      double amount = _round(collectedAmount);

      QuerySnapshot dailySnap =
          await _db
              .collection('daily_sales')
              .where('transactionId', isEqualTo: transactionId)
              .limit(1)
              .get();

      if (dailySnap.docs.isEmpty) throw "Daily sales record not found!";
      DocumentSnapshot dailyDoc = dailySnap.docs.first;
      Map<String, dynamic> dailyData = dailyDoc.data() as Map<String, dynamic>;

      String cType = (dailyData['customerType'] ?? '').toString().toLowerCase();
      if (cType == 'agent' || cType == 'debtor') {
        throw "Agent dues must be collected from the Debtor Ledger.";
      }
      if (cType == 'condition_advance') {
        throw "Condition dues must be collected from the Condition Sales page.";
      }

      double currentPaid =
          double.tryParse(dailyData['paid']?.toString() ?? '0') ?? 0.0;
      double newPending = _round(currentPending - amount);
      if (newPending < 0) newPending = 0.0;

      String lowerMethod = method.toLowerCase();
      double addCash = lowerMethod == 'cash' ? amount : 0.0;
      double addBkash = lowerMethod == 'bkash' ? amount : 0.0;
      double addNagad = lowerMethod == 'nagad' ? amount : 0.0;
      double addBank = lowerMethod == 'bank' ? amount : 0.0;

      Map<String, dynamic> historyEntry = {
        'type': lowerMethod,
        'amount': amount,
        'timestamp': Timestamp.now(),
        'note': 'Late Due Collection',
      };

      Map<String, dynamic> dailyUpdateData = {
        'paid': _round(currentPaid + amount),
        'pending': newPending,
        'status': newPending <= 0.5 ? 'paid' : 'partial',
        'paymentMethod.cash': FieldValue.increment(addCash),
        'paymentMethod.bkash': FieldValue.increment(addBkash),
        'paymentMethod.nagad': FieldValue.increment(addNagad),
        'paymentMethod.bank': FieldValue.increment(addBank),
      };

      Map<String, dynamic> orderUpdateData = {
        'paymentDetails.cash': FieldValue.increment(addCash),
        'paymentDetails.bkash': FieldValue.increment(addBkash),
        'paymentDetails.nagad': FieldValue.increment(addNagad),
        'paymentDetails.bank': FieldValue.increment(addBank),
        'paymentDetails.paidForInvoice': FieldValue.increment(amount),
        'paymentDetails.totalPaidInput': FieldValue.increment(amount),
        'paymentDetails.due': newPending,
      };

      if (newPending <= 0.5) {
        orderUpdateData['isFullyPaid'] = true;
        orderUpdateData['status'] = 'completed';
      }

      if (refNumber != null && refNumber.isNotEmpty) {
        if (lowerMethod == 'bank') {
          historyEntry['bankName'] = method;
          historyEntry['accountNumber'] = refNumber;
          dailyUpdateData['paymentMethod.bankName'] = method;
          dailyUpdateData['paymentMethod.accountNumber'] = refNumber;
          orderUpdateData['paymentDetails.bankName'] = method;
          orderUpdateData['paymentDetails.accountNumber'] = refNumber;
        } else if (lowerMethod == 'bkash') {
          historyEntry['bkashNumber'] = refNumber;
          dailyUpdateData['paymentMethod.bkashNumber'] = refNumber;
          orderUpdateData['paymentDetails.bkashNumber'] = refNumber;
        } else if (lowerMethod == 'nagad') {
          historyEntry['nagadNumber'] = refNumber;
          dailyUpdateData['paymentMethod.nagadNumber'] = refNumber;
          orderUpdateData['paymentDetails.nagadNumber'] = refNumber;
        }
      }

      dailyUpdateData['paymentHistory'] = FieldValue.arrayUnion([historyEntry]);

      batch.update(dailyDoc.reference, dailyUpdateData);

      DocumentReference orderRef = _db
          .collection('sales_orders')
          .doc(transactionId);
      DocumentSnapshot orderSnap = await orderRef.get();
      if (orderSnap.exists) {
        batch.update(orderRef, orderUpdateData);
      }

      await batch.commit();
      await loadDailySales();

      Get.back();
      Get.snackbar(
        "Success",
        "৳$amount collected successfully!",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString(),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
}