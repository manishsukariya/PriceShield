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

  Future<void> _enterBarcodeManually() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter barcode'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Barcode number'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || code == null || code.isEmpty) return;
    setState(() => _openingProduct = true);
    await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(barcode: code)));
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
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
          IgnorePointer(child: Center(child: Container(width: 270, height: 170, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(22))))),
          Positioned(top: 24, left: 24, right: 24, child: Text('Place the barcode inside the frame', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black.withOpacity(.7), blurRadius: 4)]))),
          Positioned(bottom: 28, left: 24, right: 24, child: ElevatedButton.icon(onPressed: _openingProduct ? null : _enterBarcodeManually, icon: const Icon(Icons.keyboard_outlined), label: const Text('Enter barcode manually'), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black))),
        ],
      ),
    );
  }
}
