import 'dart:async';

import 'package:flutter/material.dart';
import 'package:priceshield/core/services/auth_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';

class VerifyOtpScreen extends StatefulWidget {
  const VerifyOtpScreen({super.key, required this.email, this.resendAfterSeconds = 60, this.initialOtp});
  final String email;
  final int resendAfterSeconds;
  final String? initialOtp;
  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  late int _seconds = widget.resendAfterSeconds;
  bool _loading = false;
  @override void initState() { super.initState(); if (widget.initialOtp != null) _code.text = widget.initialOtp!; _startTimer(); }
  @override void dispose() { _timer?.cancel(); _code.dispose(); super.dispose(); }
  void _startTimer() { _timer?.cancel(); _timer = Timer.periodic(const Duration(seconds: 1), (timer) { if (_seconds <= 1) { timer.cancel(); if (mounted) setState(() => _seconds = 0); } else if (mounted) setState(() => _seconds--); }); }
  Future<void> _verify() async {
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) { _show('Enter the 6-digit code.'); return; }
    setState(() => _loading = true);
    try { await authService.verifyRegistrationOtp(email: widget.email, otp: _code.text); if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false); }
    on PriceShieldApiException catch (error) { _show(error.message); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _resend() async {
    if (_seconds > 0) return;
    setState(() => _loading = true);
    try { final result = await authService.resendRegistrationOtp(widget.email); final seconds = int.tryParse('${result['resendAfterSeconds']}') ?? 60; if (mounted) { setState(() => _seconds = seconds); _startTimer(); _show('A new verification code was sent.'); } }
    on PriceShieldApiException catch (error) { _show(error.message); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  void _show(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verify email')),
    body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 40), const Icon(Icons.mark_email_read_outlined, size: 64), const SizedBox(height: 20), const Text('Enter verification code', textAlign: TextAlign.center, style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('We sent a 6-digit code to ${widget.email}. It expires in 5 minutes.', textAlign: TextAlign.center), if (widget.initialOtp != null) ...[const SizedBox(height: 8), const Text('Development mode: OTP filled automatically.', textAlign: TextAlign.center, style: TextStyle(color: Colors.orange))], const SizedBox(height: 28),
      TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, letterSpacing: 8), decoration: const InputDecoration(counterText: '', hintText: '000000', border: OutlineInputBorder())), const SizedBox(height: 20),
      FilledButton(onPressed: _loading ? null : _verify, child: Text(_loading ? 'Please wait...' : 'Verify and create account')), const SizedBox(height: 12), TextButton(onPressed: _loading || _seconds > 0 ? null : _resend, child: Text(_seconds > 0 ? 'Resend code in ${_seconds}s' : 'Resend code')),
    ])),
  );
}
