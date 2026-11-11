import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:priceshield/core/services/auth_session.dart';
import 'package:priceshield/core/services/cloudinary_upload_service.dart';
import 'package:priceshield/core/services/gs1_india_brand_resolver.dart';
import 'package:priceshield/core/services/priceshield_api_client.dart';
import 'package:priceshield/core/theme/app_theme.dart';
import 'package:priceshield/core/widgets/app_ui.dart';
import 'package:priceshield/features/scanner/presentation/screens/scan_result_screen.dart';
import 'package:priceshield/features/scanner/services/packaging_compliance_service.dart';

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
  bool _isReferenceEstimate = false;
  String? _productSource;
  String? _mrpDisclaimer;
  String? _loadError;
  Gs1BrandInfo? _detectedBrandInfo;
  File? _frontImage;
  File? _backImage;
  String _ocrText = '';
  PackagingComplianceResult? _complianceResult;
  bool _readingPackage = false;
  bool _submittingProduct = false;
  bool _isStickerFlagged = false;
  String _venueType = 'RETAIL';
  num? _catalogBaseMrp;

  @override
  void initState() {
    super.initState();
    final cached = priceShieldApi.getCachedProduct(widget.barcode);
    if (cached != null) {
      _nameController.text = cached['name']?.toString() ?? '';
      final mrp = num.tryParse(cached['mrp']?.toString() ?? '');
      _catalogBaseMrp = mrp;
      _mrpController.text = (mrp != null && mrp > 0) ? mrp.toString() : '';
      _isKnownProduct =
          _nameController.text.isNotEmpty && _mrpController.text.isNotEmpty;
      _productSource = cached['source']?.toString();
      _mrpDisclaimer = cached['mrpDisclaimer']?.toString();
      _isReferenceEstimate = cached['isReferenceEstimate'] == true || _isKnownProduct;
      _loading = false;
    } else {
      _fetchProduct();
    }
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
      _catalogBaseMrp = mrp;
      _mrpController.text = (mrp != null && mrp > 0) ? mrp.toString() : '';
      _isKnownProduct =
          _nameController.text.isNotEmpty && _mrpController.text.isNotEmpty;
      _productSource = product['source']?.toString();
      _mrpDisclaimer = product['mrpDisclaimer']?.toString();
      _isReferenceEstimate = product['isReferenceEstimate'] == true || _isKnownProduct;
      _loadError = null;

      if (_nameController.text.trim().isEmpty) {
        final brand = Gs1IndiaBrandResolver.resolve(widget.barcode);
        if (brand != null) {
          _detectedBrandInfo = brand;
          _nameController.text = '${brand.brandName} (${brand.category})';
        }
      }
    } on PriceShieldApiException catch (e) {
      _isKnownProduct = false;
      final brand = Gs1IndiaBrandResolver.resolve(widget.barcode);
      if (brand != null) {
        _detectedBrandInfo = brand;
        _nameController.text = '${brand.brandName} (${brand.category})';
      }
      if (e.statusCode == 404) {
        // Product not found in local catalog or OFF fallback.
        // Ready for instant on-device OCR / manual input without noisy error banner.
        _loadError = null;
      } else {
        _loadError = e.message;
      }
    } catch (_) {
      _isKnownProduct = false;
      final brand = Gs1IndiaBrandResolver.resolve(widget.barcode);
      if (brand != null) {
        _detectedBrandInfo = brand;
        _nameController.text = '${brand.brandName} (${brand.category})';
      }
      _loadError = 'Could not reach server. You can enter details manually.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _checkPrice() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final mrp = num.tryParse(_mrpController.text.trim());
    final charged = num.tryParse(_chargedPriceController.text.trim());
    if (mrp == null || charged == null || mrp <= 0 || charged <= 0) return;

    // Cache locally for fast retrieval on repeated scans in this session
    priceShieldApi.cacheProduct(widget.barcode, {
      'barcode': widget.barcode,
      'name': _nameController.text.trim(),
      'mrp': mrp,
      'source': _productSource ?? 'user_verified_session',
      'isReferenceEstimate': true,
    });

    if (!_isKnownProduct && AuthSession.isSignedIn) {
      // Queue for backend moderation review asynchronously
      priceShieldApi.createProductSubmission(
        barcode: widget.barcode,
        productName: _nameController.text.trim(),
        printedMrp: mrp,
        ocrText: _ocrText,
      ).catchError((_) => <String, dynamic>{});
    }

    PackagingComplianceResult compliance =
        _complianceResult ?? PackagingComplianceService.analyze(_ocrText);
    if (_isStickerFlagged && !compliance.hasViolation) {
      compliance = PackagingComplianceResult.stickerTampered;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ScanResultScreen(
          name: _nameController.text.trim(),
          barcode: widget.barcode,
          mrp: mrp,
          charged: charged,
          complianceResult: compliance.hasViolation ? compliance : null,
          venueType: _venueType,
          isStickerFlagged: _isStickerFlagged,
        ),
      ),
    );
  }

  Future<void> _pickPackageImage({required bool isFront}) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;
    final image = File(picked.path);
    setState(() {
      if (isFront) {
        _frontImage = image;
      } else {
        _backImage = image;
      }
    });
    await _readPackageText(image);
  }

  num? _extractMrpFromOcr(String text) {
    // 1. Standard OCR match:
    final match = RegExp(
      r'(?:(?:M\.?\s*R\.?\s*P\.?|MAX(?:IMUM)?\.?\s*RETAIL\s*PRICE)(?:\s*\([^)]*\))?|INCL\.?\s*OF\s*ALL\s*TAXES|Rs\.?|INR|₹)\s*[:\.\-]?\s*(?:Rs\.?|INR|₹)?\s*(\d+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      return num.tryParse(match.group(1)!);
    }

    // 2. Chilled bottle / condensation de-noised match:
    // Handles OCR digit/character substitutions like 'O'/'o' -> '0', 'S'/'s' -> '5', 'l'/'I' -> '1', '2O' -> '20'
    final fuzzyMatch = RegExp(
      r'(?:M\.?\s*R\.?\s*P\.?|MAX\.?\s*PRICE|Rs\.?|₹)\s*[:\.\-]?\s*(?:Rs\.?|₹)?\s*([0-9OoSlIB]{1,4}(?:[\.,][0-9Oo]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (fuzzyMatch != null) {
      final cleaned = fuzzyMatch
          .group(1)!
          .replaceAll(RegExp(r'[Oo]'), '0')
          .replaceAll(RegExp(r'[Ss]'), '5')
          .replaceAll(RegExp(r'[lIB]'), '1')
          .replaceAll(',', '.');
      return num.tryParse(cleaned);
    }
    return null;
  }

  Future<void> _readPackageText(File image) async {
    setState(() => _readingPackage = true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFile(image));
      final text = result.text.trim();
      if (text.isNotEmpty) {
        _ocrText = [_ocrText, text].where((item) => item.isNotEmpty).join('\n');

        // Analyze packaging compliance from extracted OCR
        final compliance = PackagingComplianceService.analyze(_ocrText);
        if (compliance.hasViolation) {
          _complianceResult = compliance;
        }

        // Robust & fuzzy OCR printed MRP extraction:
        final extractedMrp = _extractMrpFromOcr(_ocrText);
        if (_mrpController.text.trim().isEmpty && extractedMrp != null && extractedMrp > 0) {
          _mrpController.text = extractedMrp.toString();
        }

        // Suggest name from first clear title-like line if currently empty
        if (_nameController.text.trim().isEmpty) {
          final lines = text.split('\n').map((l) => l.trim()).where((l) => l.length >= 3);
          for (final line in lines) {
            final lower = line.toLowerCase();
            if (!lower.startsWith('mrp') &&
                !lower.startsWith('mfg') &&
                !lower.startsWith('exp') &&
                !lower.startsWith('batch') &&
                !lower.startsWith('net') &&
                !lower.startsWith('pkd') &&
                !lower.startsWith('packed') &&
                !lower.startsWith('use by') &&
                !lower.startsWith('best before') &&
                !lower.startsWith('fssai') &&
                !lower.startsWith('lic') &&
                !lower.startsWith('qty') &&
                !lower.startsWith('weight') &&
                !lower.startsWith('ingredients') &&
                !lower.startsWith('nutrition') &&
                !RegExp(r'^\d+$').hasMatch(line)) {
              _nameController.text = line;
              break;
            }
          }
        }

        if (mounted) {
          final compliance = _complianceResult;
          String toastText;
          if (compliance != null && compliance.hasViolation) {
            toastText = extractedMrp != null
                ? 'Extracted MRP: \u{20B9}$extractedMrp • ⚠️ ${compliance.title}'
                : '⚠️ ${compliance.title}: ${compliance.matchedSnippet ?? ''}';
          } else {
            toastText = extractedMrp != null
                ? 'Extracted MRP: \u{20B9}$extractedMrp'
                : 'Text scanned. Verify fields below.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(toastText),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text could not be read. Enter the package details manually.')),
        );
      }
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _readingPackage = false);
    }
  }

  Future<void> _submitForReview() async {
    if (_frontImage == null && _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a front or back photo of the package to submit.'),
          backgroundColor: PriceShieldColors.navy,
        ),
      );
      return;
    }
    setState(() => _submittingProduct = true);
    try {
      final frontUpload = _frontImage == null
          ? null
          : await CloudinaryUploadService.uploadFile(file: _frontImage!, isVideo: false);
      final backUpload = _backImage == null
          ? null
          : await CloudinaryUploadService.uploadFile(file: _backImage!, isVideo: false);
      final parsedMrp = num.tryParse(_mrpController.text.trim());
      if (!priceShieldApi.isConfigured) {
        throw const PriceShieldApiException('Service is temporarily unavailable. Please try again.');
      }
      await priceShieldApi.createProductSubmission(
        barcode: widget.barcode,
        productName: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        printedMrp: parsedMrp,
        ocrText: _ocrText,
        frontImageUrl: frontUpload?.secureUrl,
        backImageUrl: backUpload?.secureUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submitted for moderation review. Approved updates help keep the catalog accurate.'),
            backgroundColor: PriceShieldColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        final cleanMsg = error is PriceShieldApiException
            ? error.message
            : error
                .toString()
                .replaceAll('Bad state: ', '')
                .replaceAll('Exception: ', '')
                .replaceAll('StateError: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanMsg.isNotEmpty ? cleanMsg : 'Could not submit product details.'),
            backgroundColor: PriceShieldColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingProduct = false);
    }
  }

  String _sourceLabel(String? source) {
    switch (source) {
      case 'offline_reference_catalog':
        return 'Offline Reference Catalog';
      case 'catalog_db':
        return 'PriceShield Reference Catalog';
      case 'open_food_facts':
        return 'Open Food Facts';
      case 'open_beauty_facts':
        return 'Open Beauty Facts';
      case 'open_products_facts':
        return 'Open Products Facts';
      default:
        return 'Reference Catalog';
    }
  }

  InputDecoration _decoration(String label, {String? prefix}) => InputDecoration(
        labelText: label,
        prefixText: prefix,
        filled: true,
        fillColor: PriceShieldColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: PriceShieldColors.background, body: Center(child: CircularProgressIndicator(color: PriceShieldColors.primary)));
    }
    final hasName = _nameController.text.trim().isNotEmpty;
    final hasMrp = _mrpController.text.trim().isNotEmpty;
    final isFullyVerified = _isKnownProduct && hasName && hasMrp;
    final manualEntry = !isFullyVerified;
    final bannerMessage = isFullyVerified
        ? (_mrpDisclaimer ??
            'Catalog reference (${_sourceLabel(_productSource)}). Always verify the MRP printed on the physical package before checking.')
        : hasName
            ? 'Product reference found! Enter or verify the printed MRP from the package.'
            : 'Product not found in catalog. Enter the name and printed MRP from the package.';
    final bannerColor = isFullyVerified
        ? PriceShieldColors.mint
        : hasName
            ? const Color(0xffe8f4fd)
            : const Color(0xfffff7e8);
    final bannerIcon = isFullyVerified
        ? Icons.verified_outlined
        : hasName
            ? Icons.info_outline_rounded
            : Icons.edit_note;
    final bannerIconColor = isFullyVerified
        ? PriceShieldColors.primary
        : hasName
            ? const Color(0xff0284c7)
            : PriceShieldColors.warning;

    return Scaffold(
      backgroundColor: PriceShieldColors.background,
      appBar: AppBar(
        backgroundColor: PriceShieldColors.background,
        foregroundColor: PriceShieldColors.text,
        elevation: 0,
        title: const Text('Product details'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                color: bannerColor,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(bannerIcon, color: bannerIconColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(bannerMessage),
                    ),
                  ],
                ),
              ),
              if (manualEntry) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xffEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xffBFDBFE)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.stars_rounded, color: Color(0xff2563EB), size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Contribute to PriceShield Catalog: Submit verified packet details for moderation review.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_complianceResult != null && _complianceResult!.hasViolation) ...[
                const SizedBox(height: 12),
                AppCard(
                  color: const Color(0xffFFFBEB),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xffD97706), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _complianceResult!.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xff92400E),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _complianceResult!.description,
                              style: const TextStyle(fontSize: 12, color: Color(0xff78350F), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_loadError != null) ...[
                const SizedBox(height: 12),
                Text(_loadError!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 20),
              AppCard(child: Row(children: [const Icon(Icons.qr_code_2_rounded, color: PriceShieldColors.primary), const SizedBox(width: 10), Expanded(child: Text('Barcode: ${widget.barcode}', style: const TextStyle(color: PriceShieldColors.muted)))])),
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _decoration('Printed MRP', prefix: '₹ '),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final amount = num.tryParse(value?.trim() ?? '');
                  return amount == null || amount <= 0 ? 'Enter a valid printed MRP' : null;
                },
              ),
              if (_isReferenceEstimate && _isKnownProduct) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xff0284C7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reference estimate (${_sourceLabel(_productSource)}) — MRP varies by batch/pack; confirm on the packet.',
                        style: const TextStyle(fontSize: 11, color: Color(0xff0369A1)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ...(_detectedBrandInfo?.suggestedMrps ?? const [10, 15, 20, 25, 30, 40, 50]).map(
                    (val) {
                      final selected = _mrpController.text == val.toString();
                      return ChoiceChip(
                        label: Text('₹$val'),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _mrpController.text = val.toString();
                          });
                        },
                        selectedColor: const Color(0xffE8F8F5),
                        backgroundColor: const Color(0xffF8FAFC),
                        side: BorderSide(
                          color: selected ? const Color(0xff2BAE9A) : const Color(0xffE2E8F0),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? const Color(0xff2BAE9A) : const Color(0xff475569),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (_catalogBaseMrp != null &&
                  num.tryParse(_mrpController.text.trim()) != null &&
                  num.parse(_mrpController.text.trim()) < _catalogBaseMrp!) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xffFDBA74)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Color(0xffEA580C), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '📦 Batch-Bound MRP (Rule 18(2)): Catalog standard is ₹$_catalogBaseMrp, but this unit has printed ₹${_mrpController.text.trim()}. Retailer cannot charge revised rates on old batch stock.',
                          style: const TextStyle(fontSize: 11, color: Color(0xff9A3412), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _chargedPriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _decoration('Price charged by shop', prefix: '₹ '),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final amount = num.tryParse(value?.trim() ?? '');
                  return amount == null || amount <= 0 ? 'Enter the price charged' : null;
                },
              ),
              if (_mrpController.text.trim().isNotEmpty && num.tryParse(_mrpController.text) != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: Text('Exact MRP (₹${_mrpController.text})'),
                      onPressed: () {
                        setState(() => _chargedPriceController.text = _mrpController.text);
                      },
                      backgroundColor: const Color(0xffF1F5F9),
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xff334155)),
                    ),
                    ActionChip(
                      label: Text('+₹5 Surcharge (₹${(num.parse(_mrpController.text) + 5).toStringAsFixed(0)})'),
                      onPressed: () {
                        setState(() {
                          final base = num.parse(_mrpController.text);
                          _chargedPriceController.text = (base + 5).toStringAsFixed(0);
                        });
                      },
                      backgroundColor: const Color(0xffFEE2E2),
                      side: const BorderSide(color: Color(0xffFCA5A5)),
                      labelStyle: const TextStyle(color: Color(0xffDC2626), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    ActionChip(
                      label: Text('+₹10 Surcharge (₹${(num.parse(_mrpController.text) + 10).toStringAsFixed(0)})'),
                      onPressed: () {
                        setState(() {
                          final base = num.parse(_mrpController.text);
                          _chargedPriceController.text = (base + 10).toStringAsFixed(0);
                        });
                      },
                      backgroundColor: const Color(0xffFEF2F2),
                      side: const BorderSide(color: Color(0xffFECACA)),
                      labelStyle: const TextStyle(color: Color(0xffB91C1C), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ],
              // Sticker Overwrite / Tampered MRP Toggle
              InkWell(
                onTap: () => setState(() => _isStickerFlagged = !_isStickerFlagged),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isStickerFlagged ? const Color(0xffFEF2F2) : const Color(0xffF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isStickerFlagged ? const Color(0xffEF4444) : const Color(0xffE2E8F0),
                      width: _isStickerFlagged ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isStickerFlagged ? Icons.check_circle_rounded : Icons.label_off_outlined,
                        color: _isStickerFlagged ? const Color(0xffDC2626) : const Color(0xff64748B),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🏷️ Sticker / Tampered MRP Tag?',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _isStickerFlagged ? const Color(0xff991B1B) : const Color(0xff334155),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isStickerFlagged
                                  ? 'Flagged: Pasting price stickers over printed MRP is prohibited under Rule 18(2) — attach clear packet photo.'
                                  : 'Tap if shop placed a price sticker or marker over original MRP',
                              style: TextStyle(
                                fontSize: 11,
                                color: _isStickerFlagged ? const Color(0xffB91C1C) : const Color(0xff64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _isStickerFlagged,
                        onChanged: (val) => setState(() => _isStickerFlagged = val),
                        activeColor: const Color(0xffDC2626),
                      ),
                    ],
                  ),
                ),
              ),

              // Purchase Venue Context Selector
              const SizedBox(height: 18),
              const Text(
                'Purchase Venue Context',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PriceShieldColors.navy,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _venueType = 'RETAIL'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                        decoration: BoxDecoration(
                          color: _venueType == 'RETAIL' ? PriceShieldColors.mint : const Color(0xffF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _venueType == 'RETAIL' ? PriceShieldColors.primary : const Color(0xffE2E8F0),
                            width: _venueType == 'RETAIL' ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.storefront_rounded,
                              color: _venueType == 'RETAIL' ? PriceShieldColors.primary : const Color(0xff64748B),
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '🏪 Retail Shop / Kirana',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _venueType == 'RETAIL' ? PriceShieldColors.navy : const Color(0xff475569),
                              ),
                            ),
                            const Text(
                              'Strict MRP Applicable',
                              style: TextStyle(fontSize: 10, color: Color(0xff64748B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _venueType = 'RESTAURANT'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                        decoration: BoxDecoration(
                          color: _venueType == 'RESTAURANT' ? const Color(0xffFFFBEB) : const Color(0xffF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _venueType == 'RESTAURANT' ? const Color(0xffF59E0B) : const Color(0xffE2E8F0),
                            width: _venueType == 'RESTAURANT' ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.restaurant_rounded,
                              color: _venueType == 'RESTAURANT' ? const Color(0xffB45309) : const Color(0xff64748B),
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '🍽️ Dine-in Cafe / Hotel',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _venueType == 'RESTAURANT' ? const Color(0xff78350F) : const Color(0xff475569),
                              ),
                            ),
                            const Text(
                              'SC FHRAI 2017 Ruling',
                              style: TextStyle(fontSize: 10, color: Color(0xff64748B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_venueType == 'RESTAURANT') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xffFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xffFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xffD97706), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚖️ Supreme Court Ruling (FHRAI 2017): Seated restaurants providing table service & ambiance may legally charge above MRP. Over-the-counter takeaways, railway stalls, and kiranas cannot.',
                          style: TextStyle(fontSize: 11, color: Color(0xff92400E), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (manualEntry) ...[
                const SizedBox(height: 20),
                AppCard(
                  color: const Color(0xffF1F4FF),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Add Unlisted Product', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Take a photo of the package to auto-fill the price and product details.'),
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
                        child: Text('Details auto-detected. Please verify the product name and MRP above.'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _submittingProduct ? null : _submitForReview,
                        icon: _submittingProduct
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_file_outlined),
                        label: const Text('Save to community catalog'),
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
                    backgroundColor: PriceShieldColors.navy,
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
