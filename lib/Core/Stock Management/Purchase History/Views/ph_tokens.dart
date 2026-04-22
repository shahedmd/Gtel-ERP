import 'package:flutter/material.dart';

/// Central design-token class for the Purchase History feature.
/// Import this file in every sub-widget; never hardcode colours or text styles.
abstract final class PHTokens {
  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const Color bg = Color(0xFFF1F5F9);
  static const Color surface = Colors.white;

  // ── Slate scale ────────────────────────────────────────────────────────────
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF8FAFC);

  // ── Accent colours ─────────────────────────────────────────────────────────
  static const Color blue = Color(0xFF3B82F6);
  static const Color blueLight = Color(0xFFEFF6FF);
  static const Color green = Color(0xFF10B981);
  static const Color greenLight = Color(0xFFECFDF5);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFFFBEB);
  static const Color red = Color(0xFFEF4444);

  // ── Shared text styles ─────────────────────────────────────────────────────
  static const TextStyle tableHeaderCell = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: slate400,
    letterSpacing: 0.8,
  );

  static const TextStyle dialogLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: slate400,
    letterSpacing: 0.6,
  );

  // ── Shared border radius ───────────────────────────────────────────────────
  static const double radiusSm = 5;
  static const double radiusMd = 7;
  static const double radiusLg = 8;
  static const double radiusXl = 12;

  // ── Input decoration factory ───────────────────────────────────────────────
  static InputDecoration inputDecoration({
    String? hint,
    Widget? prefix,
    Widget? suffix,
    bool dense = true,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: slate400),
      prefixIcon: prefix,
      suffixIcon: suffix,
      isDense: dense,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: slate100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: blue),
      ),
    );
  }
}