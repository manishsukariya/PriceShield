import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:priceshield/core/services/auth_service.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/features/auth/presentation/screens/register_screen.dart';
import 'package:priceshield/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:priceshield/features/auth/presentation/screens/verify_otp_screen.dart';
import 'package:priceshield/features/auth/presentation/widgets/google_sign_in_button.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService({this.onGoogleSignIn});

  final Future<void> Function()? onGoogleSignIn;
  int googleCalls = 0;

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
    if (onGoogleSignIn != null) {
      await onGoogleSignIn!();
    }
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    await AuthSession.clear();
  });

  group('AuthService.mapGoogleSignInError', () {
    final service = AuthService();

    test('maps every GoogleSignInExceptionCode cleanly', () {
      expect(
        service
            .mapGoogleSignInError(
              const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
            )
            .code,
        'google-canceled',
      );
      expect(
        service
            .mapGoogleSignInError(
              const GoogleSignInException(
                code: GoogleSignInExceptionCode.interrupted,
              ),
            )
            .code,
        'google-interrupted',
      );
      expect(
        service
            .mapGoogleSignInError(
              const GoogleSignInException(
                code: GoogleSignInExceptionCode.clientConfigurationError,
              ),
            )
            .code,
        'google-not-configured',
      );
      expect(
        service
            .mapGoogleSignInError(
              const GoogleSignInException(
                code: GoogleSignInExceptionCode.providerConfigurationError,
              ),
            )
            .code,
        'google-not-configured',
      );
      expect(
        service
            .mapGoogleSignInError(
              const GoogleSignInException(
                code: GoogleSignInExceptionCode.uiUnavailable,
              ),
            )
            .code,
        'google-ui-unavailable',
      );
      expect(
        service
            .mapGoogleSignInError(
              const GoogleSignInException(
                code: GoogleSignInExceptionCode.userMismatch,
              ),
            )
            .code,
        'google-user-mismatch',
      );
      expect(
        service
            .mapGoogleSignInError(
              const GoogleSignInException(
                code: GoogleSignInExceptionCode.unknownError,
              ),
            )
            .code,
        'unknownError',
      );
    });
  });

  group('GoogleSignInButton', () {
    testWidgets('shows label when idle and spinner when loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(onPressed: () => taps++),
          ),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      await tester.tap(find.byKey(const Key('google_sign_in_button')));
      expect(taps, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(loading: true, onPressed: () => taps++),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const Key('google_sign_in_button')));
      expect(taps, 1);
    });
  });

  group('SignInScreen Google Sign-In', () {
    testWidgets('renders Continue with Google and navigates to /home on success', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeAuth = _FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: SignInScreen(authService: fakeAuth),
          routes: {
            '/home': (_) => const Scaffold(body: Text('HOME_ROUTE')),
            '/register': (_) => const Scaffold(body: Text('REGISTER_ROUTE')),
          },
        ),
      );
      await tester.pump();

      final googleBtn = find.byKey(const Key('google_sign_in_button'));
      expect(googleBtn, findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('⚡ Instant Scan (Continue as Guest)'), findsOneWidget);

      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      expect(fakeAuth.googleCalls, 1);
      expect(find.text('HOME_ROUTE'), findsOneWidget);
    });

    testWidgets('ignores google-canceled quietly without snackbar or navigation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeAuth = _FakeAuthService(
        onGoogleSignIn: () async {
          throw const PriceShieldAuthException(
            'Google sign-in was canceled.',
            code: 'google-canceled',
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SignInScreen(authService: fakeAuth),
          routes: {
            '/home': (_) => const Scaffold(body: Text('HOME_ROUTE')),
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('google_sign_in_button')));
      await tester.pumpAndSettle();

      expect(fakeAuth.googleCalls, 1);
      expect(find.text('HOME_ROUTE'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('shows helpful error SnackBar on configuration failure', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeAuth = _FakeAuthService(
        onGoogleSignIn: () async {
          throw const PriceShieldAuthException(
            'Google Sign-In is not configured for this build yet.',
            code: 'google-not-configured',
          );
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SignInScreen(authService: fakeAuth),
          routes: {
            '/home': (_) => const Scaffold(body: Text('HOME_ROUTE')),
          },
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('google_sign_in_button')));
      await tester.pump();

      expect(
        find.text('Google Sign-In is not configured for this build yet.'),
        findsOneWidget,
      );
      expect(find.text('HOME_ROUTE'), findsNothing);
    });
  });

  group('RegisterScreen Google Sign-In', () {
    testWidgets('renders Continue with Google and navigates to /home on success', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeAuth = _FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: RegisterScreen(authService: fakeAuth),
          routes: {
            '/home': (_) => const Scaffold(body: Text('HOME_ROUTE')),
            '/signin': (_) => const Scaffold(body: Text('SIGNIN_ROUTE')),
          },
        ),
      );
      await tester.pump();

      final googleBtn = find.byKey(const Key('google_sign_in_button'));
      expect(googleBtn, findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      expect(fakeAuth.googleCalls, 1);
      expect(find.text('HOME_ROUTE'), findsOneWidget);
    });
  });

  group('VerifyOtpScreen Google fallback', () {
    testWidgets('shows fallback button and signs in with Google on tap', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeAuth = _FakeAuthService();

      await tester.pumpWidget(
        MaterialApp(
          home: VerifyOtpScreen(
            email: 'user@example.com',
            authService: fakeAuth,
          ),
          routes: {
            '/home': (_) => const Scaffold(body: Text('HOME_ROUTE')),
          },
        ),
      );
      await tester.pump();

      final fallbackBtn = find.byKey(const Key('verify_google_fallback_button'));
      expect(fallbackBtn, findsOneWidget);
      expect(
        find.text('Email not arriving? Continue with Google instead'),
        findsOneWidget,
      );

      await tester.tap(fallbackBtn);
      await tester.pumpAndSettle();

      expect(fakeAuth.googleCalls, 1);
      expect(find.text('HOME_ROUTE'), findsOneWidget);
    });
  });
}
