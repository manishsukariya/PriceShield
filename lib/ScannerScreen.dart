import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'product_details_screen.dart';

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Scan Product"),
        centerTitle: true,
      ),
      body: MobileScanner(
        fit: BoxFit.cover,
        onDetect: (capture) {
          final code = capture.barcodes.first.rawValue;
          if (code != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailsScreen(barcode: code),
              ),
            );
          }
        },
      ),
    );
  }
}
