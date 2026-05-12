import 'package:get/get.dart';
import 'package:gtel_erp/Account%20Overview/aopage.dart';
import 'package:gtel_erp/Cash/page.dart';
import 'package:gtel_erp/Core/Debtor_Market_Customer_Suppliers/debtorlistuipage.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Daily%20Expense/dailyexpenseuipage.dart';
import 'package:gtel_erp/Core/Gtel%20Expense/Monthly%20Expense/monthlyexpenseuipage.dart';
import 'package:gtel_erp/Stock%20Management/Local%20Purchase/local_purchase_page.dart';
import 'package:gtel_erp/Stock%20Management/Purchase%20History/Views/purchase_history.dart';
import 'package:gtel_erp/Stock%20Management/Stock%20Service%20&%20Damage/View/service_page.dart';
import 'package:gtel_erp/Stock%20Management/china_order_list.dart';
import 'package:gtel_erp/Stock%20Management/stock_page_ui.dart';
import 'package:gtel_erp/Customer/cusotmerpage.dart';
import 'package:gtel_erp/Live%20order/liveorder.dart';
import 'package:gtel_erp/Profit%26loss/page.dart';
import 'package:gtel_erp/Sale%20Return/salereturnpage.dart';
import 'package:gtel_erp/Shipment/shipmentpage.dart';
import 'package:gtel_erp/Staff%20Sale%20Report/ui.dart';
import 'package:gtel_erp/Vendor/vendorpage.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/conditionpage.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Monthly/monthsalespage.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Product%20analytics/ppage.dart';
import 'package:gtel_erp/Web%20Screen/Sales/dailysales.dart';
import 'package:gtel_erp/Web%20Screen/Staff/Staffpage.dart';
import 'package:gtel_erp/Web%20Screen/homepage.dart';
import 'package:gtel_erp/Web%20Screen/overviewpage.dart';

import '../Authentication/login_page_ui.dart';
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
}

class AppRouteMeta {
  final String route;
  final String title;

  const AppRouteMeta({required this.route, required this.title});
}

abstract class AppRouteRegistry {
  static const List<AppRouteMeta> permissionRoutes = [
    AppRouteMeta(route: Routes.liveorder, title: 'New Order'),
    AppRouteMeta(route: Routes.dailysales, title: 'Daily Sales'),
    AppRouteMeta(route: Routes.monthlysalespage, title: 'Monthly Sales'),
    AppRouteMeta(route: Routes.conditionpage, title: 'Condition Sale'),
    AppRouteMeta(route: Routes.salereturn, title: 'Sale Return'),
    AppRouteMeta(route: Routes.staffsalesreport, title: 'Staff Sales Report'),
    AppRouteMeta(route: Routes.productoverview, title: 'Product Analytics'),
    AppRouteMeta(route: Routes.customeroverview, title: 'Customer Analytics'),
    AppRouteMeta(route: Routes.debtor, title: 'Debtor / Agent'),
    AppRouteMeta(route: Routes.stock, title: 'Stock Management'),
    AppRouteMeta(route: Routes.service, title: 'Service Product'),
    AppRouteMeta(route: Routes.shipment, title: 'Shipment'),
    AppRouteMeta(route: Routes.orderlist, title: 'China Order List'),
    AppRouteMeta(route: Routes.localpurchase, title: 'Local Purchase'),
    AppRouteMeta(route: Routes.purchase, title: 'Purchase History'),
    AppRouteMeta(route: Routes.dashboard, title: 'Daily Ledger'),
    AppRouteMeta(route: Routes.cash, title: 'Cash Drawer'),
    AppRouteMeta(route: Routes.profitloss, title: 'Profit & Loss'),
    AppRouteMeta(route: Routes.overviewaccount, title: 'Account Overview'),
    AppRouteMeta(route: Routes.vendor, title: 'Vendor'),
    AppRouteMeta(route: Routes.dailyexpenses, title: 'Daily Expenses'),
    AppRouteMeta(route: Routes.monthlyexpense, title: 'Monthly Expenses'),
    AppRouteMeta(route: Routes.staff, title: 'Staff Members'),
  ];

  static List<String> get permissionRouteNames {
    return permissionRoutes.map((item) => item.route).toList();
  }

  static String routeDisplayName(String route) {
    return permissionRoutes
            .firstWhereOrNull((item) => item.route == route)
            ?.title ??
        route;
  }

  static Map<String, String> actionLabelsForRoute(String route) {
    return actionPermissions[route] ?? const {};
  }

