import 'package:get/get.dart';
import 'package:gtel_erp/Account%20Overview/aopage.dart';
import 'package:gtel_erp/Cash/page.dart';
import 'package:gtel_erp/Core/Auth/login.dart';
import 'package:gtel_erp/Customer/cusotmerpage.dart';
import 'package:gtel_erp/Live%20order/liveorder.dart';
import 'package:gtel_erp/Profit&loss/page.dart';
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
import '../../Permission/permission_guard.dart';
import '../../Superadmin/super_admin_panel.dart';
import '../Bindings/home_bindings.dart';

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
  static const String superadmin = '/superadmin'; // ← নতুন
}

abstract class AppPages {
  static final List<GetPage> pages = [
    GetPage(name: Routes.login, page: () => const LoginPage()),
    GetPage(
      name: Routes.home,
      page: () => AdminHomepage(),
      binding: HomeBinding(),
    ),
  ];
static final List<GetPage> nestedPages = [
  GetPage(
    name: Routes.overviewaccount,
    page: () => const PermissionGuard(
      moduleKey: 'overview',
      child: FinancialOverviewPage(),
    ),
  ),
  GetPage(
    name: Routes.dashboard,
    page: () => PermissionGuard(
      moduleKey: 'daily_ledger',
      child: DailyOverviewPage(),
    ),
  ),
  GetPage(
    name: Routes.debtor,
    page: () => PermissionGuard(
      moduleKey: 'debtor',
      child: Debatorpage(),
    ),
  ),
  GetPage(
    name: Routes.dailyexpenses,
    page: () =>  PermissionGuard(
      moduleKey: 'daily_expenses',
      child: DailyExpensesPage(),
    ),
  ),
  GetPage(
    name: Routes.monthlyexpense,
    page: () =>  PermissionGuard(
      moduleKey: 'monthly_expenses',
      child: MonthlyExpensesPage(),
    ),
  ),
  GetPage(
    name: Routes.dailysales,
    page: () =>  PermissionGuard(
      moduleKey: 'daily_sales',
      child: DailySalesPage(),
    ),
  ),
  GetPage(
    name: Routes.monthlysalespage,
    page: () =>  PermissionGuard(
      moduleKey: 'monthly_sales',
      child: MonthlySalesPage(),
    ),
  ),
  GetPage(
    name: Routes.stock,
    page: () => PermissionGuard(
      moduleKey: 'stock',
      child: ProductScreen(),
    ),
  ),
  GetPage(
    name: Routes.staff,
    page: () =>  PermissionGuard(
      moduleKey: 'staff',
      child: StaffListPage(),
    ),
  ),
  GetPage(
    name: Routes.liveorder,
    page: () =>  PermissionGuard(
      moduleKey: 'new_order',
      child: LiveOrderSalesPage(),
    ),
  ),
  GetPage(
    name: Routes.profitloss,
    page: () => PermissionGuard(
      moduleKey: 'profit_loss',
      child: ProfitView(),
    ),
  ),
  GetPage(
    name: Routes.cash,
    page: () =>  PermissionGuard(
      moduleKey: 'cash',
      child: CashDrawerView(),
    ),
  ),
  GetPage(
    name: Routes.service,
    page: () =>  PermissionGuard(
      moduleKey: 'service',
      child: ServicePage(),
    ),
  ),
  GetPage(
    name: Routes.salereturn,
    page: () =>  PermissionGuard(
      moduleKey: 'sale_return',
      child: SaleReturnPage(),
    ),
  ),
  GetPage(
    name: Routes.shipment,
    page: () =>  PermissionGuard(
      moduleKey: 'shipment',
      child: ShipmentPage(),
    ),
  ),
  GetPage(
    name: Routes.conditionpage,
    page: () =>  PermissionGuard(
      moduleKey: 'condition_sale',
      child: ConditionSalesPage(),
    ),
  ),
  GetPage(
    name: Routes.vendor,
    page: () =>  PermissionGuard(
      moduleKey: 'vendor',
      child: VendorPage(),
    ),
  ),
  GetPage(
    name: Routes.customeroverview,
    page: () =>  PermissionGuard(
      moduleKey: 'customer',
      child: CustomerAnalyticsPage(),
    ),
  ),
  GetPage(
    name: Routes.staffsalesreport,
    page: () => const PermissionGuard(
      moduleKey: 'staff_overview',
      child: StaffReportScreen(),
    ),
  ),
  GetPage(
    name: Routes.productoverview,
    page: () => const PermissionGuard(
      moduleKey: 'product_overview',
      child: HotSellingProductPage(),
    ),
  ),
  GetPage(
    name: Routes.purchase,
    page: () =>  PermissionGuard(
      moduleKey: 'purchase_history',
      child: GlobalPurchasePage(),
    ),
  ),
  GetPage(
    name: Routes.orderlist,
    page: () =>  PermissionGuard(
      moduleKey: 'order_list',
      child: OrderHistoryPage(),
    ),
  ),
  GetPage(
    name: Routes.localpurchase,
    page: () => const PermissionGuard(
      moduleKey: 'local_purchase',
      child: SmartPurchaseScreen(),
    ),
  ),
  // ── Super Admin Panel — permission guard নেই, role check করে ────────────
  GetPage(
    name: Routes.superadmin,
    page: () => const SuperAdminPage(),
  ),
];
}