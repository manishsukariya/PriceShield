import 'package:flutter/material.dart';

import 'package:priceshield/app/auth_gate.dart';
import 'package:priceshield/app/navigation/main_navigation.dart';
import 'package:priceshield/features/auth/presentation/screens/register_screen.dart';
import 'package:priceshield/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:priceshield/features/auth/presentation/screens/welcome_screen.dart';

class PriceShieldApp extends StatelessWidget {
  const PriceShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PriceShield',
      home: const AuthGate(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/signin': (context) => const SignInScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const MainNavigation(),
      },
    );
  }
}
