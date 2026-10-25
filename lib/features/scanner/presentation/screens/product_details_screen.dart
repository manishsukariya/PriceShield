import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:priceshield/core/services/cloudinary_upload_service.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/features/scanner/presentation/screens/scan_result_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.barcode});

  final String barcode;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mrpController = TextEditingController();
  final _chargedPriceController = TextEditingController();

  bool _loading = true;
  bool _isKnownProduct = false;
  String? _loadError;
  File? _frontImage;
  File? _backImage;
  String _ocrText = '';
  bool _readingPackage = false;
  bool _submittingProduct = false;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mrpController.dispose();
    _chargedPriceController.dispose();
    super.dispose();
  }

  Future<void> _fetchProduct() async {
    try {
      final product = await priceShieldApi.getProduct(widget.barcode);
      _nameController.text = product['name']?.toString() ?? '';
      final mrp = num.tryParse(product['mrp']?.toString() ?? '');
      _mrpController.text = mrp?.toStringAsFixed(0) ?? '';
      _isKnownProduct =
          _nameController.text.isNotEmpty && _mrpController.text.isNotEmpty;
    } on PriceShieldApiException {
      _loadError = 'Product details could not be fetched. You can enter them manually.';
    } catch (_) {
      _loadError = 'Product details could not be fetched. You can enter them manually.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _checkPrice() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final mrp = int.parse(_mrpController.text.trim());
    final charged = int.parse(_chargedPriceController.text.trim());
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          name: _nameController.text.trim(),
          barcode: widget.barcode,
          mrp: mrp,
          charged: charged,
        ),
      ),
    );
  }

  Future<void> _pickPackageImage({required bool isFront}) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;
    final image = File(picked.path);
    setState(() {
      if (isFront) _frontImage = image; else _backImage = image;
    });
    await _readPackageText(image);
  }

  Future<void> _readPackageText(File image) async {
    setState(() => _readingPackage = true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFile(image));
      final text = result.text.trim();
      if (text.isNotEmpty) {
        _ocrText = [_ocrText, text].where((item) => item.isNotEmpty).join('\n');
        final match = RegExp(r'(?:MRP|Rs\\.?|₹)\\s*[:\\-]?\\s*(\\d+(?:\\.\\d{1,2})?)', caseSensitive: false).firstMatch(_ocrText);
        if (_mrpController.text.trim().isEmpty && match != null) _mrpController.text = match.group(1)!;
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Text could not be read. Enter the package details manually.')));
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _readingPackage = false);
    }
  }

  Future<void> _submitForReview() async {
    if (_frontImage == null && _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a front or back package photo for review.')));
      return;
    }
    setState(() => _submittingProduct = true);
    try {
      final frontUpload = _frontImage == null ? null : await CloudinaryUploadService.uploadFile(file: _frontImage!, isVideo: false);
      final backUpload = _backImage == null ? null : await CloudinaryUploadService.uploadFile(file: _backImage!, isVideo: false);
      final parsedMrp = num.tryParse(_mrpController.text.trim());
      if (!priceShieldApi.isConfigured) throw const PriceShieldApiException('The PriceShield backend is not configured.');
      await priceShieldApi.createProductSubmission(barcode: widget.barcode, productName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(), printedMrp: parsedMrp, ocrText: _ocrText, frontImageUrl: frontUpload?.secureUrl, backImageUrl: backUpload?.secureUrl);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product details submitted for review. The MRP remains unverified.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submittingProduct = false);
    }
  }

  InputDecoration _decoration(String label, {String? prefix}) => InputDecoration(
        labelText: label,
        prefixText: prefix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final manualEntry = !_isKnownProduct;
    return Scaffold(
      backgroundColor: const Color(0xffF6F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xffF6F7F9),
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Product details'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: manualEntry ? const Color(0xffFFF1DD) : const Color(0xffE3F6F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(manualEntry ? Icons.edit_note : Icons.verified_outlined,
                        color: manualEntry ? Colors.orange : Colors.teal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        manualEntry
                            ? 'Product was not found. Enter the name and printed MRP from the package.'
                            : 'Product details found. Verify the MRP printed on the package before continuing.',
                      ),
                    ),
                  ],
                ),
              ),
              if (_loadError != null) ...[
                const SizedBox(height: 12),
                Text(_loadError!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 20),
              Text('Barcode: ${widget.barcode}', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration('Product name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the product name'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _mrpController,
                keyboardType: TextInputType.number,
                decoration: _decoration('Printed MRP', prefix: '₹ '),
                validator: (value) {
                  final amount = int.tryParse(value?.trim() ?? '');
                  return amount == null || amount <= 0 ? 'Enter a valid printed MRP' : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _chargedPriceController,
                keyboardType: TextInputType.number,
                decoration: _decoration('Price charged by shop', prefix: '₹ '),
                validator: (value) {
                  final amount = int.tryParse(value?.trim() ?? '');
                  return amount == null || amount <= 0 ? 'Enter the price charged' : null;
                },
              ),
              if (manualEntry) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xffF1F4FF), borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Help add this product', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Capture the package front and back. Review any OCR result against the printed label.'),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton.icon(
                          onPressed: _readingPackage ? null : () => _pickPackageImage(isFront: true),
                          icon: Icon(_frontImage == null ? Icons.camera_alt_outlined : Icons.check_circle_outline),
                          label: Text(_frontImage == null ? 'Package front' : 'Front added'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _readingPackage ? null : () => _pickPackageImage(isFront: false),
                          icon: Icon(_backImage == null ? Icons.check_box_outline_blank : Icons.check_circle_outline),
                          label: Text(_backImage == null ? 'Package back' : 'Back added'),
                        ),
                      ]),
                      if (_readingPackage) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
                      if (_ocrText.isNotEmpty) const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('OCR extracted text is unverified. Correct the fields above before continuing.'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _submittingProduct ? null : _submitForReview,
                        icon: _submittingProduct
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_file_outlined),
                        label: const Text('Submit for catalog review'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _checkPrice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0D1B2A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Check price'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
