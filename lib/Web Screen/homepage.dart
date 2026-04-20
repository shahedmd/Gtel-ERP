// lib/Web Screen/homepage.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/app_pages.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/sidemenubar.dart';
import 'package:gtel_erp/Core/Core%20Utils/navigation_key.dart';

import '../Core/Core Utils/responsive.dart';

class AdminHomepage extends StatelessWidget {
  const AdminHomepage({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      sidebar: SidebarMenu(),
      title: 'G-Tel ERP',
      body: Navigator(
        key: Get.nestedKey(NavKey.nestedHome),
        initialRoute: Routes.dailysales,
        onGenerateRoute: (settings) {
          final GetPage? matchedPage = AppPages.nestedPages.firstWhereOrNull(
            (page) => page.name == settings.name,
          );

          if (matchedPage != null) {
            return GetPageRoute(page: matchedPage.page);
          }

          return GetPageRoute(
            page: () => const Center(child: Text('Page Not Found')),
          );
        },
      ),
    );
  }
}