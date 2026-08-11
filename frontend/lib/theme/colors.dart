import 'package:flutter/material.dart';

abstract class AppColors {
  // Backgrounds - Light
  static const cream = Color(0xFFFAF6F0);
  static const paper = Color(0xFFFFFFFF);
  static const sand = Color(0xFFF2EBE0);

  // Backgrounds - Dark
  static const darkCream = Color(0xFF1A1816);
  static const darkPaper = Color(0xFF242220);
  static const darkSand = Color(0xFF2E2A25);

  // Text - Light
  static const ink = Color(0xFF2E2A25);
  static const inkSoft = Color(0xFF6B6259);
  static const inkFaint = Color(0xFFA79E92);

  // Text - Dark
  static const darkInk = Color(0xFFFAF6F0);
  static const darkInkSoft = Color(0xFFB8AFA3);
  static const darkInkFaint = Color(0xFF7A7369);

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

  // Borders and shadows - Light
  static const border = Color(0xFFEAE0D2);
  static const shadow = Color(0x1F2E2A25);

  // Borders and shadows - Dark
  static const darkBorder = Color(0xFF3A3632);
  static const darkShadow = Color(0x3D000000);

  // Avatar palettes
  static const avatarPalette = [
    Color(0xFFD79A4B),
    Color(0xFF849A76),
    Color(0xFFC97B5F),
    Color(0xFF6E97A0),
    Color(0xFFA98AB8),
    Color(0xFFC9A24A),
  ];

  static const darkAvatarPalette = [
    Color(0xFFE0A858),
    Color(0xFF94AA86),
    Color(0xFFD98B6F),
    Color(0xFF7EA7B0),
    Color(0xFFB99AC8),
    Color(0xFFD9B25A),
  ];

  static Color avatarFor(String name, {bool isDark = false}) {
    final sum = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final palette = isDark ? darkAvatarPalette : avatarPalette;
    return palette[sum % palette.length];
  }
}