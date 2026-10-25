import 'package:flutter/material.dart';

import 'package:priceshield/app/navigation/main_navigation.dart';
import 'package:priceshield/features/auth/presentation/screens/welcome_screen.dart';
import 'package:priceshield/core/services/auth_session.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthUser?>(
      valueListenable: AuthSession.currentUser,
      builder: (context, user, _) {
        if (user != null) {
          return const MainNavigation();
        }
        return const WelcomeScreen();
      },
    );
  }
}