  static const Map<String, Map<String, String>> actionPermissions = {
    Routes.dailysales: {
      'sale.reprint': 'Reprint Sale',
      'sale.delete': 'Delete Sale',
      'sale.edit_payment': 'Edit Payment',
      'sale.discount': 'Discount',
    },
    Routes.liveorder: {
      'live_sale.create_invoice': 'Create Invoice',
      'live_sale.change_price': 'Change Price',
      'live_sale.discount': 'Discount',
      'live_sale.delete_item': 'Delete Item',
    },
    Routes.conditionpage: {
      'condition.collect_payment': 'Collect Payment',
      'condition.reprint': 'Reprint',
      'condition.cancel': 'Cancel Sale',
    },
    Routes.salereturn: {
      'sale_return.create': 'Create Return',
      'sale_return.approve': 'Approve Return',
      'sale_return.delete': 'Delete Return',
    },
    Routes.stock: {
      'stock.adjust': 'Adjust Stock',
      'stock.edit_price': 'Edit Price',
      'stock.delete_product': 'Delete Product',
      'stock.export': 'Export Stock',
    },
    Routes.localpurchase: {
      'purchase.create': 'Create Purchase',
      'purchase.edit': 'Edit Purchase',
      'purchase.delete': 'Delete Purchase',
      'purchase.payment': 'Make Payment',
    },
    Routes.purchase: {
      'purchase_history.reprint': 'Reprint Invoice',
      'purchase_history.payment': 'Make Payment',
      'purchase_history.delete': 'Delete Record',
    },
    Routes.cash: {
      'cash.add_entry': 'Add Entry',
      'cash.edit_entry': 'Edit Entry',
      'cash.delete_entry': 'Delete Entry',
      'cash.export': 'Export Ledger',
    },
    Routes.debtor: {
      'debtor.add_transaction': 'Add Transaction',
      'debtor.edit_transaction': 'Edit Transaction',
      'debtor.delete_transaction': 'Delete Transaction',
      'debtor.sync_balance': 'Sync Balance',
    },
    Routes.shipment: {
      'shipment.create': 'Create Shipment',
      'shipment.edit': 'Edit Shipment',
      'shipment.delete': 'Delete Shipment',
      'shipment.close': 'Close Shipment',
    },
    Routes.staff: {
      'staff.add_salary': 'Add Salary',
      'staff.edit_salary': 'Edit Salary',
      'staff.delete_salary': 'Delete Salary',
      'staff.suspend': 'Suspend Staff',
    },
    Routes.vendor: {
      'vendor.add_payment': 'Add Payment',
      'vendor.edit_payment': 'Edit Payment',
      'vendor.delete_payment': 'Delete Payment',
    },
  };
}

abstract class AppPages {
  static final List<GetPage> pages = [
    GetPage(name: Routes.login, page: () => const LoginPage()),
    GetPage(
      name: Routes.home,
      page: () => const AdminHomepage(),
      preventDuplicates: true,
    ),
  ];

  static final List<GetPage> nestedPages = [
    GetPage(
      name: Routes.liveorder,
      page:
          () => PermissionGuard(
            route: Routes.liveorder,
            child: LiveOrderSalesPage(),
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
      name: Routes.conditionpage,
      page:
          () => PermissionGuard(
            route: Routes.conditionpage,
            child: ConditionSalesPage(),
          ),
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
      name: Routes.customeroverview,
      page:
          () => PermissionGuard(
            route: Routes.customeroverview,
            child: CustomerAnalyticsPage(),
          ),
    ),
    GetPage(
      name: Routes.debtor,
      page: () => PermissionGuard(route: Routes.debtor, child: Debatorpage()),
    ),
    GetPage(
      name: Routes.stock,
      page: () => PermissionGuard(route: Routes.stock, child: ProductScreen()),
    ),
    GetPage(
      name: Routes.service,
      page: () => PermissionGuard(route: Routes.service, child: ServicePage()),
    ),
    GetPage(
      name: Routes.shipment,
      page:
          () => PermissionGuard(route: Routes.shipment, child: ShipmentPage()),
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
    GetPage(
      name: Routes.purchase,
      page:
          () => PermissionGuard(
            route: Routes.purchase,
            child: GlobalPurchasePage(),
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
      name: Routes.cash,
      page: () => PermissionGuard(route: Routes.cash, child: CashDrawerView()),
    ),
    GetPage(
      name: Routes.profitloss,
      page:
          () => PermissionGuard(route: Routes.profitloss, child: ProfitView()),
    ),
    GetPage(
      name: Routes.overviewaccount,
      page:
          () => PermissionGuard(
            route: Routes.overviewaccount,
            child: const FinancialOverviewPage(),
          ),
    ),
    GetPage(
      name: Routes.vendor,
      page: () => PermissionGuard(route: Routes.vendor, child: VendorPage()),
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
      name: Routes.staff,
      page: () => PermissionGuard(route: Routes.staff, child: StaffListPage()),
    ),
    GetPage(name: Routes.superadmin, page: () => const SuperAdminPage()),
  ];
}