import 'package:flutter/material.dart';
import 'package:priceshield/core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scaleAnimation = Tween<double>(begin: .82, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    Future.delayed(const Duration(seconds: 2), () { if (mounted) Navigator.pushReplacementNamed(context, '/welcome'); });
  }
  @override void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PriceShieldColors.navy,
        body: Center(child: FadeTransition(opacity: _fadeAnimation, child: ScaleTransition(scale: _scaleAnimation, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 126, height: 126, padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: PriceShieldColors.primary, borderRadius: BorderRadius.circular(36)), child: Image.asset('assets/images/priceshield_logo.png')), const SizedBox(height: 24), const Text('PriceShield', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('Pay the right price. Always.', style: TextStyle(color: Color(0xffC9D5E6), fontSize: 15))]))),
      );
}
