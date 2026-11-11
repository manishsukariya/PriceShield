import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:priceshield/core/widgets/wave_clipper.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/services/auth_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/features/auth/presentation/screens/verify_otp_screen.dart';
import 'package:priceshield/features/auth/presentation/widgets/google_sign_in_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final mobilenumbarController = TextEditingController();

  bool loading = false;
  bool _googleLoading = false;
  bool _passwordVisible = false;

  AuthService get _auth => widget.authService ?? authService;
  bool get _busy => loading || _googleLoading;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    mobilenumbarController.dispose();
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
                      Icons.person_add_alt_1,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Create Account",
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// 🔥 REGISTER CARD
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
                        "Register",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _field(nameController, "Full Name", Icons.person),
                    const SizedBox(height: 14),
                    _field(
                      mobilenumbarController,
                      "Mobile Number",
                      Icons.phone,
                    ),
                    const SizedBox(height: 14),
                    _field(emailController, "Email address", Icons.email),
                    const SizedBox(height: 14),
                    _field(
                      passwordController,
                      "Password",
                      Icons.lock,
                      isPassword: true,
                      autofillHints: const [AutofillHints.newPassword],
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _busy ? null : registerUser,
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
                                "Register",
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
                        const Text("Already have an account? "),
                        GestureDetector(
                          onTap: _busy
                              ? null
                              : () => Navigator.pushReplacementNamed(
                                    context,
                                    '/signin',
                                  ),
                          child: const Text(
                            "Login",
                            style: TextStyle(
                              color: PriceShieldColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

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

                    GoogleSignInButton(
                      onPressed: _signUpWithGoogle,
                      loading: _googleLoading,
                      disabled: loading,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  /// 🔥 REGISTER LOGIC
  Future<void> registerUser() async {
    if (nameController.text.isEmpty ||
        mobilenumbarController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _show("All fields are required");
      return;
    }
    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobilenumbarController.text.trim())) {
      _show('Enter a valid 10-digit mobile number');
      return;
    }

    setState(() => loading = true);

    try {
      await _auth.register(
        displayName: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        mobile: mobilenumbarController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(
            email: emailController.text.trim(),
            displayName: nameController.text.trim(),
            mobile: mobilenumbarController.text.trim(),
            authService: widget.authService,
          ),
        ),
      );
    } on PriceShieldAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        await _continueExistingAccount();
      } else {
        _show(e.message);
      }
    } catch (_) {
      _show(
        'Account could not be created. Check your connection and try again.',
      );
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await _auth.signInWithGoogle();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    } on PriceShieldAuthException catch (e) {
      if (e.code != 'google-canceled' && mounted) {
        _show(e.message);
      }
    } on PriceShieldApiException catch (e) {
      if (mounted) _show(e.message);
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

  Future<void> _continueExistingAccount() async {
    try {
      await _auth.continueUnverifiedRegistration(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (!mounted) return;
      _show('This email is already registered but not verified. A new verification link was sent.');
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyOtpScreen(
            email: emailController.text.trim(),
            displayName: nameController.text.trim(),
            mobile: mobilenumbarController.text.trim(),
            authService: widget.authService,
          ),
        ),
      );
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
      autofillHints: autofillHints ?? (c == emailController ? const [AutofillHints.email] : null),
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
