import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PriceShieldColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(),
              Center(child: Container(width: 112, height: 112, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: PriceShieldColors.mint, borderRadius: BorderRadius.circular(32)), child: Image.asset('assets/images/priceshield_logo.png'))),
              const SizedBox(height: 32),
              Text('Know the price.\nProtect your rights.', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 14),
              const Text('Scan products, verify the printed MRP and report overcharging with confidence.', style: TextStyle(color: PriceShieldColors.muted, fontSize: 16, height: 1.45)),
              const SizedBox(height: 24),
              const _WelcomePoint(icon: Icons.qr_code_scanner_rounded, text: 'Check prices instantly'),
              const _WelcomePoint(icon: Icons.verified_outlined, text: 'Keep a clear record of every scan'),
              const _WelcomePoint(icon: Icons.shield_outlined, text: 'Report unfair charges securely'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/signin'),
                  child: const Text('Get started / Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    AuthSession.continueAsGuest();
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  icon: const Icon(Icons.bolt, color: PriceShieldColors.primary),
                  label: const Text(
                    '⚡ Instant Scan (Continue as Guest)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: PriceShieldColors.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: PriceShieldColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
}

class _WelcomePoint extends StatelessWidget {
  const _WelcomePoint({required this.icon, required this.text});
  final IconData icon; final String text;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: PriceShieldColors.mint, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: PriceShieldColors.primary, size: 20)), const SizedBox(width: 12), Text(text, style: const TextStyle(fontWeight: FontWeight.w600))]));
}
