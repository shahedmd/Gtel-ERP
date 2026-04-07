import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:gtel_erp/Core/Menubar%20&%20Navigation/sidemenubar.dart';
import '../Core/Menubar & Navigation/app_pages.dart'; // AppPages এর জন্য
import '../core/utils/navigation_key.dart'; // NavKey এর জন্য


class AdminHomepage extends StatelessWidget {
  const AdminHomepage({super.key});

  @override
  Widget build(BuildContext context) {
  
    final isMobile = MediaQuery.of(context).size.width < 450;


    return Scaffold(
 
      drawer: isMobile ? Drawer(child: SidebarMenu()) : null,
      appBar:
          isMobile
              ? AppBar(
                title:  Text("G Tel ERP", style: TextStyle(fontSize: isMobile? 14: 18.sp),),
                leading: Builder(
                  builder: (context) {
                    return IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    );
                  },
                ),
              )
              : null,

      body: SafeArea(
        child: SizedBox(
          child: Row(
            children: [

              if (!isMobile) SidebarMenu(),

              Expanded(
                child: Navigator(
                  key: Get.nestedKey(NavKey.nestedHome),
                  initialRoute: Routes.dailysales,
                  onGenerateRoute: (settings) {

                    final GetPage? matchedPage = AppPages.nestedPages
                        .firstWhereOrNull((page) => page.name == settings.name);

                    if (matchedPage != null) {
                      return GetPageRoute(page: matchedPage.page);
                    }
                    return GetPageRoute(
                      page:
                          () => const Center(
                            child: Text("Page Not Found in Nested Pages"),
                          ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}