import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:priceshield/app/navigation/main_navigation.dart';
import 'package:priceshield/features/auth/presentation/screens/welcome_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'We could not restore your session. Please reopen the app.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (snapshot.hasData) {
          return const MainNavigation();
        }

        return const WelcomeScreen();
      },
    );
  }
}
