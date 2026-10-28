import 'package:flutter/material.dart';

abstract final class PriceShieldColors {
  static const navy = Color(0xff10233F);
  static const primary = Color(0xff0F9D8A);
  static const mint = Color(0xffDDF7F1);
  static const background = Color(0xffF6F8FB);
  static const surface = Colors.white;
  static const text = Color(0xff172033);
  static const muted = Color(0xff5D6878);
  static const border = Color(0xffDCE3EC);
  static const success = Color(0xff168A68);
  static const warning = Color(0xffC98216);
  static const danger = Color(0xffC94C4C);
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
            side: const BorderSide(color: PriceShieldColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0x260F9D8A),
          labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );
}
