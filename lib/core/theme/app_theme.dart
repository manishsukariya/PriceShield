import 'package:flutter/material.dart';

abstract final class PriceShieldColors {
  static const navy = Color(0xff0D1B2A);
  static const primary = Color(0xff2BAE9A);
  static const mint = Color(0xff66F5CA);
  static const background = Color(0xffF6F7F9);
  static const surface = Colors.white;
  static const text = Color(0xff162238);
  static const muted = Color(0xff6B7280);
  static const success = Color(0xff16856F);
  static const warning = Color(0xffB76E00);
  static const danger = Color(0xffB42318);
}

abstract final class PriceShieldTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: PriceShieldColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: PriceShieldColors.primary,
          primary: PriceShieldColors.primary,
          secondary: PriceShieldColors.mint,
          surface: PriceShieldColors.surface,
          error: PriceShieldColors.danger,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: PriceShieldColors.text, height: 1.15),
          headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: PriceShieldColors.text),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: PriceShieldColors.text),
          titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PriceShieldColors.text),
          bodyLarge: TextStyle(fontSize: 16, color: PriceShieldColors.text, height: 1.4),
          bodyMedium: TextStyle(fontSize: 14, color: PriceShieldColors.text, height: 1.35),
          bodySmall: TextStyle(fontSize: 12, color: PriceShieldColors.muted),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: PriceShieldColors.background,
          foregroundColor: PriceShieldColors.text,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: PriceShieldColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: PriceShieldColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: PriceShieldColors.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: PriceShieldColors.danger)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: PriceShieldColors.danger, width: 1.5)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 52),
            backgroundColor: PriceShieldColors.navy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: PriceShieldColors.navy,
            side: const BorderSide(color: Color(0xffD9DEE7)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0x332BAE9A),
          labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );
}
