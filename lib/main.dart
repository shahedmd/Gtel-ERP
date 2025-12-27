import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Web%20Elements/customwidget.dart';
import 'package:gtel_erp/Web%20Screen/Debator%20Finance/debatorcontroller.dart';
import 'package:gtel_erp/Web%20Screen/Expenses/dailycontroller.dart';
import 'package:gtel_erp/Web%20Screen/Sales/controller.dart';
import 'Web Screen/Expenses/monthlycontroller.dart';
import 'Web Screen/homepage.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  Get.put(MonthlyExpensesController());
  Get.put(DailySalesController());
  Get.put(DailyExpensesController());
  Get.put(NavigationController());
  Get.put(DebatorController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        


        return ScreenUtilInit(
          designSize: const Size(1440, 900),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return GetMaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'G-Tel ERP',
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                iconTheme: const IconThemeData(color: Colors.white),
                // Standardize your fonts for a clean POS look
                textTheme: Typography.englishLike2021.apply(
                  fontSizeFactor: 1.sp,
                ),
              ),
              // AdminHomepage (MainLayout) is our root "Shell"
              home: AdminHomepage(),
              // Set initial route for the inner navigator in AdminHomepage
            );
          },
        );
      },
    );
  }
}
