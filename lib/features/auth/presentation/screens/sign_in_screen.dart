import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:priceshield/core/services/auth_service.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/widgets/wave_clipper.dart';
import 'package:priceshield/core/theme/app_theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool _passwordVisible = false;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PriceShieldColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            /// 🔥 TOP WAVE
            ClipPath(
              clipper: WaveClipper(),
              child: Container(
                height: 280,
                width: double.infinity,
                color: PriceShieldColors.navy,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "PriceShield",
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Pay the right price. Always.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

            /// 🔥 LOGIN CARD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                transform: Matrix4.translationValues(0, 0, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Sign In",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _field(emailController, "Email address", Icons.email),
                    const SizedBox(height: 14),
                    _field(
                      passwordController,
                      "Password",
                      Icons.lock,
                      isPassword: true,
                      autofillHints: const [AutofillHints.password],
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: loading ? null : _forgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: loading ? null : loginUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PriceShieldColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Login",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? "),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: const Text(
                            "Sign up",
                            style: TextStyle(
                              color: PriceShieldColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: const [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "OR",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          AuthSession.continueAsGuest();
                          Navigator.pushReplacementNamed(context, '/home');
                        },
                        icon: const Icon(Icons.bolt_rounded, color: PriceShieldColors.primary),
                        label: const Text(
                          "⚡ Instant Scan (Continue as Guest)",
                          style: TextStyle(
                            color: PriceShieldColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: PriceShieldColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔥 LOGIN LOGIC
  Future<void> loginUser() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _show("Email & Password required");
      return;
    }

    setState(() => loading = true);

    try {
      await authService.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } on PriceShieldAuthException catch (e) {
      if (e.code == 'email-not-verified') {
        await _showUnverifiedDialog();
      } else {
        _show(e.message);
      }
    } on PriceShieldApiException catch (e) {
      _show(e.message);
    } catch (_) {
      _show(
        'Login could not be completed. Check your connection and try again.',
      );
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _forgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _show('Enter your email address first.');
      return;
    }
    setState(() => loading = true);
    try {
      await authService.sendPasswordReset(email);
      _show('Password reset link sent. Check your inbox.');
    } on PriceShieldAuthException catch (error) {
      _show(error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _showUnverifiedDialog() async {
    if (!mounted) return;
    final resend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email not verified'),
        content: const Text(
          'Verify your email using the link we sent before signing in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resend link'),
          ),
        ],
      ),
    );
    if (resend != true) return;
    if (_resendSeconds > 0) {
      _show('Please wait ${_resendSeconds}s before requesting another link.');
      return;
    }
    try {
      await authService.resendVerification();
      _resendSeconds = 60;
      _resendTimer?.cancel();
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_resendSeconds <= 1) {
          timer.cancel();
          _resendSeconds = 0;
        } else {
          _resendSeconds--;
        }
      });
      _show('A new verification link was sent.');
    } on PriceShieldAuthException catch (error) {
      _show(error.message);
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _field(
    TextEditingController c,
    String h,
    IconData i, {
    bool isPassword = false,
    List<String>? autofillHints,
  }) {
    return TextField(
      controller: c,
      obscureText: isPassword && !_passwordVisible,
      keyboardType: c == emailController ? TextInputType.emailAddress : TextInputType.text,
      autofillHints: autofillHints ?? (c == emailController ? const [AutofillHints.username] : null),
      decoration: InputDecoration(
        prefixIcon: Icon(i),
        hintText: h,
        filled: true,
        fillColor: PriceShieldColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        suffixIcon: isPassword
            ? IconButton(
                tooltip: _passwordVisible ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                icon: Icon(_passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              )
            : null,
      ),
    );
  }
}
