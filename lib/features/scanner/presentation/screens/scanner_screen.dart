import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:priceshield/features/scanner/presentation/screens/product_details_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _openingProduct = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_openingProduct) return;
    String? code;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        code = value;
        break;
      }
    }
    if (code == null) return;

    setState(() => _openingProduct = true);
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailsScreen(barcode: code!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan product'),
        centerTitle: true,
      ),
      body: MobileScanner(
        fit: BoxFit.cover,
        onDetect: _onDetect,
        errorBuilder: (_, error, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Camera could not start. Allow camera permission in phone settings and try again.\n\n${error.errorCode.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
