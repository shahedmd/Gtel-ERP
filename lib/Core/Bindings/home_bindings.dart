import 'package:get/get.dart';
import 'package:gtel_erp/Cash/controller.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockcontroller.dart';
import 'package:gtel_erp/Customer/customercontroller.dart';
import 'package:gtel_erp/Shipment/controller.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/sidemenubar.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/Debtor%20Purchase/purchasecontroller.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/gteldebtorcontroller.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Monthly%20Expense/montlyexpensecontroller.dart';
import 'package:gtel_erp/Web%20Screen/Sales/controller.dart';
import 'package:gtel_erp/Web%20Screen/Staff/controller.dart';
import 'package:gtel_erp/Web%20Screen/overviewcontroller.dart';
import 'package:gtel_erp/controller.dart';
import '../Gtel Expense/Daily Expense/dailyexpensecontroller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(NavigationController(), permanent: true);

    Get.put(MonthlyExpensesController(), permanent: true);
    Get.put(DailyExpensesController(), permanent: true);

    Get.put(DailySalesController(), permanent: true);
    Get.put(OverviewController(), permanent: true);
    Get.put(CashDrawerController(), permanent: true);

    Get.lazyPut(() => DebatorController(), fenix: true);
    Get.lazyPut(() => ProductController(), fenix: true);
    Get.lazyPut(() => ShipmentController(), fenix: true);
    Get.lazyPut(() => StaffController(), fenix: true);
    Get.lazyPut(() => DebtorPurchaseController(), fenix: true);
    Get.lazyPut(() => RoleController(), fenix: true);
    Get.lazyPut(() => CustomerAnalyticsController(), fenix: true);
  }
}
