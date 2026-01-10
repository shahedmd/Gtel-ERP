import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Stock/Service/servicepage.dart';
import 'package:gtel_erp/Web%20Screen/Sales/Condition/conditionpage.dart';
import '../Cash/page.dart';
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
                    return GetPageRoute(page: () => ProfitLossPage());
                  }
                  if (settings.name == Routes.CASH) {
                    return GetPageRoute(page: () => CashDrawerPage());
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
