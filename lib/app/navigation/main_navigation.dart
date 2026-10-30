import 'package:flutter/material.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaints_screen.dart';
import 'package:priceshield/features/home/presentation/screens/home_screen.dart';
import 'package:priceshield/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:priceshield/features/profile/presentation/screens/profile_screen.dart';
import 'package:priceshield/core/theme/app_theme.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const ComplaintsScreen(),
    const ProfileScreen(),
  ];

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],

      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openScanner,
              tooltip: 'Scan product',
              backgroundColor: PriceShieldColors.navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan product'),
            )
          : null,

      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,

      /// ✅ BOTTOM NAV BAR
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: "Complaints",

          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
