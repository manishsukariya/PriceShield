import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthUser {
  const AuthUser(this.data);

  final Map<String, dynamic> data;
  String get id => data['id']?.toString() ?? '';
  String get email => data['email']?.toString() ?? '';
  String get displayName => data['displayName']?.toString() ?? '';
  String? get mobile => data['mobile']?.toString();
  String? get photoUrl => data['photoUrl']?.toString();
}

/// UI session state backed by Firebase Auth. The Firebase ID token is kept
/// in memory only and refreshed before API requests; passwords and tokens are
/// never written to disk or logs.
class AuthSession {
  static final ValueNotifier<AuthUser?> currentUser = ValueNotifier(null);
  static String? _token;

  static String? get token => _token;
  static bool get isSignedIn => _token != null && currentUser.value != null;

  static Future<String?> refreshToken({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _token = null;
      return null;
    }
    _token = await user.getIdToken(forceRefresh);
    return _token;
  }

  static Future<void> save({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    _token = token;
    currentUser.value = AuthUser(user);
  }

  static Future<void> updateUser(Map<String, dynamic> user) async {
    final token = await refreshToken();
    if (token != null) await save(token: token, user: user);
  }

  static Future<void> clear() async {
    _token = null;
    currentUser.value = null;
  }
}
