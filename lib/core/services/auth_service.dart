import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    await _auth.signOut();
    await AuthSession.clear();
  }

  Future<void> _syncBackendProfile({
    String? displayName,
    String? mobile,
  }) async {
    final token = await AuthSession.refreshToken(forceRefresh: true);
    if (token == null)
      throw const PriceShieldAuthException('Please sign in again.');
    var profile = await priceShieldApi.getProfile();
    final changes = <String, dynamic>{
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
      if (mobile != null && mobile.trim().isNotEmpty) 'mobile': mobile.trim(),
    };
    if (changes.isNotEmpty)
      profile = await priceShieldApi.updateProfile(changes);
    await AuthSession.save(token: token, user: profile);
  }

  PriceShieldAuthException _mapFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return const PriceShieldAuthException(
          'An account with this email already exists.',
          code: 'email-already-in-use',
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
