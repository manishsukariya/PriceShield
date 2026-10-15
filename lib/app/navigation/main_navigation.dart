import 'package:flutter/material.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaints_screen.dart';
import 'package:priceshield/features/home/presentation/screens/home_screen.dart';
import 'package:priceshield/features/scanner/presentation/screens/scanner_screen.dart';
import 'package:priceshield/features/profile/presentation/screens/profile_screen.dart';

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
          ? Padding(
        padding: const EdgeInsets.only(bottom: 45),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _openScanner,
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            label: const Text(
              "Scan Product",
              style: TextStyle(
                fontSize: 16,color: Colors.white
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff0D1B2A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      )
          : null,

      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerDocked,

      /// ✅ BOTTOM NAV BAR
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: "Complaints",

          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
