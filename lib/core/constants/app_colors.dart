import 'package:flutter/material.dart';

class AppColors {
  // Brand Identity Colors (From Official Visual Assets)
  static const Color neonLime = Color(0xFFCEFD37);        // Primary Electric Neon Lime (#CEFD37)
  static const Color brandPurple = Color(0xFF7C3AED);     // Vibrant Accent Purple (#7C3AED)
  static const Color brandPurpleLight = Color(0xFFF3E8FF);// Purple tint container
  static const Color brandDark = Color(0xFF18181B);       // Matte Deep Charcoal (#18181B)
  static const Color brandPink = Color(0xFFFF5A7E);       // Coral Pink variant (#FF5A7E)

  // GoPay Brand & Core Palette
  static const Color gopayBlue = Color(0xFF00AED6);       // Cyber GoPay Cyan (Savings / Tabungan)
  static const Color gopayBlueDark = Color(0xFF0082A6);   // Darker shade for gradients
  static const Color gopayBlueLight = Color(0xFFE7F7FB);  // Light cyan tint container

  static const Color gojekGreen = Color(0xFF00AA13);      // GoPay Green (Primary & Income)
  static const Color gojekGreenLight = Color(0xFFE8F8EE); // Income tint

  static const Color coralRed = Color(0xFFF04438);        // Coral Red (Expense)
  static const Color gopayRed = coralRed;                 // Backward compatibility alias
  static const Color gopayRedLight = Color(0xFFFEF3F2);   // Expense tint

  static const Color warningAmber = Color(0xFFF79009);    // Warning Amber
  static const Color warmOrange = warningAmber;           // Alias

  // Gen Z Bento & Keycap Accents
  static const Color electricEmerald = Color(0xFF00C853); // Electric Emerald Green
  static const Color sunnyYellow = Color(0xFFFACC15);     // Electric Lime / Sunny Yellow Sparkle
  static const Color deepInkNavy = Color(0xFF0F172A);     // Deep Ink Navy base

  // Canvas & Surfaces - Light Mode (Default)
  static const Color background = Color(0xFFF2F4F7);      // Soft Cool Gray canvas
  static const Color surface = Color(0xFFFFFFFF);         // Pure White card surfaces
  static const Color surfaceElevated = Color(0xFFF9FAFB); // Subtle inner surface
  static const Color border = Color(0xFFE4E7EC);          // Thin 1px border
  static const Color borderLight = Color(0xFFF2F4F7);

  // Canvas & Surfaces - Dark Mode
  static const Color darkBackground = Color(0xFF0B0E14);
  static const Color darkSurface = Color(0xFF151921);
  static const Color darkInnerSurface = Color(0xFF1E2430);
  static const Color darkBorder = Color(0xFF262D3D);

  // Text Colors (High Contrast)
  static const Color textPrimary = Color(0xFF101828);     // Clean Deep Charcoal / Black
  static const Color textSecondary = Color(0xFF667085);   // Cool Slate Gray
  static const Color textMuted = Color(0xFF98A2B3);       // Light Muted Gray

  // Backward Compatible Aliases
  static const Color emeraldGreen = gojekGreen;
  static const Color infoBlue = gopayBlue;

  // Status Colors
  static const Color success = gojekGreen;
  static const Color warning = warningAmber;
  static const Color danger = coralRed;

  // Shaping Tokens (GoPay Rounded Rectangle System)
  static final BorderRadius radiusHero = BorderRadius.circular(24);
  static final BorderRadius radiusGrouped = BorderRadius.circular(20);
  static final BorderRadius radiusInner = BorderRadius.circular(16);
  static final BorderRadius radiusChip = BorderRadius.circular(12);
  static final BorderRadius radiusButton = BorderRadius.circular(12);

  // GoPay Soft Elevation Shadow
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get heroShadow => [
        BoxShadow(
          color: const Color(0xFF00AED6).withOpacity(0.20),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}
