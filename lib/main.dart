import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:priceshield/app/app.dart';
import 'package:priceshield/core/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await authService.restoreSession();
  runApp(const PriceShieldApp());
}
