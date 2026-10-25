import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';

class AuthService {
  Future<Map<String, dynamic>> register({
    required String displayName,
    required String email,
    required String password,
    required String mobile,
  }) => priceShieldApi.register(
        displayName: displayName,
        email: email,
        password: password,
        mobile: mobile,
      );

  Future<void> verifyRegistrationOtp({required String email, required String otp}) async =>
      _saveSession(await priceShieldApi.verifyRegistrationOtp(email: email, otp: otp));

  Future<Map<String, dynamic>> resendRegistrationOtp(String email) =>
      priceShieldApi.resendRegistrationOtp(email);

  Future<void> login({required String email, required String password}) async =>
      _saveSession(await priceShieldApi.login(email: email, password: password));

  Future<void> logout() async {
    try {
      await priceShieldApi.logout();
    } finally {
      await AuthSession.clear();
    }
  }

  Future<void> _saveSession(Map<String, dynamic> response) async {
    final token = response['accessToken']?.toString();
    final user = response['user'];
    if (token == null || token.isEmpty || user is! Map) {
      throw const PriceShieldApiException('The server returned an invalid sign-in response.');
    }
    await AuthSession.save(token: token, user: Map<String, dynamic>.from(user));
  }
}

final authService = AuthService();
