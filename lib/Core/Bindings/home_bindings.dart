import 'package:get/get.dart';
import 'package:gtel_erp/Cash/controller.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/sidemenubar.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/Debtor%20Purchase/purchasecontroller.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/debatorcontroller.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/monthlycontroller.dart';
import 'package:gtel_erp/Web%20Screen/Sales/controller.dart';
import 'package:gtel_erp/Web%20Screen/Staff/controller.dart';
import 'package:gtel_erp/Web%20Screen/overviewcontroller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => NavigationController());

    Get.lazyPut(() => MonthlyExpensesController());
    Get.lazyPut(() => DailySalesController());
    Get.lazyPut(() => DailyExpensesController());
    Get.lazyPut(() => DebatorController());
    Get.lazyPut(() => ProductController());
    Get.lazyPut(() => CashDrawerController());
    Get.lazyPut(() => ShipmentController());
    Get.lazyPut(() => StaffController());
    Get.lazyPut(() => DebtorPurchaseController());
    Get.lazyPut(() => OverviewController());
  }
}
