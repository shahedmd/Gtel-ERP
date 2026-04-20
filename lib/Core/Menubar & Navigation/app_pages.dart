// lib/Core/Menubar & Navigation/app_pages.dart

import 'package:get/get.dart';
import 'package:gtel_erp/Account%20Overview/aopage.dart';
import 'package:gtel_erp/Cash/page.dart';
import 'package:gtel_erp/Core/Auth/login.dart';
import 'package:gtel_erp/Customer/cusotmerpage.dart';
import 'package:gtel_erp/Live%20order/liveorder.dart';
import 'package:gtel_erp/Profit%26loss/page.dart';
import 'package:gtel_erp/Sale%20Return/salereturnpage.dart';
import 'package:gtel_erp/Shipment/shipmentpage.dart';
import 'package:gtel_erp/Staff%20Sale%20Report/ui.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockdamange_servicepage.dart';
import 'package:gtel_erp/Core/Stock%20Management/chinaorderlist.dart';
import 'package:gtel_erp/Core/Stock%20Management/localpurchaseapage.dart';
import 'package:gtel_erp/Core/Stock%20Management/stockpage.dart';
import 'package:gtel_erp/Vendor/vendorpage.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/debtorlistuipage.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/purchasehistorypage.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Daily%20Expense/dailyexpenseuipage.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Monthly%20Expense/monthlyexpenseuipage.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/conditionpage.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Monthly/monthsalespage.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Product%20analytics/ppage.dart';
import 'package:gtel_erp/Web%20Screen/Sales/dailysales.dart';
import 'package:gtel_erp/Web%20Screen/Staff/Staffpage.dart';
import 'package:gtel_erp/Web%20Screen/homepage.dart';
import 'package:gtel_erp/Web%20Screen/overviewpage.dart';
import '../Bindings/home_binding_v2.dart';
import '../Permission/permission_guard.dart';
import '../Super Admin Panel/superadminpage.dart';

abstract class Routes {
  static const String login = '/';
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String debtor = '/debtor';
  static const String dailyexpenses = '/expenses-daily';
  static const String monthlyexpense = '/expenses-monthly';
  static const String dailysales = '/sales-daily';
  static const String monthlysalespage = '/sales-monthly';
  static const String stock = '/stock';
  static const String profitloss = '/profit';
  static const String staff = '/staff';
  static const String liveorder = '/liveorder';
  static const String cash = '/cash';
  static const String service = '/service';
  static const String salereturn = '/salereturn';
  static const String shipment = '/shipment';
  static const String conditionpage = '/condition';
  static const String vendor = '/vendor';
  static const String overviewaccount = '/accountoverview';
  static const String customeroverview = '/customeroverview';
  static const String staffsalesreport = '/staffsalereport';
  static const String productoverview = '/productoverview';
  static const String purchase = '/purchase';
  static const String orderlist = '/orderlist';
  static const String localpurchase = '/localpurchase';
  static const String superadmin = '/superadmin';

  // static const String agentportal = '/agent';
}

// ─────────────────────────────────────────────────────────────
// AppPages — সব route definition
// প্রতিটা nested page PermissionGuard দিয়ে wrap করা
// ─────────────────────────────────────────────────────────────
abstract class AppPages {
  static final List<GetPage> pages = [
    GetPage(name: Routes.login, page: () => const LoginPage()),
    GetPage(
      name: Routes.home,
      page: () => AdminHomepage(),
      binding: HomeBinding(),
      preventDuplicates: true,
    ),
  ];

  static final List<GetPage> nestedPages = [
    GetPage(
      name: Routes.overviewaccount,
      page:
          () => PermissionGuard(
            route: Routes.overviewaccount,
            child: const FinancialOverviewPage(),
          ),
    ),
    GetPage(
      name: Routes.dashboard,
      page:
          () => PermissionGuard(
            route: Routes.dashboard,
            child: DailyOverviewPage(),
          ),
    ),
    GetPage(
      name: Routes.debtor,
      page: () => PermissionGuard(route: Routes.debtor, child: Debatorpage()),
    ),
    GetPage(
      name: Routes.dailyexpenses,
      page:
          () => PermissionGuard(
            route: Routes.dailyexpenses,
            child: DailyExpensesPage(),
          ),
    ),
    GetPage(
      name: Routes.monthlyexpense,
      page:
          () => PermissionGuard(
            route: Routes.monthlyexpense,
            child: MonthlyExpensesPage(),
          ),
    ),
    GetPage(
      name: Routes.dailysales,
      page:
          () => PermissionGuard(
            route: Routes.dailysales,
            child: DailySalesPage(),
          ),
    ),
    GetPage(
      name: Routes.monthlysalespage,
      page:
          () => PermissionGuard(
            route: Routes.monthlysalespage,
            child: MonthlySalesPage(),
          ),
    ),
    GetPage(
      name: Routes.stock,
      page: () => PermissionGuard(route: Routes.stock, child: ProductScreen()),
    ),
    GetPage(
      name: Routes.staff,
      page: () => PermissionGuard(route: Routes.staff, child: StaffListPage()),
    ),
    GetPage(
      name: Routes.liveorder,
      page:
          () => PermissionGuard(
            route: Routes.liveorder,
            child: LiveOrderSalesPage(),
          ),
    ),
    GetPage(
      name: Routes.profitloss,
      page:
          () => PermissionGuard(route: Routes.profitloss, child: ProfitView()),
    ),
    GetPage(
      name: Routes.cash,
      page: () => PermissionGuard(route: Routes.cash, child: CashDrawerView()),
    ),
    GetPage(
      name: Routes.service,
      page: () => PermissionGuard(route: Routes.service, child: ServicePage()),
    ),
    GetPage(
      name: Routes.salereturn,
      page:
          () => PermissionGuard(
            route: Routes.salereturn,
            child: SaleReturnPage(),
          ),
    ),
    GetPage(
      name: Routes.shipment,
      page:
          () => PermissionGuard(route: Routes.shipment, child: ShipmentPage()),
    ),
    GetPage(
      name: Routes.conditionpage,
      page:
          () => PermissionGuard(
            route: Routes.conditionpage,
            child: ConditionSalesPage(),
          ),
    ),
    GetPage(
      name: Routes.vendor,
      page: () => PermissionGuard(route: Routes.vendor, child: VendorPage()),
    ),
    GetPage(
      name: Routes.customeroverview,
      page:
          () => PermissionGuard(
            route: Routes.customeroverview,
            child: CustomerAnalyticsPage(),
          ),
    ),
    GetPage(
      name: Routes.staffsalesreport,
      page:
          () => PermissionGuard(
            route: Routes.staffsalesreport,
            child: StaffReportScreen(),
          ),
    ),
    GetPage(
      name: Routes.productoverview,
      page:
          () => PermissionGuard(
            route: Routes.productoverview,
            child: HotSellingProductPage(),
          ),
    ),
    GetPage(
      name: Routes.purchase,
      page:
          () => PermissionGuard(
            route: Routes.purchase,
            child: GlobalPurchasePage(),
          ),
    ),
    GetPage(
      name: Routes.orderlist,
      page:
          () => PermissionGuard(
            route: Routes.orderlist,
            child: OrderHistoryPage(),
          ),
    ),
    GetPage(
      name: Routes.localpurchase,
      page:
          () => PermissionGuard(
            route: Routes.localpurchase,
            child: SmartPurchaseScreen(),
          ),
    ),
    GetPage(name: Routes.superadmin, page: () => const SuperAdminPage()),
  ];
}
