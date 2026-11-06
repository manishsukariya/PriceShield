import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:priceshield/app/app.dart';
import 'package:priceshield/core/services/auth_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await authService.restoreSession();
  // Asynchronously ping backend so Render instance wakes up during app startup
  priceShieldApi.warmUpBackend();
  runApp(const PriceShieldApp());
}
