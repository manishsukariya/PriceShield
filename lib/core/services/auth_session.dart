import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  const AuthUser(this.data);

  final Map<String, dynamic> data;
  String get id => data['id']?.toString() ?? '';
  String get email => data['email']?.toString() ?? '';
  String get displayName => data['displayName']?.toString() ?? '';
  String? get mobile => data['mobile']?.toString();
  String? get photoUrl => data['photoUrl']?.toString();
}

/// Local session state for a backend-issued access token. No credentials,
/// passwords, or tokens are written to logs.
class AuthSession {
  static const _tokenKey = 'priceshield_access_token';
  static const _userKey = 'priceshield_session_user';
  static final ValueNotifier<AuthUser?> currentUser = ValueNotifier(null);
  static String? _token;

  static String? get token => _token;
  static bool get isSignedIn => _token != null && currentUser.value != null;

  static Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    final encodedUser = preferences.getString(_userKey);
    if (token == null || encodedUser == null) return;
    try {
      final value = jsonDecode(encodedUser);
      if (value is Map) {
        _token = token;
        currentUser.value = AuthUser(Map<String, dynamic>.from(value));
      }
    } on FormatException {
      await clear();
    }
  }

  static Future<void> save({required String token, required Map<String, dynamic> user}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
    await preferences.setString(_userKey, jsonEncode(user));
    _token = token;
    currentUser.value = AuthUser(user);
  }

  static Future<void> updateUser(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    await save(token: token, user: user);
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_userKey);
    _token = null;
    currentUser.value = null;
  }
}
