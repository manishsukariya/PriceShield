import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';

class PriceShieldAuthException implements Exception {
  const PriceShieldAuthException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignInOverride = googleSignIn;

  static const _configuredGoogleServerClientId = String.fromEnvironment(
    'PRICESHIELD_GOOGLE_SERVER_CLIENT_ID',
  );

  final FirebaseAuth? _firebaseAuth;
  final GoogleSignIn? _googleSignInOverride;
  bool _googleInitialized = false;
  Future<void>? _googleInitInFlight;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn =>
      _googleSignInOverride ?? GoogleSignIn.instance;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    final inFlight = _googleInitInFlight ??= _googleSignIn.initialize(
      serverClientId: _configuredGoogleServerClientId.isNotEmpty
          ? _configuredGoogleServerClientId
          : null,
    );
    try {
      await inFlight;
      _googleInitialized = true;
    } catch (_) {
      _googleInitInFlight = null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register({
    required String displayName,
    required String email,
    required String password,
    required String mobile,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null)
        throw const PriceShieldAuthException('Account could not be created.');
      await user.updateDisplayName(displayName.trim());
      await user.sendEmailVerification();
      await AuthSession.clear();
      return {
        'email': user.email ?? email.trim(),
        'displayName': displayName.trim(),
        'mobile': mobile.trim(),
      };
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  Future<void> login({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null)
        throw const PriceShieldAuthException('Login could not be completed.');
      await user.reload();
      final current = _auth.currentUser;
      if (current == null)
        throw const PriceShieldAuthException('Login could not be completed.');
      if (!current.emailVerified) {
        throw const PriceShieldAuthException(
          'Verify your email before signing in.',
          code: 'email-not-verified',
        );
      }
      await _syncBackendProfile();
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  /// Signs in (or registers) using the native Google account picker and links
  /// the resulting verified Google identity into Firebase + PriceShield backend.
  Future<void> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw const PriceShieldAuthException(
          'Google Sign-In is not available on this device.',
          code: 'google-unsupported',
        );
      }
      final account = await _googleSignIn.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const PriceShieldAuthException(
          'Google did not return a valid identity token. Please try again.',
          code: 'google-missing-id-token',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw const PriceShieldAuthException('Google sign-in could not be completed.');
      }
      await _syncBackendProfile(
        fallbackDisplayName: user.displayName ?? account.displayName,
      );
    } on PriceShieldAuthException {
      rethrow;
    } on GoogleSignInException catch (error) {
      throw mapGoogleSignInError(error);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  /// Signs in an existing account only to continue an unfinished email
  /// verification. It never creates a backend profile until verification.
  Future<void> continueUnverifiedRegistration({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const PriceShieldAuthException('Account could not be opened.');
      }
      await user.reload();
      final current = _auth.currentUser;
      if (current == null) {
        throw const PriceShieldAuthException('Account could not be opened.');
      }
      if (current.emailVerified) {
        throw const PriceShieldAuthException(
          'This email is already verified. Please sign in.',
          code: 'already-verified',
        );
      }
      await current.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  Future<void> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.reload();
      final current = _auth.currentUser;
      if (current == null || !current.emailVerified) {
        await AuthSession.clear();
        return;
      }
      await _syncBackendProfile();
    } on FirebaseAuthException {
      await AuthSession.clear();
    } on PriceShieldApiException {
      await AuthSession.clear();
    }
  }

  Future<void> reloadVerification({String? displayName, String? mobile}) async {
    final user = _auth.currentUser;
    if (user == null)
      throw const PriceShieldAuthException(
        'Registration session expired. Please sign in again.',
      );
    await user.reload();
    final current = _auth.currentUser;
    if (current == null || !current.emailVerified) {
      throw const PriceShieldAuthException(
        'Your email is not verified yet.',
        code: 'email-not-verified',
      );
    }
    await _syncBackendProfile(displayName: displayName, mobile: mobile);
  }

  Future<void> resendVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null)
        throw const PriceShieldAuthException(
          'Registration session expired. Please sign in again.',
        );
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseError(error);
    }
  }

  Future<void> logout() async {
    if (_googleInitialized) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
    await AuthSession.clear();
  }

  Future<void> deleteAccount() async {
    await priceShieldApi.deleteAccount();
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (error) {
      if (error.code != 'requires-recent-login') {
        throw _mapFirebaseError(error);
      }
    } finally {
      if (_googleInitialized) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }
      await _auth.signOut();
      await AuthSession.clear();
    }
  }

  Future<void> _syncBackendProfile({
    String? displayName,
    String? mobile,
    String? fallbackDisplayName,
  }) async {
    final token = await AuthSession.refreshToken(forceRefresh: true);
    if (token == null)
      throw const PriceShieldAuthException('Please sign in again.');
    var profile = await priceShieldApi.getProfile();
    final existingName = profile['displayName']?.toString().trim() ?? '';
    final changes = <String, dynamic>{
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim()
      else if (existingName.isEmpty &&
          fallbackDisplayName != null &&
          fallbackDisplayName.trim().isNotEmpty)
        'displayName': fallbackDisplayName.trim(),
      if (mobile != null && mobile.trim().isNotEmpty) 'mobile': mobile.trim(),
    };
    if (changes.isNotEmpty)
      profile = await priceShieldApi.updateProfile(changes);
    await AuthSession.save(token: token, user: profile);
  }

  @visibleForTesting
  PriceShieldAuthException mapGoogleSignInError(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return const PriceShieldAuthException(
          'Google sign-in was canceled.',
          code: 'google-canceled',
        );
      case GoogleSignInExceptionCode.interrupted:
        return const PriceShieldAuthException(
          'Google sign-in was interrupted. Please try again.',
          code: 'google-interrupted',
        );
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return const PriceShieldAuthException(
          'Google Sign-In is not configured for this build yet. Verify Firebase SHA-1 and Web Client ID in google-services.json.',
          code: 'google-not-configured',
        );
      case GoogleSignInExceptionCode.uiUnavailable:
        return const PriceShieldAuthException(
          'Unable to open the Google account selector right now.',
          code: 'google-ui-unavailable',
        );
      case GoogleSignInExceptionCode.userMismatch:
        return const PriceShieldAuthException(
          'Selected Google account does not match the active session.',
          code: 'google-user-mismatch',
        );
      default:
        return PriceShieldAuthException(
          'Google sign-in failed. Please try again.',
          code: error.code.name,
        );
    }
  }

  PriceShieldAuthException _mapFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return const PriceShieldAuthException(
          'An account with this email already exists.',
          code: 'email-already-in-use',
        );
      case 'account-exists-with-different-credential':
        return const PriceShieldAuthException(
          'An account with this email already exists using another sign-in method.',
          code: 'account-exists-with-different-credential',
        );
      case 'user-disabled':
        return const PriceShieldAuthException(
          'This account has been disabled.',
          code: 'user-disabled',
        );
      case 'operation-not-allowed':
        return const PriceShieldAuthException(
          'This sign-in method is not enabled in Firebase Authentication.',
          code: 'operation-not-allowed',
        );
      case 'invalid-email':
        return const PriceShieldAuthException(
          'Enter a valid email address.',
          code: 'invalid-email',
        );
      case 'weak-password':
        return const PriceShieldAuthException(
          'Choose a stronger password.',
          code: 'weak-password',
        );
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return const PriceShieldAuthException(
          'Email or password is incorrect.',
          code: 'invalid-credential',
        );
      case 'too-many-requests':
        return const PriceShieldAuthException(
          'Too many attempts. Please try again later.',
          code: 'too-many-requests',
        );
      case 'network-request-failed':
        return const PriceShieldAuthException(
          'Could not reach Firebase. Check your connection and try again.',
          code: 'network-request-failed',
        );
      default:
        return PriceShieldAuthException(
          'Authentication failed. Please try again.',
          code: error.code,
        );
    }
  }
}

final authService = AuthService();
