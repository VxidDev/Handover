import 'package:flutter/material.dart';

/// A warm palette inspired by pottery, paper, and porch light —
/// meant to feel like a community bulletin board, not a dashboard.
abstract class AppColors {
  // Backgrounds
  static const cream = Color(0xFFFAF6F0);
  static const paper = Color(0xFFFFFFFF);
  static const sand = Color(0xFFF2EBE0);

  // Text
  static const ink = Color(0xFF2E2A25);
  static const inkSoft = Color(0xFF6B6259);
  static const inkFaint = Color(0xFFA79E92);

  // Primary — terracotta, warm and inviting
  static const terracotta = Color(0xFFC1653A);
  static const terracottaDeep = Color(0xFFA24E29);
  static const terracottaLight = Color(0xFFEFCBB6);
  static const terracottaTint = Color(0xFFFBE9E0);

  // Secondary — sage, calm and reassuring
  static const sage = Color(0xFF748966);
  static const sageLight = Color(0xFFDEE7D3);

  // Accent — gold, for gratitude / tips
  static const gold = Color(0xFFD79A4B);
  static const goldTint = Color(0xFFF7E7C9);

  // Status
  static const success = Color(0xFF748966);
  static const busy = Color(0xFFB98A54);
  static const error = Color(0xFFB0503F);
  static const errorTint = Color(0xFFF6E0DB);

  static const border = Color(0xFFEAE0D2);
  static const shadow = Color(0x1F2E2A25);

  /// A small rotating set of muted, friendly avatar colors.
  static const avatarPalette = [
    Color(0xFFD79A4B), // ochre
    Color(0xFF849A76), // sage
    Color(0xFFC97B5F), // terracotta
    Color(0xFF6E97A0), // muted teal
    Color(0xFFA98AB8), // dusty violet
    Color(0xFFC9A24A), // gold
  ];

  static Color avatarFor(String name) {
    final sum = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return avatarPalette[sum % avatarPalette.length];
  }
}