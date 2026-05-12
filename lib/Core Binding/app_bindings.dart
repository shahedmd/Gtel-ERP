import 'package:get/get.dart';
import 'package:gtel_erp/Cash/controller.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/gteldebtorcontroller.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Daily%20Expense/dailyexpensecontroller.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Monthly%20Expense/montlyexpensecontroller.dart';
import 'package:gtel_erp/Stock%20Management/Local%20Purchase/purchase_controller.dart';
import 'package:gtel_erp/Stock%20Management/stock_controller.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Web%20Screen/Sales/controller.dart';
import 'package:gtel_erp/Web%20Screen/Staff/controller.dart';
import 'package:gtel_erp/Web%20Screen/overviewcontroller.dart';

import '../Authentication/auth_controller.dart';
import '../Menubar and Navigation/menu_bar.dart';
import '../Permission/permission_controller.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController(), permanent: true);
    Get.put(NavigationController(), permanent: true);
    Get.put(PermissionController(), permanent: true);

    Get.lazyPut(() => DailySalesController(), fenix: true);
    Get.lazyPut(() => MonthlyExpensesController(), fenix: true);
    Get.lazyPut(() => DailyExpensesController(), fenix: true);
    Get.lazyPut(() => DebatorController(), fenix: true);
    Get.lazyPut(() => ProductController(), fenix: true);
    Get.lazyPut(() => CashDrawerController(), fenix: true);
    Get.lazyPut(() => ShipmentController(), fenix: true);
    Get.lazyPut(() => StaffController(), fenix: true);
    Get.lazyPut(() => DebtorPurchaseController(), fenix: true);
    Get.lazyPut(() => OverviewController(), fenix: true);
  }
}