
import 'package:flutter/material.dart';
class Responsive {
  // Breakpoints
  static const double mobileBreak = 600;
  static const double tabletBreak = 900;
  static const double desktopBreak = 1200;

  // Device type check
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreak;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreak &&
      MediaQuery.of(context).size.width < tabletBreak;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreak;

  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;


  static double fs(BuildContext context, double size) {
    if (isMobile(context)) return size * 0.85;
    if (isTablet(context)) return size * 0.92;
    return size;
  }

  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet ?? desktop;
    return desktop;
  }

  // ─────────────────────────────────────────────────────────────
  // Common responsive values — সারা app-এ একই
  // ─────────────────────────────────────────────────────────────

  // Padding
  static EdgeInsets pagePadding(BuildContext context) =>
      EdgeInsets.all(value(context, mobile: 12.0, tablet: 16.0, desktop: 20.0));

  static EdgeInsets cardPadding(BuildContext context) =>
      EdgeInsets.all(value(context, mobile: 10.0, tablet: 14.0, desktop: 16.0));

  // Font sizes — সারা app-এ consistent
  static double titleLarge(BuildContext context) =>
      value(context, mobile: 16.0, tablet: 18.0, desktop: 22.0);

  static double titleMedium(BuildContext context) =>
      value(context, mobile: 14.0, tablet: 15.0, desktop: 18.0);

  static double titleSmall(BuildContext context) =>
      value(context, mobile: 13.0, tablet: 14.0, desktop: 16.0);

  static double bodyLarge(BuildContext context) =>
      value(context, mobile: 13.0, tablet: 14.0, desktop: 15.0);

  static double bodyMedium(BuildContext context) =>
      value(context, mobile: 12.0, tablet: 13.0, desktop: 14.0);

  static double bodySmall(BuildContext context) =>
      value(context, mobile: 11.0, tablet: 11.0, desktop: 12.0);

  // Card grid columns — screen size অনুযায়ী
  static int gridColumns(BuildContext context) =>
      value(context, mobile: 1, tablet: 2, desktop: 3);

  // Icon size
  static double iconSize(BuildContext context) =>
      value(context, mobile: 18.0, tablet: 20.0, desktop: 22.0);

  // Button height
  static double buttonHeight(BuildContext context) =>
      value(context, mobile: 42.0, tablet: 46.0, desktop: 50.0);

  // Table column — mobile-এ কম column দেখাবে
  static bool showTableColumn(BuildContext context) => !isMobile(context);
}

// ─────────────────────────────────────────────────────────────
// ResponsiveBuilder — device type অনুযায়ী আলাদা widget
//
// ব্যবহার:
// ResponsiveBuilder(
//   mobile: MobileLayout(),
//   desktop: DesktopLayout(),
// )
// ─────────────────────────────────────────────────────────────
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isMobile(context)) return mobile;
    if (Responsive.isTablet(context)) return tablet ?? desktop;
    return desktop;
  }
}

// ─────────────────────────────────────────────────────────────
// ResponsiveLayout — Scaffold-level layout
// Sidebar শুধু desktop-এ দেখাবে
// Mobile-এ Drawer হবে
// ─────────────────────────────────────────────────────────────
class ResponsiveLayout extends StatelessWidget {
  final Widget sidebar;
  final Widget body;
  final String title;

  const ResponsiveLayout({
    super.key,
    required this.sidebar,
    required this.body,
    this.title = 'G-Tel ERP',
  });

  @override
  Widget build(BuildContext context) {
    final bool mobile = Responsive.isMobile(context);

    return Scaffold(
      drawer: mobile ? Drawer(child: sidebar) : null,
      appBar:
          mobile
              ? AppBar(
                title: Text(
                  title,
                  style: TextStyle(
                    fontSize: Responsive.titleSmall(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                leading: Builder(
                  builder:
                      (ctx) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                      ),
                ),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0.5,
              )
              : null,
      body: SafeArea(
        child: Row(children: [if (!mobile) sidebar, Expanded(child: body)]),
      ),
    );
  }
}