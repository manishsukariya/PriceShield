import 'package:flutter/material.dart';

import 'package:priceshield/core/services/auth_session.dart';

import 'package:priceshield/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthSession.restore();
  runApp(const PriceShieldApp());
}
