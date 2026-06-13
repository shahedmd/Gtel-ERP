import 'package:get/get.dart';
import 'package:gtel_erp/Core/Auth/auth.dart';

import '../Gtel Expense/Daily Expense/dailyexpensecontroller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController(), permanent: true);
    Get.put(() => DailyExpensesController(), permanent: true);
  }
}
