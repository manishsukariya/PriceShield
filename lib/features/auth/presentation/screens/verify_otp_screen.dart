import 'dart:async';

import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';

/// Existing file/route name retained for navigation compatibility. Firebase
/// sends a verification link; no OTP is generated or entered here.
class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({
    super.key,
    required this.email,
    this.displayName,
    this.mobile,
    this.authService,
  });

  final String email;
  final String? displayName;
  final String? mobile;
  final AuthService? authService;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  Timer? _timer;
  int _seconds = 60;
  bool _loading = false;
  bool _googleLoading = false;

  AuthService get _auth => widget.authService ?? authService;
  bool get _busy => _loading || _googleLoading;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _seconds = 0);
      } else if (mounted) {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _checkVerification() async {
    setState(() => _loading = true);
    try {
      await _auth.reloadVerification(
        displayName: widget.displayName,
        mobile: widget.mobile,
      );
      if (mounted)
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } on PriceShieldAuthException catch (error) {
      _show(error.message);
    } on PriceShieldApiException catch (_) {
      _show(
        'Your email is verified, but we could not finish setting up your account. Check that the app can reach the server, then try again.',
      );
    } on Exception catch (_) {
      _show('We could not complete verification. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_seconds > 0) return;
    setState(() => _loading = true);
    try {
      await _auth.resendVerification();
      if (mounted) {
        setState(() => _seconds = 60);
        _startTimer();
        _show('A new verification link was sent.');
      }
    } on PriceShieldAuthException catch (error) {
      _show(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await _auth.signInWithGoogle();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } on PriceShieldAuthException catch (error) {
      if (error.code != 'google-canceled' && mounted) {
        _show(error.message);
      }
    } on PriceShieldApiException catch (error) {
      if (mounted) _show(error.message);
    } catch (_) {
      if (mounted) {
        _show(
          'Google sign-in could not be completed. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PriceShieldColors.background,
        appBar: AppBar(title: const Text('Verify your email')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            AppCard(
              color: PriceShieldColors.navy,
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: PriceShieldColors.primary,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Check your inbox',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A verification link was sent to ${widget.email}. Open it, then return here.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xffC9D5E6), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Almost there',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'After opening the link, tap the button below so we can finish setting up your account.',
                    style: TextStyle(color: PriceShieldColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _checkVerification,
                      child: Text(
                        _loading ? 'Checking...' : 'I verified my email',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy || _seconds > 0 ? null : _resend,
                    child: Text(
                      _seconds > 0
                          ? 'Resend link in ${_seconds}s'
                          : 'Resend verification link',
                    ),
                  ),
                  const Divider(height: 24),
                  TextButton.icon(
                    key: const Key('verify_google_fallback_button'),
                    onPressed: _busy ? null : _continueWithGoogle,
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: Text(
                      _googleLoading
                          ? 'Signing in with Google...'
                          : 'Email not arriving? Continue with Google instead',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
