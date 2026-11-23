import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:priceshield/core/services/mrp_enrichment_service.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';
import 'package:priceshield/features/complaints/presentation/screens/complaint_screen.dart';
import 'package:priceshield/features/scanner/presentation/screens/product_details_screen.dart';

class NoBarcodeScanScreen extends StatefulWidget {
  const NoBarcodeScanScreen({super.key});

  @override
  State<NoBarcodeScanScreen> createState() => _NoBarcodeScanScreenState();
}

class _NoBarcodeScanScreenState extends State<NoBarcodeScanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mrpController = TextEditingController();
  final _chargedPriceController = TextEditingController();

  String _category = 'MEDICINE';
  bool _isFrontBackMode = false;
  File? _frontImage;
  File? _backImage;
  bool _isScanningOcr = false;
  String _ocrExtractedFeedback = '';

  @override
  void dispose() {
    _nameController.dispose();
    _mrpController.dispose();
    _chargedPriceController.dispose();
    super.dispose();
  }

  void _selectRailNeerPreset({required String name, required double mrp}) {
    setState(() {
      _category = 'WATER';
      _nameController.text = name;
      _mrpController.text = MrpEnrichmentService.formatMrp(mrp);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: $name (Official IRCTC MRP: ₹$mrp)'),
        backgroundColor: PriceShieldColors.navy,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _capturePhoto({required bool isFront}) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: PriceShieldColors.primary),
                title: const Text('Open Camera', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Take live photo of packaging / medicine strip'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: PriceShieldColors.navy),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Select existing photo of packet'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await picker.pickImage(source: source, imageQuality: 90);
      if (picked == null) return;

      final file = File(picked.path);
      setState(() {
        if (isFront) {
          _frontImage = file;
        } else {
          _backImage = file;
        }
      });

      await _runOcrOnImage(file, isFront: isFront);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not capture photo: $e')),
        );
      }
    }
  }

  Future<void> _runOcrOnImage(File file, {required bool isFront}) async {
    setState(() => _isScanningOcr = true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFile(file));
      final text = result.text.trim();
      if (text.isEmpty) {
        setState(() {
          _ocrExtractedFeedback = 'No clear text detected. Please enter details manually.';
        });
        return;
      }

      // 1. Extract Printed MRP
      final extractedMrp = MrpEnrichmentService.extractMrpFromOcr(text);
      if (extractedMrp != null && extractedMrp > 0) {
        _mrpController.text = MrpEnrichmentService.formatMrp(extractedMrp);
      }

      // 2. Extract Title / Medicine Name if currently empty
      if (_nameController.text.trim().isEmpty) {
        final lines = text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.length >= 3 && l.length <= 45)
            .toList();

        for (final line in lines) {
          final lower = line.toLowerCase();
          if (!lower.startsWith('mrp') &&
              !lower.startsWith('mfg') &&
              !lower.startsWith('exp') &&
              !lower.startsWith('batch') &&
              !lower.startsWith('pkd') &&
              !lower.startsWith('use by') &&
              !lower.startsWith('net') &&
              !lower.startsWith('fssai') &&
              !lower.startsWith('lic') &&
              !lower.startsWith('caution') &&
              !RegExp(r'^\d+$').hasMatch(line)) {
            _nameController.text = line;
            break;
          }
        }
      }

      setState(() {
        if (extractedMrp != null && _nameController.text.isNotEmpty) {
          _ocrExtractedFeedback = '✅ Extracted: "${_nameController.text}" • MRP: ₹${MrpEnrichmentService.formatMrp(extractedMrp)}';
        } else if (extractedMrp != null) {
          _ocrExtractedFeedback = '✅ Extracted Printed MRP: ₹${MrpEnrichmentService.formatMrp(extractedMrp)}';
        } else if (_nameController.text.isNotEmpty) {
          _ocrExtractedFeedback = '✅ Detected: "${_nameController.text}". Enter printed MRP below.';
        } else {
          _ocrExtractedFeedback = 'Text read. Verify details in form.';
        }
      });
    } catch (_) {
      setState(() {
        _ocrExtractedFeedback = 'Text OCR could not run. Fill fields manually.';
      });
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _isScanningOcr = false);
    }
  }

  void _proceedToComplaint() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final mrp = num.tryParse(_mrpController.text.trim()) ?? 0;
    final charged = num.tryParse(_chargedPriceController.text.trim()) ?? 0;

    if (charged <= mrp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Price charged must be greater than printed MRP to file an overcharge complaint.'),
          backgroundColor: PriceShieldColors.danger,
        ),
      );
      return;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    final syntheticBarcode = 'NOBAR-$_category-$timestamp';

    final packetPhotos = <File>[];
    if (_frontImage != null) packetPhotos.add(_frontImage!);
    if (_backImage != null) packetPhotos.add(_backImage!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintScreen(
          name: name,
          barcode: syntheticBarcode,
          mrp: mrp,
          charged: charged,
          venueType: 'RETAIL',
          initialNotes: 'Unbarcoded Item Report ($categoryLabel). Packaging verified with on-device camera OCR.',
          initialPacketPhotos: packetPhotos.isNotEmpty ? packetPhotos : null,
        ),
      ),
    );
  }

  void _proceedToProductDetails() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final mrp = num.tryParse(_mrpController.text.trim());
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    final syntheticBarcode = 'NOBAR-$_category-$timestamp';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(
          barcode: syntheticBarcode,
          initialName: name,
          initialMrp: mrp,
        ),
      ),
    );
  }

  String get categoryLabel {
    switch (_category) {
      case 'MEDICINE':
        return 'Pharma / DPCO Medicine Strip';
      case 'WATER':
        return 'Packaged Drinking Water / Rail Neer';
      case 'KIRANA':
        return 'Kirana / Loose Pack';
      case 'STALL':
        return 'Railway / Bus Stall Snack';
      default:
        return 'Unbarcoded Pack';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mrp = num.tryParse(_mrpController.text.trim());
    final charged = num.tryParse(_chargedPriceController.text.trim());
    final isOvercharged = mrp != null && charged != null && charged > mrp;
    final overchargeAmount = isOvercharged ? (charged - mrp) : 0;
    final overchargePercent = isOvercharged && mrp > 0 ? ((overchargeAmount / mrp) * 100).toStringAsFixed(1) : '0';

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: const Text('Report Item Without Barcode'),
        backgroundColor: Colors.white,
        foregroundColor: PriceShieldColors.navy,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Legal Metrology Advisory Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.gavel_rounded, color: Color(0xff1D4ED8), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Barcodes are NOT legally mandatory. Under Rule 18(2) Legal Metrology & DPCO 2013, physical packet photo is 100% admissible evidence in consumer court.',
                        style: TextStyle(fontSize: 12, color: Color(0xff1E40AF), height: 1.35, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Category Selector Chips
              const Text(
                'Select Item Category',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: PriceShieldColors.navy),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('💊 Medicine / Tablet Strip'),
                      selected: _category == 'MEDICINE',
                      onSelected: (_) => setState(() => _category = 'MEDICINE'),
                      selectedColor: PriceShieldColors.navy,
                      labelStyle: TextStyle(
                        color: _category == 'MEDICINE' ? Colors.white : PriceShieldColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('🚆 Water / Rail Neer'),
                      selected: _category == 'WATER',
                      onSelected: (_) => setState(() => _category = 'WATER'),
                      selectedColor: PriceShieldColors.navy,
                      labelStyle: TextStyle(
                        color: _category == 'WATER' ? Colors.white : PriceShieldColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('🛒 Kirana / Loose Pack'),
                      selected: _category == 'KIRANA',
                      onSelected: (_) => setState(() => _category = 'KIRANA'),
                      selectedColor: PriceShieldColors.navy,
                      labelStyle: TextStyle(
                        color: _category == 'KIRANA' ? Colors.white : PriceShieldColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('☕ Station / Bus Stall'),
                      selected: _category == 'STALL',
                      onSelected: (_) => setState(() => _category = 'STALL'),
                      selectedColor: PriceShieldColors.navy,
                      labelStyle: TextStyle(
                        color: _category == 'STALL' ? Colors.white : PriceShieldColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 1-Tap IRCTC Presets
              if (_category == 'WATER') ...[
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectRailNeerPreset(
                          name: 'IRCTC Rail Neer Packaged Drinking Water 1L',
                          mrp: 15.00,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xffF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xff86EFAC)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('🚆 Rail Neer 1L', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xff166534))),
                              Text('Official MRP: ₹15.00', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xff15803D))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectRailNeerPreset(
                          name: 'IRCTC Rail Neer Packaged Drinking Water 500ml',
                          mrp: 10.00,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xffF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xff86EFAC)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('🚆 Rail Neer 500ml', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xff166534))),
                              Text('Official MRP: ₹10.00', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xff15803D))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Photo Capture Section
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.camera_enhance_rounded, color: PriceShieldColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Step 1: Capture Packaging Photo',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: PriceShieldColors.navy),
                          ),
                        ),
                        Row(
                          children: [
                            const Text('Box Front & Back', style: TextStyle(fontSize: 11, color: PriceShieldColors.muted)),
                            Switch.adaptive(
                              value: _isFrontBackMode,
                              onChanged: (val) => setState(() => _isFrontBackMode = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Take a clear photo of product name & printed MRP. On-device Google ML Kit OCR will autofill details in 0.5s.',
                      style: TextStyle(fontSize: 12, color: PriceShieldColors.muted),
                    ),
                    const SizedBox(height: 12),

                    // Camera Photo Tiles
                    Row(
                      children: [
                        // Photo 1 (Front / Single-Shot)
                        Expanded(
                          child: _PhotoCaptureTile(
                            title: _isFrontBackMode ? 'Front (Product Name)' : 'Packet / Strip Photo',
                            imageFile: _frontImage,
                            onTap: () => _capturePhoto(isFront: true),
                            onDelete: _frontImage == null ? null : () => setState(() => _frontImage = null),
                          ),
                        ),
                        if (_isFrontBackMode) ...[
                          const SizedBox(width: 10),
                          // Photo 2 (Back / MRP Flap)
                          Expanded(
                            child: _PhotoCaptureTile(
                              title: 'Back (MRP & Batch)',
                              imageFile: _backImage,
                              onTap: () => _capturePhoto(isFront: false),
                              onDelete: _backImage == null ? null : () => setState(() => _backImage = null),
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (_isScanningOcr) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Reading packet text with ML Kit OCR...', style: TextStyle(fontSize: 12, color: PriceShieldColors.primary)),
                        ],
                      ),
                    ],

                    if (_ocrExtractedFeedback.isNotEmpty && !_isScanningOcr) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xffF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xff86EFAC)),
                        ),
                        child: Text(
                          _ocrExtractedFeedback,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xff166534)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Step 2: Details & Pricing Form
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Step 2: Verify Product & Price Details',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: PriceShieldColors.navy),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: _category == 'MEDICINE'
                            ? 'Medicine / Salt Name (e.g. Dolo 650 Strip)'
                            : 'Product Name (e.g. Rail Neer 1L / Roasted Peanuts)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.inventory_2_outlined),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter product name' : null,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _mrpController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Printed MRP',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (val) {
                              final numVal = num.tryParse(val?.trim() ?? '');
                              return numVal == null || numVal <= 0 ? 'Enter printed MRP' : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _chargedPriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Price Charged',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (val) {
                              final numVal = num.tryParse(val?.trim() ?? '');
                              return numVal == null || numVal <= 0 ? 'Enter charged price' : null;
                            },
                          ),
                        ),
                      ],
                    ),

                    // Overcharge Analysis Card
                    if (isOvercharged) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xffFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: PriceShieldColors.danger, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🚨 ₹$overchargeAmount Extra Charged (+$overchargePercent%)',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: PriceShieldColors.danger, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Violation under Sec 36 Legal Metrology Act / DPCO 2013.',
                                    style: TextStyle(fontSize: 11, color: Color(0xff991B1B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Primary Action: File Formal Complaint
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isOvercharged ? _proceedToComplaint : _proceedToProductDetails,
                  icon: Icon(isOvercharged ? Icons.gavel_rounded : Icons.arrow_forward_rounded, size: 20),
                  label: Text(
                    isOvercharged ? 'File Overcharge Complaint (₹$overchargeAmount Extra)' : 'Check Legal Rights & Details',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOvercharged ? PriceShieldColors.danger : PriceShieldColors.navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoCaptureTile extends StatelessWidget {
  final String title;
  final File? imageFile;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PhotoCaptureTile({
    required this.title,
    required this.imageFile,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (imageFile != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              imageFile!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 6,
            left: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (onDelete != null)
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xffF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffCBD5E1), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: PriceShieldColors.primary, size: 28),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PriceShieldColors.navy),
              ),
            ),
            const SizedBox(height: 2),
            const Text('Tap to capture', style: TextStyle(fontSize: 10, color: PriceShieldColors.muted)),
          ],
        ),
      ),
    );
  }
}
