import 'dart:async';

import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';

/// Existing file/route name retained for navigation compatibility. Firebase
/// sends a verification link; no OTP is generated or entered here.
class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({
    super.key,
    required this.email,
    this.displayName,
    this.mobile,
  });

  final String email;
  final String? displayName;
  final String? mobile;

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  Timer? _timer;
  int _seconds = 60;
  bool _loading = false;

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
      await authService.reloadVerification(
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
      await authService.resendVerification();
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

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verify your email')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.mark_email_read_outlined, size: 64),
          const SizedBox(height: 20),
          const Text(
            'Check your inbox',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'A verification link was sent to ${widget.email}. Open the link, then return here.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _loading ? null : _checkVerification,
            child: Text(_loading ? 'Checking...' : 'I verified my email'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loading || _seconds > 0 ? null : _resend,
            child: Text(
              _seconds > 0
                  ? 'Resend link in ${_seconds}s'
                  : 'Resend verification link',
            ),
          ),
        ],
      ),
    ),
  );
}
