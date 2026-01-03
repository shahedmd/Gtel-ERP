

// Ensure these match your actual file paths
import 'package:get/get.dart';

import 'Expenses/dailycontroller.dart';
import 'Sales/controller.dart';

class OverviewController extends GetxController {
  final DailySalesController salesCtrl = Get.find<DailySalesController>();
  final DailyExpensesController expenseCtrl =
      Get.find<DailyExpensesController>();

  var selectedDate = DateTime.now().obs;

  // Observables
  RxDouble grossSales = 0.0.obs;
  RxDouble totalCollected = 0.0.obs;
  RxDouble totalExpenses = 0.0.obs;
  RxDouble netProfiit = 0.0.obs;
  RxDouble outstandingDebt = 0.0.obs;

  RxMap<String, double> paymentMethods =
      <String, double>{
        "cash": 0.0,
        "bkash": 0.0,
        "nagad": 0.0,
        "bank": 0.0,
      }.obs;

  @override
  void onInit() {
    super.onInit();
    _syncDateAndFetch();

    // Listen to changes in the lists to update charts in real-time
    ever(salesCtrl.salesList, (_) => _recalculate());
    ever(expenseCtrl.dailyList, (_) => _recalculate());
    ever(salesCtrl.totalSales, (_) => _recalculate());
    ever(expenseCtrl.dailyTotal, (_) => _recalculate());

    _recalculate();
  }

  void _syncDateAndFetch() {
    salesCtrl.changeDate(selectedDate.value);
    expenseCtrl.changeDate(selectedDate.value);
  }

  void _recalculate() {
    // 1. Fetch Totals from Sub-Controllers
    grossSales.value = salesCtrl.totalSales.value;
    totalCollected.value = salesCtrl.paidAmount.value;
    outstandingDebt.value = salesCtrl.debtorPending.value;
    totalExpenses.value = expenseCtrl.dailyTotal.value.toDouble();

    // Net Profit = Collected Revenue - Expenses
    netProfiit.value = totalCollected.value - totalExpenses.value;

    // 2. Calculate Payment Method Breakdown (THE FIX IS HERE)
    double cash = 0, bkash = 0, nagad = 0, bank = 0;

    for (var sale in salesCtrl.salesList) {
      // Access the paymentMethod map from your model
      var pm = sale.paymentMethod;

      if (pm != null) {
        String type = (pm['type'] ?? 'cash').toString().toLowerCase();

        // CASE 1: New Multi-Payment System
        if (type == 'multi') {
          cash += (double.tryParse(pm['cash'].toString()) ?? 0.0);
          bkash += (double.tryParse(pm['bkash'].toString()) ?? 0.0);
          nagad += (double.tryParse(pm['nagad'].toString()) ?? 0.0);
          bank += (double.tryParse(pm['bank'].toString()) ?? 0.0);
        }
        // CASE 2: Old/Single Payment System
        else {
          // In old system, we take the full 'paid' amount for the specific type
          double amount = double.tryParse(sale.paid.toString()) ?? 0.0;

          if (type == 'bkash') {
            bkash += amount;
          }
           if (type == 'nagad') {
             nagad += amount;
           }
           if (type == 'bank') {
             bank += amount;
           } else {
             cash += amount; // Default to cash
           }
        }
      } else {
        // Fallback if paymentMethod is missing, assume cash
        cash += double.tryParse(sale.paid.toString()) ?? 0.0;
      }
    }

    // Update the map for the Pie Chart
    paymentMethods["cash"] = cash;
    paymentMethods["bkash"] = bkash;
    paymentMethods["nagad"] = nagad;
    paymentMethods["bank"] = bank;

    paymentMethods.refresh();
  }

  Future<void> selectDate(DateTime date) async {
    selectedDate.value = date;
    _syncDateAndFetch();
    _recalculate();
  }
}
