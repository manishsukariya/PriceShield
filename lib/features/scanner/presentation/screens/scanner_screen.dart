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
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _ManualBarcodeDialog(),
    );
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
            errorBuilder: (_, error, _) => Center(
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
          Positioned(top: 24, left: 24, right: 24, child: Text('Place the barcode inside the frame', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 4)]))),
          Positioned(bottom: 28, left: 24, right: 24, child: ElevatedButton.icon(onPressed: _openingProduct ? null : _enterBarcodeManually, icon: const Icon(Icons.keyboard_outlined), label: const Text('Enter barcode manually'), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black))),
        ],
      ),
    );
  }
}

/// Owns the text controller for the entire dialog route lifecycle. Disposing
/// it in State.dispose prevents Flutter's inherited EditableText assertion
/// when the user dismisses the dialog with Cancel.
class _ManualBarcodeDialog extends StatefulWidget {
  const _ManualBarcodeDialog();
  @override State<_ManualBarcodeDialog> createState() => _ManualBarcodeDialogState();
}

class _ManualBarcodeDialogState extends State<_ManualBarcodeDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    final value = _controller.text.trim();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Enter barcode'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _continue(),
            decoration: const InputDecoration(labelText: 'Barcode number', hintText: 'e.g. 8901234567890'),
            validator: (value) {
              final code = value?.trim() ?? '';
              if (code.isEmpty) return 'Enter a barcode';
              if (!RegExp(r'^\d{6,14}$').hasMatch(code)) return 'Enter 6 to 14 digits';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: _continue, child: const Text('Continue')),
        ],
      );
}
