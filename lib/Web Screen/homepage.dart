import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Account%20Overview/aopage.dart';
import 'package:gtel_erp/Cash/page.dart';
import 'package:gtel_erp/Customer/cusotmerpage.dart';
import 'package:gtel_erp/Staff%20Sale%20Report/ui.dart';
import 'package:gtel_erp/Stock/Service/servicepage.dart';
import 'package:gtel_erp/Stock/orderhistory.dart';
import 'package:gtel_erp/Vendor/vendorpage.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/purchasehistorypage.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/conditionpage.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Product%20analytics/ppage.dart';
import '../Live order/liveorder.dart';
import '../Profit&loss/page.dart';
import '../Sale Return/salereturnpage.dart';
import '../Shipment/shipmentpage.dart';
import '../Stock/stockpage.dart';
import '../Web Elements/customwidget.dart';
import '../Web Elements/route.dart';
import 'Debator Finance/debator.dart';
import 'Expenses/dailyexpense.dart';
import 'Expenses/monthlyexpense.dart';
import 'Sales/Monthly/monthsalespage.dart';
import 'Sales/dailysales.dart';
import 'Staff/Staffpage.dart';
import 'overviewpage.dart';

class AdminHomepage extends StatefulWidget {
  const AdminHomepage({super.key});

  @override
  State<AdminHomepage> createState() => _AdminHomepageState();
}

class _AdminHomepageState extends State<AdminHomepage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        child: Row(
          children: [
            SidebarMenu(),

            Expanded(
              child: Navigator(
                key: Get.nestedKey(1),
                initialRoute: Routes.DASHBOARD,
                onGenerateRoute: (settings) {
                  // Map your IDs to your actual Pages here
                  if (settings.name == Routes.DASHBOARD) {
                    return GetPageRoute(page: () => DailyOverviewPage());
                  }
                  if (settings.name == Routes.DEBTOR) {
                    return GetPageRoute(page: () => Debatorpage());
                  }
                  if (settings.name == Routes.DAILY_EXPENSES) {
                    return GetPageRoute(page: () => DailyExpensesPage());
                  }
                  if (settings.name == Routes.MONTHLY_EXPENSES) {
                    return GetPageRoute(page: () => MonthlyExpensesPage());
                  }
                  if (settings.name == Routes.DAILY_SALES) {
                    return GetPageRoute(page: () => DailySalesPage());
                  }
                  if (settings.name == Routes.MONTHLY_SALES) {
                    return GetPageRoute(page: () => MonthlySalesPage());
                  }
                  if (settings.name == Routes.STOCK) {
                    return GetPageRoute(page: () => ProductScreen());
                  }
                  if (settings.name == Routes.STAFF) {
                    return GetPageRoute(page: () => StaffListPage());
                  }
                  if (settings.name == Routes.LIVEORDER) {
                    return GetPageRoute(page: () => LiveOrderSalesPage());
                  }
                  if (settings.name == Routes.PROFITLOSS) {
                    return GetPageRoute(page: () => ProfitView());
                  }
                  if (settings.name == Routes.CASH) {
                    return GetPageRoute(page: () => CashDrawerView());
                  }
                  if (settings.name == Routes.SERVICE) {
                    return GetPageRoute(page: () => ServicePage());
                  }
                  if (settings.name == Routes.SALERETURN) {
                    return GetPageRoute(page: () => SaleReturnPage());
                  }
                  if (settings.name == Routes.SHIPMENT) {
                    return GetPageRoute(page: () => ShipmentPage());
                  }
                  if (settings.name == Routes.CONDITION) {
                    return GetPageRoute(page: () => ConditionSalesPage());
                  }
                  if (settings.name == Routes.VENDOR) {
                    return GetPageRoute(page: () => VendorPage());
                  }
                  if (settings.name == Routes.OVERVIEWACCOUNT) {
                    return GetPageRoute(page: () => FinancialOverviewPage());
                  }
                  if (settings.name == Routes.CUSTOMEROVERVIEW) {
                    return GetPageRoute(page: () => CustomerAnalyticsPage());
                  }
                  if (settings.name == Routes.STAFFSALEREPORT) {
                    return GetPageRoute(page: () => StaffReportScreen());
                  }
                  if (settings.name == Routes.PRODUCTOVERVIEW) {
                    return GetPageRoute(page: () => HotSellingProductPage());
                  }
                  if (settings.name == Routes.PURCHASE) {
                    return GetPageRoute(page: () => GlobalPurchasePage());
                  }
                   if (settings.name == Routes.ORDERLIST) {
                    return GetPageRoute(page: () => OrderHistoryPage());
                  }
                  return GetPageRoute(
                    page: () => const Center(child: Text("Not Found")),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
