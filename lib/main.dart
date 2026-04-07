import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Auth/auth_binding.dart';
import 'package:gtel_erp/Core/Bindings/home_bindings.dart';
import 'firebase_options.dart';
import 'Core/Auth/login.dart';
import 'Web Screen/homepage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: kIsWeb ? const Size(1440, 900) : const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'G-Tel ERP',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            brightness: Brightness.light,
            textTheme: Typography.englishLike2021.apply(fontSizeFactor: 1.sp),
          ),
          initialBinding: AuthBinding(),

          initialRoute: '/',
          

          getPages: [
            GetPage(name: '/', page: () => const LoginPage()),
            GetPage(
              name: '/home',
              page: () => AdminHomepage(),
              binding: HomeBinding(),
              preventDuplicates: true,
            ),
          ],
        );
      },
    );
  }
}
