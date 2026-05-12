import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const darkSlate = Color(0xFF0F172A);
  static const activeAccent = Color(0xFF2563EB);
  static const bgGrey = Color(0xFFF8FAFC);
  static const textDark = Color(0xFF334155);
  static const borderLight = Color(0xFFE2E8F0);
  static const slateGrey = Color(0xFF64748B);
  static const headerBg = Color(0xFFF1F5F9);
}

// ─── Layout ───────────────────────────────────────────────────────────────────
abstract final class AppLayout {
  static const mobileBreakpoint = 850.0;
  static const pageSize = 15;
  static const tableMinWidth = 900.0;
}

// ─── Scroll behaviour ─────────────────────────────────────────────────────────
/// Enables both touch and mouse drag on scrollable tables.
final class TableScrollBehavior extends MaterialScrollBehavior {
  const TableScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}
